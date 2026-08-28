import 'package:abar_tawseeh_ict/services/network_info_service.dart';
import 'package:abar_tawseeh_ict/utils/windows_default_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkInfoService.normalizeIpv4', () {
    test('accepts valid IPv4', () {
      expect(NetworkInfoService.normalizeIpv4('192.168.50.254'), '192.168.50.254');
      expect(NetworkInfoService.normalizeIpv4(' 10.0.0.1 '), '10.0.0.1');
    });

    test('strips quotes from Android-style values', () {
      expect(NetworkInfoService.normalizeIpv4('"172.16.3.1"'), '172.16.3.1');
    });

    test('rejects invalid or placeholder addresses', () {
      expect(NetworkInfoService.normalizeIpv4(null), isNull);
      expect(NetworkInfoService.normalizeIpv4(''), isNull);
      expect(NetworkInfoService.normalizeIpv4('0.0.0.0'), isNull);
      expect(NetworkInfoService.normalizeIpv4('not-an-ip'), isNull);
      expect(NetworkInfoService.normalizeIpv4('256.1.1.1'), isNull);
      expect(NetworkInfoService.normalizeIpv4('1.2.3'), isNull);
    });
  });

  group('WindowsDefaultGatewayParser', () {
    const routePrint = '''
IPv4 Route Table
===========================================================================
Active Routes:
Network Destination        Netmask          Gateway       Interface  Metric
          0.0.0.0          0.0.0.0      192.168.88.1    192.168.88.20     25
          0.0.0.0          0.0.0.0         On-link         10.0.0.1    256
          0.0.0.0          0.0.0.0         10.8.0.1        10.8.0.2      1
        127.0.0.0        255.0.0.0         On-link         127.0.0.1    331
''';

    test('parses default routes and skips On-link', () {
      final routes = WindowsDefaultGatewayParser.parseRoutePrint(routePrint);
      expect(routes.map((r) => r.gateway).toList(), [
        '192.168.88.1',
        '10.8.0.1',
      ]);
      expect(routes.first.interfaceIp, '192.168.88.20');
      expect(routes.first.metric, 25);
    });

    test('prefers LAN subnet over VPN even if VPN metric is lower', () {
      final routes = WindowsDefaultGatewayParser.parseRoutePrint(routePrint);
      final best = WindowsDefaultGatewayParser.selectBestRoute(
        routes,
        localIps: const ['192.168.88.20'],
      );
      expect(best?.gateway, '192.168.88.1');
      expect(best?.interfaceIp, '192.168.88.20');
    });

    test('falls back to LAN gateway instead of VPN metric', () {
      final routes = WindowsDefaultGatewayParser.parseRoutePrint(routePrint);
      final best = WindowsDefaultGatewayParser.selectBestRoute(routes);
      expect(best?.gateway, '192.168.88.1');
    });

    test('parses ipconfig IPv4 default gateway', () {
      const ipconfig = '''
Ethernet adapter Ethernet:

   Connection-specific DNS Suffix  . :
   IPv4 Address. . . . . . . . . . . : 192.168.50.20
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Default Gateway . . . . . . . . . : 192.168.50.1
''';
      expect(
        WindowsDefaultGatewayParser.parseIpconfig(ipconfig),
        '192.168.50.1',
      );
    });
  });
}
