import '../models/client_info.dart';
import '../models/client_traffic_rate.dart';
import '../utils/client_display_policy.dart';

/// Tracks live traffic samples keyed by client IP.
///
/// Samples arrive from RouterOS at poll cadence; [syncDisplayTick] publishes
/// them to the UI once per second (Task Manager style).
class ClientTrafficStore {
  final Map<String, ClientTrafficRate> _sampleRatesByIp = {};
  final Map<String, ClientTrafficRate> _displayRatesByIp = {};
  final Set<String> _measuredIps = {};
  final Map<String, int> _zeroSampleStreak = {};
  final Map<String, DateTime> _leftViewportAt = {};
  final Map<String, DateTime> _awaitingFirstAt = {};
  bool _pollReady = false;

  static const int _zeroWarmupPolls = 2;

  /// Keep last rate after a row leaves the viewport so re-entry is not a skeleton.
  Duration retainAfterLeave = const Duration(seconds: 5);

  /// After this, show idle instead of an infinite skeleton.
  Duration placeholderTimeout = const Duration(seconds: 3);

  /// IPs that left the poll viewport — allow fresh warmup when they re-enter.
  final Set<String> _viewportActiveIps = {};

  bool get pollReady => _pollReady;

  ({Set<String> ips, Map<String, String> macToIp}) trackingContext(
    List<ClientInfo> displayClients,
  ) {
    final ips = <String>{};
    final macToIp = <String, String>{};

    for (final client in displayClients) {
      if (!ClientDisplayPolicy.shouldShowInConnectedList(client)) {
        continue;
      }
      final ip = _normalizeIp(client.ipAddress);
      final mac = client.macAddress?.trim().toUpperCase();
      if (ip != null) {
        ips.add(ip);
      }
      if (mac != null && mac.isNotEmpty && ip != null) {
        macToIp[mac] = ip;
      }
    }

    return (ips: ips, macToIp: macToIp);
  }

  Set<String> newIpsSinceLastPoll(Set<String> currentIps) {
    if (!_pollReady) {
      return currentIps;
    }
    return currentIps.difference(_measuredIps);
  }

  bool isMeasured(String? ip) {
    final normalized = _normalizeIp(ip);
    if (normalized == null) {
      return false;
    }
    return _measuredIps.contains(normalized);
  }

  /// Latest one-second display frame (Task Manager cadence).
  ClientTrafficRate? rateFor(String? ip) {
    final normalized = _normalizeIp(ip);
    if (normalized == null) {
      return null;
    }
    return _displayRatesByIp[normalized] ?? _sampleRatesByIp[normalized];
  }

  /// True when a visible IP has waited too long for its first sample.
  bool awaitingFirstSampleTimedOut(String? ip, {DateTime? now}) {
    final normalized = _normalizeIp(ip);
    if (normalized == null || _measuredIps.contains(normalized)) {
      return false;
    }
    final started = _awaitingFirstAt[normalized];
    if (started == null) {
      return false;
    }
    return (now ?? DateTime.now()).difference(started) >= placeholderTimeout;
  }

  /// Any unmeasured IP currently in the poll window (for a one-shot UI timer).
  bool get hasUnmeasuredActiveIps {
    for (final ip in _viewportActiveIps) {
      if (!_measuredIps.contains(ip)) {
        return true;
      }
    }
    return false;
  }

  /// Viewport poll set changed — keep recent rates so scrolling is not a shock.
  void onViewportChanged(Set<String> activeIps, {DateTime? now}) {
    final clock = now ?? DateTime.now();

    for (final ip in _viewportActiveIps.difference(activeIps)) {
      _leftViewportAt.putIfAbsent(ip, () => clock);
    }
    for (final ip in activeIps) {
      _leftViewportAt.remove(ip);
      if (!_measuredIps.contains(ip)) {
        _awaitingFirstAt.putIfAbsent(ip, () => clock);
      }
    }
    for (final ip in activeIps.difference(_viewportActiveIps)) {
      _zeroSampleStreak.remove(ip);
    }

    _viewportActiveIps
      ..clear()
      ..addAll(activeIps);
    _pruneLeft(clock);
  }

  /// Stores raw poll samples (bps). UI reads via [syncDisplayTick].
  ///
  /// Returns true when at least one IP got its first measurement (hide skeleton).
  bool applyPoll({
    required Set<String> trackedIps,
    required Map<String, ClientTrafficRate> samples,
    required bool Function(int?, int?) rateChanged,
    DateTime? fallbackSampledAt,
  }) {
    if (samples.isNotEmpty) {
      _pollReady = true;
    }
    var firstMeasurement = false;

    for (final ip in trackedIps) {
      final sample = samples[ip];
      if (sample == null) {
        continue;
      }

      final isZero = sample.rxBps == 0 && sample.txBps == 0;
      if (isZero) {
        final streak = (_zeroSampleStreak[ip] ?? 0) + 1;
        _zeroSampleStreak[ip] = streak;
        if (!_measuredIps.contains(ip) && streak < _zeroWarmupPolls) {
          continue;
        }
      } else {
        _zeroSampleStreak.remove(ip);
      }

      final wasMeasured = _measuredIps.contains(ip);
      _sampleRatesByIp[ip] = sample;
      _measuredIps.add(ip);
      _awaitingFirstAt.remove(ip);

      if (!wasMeasured) {
        _displayRatesByIp[ip] = sample;
        firstMeasurement = true;
      }
    }

    return firstMeasurement;
  }

  /// Publishes the latest samples to the UI on a fixed one-second cadence.
  bool syncDisplayTick() {
    var changed = false;
    for (final entry in _sampleRatesByIp.entries) {
      final ip = entry.key;
      if (!_viewportActiveIps.contains(ip) && !_displayRatesByIp.containsKey(ip)) {
        continue;
      }
      final sample = entry.value;
      final previous = _displayRatesByIp[ip];
      if (previous != null &&
          previous.rxBps == sample.rxBps &&
          previous.txBps == sample.txBps) {
        continue;
      }
      _displayRatesByIp[ip] = sample;
      changed = true;
    }
    return changed;
  }

  void reset() {
    _sampleRatesByIp.clear();
    _displayRatesByIp.clear();
    _measuredIps.clear();
    _zeroSampleStreak.clear();
    _viewportActiveIps.clear();
    _leftViewportAt.clear();
    _awaitingFirstAt.clear();
    _pollReady = false;
  }

  void _pruneLeft(DateTime now) {
    final expired = <String>[];
    for (final entry in _leftViewportAt.entries) {
      if (now.difference(entry.value) >= retainAfterLeave) {
        expired.add(entry.key);
      }
    }
    for (final ip in expired) {
      _leftViewportAt.remove(ip);
      if (_viewportActiveIps.contains(ip)) {
        continue;
      }
      _sampleRatesByIp.remove(ip);
      _displayRatesByIp.remove(ip);
      _measuredIps.remove(ip);
      _zeroSampleStreak.remove(ip);
      _awaitingFirstAt.remove(ip);
    }
  }

  String? _normalizeIp(String? ip) {
    final trimmed = ip?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == '0.0.0.0') {
      return null;
    }
    return trimmed;
  }
}
