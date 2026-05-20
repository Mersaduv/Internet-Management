import 'package:flutter_test/flutter_test.dart';
import 'package:Ariyabod/models/client_info.dart';
import 'package:Ariyabod/utils/client_display_policy.dart';

void main() {
  test('mac-only wireless hidden from list', () {
    final client = ClientInfo(
      type: 'wireless',
      source: 'wireless_registration',
      macAddress: 'AA:BB:CC:DD:EE:FF',
      rawData: const {},
    );
    expect(ClientDisplayPolicy.isMacOnlyWirelessClient(client), isTrue);
    expect(ClientDisplayPolicy.shouldShowInConnectedList(client), isFalse);
    expect(ClientDisplayPolicy.shouldAllowDeviceActions(client), isFalse);
  });

  test('dhcp client with IP is shown', () {
    final client = ClientInfo(
      type: 'dhcp',
      source: 'dhcp_lease',
      ipAddress: '172.16.0.50',
      macAddress: 'AA:BB:CC:DD:EE:01',
      rawData: const {},
    );
    expect(ClientDisplayPolicy.shouldShowInConnectedList(client), isTrue);
    expect(ClientDisplayPolicy.shouldAllowDeviceActions(client), isTrue);
  });

  test('CPE board skips wireless enrichment', () {
    expect(
      ClientDisplayPolicy.shouldSkipWirelessEnrichment({
        'board-name': 'LHG5',
        'model': 'RBLHG-5nD',
        'wireless-features-enabled': false,
      }),
      isTrue,
    );
  });
}
