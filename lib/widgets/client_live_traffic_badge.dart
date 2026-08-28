import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client_info.dart';
import '../providers/clients_provider.dart';
import '../utils/app_theme.dart';
import '../utils/traffic_instant_display.dart';

/// Immutable slice for [Selector] — only rebuilds when these values change.
class ClientTrafficUiState {
  final int? rxBps;
  final int? txBps;
  final bool showPlaceholder;
  final bool measured;
  final bool inViewport;

  const ClientTrafficUiState({
    required this.rxBps,
    required this.txBps,
    required this.showPlaceholder,
    required this.measured,
    this.inViewport = false,
  });

  @override
  bool operator ==(Object other) {
    return other is ClientTrafficUiState &&
        other.rxBps == rxBps &&
        other.txBps == txBps &&
        other.showPlaceholder == showPlaceholder &&
        other.measured == measured &&
        other.inViewport == inViewport;
  }

  @override
  int get hashCode =>
      Object.hash(rxBps, txBps, showPlaceholder, measured, inViewport);
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
        inViewport: false,
      );
    }

    if (!provider.trafficUiEnabled) {
      return const ClientTrafficUiState(
        rxBps: null,
        txBps: null,
        showPlaceholder: true,
        measured: false,
        inViewport: false,
      );
    }

    final inPollTarget = provider.isTrafficPollTarget(ip);
    final measured = provider.trafficMeasuredForIp(ip);
    final sample = provider.trafficForIp(ip);
    final timedOut = provider.trafficAwaitingTimedOut(ip);

    if (!inPollTarget) {
      return const ClientTrafficUiState(
        rxBps: null,
        txBps: null,
        showPlaceholder: false,
        measured: false,
        inViewport: false,
      );
    }

    return ClientTrafficUiState(
      rxBps: sample?.rxBps,
      txBps: sample?.txBps,
      showPlaceholder: inPollTarget && !measured && !timedOut,
      measured: measured || timedOut,
      inViewport: inPollTarget,
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
        if (!state.inViewport && !state.measured) {
          return fixedSlot
              ? const _TrafficSlot(child: SizedBox.shrink())
              : const SizedBox.shrink();
        }

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
        : AppTheme.primaryFor(theme.brightness).withValues(alpha: 0.06);
    final border = colorScheme.outline.withValues(alpha: isDark ? 0.18 : 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RateLine(
            icon: Icons.arrow_downward_rounded,
            color: downloadColor,
            label: TrafficInstantDisplay.compact(rxBps, measured: measured),
            bold: emphasize && (rxBps ?? 0) > 0,
          ),
          const SizedBox(height: 2),
          _RateLine(
            icon: Icons.arrow_upward_rounded,
            color: uploadColor,
            label: TrafficInstantDisplay.compact(txBps, measured: measured),
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
    return Align(
      alignment: Alignment.centerRight,
      child: child,
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
        SizedBox(
          width: 76,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.right,
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
      width: 96,
      height: 36,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

/// Detail screen — same selector, badge, and numbers as the connected list.
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: theme.brightness == Brightness.dark
                    ? colorScheme.onSurface.withValues(alpha: 0.7)
                    : Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: ClientLiveTrafficBadge(
                client: client,
                ipAddress: ipAddress,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
