import 'package:flutter_test/flutter_test.dart';
import 'package:Ariyabod/models/client_info.dart';
import 'package:Ariyabod/utils/device_list_pagination.dart';

void main() {
  group('DeviceListPagination', () {
    test('clampLimit respects total device count', () {
      expect(DeviceListPagination.clampLimit(0, 64), 20);
      expect(DeviceListPagination.clampLimit(20, 64), 20);
      expect(DeviceListPagination.clampLimit(40, 64), 40);
      expect(DeviceListPagination.clampLimit(80, 64), 64);
      expect(DeviceListPagination.clampLimit(0, 0), 0);
    });
  });

  test('windowing slice matches page size', () {
    final all = List.generate(
      64,
      (i) => ClientInfo(
        type: 'dhcp',
        source: 'dhcp_lease',
        ipAddress: '172.16.0.$i',
        macAddress: 'AA:BB:CC:DD:EE:${i.toRadixString(16).padLeft(2, '0')}',
        rawData: const {},
      ),
    );

    final limit = DeviceListPagination.clampLimit(
      DeviceListPagination.initialPageSize,
      all.length,
    );
    final window = all.sublist(0, limit);

    expect(window.length, 20);
    expect(all.length, 64);
  });
}
