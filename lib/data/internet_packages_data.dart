import '../models/internet_package.dart';

/// دادهٔ بسته‌ها از لیست قیمت رسمی جهان بیت (دو پوستر).
abstract final class InternetPackagesData {
  /// بسته های دیدیکیت — پوستر ۱
  static const List<InternetPackage> dedicated = [
    InternetPackage(
      id: 'd-1-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 1,
      durationMonths: 1,
      priceAf: 500,
    ),
    InternetPackage(
      id: 'd-2-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 2,
      durationMonths: 1,
      priceAf: 850,
    ),
    InternetPackage(
      id: 'd-3-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 3,
      durationMonths: 1,
      priceAf: 1100,
    ),
    InternetPackage(
      id: 'd-4-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 4,
      durationMonths: 1,
      priceAf: 1600,
    ),
    InternetPackage(
      id: 'd-5-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 5,
      durationMonths: 1,
      priceAf: 1900,
    ),
    InternetPackage(
      id: 'd-6-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 6,
      durationMonths: 1,
      priceAf: 2100,
    ),
  ];

  /// بسته های نامحدود — پوستر ۱ (روزانه / شبانه)
  static const List<InternetPackage> unlimited = [
    InternetPackage(
      id: 'u-2-4-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 2,
      nightSpeedMbps: 4,
      durationMonths: 1,
      priceAf: 1000,
    ),
    InternetPackage(
      id: 'u-4-8-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 4,
      nightSpeedMbps: 8,
      durationMonths: 1,
      priceAf: 1700,
    ),
    InternetPackage(
      id: 'u-8-16-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 8,
      nightSpeedMbps: 16,
      durationMonths: 1,
      priceAf: 2800,
    ),
  ];

  /// بسته های حجمی — پوستر ۲
  static const List<InternetPackage> volume = [
    // یک ماهه
    InternetPackage(
      id: 'v-75-3-1',
      kind: InternetPackageKind.volume,
      speedMbps: 3,
      volumeGb: 75,
      durationMonths: 1,
      priceAf: 500,
    ),
    InternetPackage(
      id: 'v-100-4-1',
      kind: InternetPackageKind.volume,
      speedMbps: 4,
      volumeGb: 100,
      durationMonths: 1,
      priceAf: 650,
    ),
    InternetPackage(
      id: 'v-160-5-1',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 160,
      durationMonths: 1,
      priceAf: 850,
    ),
    InternetPackage(
      id: 'v-200-5-1',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 200,
      durationMonths: 1,
      priceAf: 900,
    ),
    InternetPackage(
      id: 'v-300-6-1',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 300,
      durationMonths: 1,
      priceAf: 1000,
    ),
    InternetPackage(
      id: 'v-400-6-1',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 400,
      durationMonths: 1,
      priceAf: 1300,
    ),
    // دو ماهه
    InternetPackage(
      id: 'v-100-5-2',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 100,
      durationMonths: 2,
      priceAf: 750,
    ),
    InternetPackage(
      id: 'v-200-6-2',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 200,
      durationMonths: 2,
      priceAf: 1100,
    ),
    // سه ماهه
    InternetPackage(
      id: 'v-200-5-3',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 200,
      durationMonths: 3,
      priceAf: 1000,
    ),
    InternetPackage(
      id: 'v-400-6-3',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 400,
      durationMonths: 3,
      priceAf: 1800,
    ),
    InternetPackage(
      id: 'v-600-6-3',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 600,
      durationMonths: 3,
      priceAf: 2100,
    ),
    // شش ماهه
    InternetPackage(
      id: 'v-600-6-6',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 600,
      durationMonths: 6,
      priceAf: 2400,
    ),
    // یک ساله
    InternetPackage(
      id: 'v-1000-8-12',
      kind: InternetPackageKind.volume,
      speedMbps: 8,
      volumeGb: 1000,
      durationMonths: 12,
      priceAf: 5000,
    ),
  ];

  static List<InternetPackage> byKind(InternetPackageKind kind) {
    switch (kind) {
      case InternetPackageKind.dedicated:
        return dedicated;
      case InternetPackageKind.unlimited:
        return unlimited;
      case InternetPackageKind.volume:
        return volume;
    }
  }
}
