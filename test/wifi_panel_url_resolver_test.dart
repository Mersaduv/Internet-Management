import 'package:flutter_test/flutter_test.dart';
import 'package:Ariyabod/utils/wifi_panel_url_resolver.dart';

void main() {
  test('CPE WiFi panel is always http://10.10.10.2/', () async {
    expect(
      await WifiPanelUrlResolver.resolve(),
      WifiPanelUrlResolver.cpeWifiPanelUrl,
    );
    expect(WifiPanelUrlResolver.cpeWifiPanelUrl, 'http://10.10.10.2/');
    expect(await WifiPanelUrlResolver.buildCandidates(), ['http://10.10.10.2/']);
  });
}
