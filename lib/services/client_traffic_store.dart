import '../models/client_info.dart';
import '../models/client_traffic_rate.dart';
import '../utils/client_display_policy.dart';

/// Tracks live traffic samples keyed by client IP.
///
/// Decoupled from [ClientsProvider] list mutations so pending-approval devices
/// (dynamic DHCP leases) stay in the poll set as soon as they appear in the UI.
class ClientTrafficStore {
  final Map<String, ClientTrafficRate> _ratesByIp = {};
  final Set<String> _measuredIps = {};
  bool _pollReady = false;

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

  ClientTrafficRate? rateFor(String? ip) {
    final normalized = _normalizeIp(ip);
    if (normalized == null) {
      return null;
    }
    return _ratesByIp[normalized];
  }

  /// Applies one poll result. Every tracked IP gets an entry (0 bps if absent).
  bool applyPoll({
    required Set<String> trackedIps,
    required Map<String, ClientTrafficRate> samples,
    required bool Function(int?, int?) rateChanged,
    DateTime? fallbackSampledAt,
  }) {
    _pollReady = true;
    final sampledAt = fallbackSampledAt ?? DateTime.now();
    var anyChanged = false;

    for (final ip in trackedIps) {
      final sample = samples[ip] ??
          ClientTrafficRate(rxBps: 0, txBps: 0, sampledAt: sampledAt);
      final previous = _ratesByIp[ip];
      final firstSample = !_measuredIps.contains(ip);

      if (!firstSample &&
          previous != null &&
          !rateChanged(previous.rxBps, sample.rxBps) &&
          !rateChanged(previous.txBps, sample.txBps)) {
        _measuredIps.add(ip);
        continue;
      }

      _ratesByIp[ip] = sample;
      _measuredIps.add(ip);
      anyChanged = true;
    }

    return anyChanged;
  }

  void reset() {
    _ratesByIp.clear();
    _measuredIps.clear();
    _pollReady = false;
  }

  String? _normalizeIp(String? ip) {
    final trimmed = ip?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == '0.0.0.0') {
      return null;
    }
    return trimmed;
  }
}
