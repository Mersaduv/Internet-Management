import '../models/internet_package.dart';

/// ولایت‌های دارای کاتالوگ بسته
enum PackageProvince { herat, nimroz, farah }

extension PackageProvinceX on PackageProvince {
  String get id {
    switch (this) {
      case PackageProvince.herat:
        return 'herat';
      case PackageProvince.nimroz:
        return 'nimroz';
      case PackageProvince.farah:
        return 'farah';
    }
  }

  static PackageProvince? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final p in PackageProvince.values) {
      if (p.id == raw) return p;
    }
    return null;
  }

  String titleFa() {
    switch (this) {
      case PackageProvince.herat:
        return 'هرات';
      case PackageProvince.nimroz:
        return 'نیمروز';
      case PackageProvince.farah:
        return 'فراه';
    }
  }

  String titleEn() {
    switch (this) {
      case PackageProvince.herat:
        return 'Herat';
      case PackageProvince.nimroz:
        return 'Nimroz';
      case PackageProvince.farah:
        return 'Farah';
    }
  }

  String title(bool isEnglish) => isEnglish ? titleEn() : titleFa();
}

/// کاتالوگ بسته‌های یک ولایت — استخراج‌شده از پوسترهای رسمی جهان بیت.
class ProvincePackageCatalog {
  const ProvincePackageCatalog({
    required this.province,
    required this.dedicated,
    required this.unlimited,
    required this.volume,
    this.volumeNoteFa,
    this.volumeNoteEn,
    this.unlimitedNoteFa,
    this.unlimitedNoteEn,
  });

  final PackageProvince province;
  final List<InternetPackage> dedicated;
  final List<InternetPackage> unlimited;
  final List<InternetPackage> volume;
  final String? volumeNoteFa;
  final String? volumeNoteEn;
  final String? unlimitedNoteFa;
  final String? unlimitedNoteEn;

  List<InternetPackage> byKind(InternetPackageKind kind) {
    switch (kind) {
      case InternetPackageKind.dedicated:
        return dedicated;
      case InternetPackageKind.unlimited:
        return unlimited;
      case InternetPackageKind.volume:
        return volume;
    }
  }

  List<InternetPackageKind> get availableKinds => [
        if (dedicated.isNotEmpty) InternetPackageKind.dedicated,
        if (unlimited.isNotEmpty) InternetPackageKind.unlimited,
        if (volume.isNotEmpty) InternetPackageKind.volume,
      ];

  String? noteForKind(InternetPackageKind kind, {required bool isEnglish}) {
    switch (kind) {
      case InternetPackageKind.volume:
        return isEnglish ? volumeNoteEn : volumeNoteFa;
      case InternetPackageKind.unlimited:
        return isEnglish ? unlimitedNoteEn : unlimitedNoteFa;
      case InternetPackageKind.dedicated:
        return null;
    }
  }
}

/// دادهٔ بسته‌ها از پوسترهای رسمی جهان بیت — هرات، نیمروز و فراه.
abstract final class InternetPackagesData {
  static const List<PackageProvince> provinces = PackageProvince.values;

  static ProvincePackageCatalog catalogFor(PackageProvince province) {
    switch (province) {
      case PackageProvince.herat:
        return herat;
      case PackageProvince.nimroz:
        return nimroz;
      case PackageProvince.farah:
        return farah;
    }
  }

  static List<InternetPackage> byKind(
    InternetPackageKind kind, {
    PackageProvince province = PackageProvince.herat,
  }) =>
      catalogFor(province).byKind(kind);

  // ─── هرات (کاتالوگ قبلی اپ) ─────────────────────────────────────────

  static const List<InternetPackage> _heratDedicated = [
    InternetPackage(
      id: 'hr-d-1-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 1,
      durationMonths: 1,
      priceAf: 500,
    ),
    InternetPackage(
      id: 'hr-d-2-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 2,
      durationMonths: 1,
      priceAf: 850,
    ),
    InternetPackage(
      id: 'hr-d-3-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 3,
      durationMonths: 1,
      priceAf: 1100,
    ),
    InternetPackage(
      id: 'hr-d-4-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 4,
      durationMonths: 1,
      priceAf: 1600,
    ),
    InternetPackage(
      id: 'hr-d-5-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 5,
      durationMonths: 1,
      priceAf: 1900,
    ),
    InternetPackage(
      id: 'hr-d-6-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 6,
      durationMonths: 1,
      priceAf: 2100,
    ),
  ];

