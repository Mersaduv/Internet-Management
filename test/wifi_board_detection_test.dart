import 'package:flutter_test/flutter_test.dart';
import 'package:abar_tawseeh_ict/screens/wifi_settings_screen.dart';
import 'package:abar_tawseeh_ict/utils/wifi_webview_boards.dart';

void main() {
  group('catalog', () {
    test('has exactly 9 board entries', () {
      expect(kWifiWebViewBoardCatalog.length, 9);
    });
  });

  group('WifiSettingsRouter.isWebViewWifiBoard', () {
    test('LHG5 / RBLHG-5nD', () {
      expect(
        WifiSettingsRouter.isWebViewWifiBoard({
          'board-name': 'LHG5',
          'model': 'RBLHG-5nD',
        }),
        isTrue,
      );
    });

    test('SXTsq lite5 / RBSXTsq5nD', () {
      expect(
        WifiSettingsRouter.isWebViewWifiBoard({
          'board-name': 'SXTsq lite5',
          'model': 'RBSXTsq5nD',
        }),
        isTrue,
      );
    });

    test('SXT Lite5 / SXT 5nD r2', () {
      expect(
        WifiSettingsRouter.isWebViewWifiBoard({
          'board-name': 'SXT Lite5',
          'model': 'SXT 5nD r2',
        }),
        isTrue,
      );
    });

    test('LHG5 ac / RBLHGG-5acD', () {
      expect(
        WifiSettingsRouter.isWebViewWifiBoard({
          'board-name': 'LHG5 ac',
          'model': 'RBLHGG-5acD',
        }),
        isTrue,
      );
    });

    test('QRT 5 / 911G-5HPnD', () {
      expect(
        WifiSettingsRouter.isWebViewWifiBoard({
          'board-name': 'QRT 5',
          'model': '911G-5HPnD',
        }),
        isTrue,
      );
    });

    test('QRT 5 ac / 911G-5HPacD', () {
      expect(
        WifiSettingsRouter.isWebViewWifiBoard({
          'board-name': 'QRT 5 ac',
          'model': '911G-5HPacD',
        }),
        isTrue,
      );
    });

    test('LHG-5 XL / RBLHGG-5acD', () {
      expect(
        WifiSettingsRouter.isWebViewWifiBoard({
          'board-name': 'LHG-5 XL',
          'model': 'RBLHGG-5acD',
        }),
        isTrue,
      );
    });

    test('SEXTANT 5 / 911G-5HPnD', () {
      expect(
        WifiSettingsRouter.isWebViewWifiBoard({
          'board-name': 'SEXTANT 5',
          'model': '911G-5HPnD',
        }),
        isTrue,
      );
    });

    test('SXT 6 / RBSXTG-6HPnD', () {
      expect(
        WifiSettingsRouter.isWebViewWifiBoard({
          'board-name': 'SXT 6',
          'model': 'RBSXTG-6HPnD',
        }),
        isTrue,
      );
    });

    test('wireless-features-enabled false alone does not match', () {
      expect(
        WifiSettingsRouter.isWebViewWifiBoard({
          'board-name': 'Unknown',
          'model': 'Unknown',
          'wireless-features-enabled': false,
        }),
        isFalse,
      );
    });

    test('generic hAP uses native form', () {
      expect(
        WifiSettingsRouter.isWebViewWifiBoard({
          'board-name': 'hAP ac2',
          'model': 'RB941-2nD',
          'wireless-features-enabled': true,
        }),
        isFalse,
      );
    });
  });
}
