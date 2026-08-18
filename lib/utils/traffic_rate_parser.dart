/// Parses MikroTik queue / hotspot counters into bit-per-second rates.
abstract final class TrafficRateParser {
  /// Minimum interval for byte-delta rate math (avoids spike on short polls).
  static const int minDeltaElapsedMs = 350;

  /// Deltas older than this are a new baseline, not an instant rate.
  ///
  /// Must cover a slow `/ip/firewall/connection/print` on busy routers
  /// (several seconds). Off-viewport IPs already drop their baseline.
  static const int maxInstantElapsedMs = 20000;

  /// Ignore absurd delta spikes from counter resets or bad intervals.
  static const int maxReasonableBps = 500000000;
  /// Extract host IP from queue target, connection endpoint, or accounting row.
  ///
  /// Handles `192.168.1.5/32`, `192.168.1.5:443`, and bare IPv4.
  static String? hostFromEndpoint(String? endpoint) {
    final value = endpoint?.trim();
    if (value == null || value.isEmpty || value == '0.0.0.0') {
      return null;
    }

    if (value.contains('/')) {
      return ipFromQueueTarget(value);
    }

    if (value.startsWith('[')) {
      final end = value.indexOf(']');
      if (end > 1) {
        return value.substring(1, end);
      }
      return null;
    }

    final colonCount = ':'.allMatches(value).length;
    if (colonCount == 1 && value.contains('.')) {
      final split = value.split(':');
      if (split.length == 2 && int.tryParse(split[1]) != null) {
        return split[0];
      }
    }

    if (colonCount == 0 && value.contains('.')) {
      return value;
    }

    return null;
  }

  /// Extract IPv4 from queue target like `192.168.1.5/32`.
  ///
  /// Group / subnet targets are not a single host — use
  /// [isDedicatedHostQueueTarget] before mapping a rate to one client.
  static String? ipFromQueueTarget(String? target) {
    final value = target?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    final first = value.split(',').first.trim();
    final slash = first.indexOf('/');
    final ip = slash >= 0 ? first.substring(0, slash) : first;
    if (ip.isEmpty || ip == '0.0.0.0') {
      return null;
    }
    return ip;
  }

  /// True only for a single host queue (`1.2.3.4` or `1.2.3.4/32`).
  ///
  /// Skips PCQ/subnet (`172.16.0.0/24`) and department group targets
  /// (`ip/32,ip/32,...`) so their shared rate is not shown on one client.
  static bool isDedicatedHostQueueTarget(String? target) {
    final value = target?.trim();
    if (value == null || value.isEmpty || value.contains(',')) {
      return false;
    }

    final slash = value.indexOf('/');
    if (slash < 0) {
      return hostFromEndpoint(value) != null;
    }

    final prefix = value.substring(slash + 1).trim();
    if (prefix != '32') {
      return false;
    }
    final ip = value.substring(0, slash).trim();
    return ip.isNotEmpty && ip != '0.0.0.0' && ip.contains('.');
  }

  /// Queue `print stats` row → download (rx) / upload (tx) in bps.
  static ({int rxBps, int txBps})? fromQueueStatsRow(Map<String, String> row) {
    final explicitRx = _parseBitsPerSecond(row['rx-rate']);
    final explicitTx = _parseBitsPerSecond(row['tx-rate']);
    if (explicitRx != null || explicitTx != null) {
      return (
        rxBps: explicitRx ?? 0,
        txBps: explicitTx ?? 0,
      );
    }

    final rate = row['rate']?.trim();
    if (rate == null || rate.isEmpty || !rate.contains('/')) {
      return null;
    }

    final parts = rate.split('/');
    if (parts.length < 2) {
      return null;
    }

    // MikroTik queue stats: rate is upload/download (tx/rx from client view).
    final tx = _parseBitsPerSecond(parts[0]) ?? 0;
    final rx = _parseBitsPerSecond(parts[1]) ?? 0;
    return (rxBps: rx, txBps: tx);
  }

  /// Hotspot byte counters delta → bps (client download = bytes-in).
  static ({int rxBps, int txBps})? fromHotspotByteDelta({
    required int prevBytesIn,
    required int prevBytesOut,
    required int bytesIn,
    required int bytesOut,
    required Duration elapsed,
  }) {
    if (elapsed.inMilliseconds < minDeltaElapsedMs) {
      return null;
    }
    final seconds = elapsed.inMilliseconds / 1000.0;
    final rx = ((bytesIn - prevBytesIn).clamp(0, 1 << 62) * 8 / seconds).round();
    final tx =
        ((bytesOut - prevBytesOut).clamp(0, 1 << 62) * 8 / seconds).round();
    if (rx == 0 && tx == 0) {
      return null;
    }
    return (rxBps: rx, txBps: tx);
  }

