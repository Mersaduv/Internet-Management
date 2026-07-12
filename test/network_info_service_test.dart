import 'package:Ariyabod/services/network_info_service.dart';
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
}
