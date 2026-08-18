import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client_info.dart';
import '../providers/clients_provider.dart';
import '../utils/app_theme.dart';
import '../utils/format_traffic_rate.dart';

/// Immutable slice for [Selector] — only rebuilds when these values change.
class ClientTrafficUiState {
  final int? rxBps;
  final int? txBps;
  final bool showPlaceholder;
  final bool measured;

  const ClientTrafficUiState({
    required this.rxBps,
    required this.txBps,
    required this.showPlaceholder,
    required this.measured,
  });

  @override
  bool operator ==(Object other) {
    return other is ClientTrafficUiState &&
        other.rxBps == rxBps &&
        other.txBps == txBps &&
        other.showPlaceholder == showPlaceholder &&
        other.measured == measured;
  }

  @override
  int get hashCode => Object.hash(rxBps, txBps, showPlaceholder, measured);
}

/// Minimal live-traffic badge for device list rows.
///
/// Uses [Selector] so traffic polling does not rebuild the whole list — only
/// rows whose rates changed are repainted. Per-IP readiness means pending
/// approval devices show traffic as soon as their first sample arrives.
class ClientLiveTrafficBadge extends StatelessWidget {
  ClientLiveTrafficBadge({
    super.key,
    this.client,
    this.ipAddress,
    this.fixedSlot = false,
  }) : assert(
          client != null || ipAddress != null,
          'Provide client or ipAddress',
        );

  final ClientInfo? client;
  final String? ipAddress;
  final bool fixedSlot;

  String? get _ip => client?.ipAddress ?? ipAddress;

  static ClientTrafficUiState _selectState(
    ClientsProvider provider,
    String? ip,
  ) {
    if (ip == null || ip.trim().isEmpty) {
      return const ClientTrafficUiState(
        rxBps: null,
        txBps: null,
        showPlaceholder: false,
        measured: false,
      );
    }

    if (!provider.trafficUiEnabled) {
      return const ClientTrafficUiState(
        rxBps: null,
        txBps: null,
        showPlaceholder: true,
        measured: false,
      );
    }

    final measured = provider.trafficMeasuredForIp(ip);
    final sample = provider.trafficForIp(ip);
    return ClientTrafficUiState(
      rxBps: sample?.rxBps,
      txBps: sample?.txBps,
      showPlaceholder: !measured,
      measured: measured,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ip = _ip?.trim();

    if (ip == null || ip.isEmpty) {
      return fixedSlot
          ? const _TrafficSlot(child: _TrafficIdle())
          : const SizedBox.shrink();
    }

    return Selector<ClientsProvider, ClientTrafficUiState>(
      selector: (_, provider) => _selectState(provider, ip),
      shouldRebuild: (previous, next) => previous != next,
      builder: (context, state, _) {
        if (state.showPlaceholder) {
          return fixedSlot
              ? const _TrafficSlot(child: _TrafficSkeleton())
              : const _TrafficSkeleton();
        }

        final body = _TrafficBadgeBody(
          rxBps: state.rxBps,
          txBps: state.txBps,
          measured: state.measured,
          emphasize: (state.rxBps ?? 0) > 0 || (state.txBps ?? 0) > 0,
        );

        return fixedSlot ? _TrafficSlot(child: body) : body;
      },
    );
  }
}

class _TrafficBadgeBody extends StatelessWidget {
  const _TrafficBadgeBody({
    required this.rxBps,
    required this.txBps,
    required this.measured,
    required this.emphasize,
  });

  final int? rxBps;
  final int? txBps;
  final bool measured;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final downloadColor = emphasize
        ? AppTheme.primaryFor(theme.brightness)
        : colorScheme.onSurface.withValues(alpha: 0.55);
    final uploadColor = colorScheme.onSurface.withValues(alpha: 0.45);
    final bg = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : AppTheme.primary.withValues(alpha: 0.06);
    final border = colorScheme.outline.withValues(alpha: isDark ? 0.18 : 0.12);

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RateLine(
            icon: Icons.arrow_downward_rounded,
            color: downloadColor,
            label: formatTrafficRateCompact(rxBps, measured: measured),
            bold: emphasize && (rxBps ?? 0) > 0,
          ),
          const SizedBox(height: 2),
          _RateLine(
            icon: Icons.arrow_upward_rounded,
            color: uploadColor,
            label: formatTrafficRateCompact(txBps, measured: measured),
            bold: emphasize && (txBps ?? 0) > 0,
          ),
        ],
      ),
    );
  }
}

class _TrafficIdle extends StatelessWidget {
  const _TrafficIdle();

  @override
  Widget build(BuildContext context) {
    return const _TrafficBadgeBody(
      rxBps: null,
      txBps: null,
      measured: false,
      emphasize: false,
    );
  }
}

class _TrafficSlot extends StatelessWidget {
  const _TrafficSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Align(
        alignment: Alignment.centerRight,
        child: child,
      ),
    );
  }
}

class _RateLine extends StatelessWidget {
  const _RateLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.bold,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrafficSkeleton extends StatelessWidget {
  const _TrafficSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 72,
      height: 36,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

/// Detail screen row — same formatting rules as the list badge.
class ClientLiveTrafficDetailRow extends StatelessWidget {
  const ClientLiveTrafficDetailRow({
    super.key,
    this.client,
    required this.ipAddress,
    required this.label,
  });

  final ClientInfo? client;
  final String ipAddress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ip = client?.ipAddress ?? ipAddress;
    return Selector<ClientsProvider, ClientTrafficUiState>(
      selector: (_, provider) =>
          ClientLiveTrafficBadge._selectState(provider, ip),
      shouldRebuild: (previous, next) => previous != next,
      builder: (context, state, _) {
        if (state.showPlaceholder) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  formatTrafficPair(
                    state.rxBps,
                    state.txBps,
                    measured: state.measured,
                  ),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
