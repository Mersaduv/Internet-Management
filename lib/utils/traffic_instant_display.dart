/// Unified instant traffic speed labels for list + detail (bits per second).
///
/// Format follows Windows Task Manager: fixed-width Mbps/Kbps labels updated on
/// a steady one-second cadence — never cumulative volume.
abstract final class TrafficInstantDisplay {
  /// Compact row label — Task Manager style (`1.2 Mbps`, `850 Kbps`, `0 bps`).
  static String compact(int? bps, {required bool measured}) {
    if (bps == null) {
      return measured ? '0 bps' : '—';
    }
    return _taskManagerLabel(bps);
  }

  /// Detail / verbose label with units (same scale as [compact]).
  static String verbose(int? bps, {required bool measured}) {
    if (bps == null) {
      return measured ? '0 bps' : '—';
    }
    return _taskManagerLabel(bps);
  }

  static String pair({
    required int? rxBps,
    required int? txBps,
    required bool measured,
  }) {
    final down = verbose(rxBps, measured: measured);
    final up = verbose(txBps, measured: measured);
    if (!measured && down == '—' && up == '—') {
      return '—';
    }
    return '↓ $down  ·  ↑ $up';
  }

  static String _taskManagerLabel(int bps) {
    if (bps == 0) {
      return '0 bps';
    }
    if (bps >= 1000000000) {
      return '${(bps / 1000000000).toStringAsFixed(1)} Gbps';
    }
    if (bps >= 1000000) {
      return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
    }
    if (bps >= 10000) {
      return '${(bps / 1000).toStringAsFixed(0)} Kbps';
    }
    if (bps >= 1000) {
      return '${(bps / 1000).toStringAsFixed(1)} Kbps';
    }
    return '$bps bps';
  }
}
