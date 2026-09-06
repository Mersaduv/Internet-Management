import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/internet_packages_data.dart';
import '../models/internet_package.dart';
import '../utils/app_layout.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';
import '../widgets/desktop_content.dart';

/// صفحهٔ کاتالوگ بسته‌های اینترنتی ابر توسعه.
class InternetPackagesScreen extends StatefulWidget {
  const InternetPackagesScreen({super.key});

  @override
  State<InternetPackagesScreen> createState() => _InternetPackagesScreenState();
}

class _InternetPackagesScreenState extends State<InternetPackagesScreen> {
  InternetPackageKind _selectedKind = InternetPackageKind.unlimited;

  String? _noteForKind(AppLocalizations? l10n) {
    switch (_selectedKind) {
      case InternetPackageKind.unlimited:
        return l10n?.unlimitedPackagesNote;
      case InternetPackageKind.family:
        return l10n?.familyPackagesNote;
      case InternetPackageKind.limited:
        return l10n?.limitedPackagesNote;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final packages = InternetPackagesData.byKind(_selectedKind);
    final isDesktop = AppLayout.isDesktop(context);
    final note = _noteForKind(l10n);
    final scaffoldBg =
        isDark ? AppTheme.darkScaffold : AppTheme.cableWhite;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [
                        Color(0xFF0A1628),
                        AppTheme.darkScaffold,
                        Color(0xFF050B14),
                      ]
                    : [
                        AppTheme.cableWhite,
                        colorScheme.surface,
                        AppTheme.cableWhite,
                      ],
              ),
            ),
          ),
          if (isDark) const Positioned.fill(child: _StarField()),
          SafeArea(
            child: DesktopContent(
              maxWidth: isDesktop ? 900 : AppLayout.pageMaxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text(
                      l10n?.internetPackagesTitle ?? 'بسته‌های اینترنتی',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: _PackageKindTabs(
                      selected: _selectedKind,
                      onChanged: (kind) {
                        if (kind == _selectedKind) return;
                        setState(() => _selectedKind = kind);
                      },
                      unlimitedLabel:
                          l10n?.unlimitedPackagesTab ?? 'نامحدود',
                      familyLabel: l10n?.familyPackagesTab ?? 'خانواده',
                      limitedLabel: l10n?.limitedPackagesTab ?? 'محدود',
                    ),
                  ),
                  Expanded(
                    child: KeyedSubtree(
                      key: ValueKey(_selectedKind),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = isDesktop
                              ? 3
                              : (constraints.maxWidth < 340 ? 1 : 2);
                          final mainAxisExtent = switch (_selectedKind) {
                            InternetPackageKind.limited =>
                              crossAxisCount == 1 ? 300.0 : 318.0,
                            InternetPackageKind.unlimited ||
                            InternetPackageKind.family =>
                              crossAxisCount == 1 ? 280.0 : 298.0,
                          };

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
                                          l10n?.durationDaysLabel(
                                                packages[index].durationDays,
                                              ) ??
                                              '${packages[index].durationDays} Day',
                                      unlimitedBadge:
                                          l10n?.unlimitedPackageBadge ??
                                              'بسته نامحدود',
                                      familyBadge:
                                          l10n?.familyPackageBadge ??
                                              'بسته خانواده',
                                      limitedBadge:
                                          l10n?.limitedPackageBadge ??
                                              'بسته محدود',
                                      daySpeedCaption:
                                          l10n?.daySpeedLabel ?? 'سرعت روزانه',
                                      nightSpeedCaption:
                                          l10n?.nightSpeedLabel ??
                                              'سرعت شبانه',
                                    );
                                  },
                                ),
                              ),
                              if (note != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    16,
                                  ),
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
          ),
        ],
      ),
    );
  }
}

class _PackageKindTabs extends StatelessWidget {
  const _PackageKindTabs({
    required this.selected,
    required this.onChanged,
    required this.unlimitedLabel,
    required this.familyLabel,
    required this.limitedLabel,
  });

  final InternetPackageKind selected;
  final ValueChanged<InternetPackageKind> onChanged;
  final String unlimitedLabel;
  final String familyLabel;
  final String limitedLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TabChip(
            label: unlimitedLabel,
            selected: selected == InternetPackageKind.unlimited,
            onTap: () => onChanged(InternetPackageKind.unlimited),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabChip(
            label: familyLabel,
            selected: selected == InternetPackageKind.family,
            onTap: () => onChanged(InternetPackageKind.family),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabChip(
            label: limitedLabel,
            selected: selected == InternetPackageKind.limited,
            onTap: () => onChanged(InternetPackageKind.limited),
          ),
        ),
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
    required this.unlimitedBadge,
    required this.familyBadge,
    required this.limitedBadge,
    required this.daySpeedCaption,
    required this.nightSpeedCaption,
  });

  final InternetPackage package;
  final String durationLabel;
  final String unlimitedBadge;
  final String familyBadge;
  final String limitedBadge;
  final String daySpeedCaption;
  final String nightSpeedCaption;

  String get _badge {
    if (package.isLimited) return limitedBadge;
    if (package.isFamily) return familyBadge;
    return unlimitedBadge;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final onCard = isDark ? AppTheme.pureWhite : colorScheme.onSurface;
    final muted = onCard.withValues(alpha: isDark ? 0.92 : 0.75);

    final cardGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF163A66),
              AppTheme.navyMid,
              Color(0xFF0C1F3D),
            ],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.pureWhite,
              Color.lerp(AppTheme.pureWhite, AppTheme.cableWhite, 0.65)!,
              AppTheme.cableWhite,
            ],
          );

    final specs = <Widget>[
      if (package.isLimited) ...[
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
      ] else ...[
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
      if (package.footnote != null) ...[
        const SizedBox(height: 8),
        Text(
          package.footnote!,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: muted,
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
              const SizedBox(height: 8),
              Text(
                package.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
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
                        fontSize: package.hasNightSpeed ? 20 : 28,
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

class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _StarFieldPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42);

    for (var i = 0; i < 90; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.4 + random.nextDouble() * 1.1;
      paint.color = AppTheme.pureWhite.withValues(
        alpha: 0.12 + random.nextDouble() * 0.35,
      );
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
