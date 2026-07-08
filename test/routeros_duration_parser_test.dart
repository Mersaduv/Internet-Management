import 'package:flutter_test/flutter_test.dart';
import 'package:Ariyabod/utils/routeros_duration_parser.dart';

void main() {
  group('RouterOsDurationParser', () {
    test('parses seconds only', () {
      expect(RouterOsDurationParser.toSeconds('30s'), 30);
    });

    test('parses minutes and seconds', () {
      expect(RouterOsDurationParser.toSeconds('2m15s'), 135);
    });

    test('parses hours and minutes', () {
      expect(RouterOsDurationParser.toSeconds('1h30m'), 5400);
    });

    test('parses weeks days hours minutes seconds', () {
      final secs = RouterOsDurationParser.toSeconds('1w3d14h27m23s');
      expect(secs, 1 * 7 * 24 * 3600 + 3 * 24 * 3600 + 14 * 3600 + 27 * 60 + 23);
    });

    test('returns null for empty input', () {
      expect(RouterOsDurationParser.toSeconds(null), isNull);
      expect(RouterOsDurationParser.toSeconds(''), isNull);
    });
  });
}
