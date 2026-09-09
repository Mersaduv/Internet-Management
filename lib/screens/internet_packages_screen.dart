import 'package:flutter/material.dart';

import '../data/internet_packages_data.dart';
import '../models/internet_package.dart';
import '../services/settings_service.dart';
import '../utils/app_layout.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';
import '../widgets/desktop_content.dart';
import '../widgets/cosmic_background.dart';

/// صفحهٔ کاتالوگ بسته‌های اینترنتی — تم هماهنگ با روشن/تاریک پروژه.
class InternetPackagesScreen extends StatefulWidget {
  const InternetPackagesScreen({super.key});

  @override
  State<InternetPackagesScreen> createState() => _InternetPackagesScreenState();
}

class _InternetPackagesScreenState extends State<InternetPackagesScreen> {
  final SettingsService _settingsService = SettingsService();

  PackageProvince? _province;
  InternetPackageKind _selectedKind = InternetPackageKind.dedicated;
  bool _loadingProvince = true;
  bool _pickerVisible = false;

  ProvincePackageCatalog? get _catalog =>
      _province == null ? null : InternetPackagesData.catalogFor(_province!);

  @override
  void initState() {
    super.initState();
    _loadProvince();
  }

  Future<void> _loadProvince() async {
    final savedId = await _settingsService.getPackageProvinceId();
    final saved = PackageProvinceX.tryParse(savedId);
    if (!mounted) return;

    if (saved == null) {
      setState(() {
        _province = null;
        _loadingProvince = false;
        _pickerVisible = true;
      });
      return;
    }

    final catalog = InternetPackagesData.catalogFor(saved);
    setState(() {
      _province = saved;
      _selectedKind = catalog.availableKinds.isNotEmpty
          ? catalog.availableKinds.first
          : InternetPackageKind.volume;
      _loadingProvince = false;
      _pickerVisible = false;
    });
  }

  Future<void> _selectProvince(
    PackageProvince province, {
    required bool persist,
  }) async {
    final catalog = InternetPackagesData.catalogFor(province);
    final kinds = catalog.availableKinds;
    setState(() {
      _province = province;
      if (!kinds.contains(_selectedKind)) {
        _selectedKind =
            kinds.isNotEmpty ? kinds.first : InternetPackageKind.volume;
      }
      _pickerVisible = false;
    });
    if (persist) {
      await _settingsService.setPackageProvinceId(province.id);
    }
  }

