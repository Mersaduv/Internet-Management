import 'package:flutter/material.dart';

class AppLayout {
  const AppLayout._();

  static const double desktopBreakpoint = 900;
  static const double pageMaxWidth = 1120;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;
}
