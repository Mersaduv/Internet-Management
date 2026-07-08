/// Parses RouterOS duration strings into total seconds.
///
/// Examples: `30s`, `2m15s`, `1h30m`, `3d2h15m30s`, `1w3d14h27m23s`
class RouterOsDurationParser {
  RouterOsDurationParser._();

  static int? toSeconds(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    var total = 0;
    final s = raw.trim();

    total += _extractUnit(s, 'w') * 7 * 24 * 3600;
    total += _extractUnit(s, 'd') * 24 * 3600;
    total += _extractUnit(s, 'h') * 3600;
    total += _extractUnit(s, 'm') * 60;
    total += _extractUnit(s, 's');

    return total;
  }

  static int _extractUnit(String s, String unit) {
    final pattern = RegExp(r'(\d+)' + unit);
    final match = pattern.firstMatch(s);
    if (match == null) {
      return 0;
    }
    return int.tryParse(match.group(1) ?? '0') ?? 0;
  }
}
