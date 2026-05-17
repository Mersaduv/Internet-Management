import 'dart:async';

import 'package:flutter/widgets.dart';

/// Keeps the RouterOS API connection warm and reconnects after idle drops.
class ConnectionHeartbeat with WidgetsBindingObserver {
  ConnectionHeartbeat({
    required Future<bool> Function() healthCheck,
    required Future<bool> Function() reconnect,
    this.interval = const Duration(seconds: 45),
  })  : _healthCheck = healthCheck,
        _reconnect = reconnect;

  final Future<bool> Function() _healthCheck;
  final Future<bool> Function() _reconnect;
  final Duration interval;

  Timer? _timer;
  bool _running = false;
  bool _tickInProgress = false;

  void start() {
    if (_running) {
      return;
    }
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    print('[HEARTBEAT] started (interval=${interval.inSeconds}s)');
    _schedulePeriodic();
  }

  void stop() {
    if (!_running) {
      return;
    }
    print('[HEARTBEAT] stopped');
    _running = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void _schedulePeriodic() {
    _timer?.cancel();
    if (!_running) {
      return;
    }
    _timer = Timer.periodic(interval, (_) {
      unawaited(_tick());
    });
  }

  Future<void> _tick() async {
    if (!_running || _tickInProgress) {
      return;
    }
    _tickInProgress = true;
    try {
      final healthy = await _healthCheck();
      print('[HEARTBEAT] healthCheck=$healthy');
      if (!healthy) {
        final reconnected = await _reconnect();
        print('[HEARTBEAT] reconnect=$reconnected');
      }
    } catch (e) {
      print('[HEARTBEAT] tick error: $e');
    } finally {
      _tickInProgress = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('[HEARTBEAT] app resumed — scheduling check');
      _timer?.cancel();
      _timer = null;
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (_running) {
          unawaited(_tick());
          _schedulePeriodic();
        }
      });
      return;
    }

    print('[HEARTBEAT] app $state — pausing timer');
    _timer?.cancel();
    _timer = null;
  }
}
