/// Fixed HTTP URL for legacy CPE WiFi panels (LHG, SXT, QRT, …).
///
/// WebView boards must always use [cpeWifiPanelUrl] — not router API host
/// and not 10.10.10.1.
class WifiPanelUrlResolver {
  WifiPanelUrlResolver._();

  static const String cpeWifiPanelUrl = 'http://10.10.10.2/';

  /// Sole URL for CPE WiFi WebView (no fallbacks).
  static Future<String> resolve() async => cpeWifiPanelUrl;

  static Future<List<String>> buildCandidates() async => [cpeWifiPanelUrl];
}
