/// Instantaneous traffic for one client IP.
class ClientTrafficRate {
  final int rxBps;
  final int txBps;
  final DateTime sampledAt;

  const ClientTrafficRate({
    required this.rxBps,
    required this.txBps,
    required this.sampledAt,
  });

  bool get hasTraffic => rxBps > 0 || txBps > 0;
}
