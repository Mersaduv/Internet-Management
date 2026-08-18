/// Parses Windows `route print` / `ipconfig` output for the IPv4 default gateway.
class WindowsDefaultRoute {
  const WindowsDefaultRoute({
    required this.gateway,
    this.interfaceIp,
    this.metric = 1 << 30,
  });

  final String gateway;
  final String? interfaceIp;
  final int metric;
}

class WindowsDefaultGatewayParser {
  WindowsDefaultGatewayParser._();

  static final RegExp _ipv4Regex = RegExp(r'^(?:\d{1,3}\.){3}\d{1,3}$');
  static final RegExp _defaultRouteRegex = RegExp(
    r'^\s*0\.0\.0\.0\s+0\.0\.0\.0\s+(\S+)\s+(\S+)\s+(\d+)\s*$',
  );
  static final RegExp _ipconfigGatewayRegex = RegExp(
    r'Default Gateway[ .\t]*:\s*(\d{1,3}(?:\.\d{1,3}){3})',
    caseSensitive: false,
  );

  static bool isValidIpv4(String? raw) {
    if (raw == null) {
      return false;
    }
    final value = raw.trim();
    if (value.isEmpty ||
        value == '0.0.0.0' ||
        value == '255.255.255.255' ||
        value.toLowerCase() == 'on-link') {
      return false;
    }
    if (!_ipv4Regex.hasMatch(value)) {
      return false;
    }
    final parts = value.split('.');
    for (final part in parts) {
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) {
        return false;
      }
    }
    return true;
  }

  static bool isPrivateIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      return false;
    }
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) {
      return false;
    }
    if (a == 10) {
      return true;
    }
    if (a == 192 && b == 168) {
      return true;
    }
    if (a == 172 && b >= 16 && b <= 31) {
      return true;
    }
    return false;
  }

  static bool sameSlash24(String a, String b) {
    final left = a.split('.');
    final right = b.split('.');
    if (left.length != 4 || right.length != 4) {
      return false;
    }
    return left[0] == right[0] && left[1] == right[1] && left[2] == right[2];
  }

  /// Parses IPv4 default routes from `route print` / `route print -4`.
  static List<WindowsDefaultRoute> parseRoutePrint(String output) {
    final routes = <WindowsDefaultRoute>[];
    for (final rawLine in output.split(RegExp(r'\r?\n'))) {
      final match = _defaultRouteRegex.firstMatch(rawLine);
      if (match == null) {
        continue;
      }
      final gateway = match.group(1)!;
      final interfaceIp = match.group(2)!;
      final metric = int.tryParse(match.group(3)!) ?? (1 << 30);
      if (!isValidIpv4(gateway)) {
        continue;
      }
      routes.add(
        WindowsDefaultRoute(
          gateway: gateway,
          interfaceIp: isValidIpv4(interfaceIp) ? interfaceIp : null,
          metric: metric,
        ),
      );
    }
    return routes;
  }

  /// Parses the first valid IPv4 default gateway from `ipconfig`.
  static String? parseIpconfig(String output) {
    for (final match in _ipconfigGatewayRegex.allMatches(output)) {
      final ip = match.group(1);
      if (isValidIpv4(ip)) {
        return ip;
      }
    }
    return null;
  }

  static bool looksLikeVpnIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      return false;
    }
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) {
      return false;
    }
    // OpenVPN / common virtual adapters
    if (a == 10 && (b == 8 || b == 9)) {
      return true;
    }
    return false;
  }

  /// Picks the LAN default gateway: same subnet as a local IP, then RFC1918, then lowest metric.
  static WindowsDefaultRoute? selectBestRoute(
    List<WindowsDefaultRoute> routes, {
    List<String> localIps = const [],
  }) {
    if (routes.isEmpty) {
      return null;
    }

    final private = routes.where((r) => isPrivateIpv4(r.gateway)).toList();
    var pool = private.isNotEmpty ? private : routes;
    final withoutVpn =
        pool.where((r) => !looksLikeVpnIpv4(r.gateway)).toList();
    if (withoutVpn.isNotEmpty) {
      pool = withoutVpn;
    }

    if (localIps.isNotEmpty) {
      final matching = pool.where((route) {
        return localIps.any((ip) => sameSlash24(route.gateway, ip));
      }).toList();
      if (matching.isNotEmpty) {
        matching.sort((a, b) => a.metric.compareTo(b.metric));
        return matching.first;
      }
    }

    pool.sort((a, b) => a.metric.compareTo(b.metric));
    return pool.first;
  }
}