  static const List<InternetPackage> _heratUnlimited = [
    InternetPackage(
      id: 'hr-u-2-4-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 2,
      nightSpeedMbps: 4,
      durationMonths: 1,
      priceAf: 1000,
    ),
    InternetPackage(
      id: 'hr-u-4-8-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 4,
      nightSpeedMbps: 8,
      durationMonths: 1,
      priceAf: 1700,
    ),
    InternetPackage(
      id: 'hr-u-8-16-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 8,
      nightSpeedMbps: 16,
      durationMonths: 1,
      priceAf: 2800,
    ),
  ];

  static const List<InternetPackage> _heratVolume = [
    InternetPackage(
      id: 'hr-v-75-3-1',
      kind: InternetPackageKind.volume,
      speedMbps: 3,
      volumeGb: 75,
      durationMonths: 1,
      priceAf: 500,
    ),
    InternetPackage(
      id: 'hr-v-100-4-1',
      kind: InternetPackageKind.volume,
      speedMbps: 4,
      volumeGb: 100,
      durationMonths: 1,
      priceAf: 650,
    ),
    InternetPackage(
      id: 'hr-v-160-5-1',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 160,
      durationMonths: 1,
      priceAf: 850,
    ),
    InternetPackage(
      id: 'hr-v-200-5-1',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 200,
      durationMonths: 1,
      priceAf: 900,
    ),
    InternetPackage(
      id: 'hr-v-300-6-1',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 300,
      durationMonths: 1,
      priceAf: 1000,
    ),
    InternetPackage(
      id: 'hr-v-400-6-1',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 400,
      durationMonths: 1,
      priceAf: 1300,
    ),
    InternetPackage(
      id: 'hr-v-100-5-2',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 100,
      durationMonths: 2,
      priceAf: 750,
    ),
    InternetPackage(
      id: 'hr-v-200-6-2',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 200,
      durationMonths: 2,
      priceAf: 1100,
    ),
    InternetPackage(
      id: 'hr-v-200-5-3',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 200,
      durationMonths: 3,
      priceAf: 1000,
    ),
    InternetPackage(
      id: 'hr-v-400-6-3',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 400,
      durationMonths: 3,
      priceAf: 1800,
    ),
    InternetPackage(
      id: 'hr-v-600-6-3',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 600,
      durationMonths: 3,
      priceAf: 2100,
    ),
    InternetPackage(
      id: 'hr-v-600-6-6',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 600,
      durationMonths: 6,
      priceAf: 2400,
    ),
    InternetPackage(
      id: 'hr-v-1000-8-12',
      kind: InternetPackageKind.volume,
      speedMbps: 8,
      volumeGb: 1000,
      durationMonths: 12,
      priceAf: 5000,
    ),
  ];

  static const ProvincePackageCatalog herat = ProvincePackageCatalog(
    province: PackageProvince.herat,
    dedicated: _heratDedicated,
    unlimited: _heratUnlimited,
    volume: _heratVolume,
    volumeNoteFa:
        'نوت: استفاده از این بسته‌ها از ساعت ۱۲ شب تا ۸ صبح رایگان می‌باشد.',
    volumeNoteEn: 'Note: Usage is free from 12 AM to 8 AM.',
    unlimitedNoteFa:
        'نوت: سرعت بسته‌های نامحدود از ساعت ۱۱ شب تا ۷ صبح دو برابر می‌باشد.',
    unlimitedNoteEn:
        'Note: Unlimited package speed doubles from 11 PM to 7 AM.',
  );

  // ─── نیمروز (package_nimroz1 + package_nimroz2) ─────────────────────

  /// نیمروز — نامحدود دیدیکیت (package_nimroz1)
  static const List<InternetPackage> _nimrozDedicated = [
    InternetPackage(
      id: 'nm-d-1-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 1,
      durationMonths: 1,
      priceAf: 900,
    ),
    InternetPackage(
      id: 'nm-d-2-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 2,
      durationMonths: 1,
      priceAf: 1100,
    ),
    InternetPackage(
      id: 'nm-d-3-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 3,
      durationMonths: 1,
      priceAf: 1500,
    ),
    InternetPackage(
      id: 'nm-d-4-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 4,
      durationMonths: 1,
      priceAf: 1800,
    ),
    InternetPackage(
      id: 'nm-d-5-1',
      kind: InternetPackageKind.dedicated,
      speedMbps: 5,
      durationMonths: 1,
      priceAf: 2500,
    ),
  ];

