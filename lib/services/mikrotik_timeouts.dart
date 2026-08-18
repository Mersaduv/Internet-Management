/// Central RouterOS API timeout values — keep queue wait predictable.
abstract final class MikrotikTimeouts {
  static const Duration login = Duration(seconds: 8);
  static const Duration defaultTalk = Duration(seconds: 10);
  static const Duration phaseTalk = Duration(seconds: 15);
  static const Duration healthCheck = Duration(seconds: 3);
  static const Duration trafficPoll = Duration(seconds: 4);

  /// Scale traffic poll timeout with connected client count.
  static Duration trafficPollForClients(int clientCount) {
    if (clientCount <= 20) {
      return trafficPoll;
    }
    if (clientCount <= 50) {
      return const Duration(seconds: 8);
    }
    if (clientCount <= 80) {
      return const Duration(seconds: 12);
    }
    return const Duration(seconds: 16);
  }

  /// Full sample timeout including optional one-time monitor queue provisioning.
  static Duration trafficSampleTimeout(int clientCount) {
    final poll = trafficPollForClients(clientCount);
    final provisionMs = (clientCount * 250).clamp(0, 45000);
    return poll + Duration(milliseconds: provisionMs);
  }
  static const Duration phase1 = Duration(seconds: 20);
  static const Duration onlineRefresh = Duration(seconds: 12);
  static const Duration isolatedConnect = Duration(seconds: 8);
  static const Duration userOperation = Duration(seconds: 45);

  static const Duration trafficPollInterval = Duration(milliseconds: 500);
  static const Duration trafficPollIntervalFallback = Duration(milliseconds: 1000);
  static const Duration statusRefreshInterval = Duration(seconds: 30);
}
