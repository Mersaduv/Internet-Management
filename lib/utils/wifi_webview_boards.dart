/// Exact Type / Model pairs that use the CPE WiFi WebView at http://10.10.10.2/
class WifiWebViewBoardEntry {
  const WifiWebViewBoardEntry({
    required this.types,
    required this.model,
  });

  /// RouterOS board-name / product type labels.
  final List<String> types;
  final String model;
}

/// Catalog — must match product list exactly (no extra boards).
const List<WifiWebViewBoardEntry> kWifiWebViewBoardCatalog = [
  WifiWebViewBoardEntry(types: ['LHG5', 'RBLHG-5nD'], model: 'RBLHG-5nD'),
  WifiWebViewBoardEntry(types: ['SXTsq lite5'], model: 'RBSXTsq5nD'),
  WifiWebViewBoardEntry(types: ['SXT Lite5'], model: 'SXT 5nD r2'),
  WifiWebViewBoardEntry(types: ['LHG5 ac'], model: 'RBLHGG-5acD'),
  WifiWebViewBoardEntry(types: ['QRT 5'], model: '911G-5HPnD'),
  WifiWebViewBoardEntry(types: ['QRT 5 ac'], model: '911G-5HPacD'),
  WifiWebViewBoardEntry(types: ['LHG-5 XL'], model: 'RBLHGG-5acD'),
  WifiWebViewBoardEntry(types: ['SEXTANT 5'], model: '911G-5HPnD'),
  WifiWebViewBoardEntry(types: ['SXT 6'], model: 'RBSXTG-6HPnD'),
];

String normalizeWifiBoardKey(String? value) {
  return (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// True only when [routerInfo] matches one entry in [kWifiWebViewBoardCatalog].
bool isWifiWebViewBoard(Map<String, dynamic>? routerInfo) {
  if (routerInfo == null) {
    return false;
  }

  final boardName = (routerInfo['board-name'] ?? '').toString().trim();
  final model = (routerInfo['model'] ?? '').toString().trim();
  final normBoard = normalizeWifiBoardKey(boardName);
  final normModel = normalizeWifiBoardKey(model);
  final modelKnown = normModel.isNotEmpty && normModel != 'unknown';

  for (final entry in kWifiWebViewBoardCatalog) {
    final entryNormModel = normalizeWifiBoardKey(entry.model);

    if (modelKnown && normModel == entryNormModel) {
      return true;
    }

    if (model.isNotEmpty &&
        model != 'Unknown' &&
        model.toLowerCase().contains(entry.model.toLowerCase())) {
      return true;
    }

    if (!modelKnown && normBoard.isNotEmpty) {
      for (final type in entry.types) {
        if (normBoard == normalizeWifiBoardKey(type)) {
          return true;
        }
      }
    }
  }

  return false;
}