  /// نیمروز — ویژه مشترکین جدید، سرعت روز/شب (package_nimroz1)
  static const List<InternetPackage> _nimrozUnlimited = [
    InternetPackage(
      id: 'nm-u-0.542-2-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 0.542, // 542 Kbps
      nightSpeedMbps: 2,
      durationMonths: 1,
      priceAf: 900,
    ),
    InternetPackage(
      id: 'nm-u-0.512-4-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 0.512, // 512 Kbps
      nightSpeedMbps: 4,
      durationMonths: 1,
      priceAf: 1200,
    ),
    InternetPackage(
      id: 'nm-u-1-4-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 1,
      nightSpeedMbps: 4,
      durationMonths: 1,
      priceAf: 1800,
    ),
    InternetPackage(
      id: 'nm-u-2-4-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 2,
      nightSpeedMbps: 4,
      durationMonths: 1,
      priceAf: 1200,
    ),
  ];

  /// نیمروز — حجمی (package_nimroz2)
  static const List<InternetPackage> _nimrozVolume = [
    // یک ماهه
    InternetPackage(
      id: 'nm-v-90-5-1',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 90,
      durationMonths: 1,
      priceAf: 600,
    ),
    InternetPackage(
      id: 'nm-v-100-5-1',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 100,
      durationMonths: 1,
      priceAf: 850,
    ),
    InternetPackage(
      id: 'nm-v-200-6-1',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 200,
      durationMonths: 1,
      priceAf: 1000,
    ),
    InternetPackage(
      id: 'nm-v-300-6-1',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 300,
      durationMonths: 1,
      priceAf: 1250,
    ),
    InternetPackage(
      id: 'nm-v-400-10-1',
      kind: InternetPackageKind.volume,
      speedMbps: 10,
      volumeGb: 400,
      durationMonths: 1,
      priceAf: 1500,
    ),
    InternetPackage(
      id: 'nm-v-600-10-1',
      kind: InternetPackageKind.volume,
      speedMbps: 10,
      volumeGb: 600,
      durationMonths: 1,
      priceAf: 2500,
    ),
    // دو ماهه
    InternetPackage(
      id: 'nm-v-100-5-2',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 100,
      durationMonths: 2,
      priceAf: 900,
    ),
    InternetPackage(
      id: 'nm-v-200-6-2',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 200,
      durationMonths: 2,
      priceAf: 1200,
    ),
    // سه ماهه
    InternetPackage(
      id: 'nm-v-200-6-3',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 200,
      durationMonths: 3,
      priceAf: 1400,
    ),
    InternetPackage(
      id: 'nm-v-250-6-3',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 250,
      durationMonths: 3,
      priceAf: 1500,
    ),
    InternetPackage(
      id: 'nm-v-400-8-3',
      kind: InternetPackageKind.volume,
      speedMbps: 8,
      volumeGb: 400,
      durationMonths: 3,
      priceAf: 2200,
    ),
    InternetPackage(
      id: 'nm-v-1000-8-3',
      kind: InternetPackageKind.volume,
      speedMbps: 8,
      volumeGb: 1000,
      durationMonths: 3,
      priceAf: 4000,
    ),
    // شش ماهه
    InternetPackage(
      id: 'nm-v-500-10-6',
      kind: InternetPackageKind.volume,
      speedMbps: 10,
      volumeGb: 500,
      durationMonths: 6,
      priceAf: 3000,
    ),
    InternetPackage(
      id: 'nm-v-600-10-6',
      kind: InternetPackageKind.volume,
      speedMbps: 10,
      volumeGb: 600,
      durationMonths: 6,
      priceAf: 3600,
    ),
    // یک ساله
    InternetPackage(
      id: 'nm-v-1000-8-12',
      kind: InternetPackageKind.volume,
      speedMbps: 8,
      volumeGb: 1000,
      durationMonths: 12,
      priceAf: 5000,
    ),
  ];

  static const ProvincePackageCatalog nimroz = ProvincePackageCatalog(
    province: PackageProvince.nimroz,
    dedicated: _nimrozDedicated,
    unlimited: _nimrozUnlimited,
    volume: _nimrozVolume,
    volumeNoteFa: 'تمام این بسته‌ها از ۱۲ شب الی ۸ صبح رایگان می‌باشد.',
    volumeNoteEn: 'All these packages are free from 12:00 AM to 8:00 AM.',
    unlimitedNoteFa: 'بسته‌های ویژه مشترکین جدید — سرعت روز و شب.',
    unlimitedNoteEn: 'Special packages for new subscribers — day and night speed.',
  );

  // ─── فراه (package_farah1 + package_farah2) ─────────────────────────

