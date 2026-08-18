import '../models/client_info.dart';

/// Shared rules for identifying the device running this app.
class CurrentDevicePolicy {
  CurrentDevicePolicy._();

  static String? normalizeIp(String? raw) {
    if (raw == null) {
      return null;
    }
    final value = raw.trim();
    if (value.isEmpty || value == '0.0.0.0') {
      return null;
    }
    return value;
  }

  static String? normalizeMac(String? raw) {
    if (raw == null) {
      return null;
    }
    final value = raw.trim().toUpperCase();
    return value.isEmpty ? null : value;
  }

  static bool ipsEqual(String? a, String? b) {
    final left = normalizeIp(a);
    final right = normalizeIp(b);
    if (left == null || right == null) {
      return false;
    }
    return left == right;
  }

  static bool sameSlash24(String a, String b) {
    final left = a.split('.');
    final right = b.split('.');
    if (left.length != 4 || right.length != 4) {
      return false;
    }
    return left[0] == right[0] &&
        left[1] == right[1] &&
        left[2] == right[2];
  }

  static ClientInfo? findClientByIp(
    Iterable<ClientInfo> clients,
    String? ip,
  ) {
    final normalized = normalizeIp(ip);
    if (normalized == null) {
      return null;
    }
    for (final client in clients) {
      if (ipsEqual(client.ipAddress, normalized)) {
        return client;
      }
    }
    return null;
  }

  static String? macForDeviceIp(
    Iterable<ClientInfo> clients,
    String? deviceIp,
  ) {
    return normalizeMac(findClientByIp(clients, deviceIp)?.macAddress);
  }

  /// Picks the best IP for "this device" using OS + router + client list.
  static String? pickBestDeviceIp({
    String? localIp,
    String? routerReportedIp,
    Iterable<ClientInfo> clients = const [],
    String? routerHost,
  }) {
    final local = normalizeIp(localIp);
    final router = normalizeIp(routerReportedIp);
    final host = normalizeIp(routerHost);
    final clientIps = clients
        .map((client) => normalizeIp(client.ipAddress))
        .whereType<String>()
        .toSet();

    if (local != null && clientIps.contains(local)) {
      return local;
    }
    if (router != null && clientIps.contains(router)) {
      return router;
    }
    if (local != null && host != null && sameSlash24(local, host)) {
      return local;
    }
    if (router != null && host != null && sameSlash24(router, host)) {
      return router;
    }
    return local ?? router;
  }

  static bool isCurrentDevice({
    required ClientInfo client,
    String? deviceIp,
    String? deviceMac,
    Iterable<ClientInfo> clients = const [],
  }) {
    if (ipsEqual(client.ipAddress, deviceIp)) {
      return true;
    }

    final clientMac = normalizeMac(client.macAddress);
    final currentMac =
        normalizeMac(deviceMac) ?? macForDeviceIp(clients, deviceIp);
    if (clientMac != null &&
        currentMac != null &&
        clientMac == currentMac) {
      return true;
    }

    return false;
  }

  static bool isCurrentTarget({
    required String ipAddress,
    String? macAddress,
    String? deviceIp,
    String? deviceMac,
    Iterable<ClientInfo> clients = const [],
  }) {
    if (ipsEqual(ipAddress, deviceIp)) {
      return true;
    }

    final normalizedMac = normalizeMac(macAddress);
    final currentMac =
        normalizeMac(deviceMac) ?? macForDeviceIp(clients, deviceIp);
    return normalizedMac != null &&
        currentMac != null &&
        normalizedMac == currentMac;
  }
}
