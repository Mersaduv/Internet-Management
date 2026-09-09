import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// پس‌زمینه مدرن: دارک = cosmic / روشن = گرادیان آبی‌خنک + glow نرم.
class CosmicBackground extends StatelessWidget {
  const CosmicBackground({
    super.key,
    this.child,
    this.showStars = true,
    this.showGlow = true,
  });

  final Widget? child;
  final bool showStars;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        _GradientLayer(isDark: isDark),
        if (showGlow) _GlowLayer(isDark: isDark),
        if (showStars && isDark) const Positioned.fill(child: _StarField()),
        if (child != null) child!,
      ],
    );
  }
}

class _GradientLayer extends StatelessWidget {
  const _GradientLayer({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppTheme.cosmicScaffoldGradient()
            : AppTheme.lightScaffoldGradient(),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _GlowLayer extends StatelessWidget {
  const _GlowLayer({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final top = isDark
        ? AppTheme.darkGlowDeep.withValues(alpha: 0.28)
        : AppTheme.navyMid.withValues(alpha: 0.10);
    final bottom = isDark
        ? AppTheme.darkGlow.withValues(alpha: 0.16)
        : AppTheme.accent.withValues(alpha: 0.10);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [top, top.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [bottom, bottom.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ],
      ),
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

    for (var i = 0; i < 110; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.35 + random.nextDouble() * 1.15;
      paint.color = AppTheme.pureWhite.withValues(
        alpha: 0.08 + random.nextDouble() * 0.32,
      );
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
