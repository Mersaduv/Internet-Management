import 'package:Ariyabod/models/client_info.dart';
import 'package:Ariyabod/utils/current_device_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrentDevicePolicy', () {
    final clients = <ClientInfo>[
      ClientInfo(
        type: 'dhcp',
        source: 'dhcp',
        ipAddress: '192.168.88.20',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        rawData: const {},
      ),
      ClientInfo(
        type: 'dhcp',
        source: 'dhcp',
        ipAddress: '192.168.88.50',
        macAddress: '11:22:33:44:55:66',
        rawData: const {},
      ),
    ];

    test('pickBestDeviceIp prefers local IP present in client list', () {
      expect(
        CurrentDevicePolicy.pickBestDeviceIp(
          localIp: '192.168.88.20',
          routerReportedIp: '10.8.0.5',
          clients: clients,
          routerHost: '192.168.88.1',
        ),
        '192.168.88.20',
      );
    });

    test('isCurrentDevice matches by IP and MAC fallback', () {
      expect(
        CurrentDevicePolicy.isCurrentDevice(
          client: clients.first,
          deviceIp: '192.168.88.20',
          clients: clients,
        ),
        isTrue,
      );
      expect(
        CurrentDevicePolicy.isCurrentDevice(
          client: clients.first,
          deviceIp: '10.0.0.9',
          deviceMac: 'AA:BB:CC:DD:EE:FF',
          clients: clients,
        ),
        isTrue,
      );
      expect(
        CurrentDevicePolicy.isCurrentDevice(
          client: clients.last,
          deviceIp: '192.168.88.20',
          clients: clients,
        ),
        isFalse,
      );
    });
  });
}
