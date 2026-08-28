import 'package:flutter_test/flutter_test.dart';
import 'package:abar_tawseeh_ict/models/client_info.dart';
import 'package:abar_tawseeh_ict/utils/client_display_name.dart';

void main() {
  group('ClientDisplayName', () {
    test('prefers hostName over IP fallback', () {
      final client = ClientInfo(
        type: 'dhcp',
        source: 'dhcp_lease',
        hostName: 'Living-Room-TV',
        ipAddress: '192.168.1.10',
        rawData: const {},
      );

      expect(ClientDisplayName.resolveHostName(client), 'Living-Room-TV');
      expect(ClientDisplayName.displayLabel(client), 'Living-Room-TV');
    });

    test('falls back to IP when no friendly name exists', () {
      final client = ClientInfo(
        type: 'dhcp',
        source: 'dhcp_lease',
        ipAddress: '192.168.1.22',
        rawData: const {},
      );

      expect(ClientDisplayName.resolveHostName(client), isNull);
      expect(
        ClientDisplayName.displayLabel(client, devicePrefix: 'Device'),
        'Device 192.168.1.22',
      );
    });

    test('uses neighbor identity from rawData', () {
      final client = ClientInfo(
        type: 'wireless',
        source: 'wireless_registration',
        ipAddress: '192.168.1.33',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        rawData: const {'identity': 'MikroTik-Office'},
      );

      expect(ClientDisplayName.resolveHostName(client), 'MikroTik-Office');
    });

    test('ignores ban markers in lease comment', () {
      expect(
        ClientDisplayName.displayNameFromLeaseComment('[AbarTawseeh BAN] Guest'),
        isNull,
      );
      expect(
        ClientDisplayName.displayNameFromLease({
          'comment': '[AbarTawseeh STATIC] Office PC',
          'host-name': 'pc-01',
        }),
        'Office PC',
      );
    });
  });
}