  /// Cumulative queue `bytes` field delta (upload/download pair in row).
  static ({int rxBps, int txBps})? fromQueueBytesDelta({
    required String? bytesField,
    required int prevRxBytes,
    required int prevTxBytes,
    required Duration elapsed,
  }) {
    if (bytesField == null || !bytesField.contains('/')) {
      return null;
    }
    final parts = bytesField.split('/');
    if (parts.length < 2) {
      return null;
    }
    final txBytes = int.tryParse(parts[0].trim()) ?? 0;
    final rxBytes = int.tryParse(parts[1].trim()) ?? 0;
    return fromByteDelta(
      prevRxBytes: prevRxBytes,
      prevTxBytes: prevTxBytes,
      rxBytes: rxBytes,
      txBytes: txBytes,
      elapsed: elapsed,
    );
  }

  /// Valid window for instant byte-delta math, or null to recapture baseline.
  static Duration? instantElapsed(DateTime? baselineAt, DateTime now) {
    if (baselineAt == null) {
      return null;
    }
    final elapsed = now.difference(baselineAt);
    final ms = elapsed.inMilliseconds;
    if (ms < minDeltaElapsedMs || ms > maxInstantElapsedMs) {
      return null;
    }
    return elapsed;
  }

  static ({int rxBps, int txBps})? fromByteDelta({
    required int prevRxBytes,
    required int prevTxBytes,
    required int rxBytes,
    required int txBytes,
    required Duration elapsed,
  }) {
    if (elapsed.inMilliseconds < minDeltaElapsedMs) {
      return null;
    }
    final seconds = elapsed.inMilliseconds / 1000.0;
    final rx = ((rxBytes - prevRxBytes).clamp(0, 1 << 62) * 8 / seconds).round();
    final tx = ((txBytes - prevTxBytes).clamp(0, 1 << 62) * 8 / seconds).round();
    if (rx > maxReasonableBps || tx > maxReasonableBps) {
      return null;
    }
    return (rxBps: rx, txBps: tx);
  }

  /// IP accounting snapshot rows → per-IP byte totals for one interval.
  static Map<String, ({int rxBytes, int txBytes})> aggregateAccountingRows({
    required Iterable<Map<String, String>> rows,
    required bool Function(String ip) isLocalIp,
    required Set<String> trackedIps,
  }) {
    final totals = <String, ({int rxBytes, int txBytes})>{};
    for (final ip in trackedIps) {
      totals[ip] = (rxBytes: 0, txBytes: 0);
    }

    for (final row in rows) {
      final src = hostFromEndpoint(row['src-address']);
      final dst = hostFromEndpoint(row['dst-address']);
      final bytes = int.tryParse(row['bytes'] ?? '') ?? 0;
      if (bytes <= 0 || src == null || dst == null) {
        continue;
      }

      final srcLocal = isLocalIp(src);
      final dstLocal = isLocalIp(dst);

      if (srcLocal && dstLocal) {
        if (trackedIps.contains(src)) {
          final prev = totals[src]!;
          totals[src] = (rxBytes: prev.rxBytes, txBytes: prev.txBytes + bytes);
        }
        if (trackedIps.contains(dst)) {
          final prev = totals[dst]!;
          totals[dst] = (rxBytes: prev.rxBytes + bytes, txBytes: prev.txBytes);
        }
      } else if (srcLocal && !dstLocal && trackedIps.contains(src)) {
        final prev = totals[src]!;
        totals[src] = (rxBytes: prev.rxBytes, txBytes: prev.txBytes + bytes);
      } else if (!srcLocal && dstLocal && trackedIps.contains(dst)) {
        final prev = totals[dst]!;
        totals[dst] = (rxBytes: prev.rxBytes + bytes, txBytes: prev.txBytes);
      }
    }

    return totals;
  }

  static bool isIpInCidr(String ip, String cidr) {
    try {
      final parts = cidr.split('/');
      if (parts.length != 2) {
        return ip == cidr;
      }
      final base = _ipv4ToInt(parts[0]);
      final prefix = int.parse(parts[1]);
      final mask = prefix == 0 ? 0 : (~0 << (32 - prefix)) & 0xFFFFFFFF;
      final target = _ipv4ToInt(ip);
      return (base & mask) == (target & mask);
    } catch (_) {
      return false;
    }
  }

  static int _ipv4ToInt(String ip) {
    final octets = ip.split('.');
    if (octets.length != 4) {
      return 0;
    }
    var value = 0;
    for (final octet in octets) {
      value = (value << 8) + (int.tryParse(octet) ?? 0);
    }
    return value;
  }

  static int? _parseBitsPerSecond(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final lower = value.toLowerCase();
    if (RegExp(r'^\d+$').hasMatch(lower)) {
      return int.tryParse(lower);
    }

    final match = RegExp(
      r'^([\d.]+)\s*([kmgt]?)(?:bps|bit)?$',
      caseSensitive: false,
    ).firstMatch(lower.replaceAll(' ', ''));
    if (match == null) {
      return int.tryParse(lower);
    }

    final amount = double.tryParse(match.group(1)!);
    if (amount == null) {
      return null;
    }

    final unit = match.group(2) ?? '';
    final multiplier = switch (unit) {
      'k' => 1000,
      'm' => 1000000,
      'g' => 1000000000,
      't' => 1000000000000,
      _ => 1,
    };
    return (amount * multiplier).round();
  }
}
