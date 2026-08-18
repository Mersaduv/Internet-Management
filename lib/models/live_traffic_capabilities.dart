/// Detected RouterOS traffic data sources on the connected device.
enum LiveTrafficSource {
  queueStats,
  kidControl,
  ipAccounting,
  hotspotActive,
  firewallConnection,
  none,
}

class LiveTrafficCapabilities {
  final LiveTrafficSource primary;
  final bool queueStats;
  final bool kidControl;
  final bool ipAccounting;
  final bool hotspotActive;
  final bool firewallConnection;
  final bool accountingLocalTraffic;
  final List<String> localNetworkCidrs;

  const LiveTrafficCapabilities({
    required this.primary,
    this.queueStats = false,
    this.kidControl = false,
    this.ipAccounting = false,
    this.hotspotActive = false,
    this.firewallConnection = false,
    this.accountingLocalTraffic = false,
    this.localNetworkCidrs = const [],
  });

  static const none = LiveTrafficCapabilities(
    primary: LiveTrafficSource.none,
  );
}
