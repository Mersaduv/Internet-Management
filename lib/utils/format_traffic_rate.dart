/// Human-readable traffic rate labels for UI.
String formatTrafficRateBps(int? bps, {String emptyLabel = '—', bool measured = false}) {
  if (bps == null) {
    return measured ? '0 bps' : emptyLabel;
  }
  if (bps == 0) {
    return '0 bps';
  }
  if (bps >= 1000000000) {
    return '${(bps / 1000000000).toStringAsFixed(1)} Gbps';
  }
  if (bps >= 1000000) {
    return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
  }
  if (bps >= 1000) {
    return '${(bps / 1000).toStringAsFixed(0)} Kbps';
  }
  return '$bps bps';
}

/// Compact label for dense list rows (e.g. `12.4M`, `850K`, `42`).
String formatTrafficRateCompact(int? bps, {String emptyLabel = '—', bool measured = false}) {
  if (bps == null) {
    return measured ? '0' : emptyLabel;
  }
  if (bps == 0) {
    return '0';
  }
  if (bps >= 1000000000) {
    return '${(bps / 1000000000).toStringAsFixed(1)}G';
  }
  if (bps >= 1000000) {
    return '${(bps / 1000000).toStringAsFixed(1)}M';
  }
  if (bps >= 10000) {
    return '${(bps / 1000).toStringAsFixed(0)}K';
  }
  if (bps >= 1000) {
    return '${(bps / 1000).toStringAsFixed(1)}K';
  }
  return '$bps';
}

String formatTrafficPair(int? rxBps, int? txBps, {bool measured = false}) {
  final down = formatTrafficRateBps(rxBps, measured: measured);
  final up = formatTrafficRateBps(txBps, measured: measured);
  if (!measured && down == '—' && up == '—') {
    return '—';
  }
  return '↓ $down · ↑ $up';
}