  String? _noteForKind(AppLocalizations? l10n) {
    final catalog = _catalog;
    if (catalog == null) return null;
    final isEn = l10n?.locale.languageCode == 'en';
    return catalog.noteForKind(_selectedKind, isEnglish: isEn == true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final isDesktop = AppLayout.isDesktop(context);
    final scaffoldBg =
        isDark ? AppTheme.darkScaffold : AppTheme.cableWhite;

    final catalog = _catalog;
    final packages = catalog?.byKind(_selectedKind) ?? const <InternetPackage>[];
    final note = _noteForKind(l10n);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CosmicBackground(
        showStars: isDark,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_loadingProvince)
              const Center(child: CircularProgressIndicator())
            else if (_province != null)
              _buildPackagesBody(
                context,
                l10n: l10n,
                packages: packages,
                isDesktop: isDesktop,
                note: note,
                colorScheme: colorScheme,
              )
            else
              const SizedBox.shrink(),
            if (_pickerVisible)
              _ProvincePickerOverlay(
                isEnglish: l10n?.locale.languageCode == 'en',
                requiredChoice: _province == null,
                selected: _province,
                onSelected: (province) =>
                    _selectProvince(province, persist: true),
                onDismiss: _province == null
                    ? null
                    : () => setState(() => _pickerVisible = false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackagesBody(
    BuildContext context, {
    required AppLocalizations? l10n,
    required List<InternetPackage> packages,
    required bool isDesktop,
    required String? note,
    required ColorScheme colorScheme,
  }) {
    final isEn = l10n?.locale.languageCode == 'en';
    final availableKinds = _catalog?.availableKinds ?? const [];

    return SafeArea(
      child: DesktopContent(
        maxWidth: isDesktop ? 900 : AppLayout.pageMaxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n?.internetPackagesTitle ?? 'بسته‌های اینترنتی',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ProvinceDropdown(
                    value: _province!,
                    isEnglish: isEn == true,
                    onChanged: (p) => _selectProvince(p, persist: true),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: _PackageKindTabs(
                selected: _selectedKind,
                availableKinds: availableKinds,
                onChanged: (kind) {
                  if (kind == _selectedKind) return;
                  setState(() => _selectedKind = kind);
                },
                dedicatedLabel: l10n?.dedicatedPackagesTab ?? 'ددیکیت',
                unlimitedLabel: l10n?.unlimitedPackagesTab ?? 'نامحدود',
                volumeLabel: l10n?.volumePackagesTab ?? 'حجمی',
              ),
            ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('${_province!.id}-$_selectedKind'),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = isDesktop
                        ? 3
                        : (constraints.maxWidth < 340 ? 1 : 2);
                    final mainAxisExtent = switch (_selectedKind) {
                      InternetPackageKind.volume =>
                        crossAxisCount == 1 ? 272.0 : 288.0,
                      InternetPackageKind.unlimited =>
                        crossAxisCount == 1 ? 272.0 : 288.0,
                      InternetPackageKind.dedicated =>
                        crossAxisCount == 1 ? 248.0 : 262.0,
                    };

                    if (packages.isEmpty) {
                      return Center(
                        child: Text(
                          isEn == true
                              ? 'No packages in this category'
                              : 'بسته‌ای در این دسته نیست',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: GridView.builder(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              note == null ? 24 : 8,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              mainAxisExtent: mainAxisExtent,
                            ),
                            itemCount: packages.length,
                            itemBuilder: (context, index) {
                              return _PackageCard(
                                package: packages[index],
                                durationLabel:
                                    l10n?.durationMonthsLabel(
                                          packages[index].durationMonths,
                                        ) ??
                                        '${packages[index].durationMonths} Month',
                                dedicatedBadge:
                                    l10n?.dedicatedPackageBadge ??
                                        'بسته ددیکیت',
                                unlimitedBadge:
                                    l10n?.unlimitedPackageBadge ??
                                        'بسته نامحدود',
                                volumeBadge: l10n?.volumePackageBadge ??
                                    'بسته حجمی',
                                daySpeedCaption:
                                    l10n?.daySpeedLabel ?? 'سرعت روزانه',
                                nightSpeedCaption:
                                    l10n?.nightSpeedLabel ?? 'سرعت شبانه',
                              );
                            },
                          ),
                        ),
                        if (note != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: _PackageNote(text: note),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvincePickerOverlay extends StatelessWidget {
  const _ProvincePickerOverlay({
    required this.isEnglish,
    required this.requiredChoice,
    required this.selected,
    required this.onSelected,
    this.onDismiss,
  });

  final bool isEnglish;
  final bool requiredChoice;
  final PackageProvince? selected;
  final ValueChanged<PackageProvince> onSelected;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DecoratedBox(
                decoration: AppTheme.cosmicCardDecoration(
                  radius: 24,
                  brightness: theme.brightness,
                  withGlow: true,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isEnglish
                            ? 'Select your province'
                            : 'ولایت خود را انتخاب کنید',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isEnglish
                            ? 'Packages differ by province. Your choice will be saved as default.'
                            : 'بسته‌ها بر اساس ولایت متفاوت‌اند. انتخاب شما به‌عنوان پیش‌فرض ذخیره می‌شود.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final province in PackageProvince.values) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => onSelected(province),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: selected == province
                                      ? (isDark
                                            ? AppTheme.darkAction
                                            : AppTheme.primary
                                                .withValues(alpha: 0.1))
                                      : (isDark
                                            ? AppTheme.darkCardBottom
                                                .withValues(alpha: 0.65)
                                            : Colors.white),
                                  border: Border.all(
                                    color: selected == province
                                        ? (isDark
                                              ? AppTheme.darkGlow
                                              : AppTheme.primary)
                                        : (isDark
                                              ? AppTheme.darkRim
                                                  .withValues(alpha: 0.4)
                                              : AppTheme.lightRim),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      color: selected == province
                                          ? (isDark
                                                ? AppTheme.darkActionForeground
                                                : AppTheme.primary)
                                          : (isDark
                                                ? AppTheme.darkTextSecondary
                                                : AppTheme.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        province.title(isEnglish),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: selected == province && isDark
                                              ? AppTheme.darkActionForeground
                                              : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (selected == province)
                                      Icon(
                                        Icons.check_circle,
                                        color: isDark
                                            ? AppTheme.darkActionForeground
                                            : AppTheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (!requiredChoice && onDismiss != null)
                        TextButton(
                          onPressed: onDismiss,
                          child: Text(isEnglish ? 'Close' : 'بستن'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProvinceDropdown extends StatelessWidget {
  const _ProvinceDropdown({
    required this.value,
    required this.isEnglish,
    required this.onChanged,
  });

  final PackageProvince value;
  final bool isEnglish;
  final ValueChanged<PackageProvince> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: AppTheme.cosmicCardDecoration(
        radius: 14,
        brightness: theme.brightness,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PackageProvince>(
          value: value,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.pureWhite,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.primary,
          ),
          padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
          items: PackageProvince.values
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(
                    p.title(isEnglish),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _PackageKindTabs extends StatelessWidget {
  const _PackageKindTabs({
    required this.selected,
    required this.availableKinds,
    required this.onChanged,
    required this.dedicatedLabel,
    required this.unlimitedLabel,
    required this.volumeLabel,
  });

  final InternetPackageKind selected;
  final List<InternetPackageKind> availableKinds;
  final ValueChanged<InternetPackageKind> onChanged;
  final String dedicatedLabel;
  final String unlimitedLabel;
  final String volumeLabel;

  String _labelFor(InternetPackageKind kind) {
    switch (kind) {
      case InternetPackageKind.dedicated:
        return dedicatedLabel;
      case InternetPackageKind.unlimited:
        return unlimitedLabel;
      case InternetPackageKind.volume:
        return volumeLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (availableKinds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        for (var i = 0; i < availableKinds.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _TabChip(
              label: _labelFor(availableKinds[i]),
              selected: selected == availableKinds[i],
              onTap: () => onChanged(availableKinds[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = AppTheme.primaryFor(theme.brightness);
    final colorScheme = theme.colorScheme;

    final selectedBg = isDark ? AppTheme.pureWhite : primary;
    final selectedFg = isDark ? AppTheme.primary : AppTheme.pureWhite;
    final unselectedBg = isDark
        ? AppTheme.navyMid.withValues(alpha: 0.35)
        : colorScheme.surface;
    final unselectedFg = isDark
        ? AppTheme.pureWhite
        : colorScheme.onSurface.withValues(alpha: 0.85);
    final borderColor = selected
        ? selectedBg
        : (isDark
              ? AppTheme.accent.withValues(alpha: 0.35)
              : AppTheme.silver.withValues(alpha: 0.55));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? selectedBg : unselectedBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: selected && !isDark
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? selectedFg : unselectedFg,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageNote extends StatelessWidget {
  const _PackageNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.navyMid.withValues(alpha: 0.45)
            : AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppTheme.accent.withValues(alpha: 0.28)
              : AppTheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: isDark
                ? AppTheme.accent.withValues(alpha: 0.95)
                : AppTheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.9),
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.durationLabel,
    required this.dedicatedBadge,
    required this.unlimitedBadge,
    required this.volumeBadge,
    required this.daySpeedCaption,
    required this.nightSpeedCaption,
  });

  final InternetPackage package;
  final String durationLabel;
  final String dedicatedBadge;
  final String unlimitedBadge;
  final String volumeBadge;
  final String daySpeedCaption;
  final String nightSpeedCaption;

  String get _badge {
    if (package.isVolume) return volumeBadge;
    if (package.isUnlimited) return unlimitedBadge;
    return dedicatedBadge;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final onCard = isDark ? AppTheme.pureWhite : colorScheme.onSurface;
    final muted = onCard.withValues(alpha: isDark ? 0.92 : 0.75);

    final cardGradient = isDark
        ? AppTheme.cosmicCardGradient()
        : AppTheme.lightCardGradient();

    final specs = <Widget>[
      if (package.isVolume) ...[
        _SpecRow(
          icon: Icons.layers_outlined,
          label: package.volumeLabel,
          color: muted,
        ),
        const SizedBox(height: 6),
        _SpecRow(
          icon: Icons.wifi_rounded,
          label: package.speedLabel,
          color: muted,
        ),
      ] else if (package.isUnlimited) ...[
        _SpecRow(
          icon: Icons.wb_sunny_outlined,
          label: '${package.speedLabel} · $daySpeedCaption',
          color: muted,
        ),
        const SizedBox(height: 6),
        _SpecRow(
          icon: Icons.nights_stay_outlined,
          label: '${package.nightSpeedLabel} · $nightSpeedCaption',
          color: muted,
        ),
      ] else ...[
        _SpecRow(
          icon: Icons.wifi_rounded,
          label: package.speedLabel,
          color: muted,
        ),
      ],
      const SizedBox(height: 6),
      _SpecRow(
        icon: Icons.calendar_month_outlined,
        label: durationLabel,
        color: muted,
      ),
      const SizedBox(height: 6),
      _SpecRow(
        icon: Icons.payments_outlined,
        label: package.priceLabel,
        color: muted,
      ),
    ];

    return Material(
      color: Colors.transparent,
      elevation: isDark ? 0 : 1,
      shadowColor: AppTheme.primary.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark
              ? AppTheme.accent.withValues(alpha: 0.28)
              : AppTheme.silver.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: cardGradient),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0A2038).withValues(alpha: 0.85)
                        : AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.accent.withValues(alpha: 0.22)
                          : AppTheme.primary.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Text(
                    _badge,
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      package.heroLabel,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: isDark ? AppTheme.pureWhite : AppTheme.primary,
                        fontSize: package.isUnlimited ? 22 : 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
              Divider(
                height: 18,
                thickness: 1,
                color: isDark
                    ? AppTheme.accent.withValues(alpha: 0.22)
                    : AppTheme.silver.withValues(alpha: 0.35),
              ),
              ...specs,
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}



