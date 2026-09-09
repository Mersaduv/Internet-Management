enum InternetPackageKind { dedicated, unlimited, volume }

/// یک بستهٔ اینترنتی — دادهٔ واقعی از لیست قیمت جهان بیت.
class InternetPackage {
  const InternetPackage({
    required this.id,
    required this.kind,
    required this.speedMbps,
    required this.durationMonths,
    required this.priceAf,
    this.volumeGb,
    this.nightSpeedMbps,
  });

  final String id;
  final InternetPackageKind kind;

  /// سرعت روزانه / ثابت (Mbps)
  final double speedMbps;

  /// سرعت شبانه — فقط بسته‌های نامحدود
  final double? nightSpeedMbps;

  /// حجم به گیگابایت — فقط بسته‌های حجمی
  final int? volumeGb;

  /// مدت اعتبار به ماه (۱۲ = یک سال)
  final int durationMonths;

  final int priceAf;

  bool get isDedicated => kind == InternetPackageKind.dedicated;
  bool get isUnlimited => kind == InternetPackageKind.unlimited;
  bool get isVolume => kind == InternetPackageKind.volume;

  static String formatMbps(double speed) {
    if (speed > 0 && speed < 1) {
      final kbps = (speed * 1000).round();
      return '${kbps}Kbps';
    }
    final value = speed == speed.roundToDouble()
        ? speed.toInt().toString()
        : speed.toString();
    return '${value}Mbps';
  }

  String get speedLabel => formatMbps(speedMbps);

  String get nightSpeedLabel =>
      nightSpeedMbps == null ? '' : formatMbps(nightSpeedMbps!);

  String get volumeLabel => volumeGb == null ? '' : '${volumeGb}GB';

  String get priceLabel => '$priceAf AF';

  /// مقدار اصلی کارت
  String get heroLabel {
    if (isVolume) return volumeLabel;
    if (isUnlimited && nightSpeedMbps != null) {
      return '${formatMbps(speedMbps)} / ${formatMbps(nightSpeedMbps!)}';
    }
    return speedLabel;
  }
}
