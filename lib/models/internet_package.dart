enum InternetPackageKind { unlimited, family, limited }

/// یک بستهٔ اینترنتی — کاتالوگ ابر توسعه.
class InternetPackage {
  const InternetPackage({
    required this.id,
    required this.kind,
    required this.name,
    required this.speedMbps,
    required this.durationDays,
    required this.priceAf,
    this.volumeGb,
    this.nightSpeedMbps,
    this.footnote,
  });

  final String id;
  final InternetPackageKind kind;

  /// نام نمایشی (مثلاً ابر توسعه - A)
  final String name;

  /// سرعت روزانه / ثابت (Mbps)
  final double speedMbps;

  /// سرعت شبانه — بسته‌های نامحدود / خانواده
  final double? nightSpeedMbps;

  /// حجم به گیگابایت — بسته‌های محدود
  final int? volumeGb;

  /// مدت اعتبار به روز
  final int durationDays;

  final int priceAf;

  /// توضیح تکمیلی کارت (مثلاً قسط ماهانه)
  final String? footnote;

  bool get isUnlimited => kind == InternetPackageKind.unlimited;
  bool get isFamily => kind == InternetPackageKind.family;
  bool get isLimited => kind == InternetPackageKind.limited;
  bool get hasNightSpeed => nightSpeedMbps != null;

  static String formatMbps(double speed) {
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
    if (isLimited) return volumeLabel;
    if (hasNightSpeed) {
      return '${formatMbps(speedMbps)} / ${formatMbps(nightSpeedMbps!)}';
    }
    return speedLabel;
  }
}
