import 'client_traffic_rate.dart';

/// Result of one live-traffic poll.
class TrafficRatesSnapshot {
  final Map<String, ClientTrafficRate> ratesByIp;
  final Map<String, ({int bytesIn, int bytesOut})> hotspotBytes;

  const TrafficRatesSnapshot({
    required this.ratesByIp,
    required this.hotspotBytes,
  });
}