  /// فراه — نامحدود جدید، روز از ۸ صبح / شب از ۸ عصر (package_farah2)
  static const List<InternetPackage> _farahUnlimited = [
    InternetPackage(
      id: 'fr-u-1-2-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 1,
      nightSpeedMbps: 2,
      durationMonths: 1,
      priceAf: 800,
    ),
    InternetPackage(
      id: 'fr-u-2-4-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 2,
      nightSpeedMbps: 4,
      durationMonths: 1,
      priceAf: 1100,
    ),
    InternetPackage(
      id: 'fr-u-3-6-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 3,
      nightSpeedMbps: 6,
      durationMonths: 1,
      priceAf: 1950,
    ),
    InternetPackage(
      id: 'fr-u-5-12-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 5,
      nightSpeedMbps: 12,
      durationMonths: 1,
      priceAf: 2500,
    ),
    InternetPackage(
      id: 'fr-u-8-15-1',
      kind: InternetPackageKind.unlimited,
      speedMbps: 8,
      nightSpeedMbps: 15,
      durationMonths: 1,
      priceAf: 4000,
    ),
  ];

  /// فراه — حجمی جدید (package_farah1)
  static const List<InternetPackage> _farahVolume = [
    InternetPackage(
      id: 'fr-v-299-5-1',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 299,
      durationMonths: 1,
      priceAf: 1250,
    ),
    InternetPackage(
      id: 'fr-v-200-4-1',
      kind: InternetPackageKind.volume,
      speedMbps: 4,
      volumeGb: 200,
      durationMonths: 1,
      priceAf: 1100,
    ),
    InternetPackage(
      id: 'fr-v-130-4-1',
      kind: InternetPackageKind.volume,
      speedMbps: 4,
      volumeGb: 130,
      durationMonths: 1,
      priceAf: 800,
    ),
    InternetPackage(
      id: 'fr-v-50-3-1',
      kind: InternetPackageKind.volume,
      speedMbps: 3,
      volumeGb: 50,
      durationMonths: 1,
      priceAf: 500,
    ),
    InternetPackage(
      id: 'fr-v-200-5-2',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 200,
      durationMonths: 2,
      priceAf: 1250,
    ),
    InternetPackage(
      id: 'fr-v-100-5-2',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 100,
      durationMonths: 2,
      priceAf: 800,
    ),
    InternetPackage(
      id: 'fr-v-600-5-1',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 600,
      durationMonths: 1,
      priceAf: 2000,
    ),
    InternetPackage(
      id: 'fr-v-400-6-1',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 400,
      durationMonths: 1,
      priceAf: 1500,
    ),
    InternetPackage(
      id: 'fr-v-400-6-3',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 400,
      durationMonths: 3,
      priceAf: 2000,
    ),
    InternetPackage(
      id: 'fr-v-150-5-3',
      kind: InternetPackageKind.volume,
      speedMbps: 5,
      volumeGb: 150,
      durationMonths: 3,
      priceAf: 1200,
    ),
    InternetPackage(
      id: 'fr-v-499-6-2',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 499,
      durationMonths: 2,
      priceAf: 2000,
    ),
    InternetPackage(
      id: 'fr-v-300-6-2',
      kind: InternetPackageKind.volume,
      speedMbps: 6,
      volumeGb: 300,
      durationMonths: 2,
      priceAf: 1500,
    ),
    InternetPackage(
      id: 'fr-v-1000-8-12',
      kind: InternetPackageKind.volume,
      speedMbps: 8,
      volumeGb: 1000,
      durationMonths: 12,
      priceAf: 5000,
    ),
    InternetPackage(
      id: 'fr-v-600-7-3',
      kind: InternetPackageKind.volume,
      speedMbps: 7,
      volumeGb: 600,
      durationMonths: 3,
      priceAf: 2800,
    ),
  ];

  static const ProvincePackageCatalog farah = ProvincePackageCatalog(
    province: PackageProvince.farah,
    dedicated: [], // در پوستر فراه بسته دیدیکیت ثابت نیست
    unlimited: _farahUnlimited,
    volume: _farahVolume,
    volumeNoteFa: 'تایم رایگان: از ۱۲ شب الی ۸ صبح.',
    volumeNoteEn: 'Free time: from 12:00 AM to 8:00 AM.',
    unlimitedNoteFa:
        'سرعت روز از ۸ صبح و سرعت شب از ۸ عصر — خدمات ویژه ولایت فراه.',
    unlimitedNoteEn:
        'Day speed from 8 AM and night speed from 8 PM — Farah special services.',
  );

  // سازگاری با کد قدیمی — کاتالوگ هرات
  static List<InternetPackage> get dedicated => _heratDedicated;
  static List<InternetPackage> get unlimited => _heratUnlimited;
  static List<InternetPackage> get volume => _heratVolume;
}
