import '../models/internet_package.dart';

/// دادهٔ بسته‌های ابر توسعه از پوسترهای رسمی (unlimited / unlimited2 / limited / limited2).
abstract final class InternetPackagesData {
  /// بسته‌های نامحدود — پوستر unlimited.jpg
  static const List<InternetPackage> unlimited = [
    InternetPackage(
      id: 'u-a',
      kind: InternetPackageKind.unlimited,
      name: 'ابر توسعه - A',
      speedMbps: 1.5,
      nightSpeedMbps: 3,
      durationDays: 30,
      priceAf: 700,
    ),
    InternetPackage(
      id: 'u-b',
      kind: InternetPackageKind.unlimited,
      name: 'ابر توسعه - B',
      speedMbps: 2.5,
      nightSpeedMbps: 5,
      durationDays: 30,
      priceAf: 1200,
    ),
    InternetPackage(
      id: 'u-c',
      kind: InternetPackageKind.unlimited,
      name: 'ابر توسعه - C',
      speedMbps: 3.5,
      nightSpeedMbps: 7,
      durationDays: 30,
      priceAf: 1400,
    ),
    InternetPackage(
      id: 'u-d',
      kind: InternetPackageKind.unlimited,
      name: 'ابر توسعه - D',
      speedMbps: 5,
      nightSpeedMbps: 7,
      durationDays: 30,
      priceAf: 1950,
    ),
    InternetPackage(
      id: 'u-e',
      kind: InternetPackageKind.unlimited,
      name: 'ابر توسعه - E',
      speedMbps: 10,
      nightSpeedMbps: 15,
      durationDays: 30,
      priceAf: 3800,
    ),
  ];

  /// بسته‌های خانواده نامحدود — پوستر unlimited2.jpg
  static const List<InternetPackage> family = [
    InternetPackage(
      id: 'f-1',
      kind: InternetPackageKind.family,
      name: 'بسته خانواده - ۱',
      speedMbps: 2,
      nightSpeedMbps: 3,
      durationDays: 30,
      priceAf: 1090,
    ),
    InternetPackage(
      id: 'f-2',
      kind: InternetPackageKind.family,
      name: 'بسته خانواده - ۲',
      speedMbps: 3,
      nightSpeedMbps: 5,
      durationDays: 30,
      priceAf: 1490,
    ),
  ];

  /// بسته‌های محدود — پوستر limited2.jpg + limited.jpg
  static const List<InternetPackage> limited = [
    InternetPackage(
      id: 'l-1',
      kind: InternetPackageKind.limited,
      name: 'ابر توسعه - ۱',
      speedMbps: 5,
      volumeGb: 150,
      durationDays: 30,
      priceAf: 800,
    ),
    InternetPackage(
      id: 'l-2',
      kind: InternetPackageKind.limited,
      name: 'ابر توسعه - ۲',
      speedMbps: 5,
      volumeGb: 350,
      durationDays: 30,
      priceAf: 1400,
    ),
    InternetPackage(
      id: 'l-3',
      kind: InternetPackageKind.limited,
      name: 'ابر توسعه - ۳',
      speedMbps: 5,
      volumeGb: 200,
      durationDays: 60,
      priceAf: 1000,
    ),
    InternetPackage(
      id: 'l-4',
      kind: InternetPackageKind.limited,
      name: 'ابر توسعه - ۴',
      speedMbps: 5,
      volumeGb: 300,
      durationDays: 60,
      priceAf: 1400,
    ),
    InternetPackage(
      id: 'l-5',
      kind: InternetPackageKind.limited,
      name: 'ابر توسعه - ۵',
      speedMbps: 5,
      volumeGb: 400,
      durationDays: 90,
      priceAf: 1800,
    ),
    InternetPackage(
      id: 'l-6',
      kind: InternetPackageKind.limited,
      name: 'ابر توسعه - ۶',
      speedMbps: 5,
      volumeGb: 500,
      durationDays: 120,
      priceAf: 2200,
    ),
    InternetPackage(
      id: 'l-8',
      kind: InternetPackageKind.limited,
      name: 'ابر توسعه - ۸',
      speedMbps: 5,
      volumeGb: 800,
      durationDays: 180,
      priceAf: 3500,
      footnote: 'با پرداخت هر ماه فقط ۵۸۰ افغانی، ۱۳۳ GB اینترنت دریافت کنید',
    ),
  ];

  static List<InternetPackage> byKind(InternetPackageKind kind) {
    switch (kind) {
      case InternetPackageKind.unlimited:
        return unlimited;
      case InternetPackageKind.family:
        return family;
      case InternetPackageKind.limited:
        return limited;
    }
  }
}
