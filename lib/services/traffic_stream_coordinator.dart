import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/client_traffic_rate.dart';

/// Adaptive polling loop that pushes live traffic samples through a [Stream].
///
/// RouterOS queue stats (`/queue/simple/print =stats=`) expose instantaneous
/// router-side bit rates, so the loop targets ~500ms cadence when polls finish
/// quickly. Slower polls automatically back off to avoid piling up requests.
class TrafficStreamCoordinator {
  TrafficStreamCoordinator({
    required Future<Map<String, ClientTrafficRate>> Function() onSample,
    required void Function(Map<String, ClientTrafficRate> rates) onRates,
    required bool Function() shouldContinue,
    Duration Function(int pollDurationMs, int trackedCount)? intervalFor,
  })  : _onSample = onSample,
        _onRates = onRates,
        _shouldContinue = shouldContinue,
        _intervalFor = intervalFor ?? _defaultIntervalFor;

  final Future<Map<String, ClientTrafficRate>> Function() _onSample;
  final void Function(Map<String, ClientTrafficRate> rates) _onRates;
  final bool Function() _shouldContinue;
  final Duration Function(int pollDurationMs, int trackedCount) _intervalFor;

  final StreamController<Map<String, ClientTrafficRate>> _controller =
      StreamController<Map<String, ClientTrafficRate>>.broadcast();

  bool _running = false;
  int _generation = 0;
  int _lastTrackedCount = 0;
  bool _usesInstantQueueRates = true;
  Completer<void>? _sleep;
  bool _pendingWake = false;

  Stream<Map<String, ClientTrafficRate>> get stream => _controller.stream;
  bool get isRunning => _running;

  void configure({
    required int trackedCount,
    required bool usesInstantQueueRates,
  }) {
    _lastTrackedCount = trackedCount;
    _usesInstantQueueRates = usesInstantQueueRates;
  }

  void start() {
    if (_running) {
      return;
    }
    _running = true;
    final generation = ++_generation;
    unawaited(_runLoop(generation));
    debugPrint('[TRAFFIC_STREAM] started');
  }

  /// Interrupt the inter-poll sleep so a new viewport can be sampled promptly.
  void wake() {
    final sleep = _sleep;
    if (sleep != null && !sleep.isCompleted) {
      sleep.complete();
    } else {
      _pendingWake = true;
    }
  }

  void stop() {
    if (!_running) {
      return;
    }
    _running = false;
    _generation++;
    _pendingWake = false;
    final sleep = _sleep;
    if (sleep != null && !sleep.isCompleted) {
      sleep.complete();
    }
    debugPrint('[TRAFFIC_STREAM] stopped');
  }

  void dispose() {
    stop();
    unawaited(_controller.close());
  }

  Future<void> _runLoop(int generation) async {
    while (_running && generation == _generation && _shouldContinue()) {
      final stopwatch = Stopwatch()..start();
      try {
        final rates = await _onSample();
        if (!_running || generation != _generation) {
          break;
        }
        if (rates.isNotEmpty) {
          _onRates(rates);
          if (!_controller.isClosed) {
            _controller.add(Map<String, ClientTrafficRate>.from(rates));
          }
        }
      } catch (e, stackTrace) {
        debugPrint('[TRAFFIC_STREAM] sample failed: $e\n$stackTrace');
      }

      stopwatch.stop();
      if (!_running || generation != _generation) {
        break;
      }

      if (_pendingWake) {
        _pendingWake = false;
        continue;
      }

      var wait = _intervalFor(
        stopwatch.elapsedMilliseconds,
        _lastTrackedCount,
      );
      if (!_usesInstantQueueRates && wait.inMilliseconds < 800) {
        wait = const Duration(milliseconds: 800);
      }
      if (wait < const Duration(milliseconds: 1)) {
        wait = const Duration(milliseconds: 1);
      }

      _sleep = Completer<void>();
      try {
        await _sleep!.future.timeout(wait);
      } on TimeoutException {
        // Cadence elapsed.
      } finally {
        _sleep = null;
      }
    }
  }

  static Duration _defaultIntervalFor(int pollDurationMs, int trackedCount) {
    const targetMs = 1000;
    final remaining = targetMs - pollDurationMs;
    if (remaining >= 50) {
      return Duration(milliseconds: remaining);
    }
    if (pollDurationMs >= 3000) {
      return const Duration(milliseconds: 500);
    }
    return const Duration(milliseconds: 50);
  }
}
