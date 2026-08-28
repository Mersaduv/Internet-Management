import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abar_tawseeh_ict/utils/smart_text_direction.dart';

void main() {
  test('English text is LTR', () {
    expect(detectInputTextDirection('MyWiFi-5G'), TextDirection.ltr);
  });

  test('Persian text is RTL', () {
    expect(detectInputTextDirection('وایفای خانه'), TextDirection.rtl);
  });

  test('empty text defaults to LTR', () {
    expect(detectInputTextDirection(''), TextDirection.ltr);
  });
}
