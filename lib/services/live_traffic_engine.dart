import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/client_traffic_rate.dart';
import '../models/live_traffic_capabilities.dart';
import '../models/mikrotik_connection.dart';
import '../utils/traffic_rate_parser.dart';
import 'mikrotik_timeouts.dart';
import 'routeros_client_v2.dart';
import 'traffic_monitor_queue_sync.dart';

/// Multi-source live traffic sampler used by ISP management apps (Mikhmon,
/// Home Assistant Mikrotik Router, Mikrocount).
///
/// Priority:
/// 1. `/queue/simple/print =stats=` — instant router-side rate
/// 2. `/ip/kid-control/device/print` — RouterOS v7+ per-MAC counters
/// 3. `/ip/accounting/snapshot` — per-IP WAN/LAN counters (RouterOS v6 style)
/// 4. `/ip/hotspot/active/print` — hotspot byte delta
/// 5. `/ip/firewall/connection/print` — per-IP byte delta (works for dynamic/pending leases)
class LiveTrafficEngine {
  RouterOSClientV2? _client;
  MikroTikConnection? _connection;

  LiveTrafficCapabilities _caps = LiveTrafficCapabilities.none;
  bool _capsProbed = false;
  bool _warmupPending = true;
  DateTime? _lastSampleAt;

  final Map<String, ({int rxBytes, int txBytes})> _prevQueueBytes = {};
  final Map<String, ({int bytesUp, int bytesDown})> _prevKidBytes = {};
  final Map<String, ({int bytesIn, int bytesOut})> _prevHotspotBytes = {};
  final Map<String, ({int rxBytes, int txBytes})> _prevConnectionBytes = {};
  final TrafficMonitorQueueSync _queueSync = TrafficMonitorQueueSync();

  LiveTrafficCapabilities get capabilities => _caps;
  bool get isReady => _client?.isConnected ?? false;

  Future<void> connect(MikroTikConnection connection) async {
    if (_connection == connection && (_client?.isConnected ?? false)) {
      return;
    }

    await disconnect();

    final client = RouterOSClientV2(
      address: connection.host,
      user: connection.username,
      password: connection.password,
      useSsl: connection.useSsl,
      port: connection.port,
    );

    final ok = await client
        .login()
        .timeout(MikrotikTimeouts.isolatedConnect, onTimeout: () => false);
    if (!ok) {
      client.close();
      throw StateError('live traffic connect failed');
    }

    _client = client;
    _connection = connection;
    _capsProbed = false;
    _warmupPending = true;
    _lastSampleAt = null;
    _clearBaselines();
    debugPrint('[LIVE_TRAFFIC] connected');
  }

  Future<Map<String, ClientTrafficRate>> sample({
    required Set<String> trackedIps,
    required Map<String, String> macToIp,
  }) async {
    final client = _client;
    if (client == null || !client.isConnected || trackedIps.isEmpty) {
      return {};
    }

    final pollTimeout = MikrotikTimeouts.trafficPollForClients(trackedIps.length);

    if (!_capsProbed) {
      _caps = await _probeCapabilities(client, pollTimeout);
      _capsProbed = true;
      debugPrint('[LIVE_TRAFFIC] primary=${_caps.primary}');
    }

    await _queueSync.ensureMonitorQueues(
      client: client,
      trackedIps: trackedIps,
    );
    if (_caps.queueStats == false) {
      _caps = LiveTrafficCapabilities(
        primary: LiveTrafficSource.queueStats,
        queueStats: true,
        kidControl: _caps.kidControl,
        ipAccounting: _caps.ipAccounting,
        hotspotActive: _caps.hotspotActive,
        firewallConnection: _caps.firewallConnection,
        accountingLocalTraffic: _caps.accountingLocalTraffic,
        localNetworkCidrs: _caps.localNetworkCidrs,
      );
    }

    final now = DateTime.now();
    final elapsed = _lastSampleAt == null ? null : now.difference(_lastSampleAt!);
    _lastSampleAt = now;

    if (_warmupPending) {
      await _captureBaselines(
        client,
        trackedIps,
        macToIp,
        pollTimeout,
      );
      _warmupPending = false;
      return {};
    }

    if (elapsed == null || elapsed.inMilliseconds < 300) {
      return {};
    }

    final sampledAt = now;
    final rates = <String, ClientTrafficRate>{};

    try {
      switch (_caps.primary) {
        case LiveTrafficSource.queueStats:
          await _mergeQueueStats(
            client,
            trackedIps,
            elapsed,
            sampledAt,
            rates,
            pollTimeout,
          );
        case LiveTrafficSource.kidControl:
          await _mergeKidControl(client, macToIp, elapsed, sampledAt, rates);
        case LiveTrafficSource.ipAccounting:
          await _mergeAccounting(
            client,
            trackedIps,
            elapsed,
            sampledAt,
            rates,
            pollTimeout,
          );
        case LiveTrafficSource.hotspotActive:
          await _mergeHotspot(client, trackedIps, elapsed, sampledAt, rates);
        case LiveTrafficSource.firewallConnection:
          await _mergeConnectionTracking(
            client,
            trackedIps,
            elapsed,
            sampledAt,
            rates,
            pollTimeout: pollTimeout,
          );
        case LiveTrafficSource.none:
          break;
      }

      await _mergeSecondarySources(
        client,
        trackedIps,
        macToIp,
        elapsed,
        sampledAt,
        rates,
        pollTimeout,
      );

      for (final ip in trackedIps) {
        rates.putIfAbsent(
          ip,
          () => ClientTrafficRate(rxBps: 0, txBps: 0, sampledAt: sampledAt),
        );
      }
    } catch (e) {
      debugPrint('[LIVE_TRAFFIC] sample failed: $e');
      await disconnect();
      return {};
    }

    return rates;
  }

  Future<void> _mergeSecondarySources(
    RouterOSClientV2 client,
    Set<String> trackedIps,
    Map<String, String> macToIp,
    Duration elapsed,
    DateTime sampledAt,
    Map<String, ClientTrafficRate> rates,
    Duration pollTimeout,
  ) async {
    if (_caps.primary != LiveTrafficSource.queueStats && _caps.queueStats) {
      await _mergeQueueStats(
        client,
        trackedIps,
        elapsed,
        sampledAt,
        rates,
        pollTimeout,
      );
    }
    if (_caps.primary != LiveTrafficSource.kidControl && _caps.kidControl) {
      await _mergeKidControl(client, macToIp, elapsed, sampledAt, rates);
    }
    if (_caps.primary != LiveTrafficSource.ipAccounting && _caps.ipAccounting) {
      await _mergeAccounting(
        client,
        trackedIps,
        elapsed,
        sampledAt,
        rates,
        pollTimeout,
      );
    }
    if (_caps.primary != LiveTrafficSource.hotspotActive && _caps.hotspotActive) {
      await _mergeHotspot(client, trackedIps, elapsed, sampledAt, rates);
    }
    if (_caps.firewallConnection) {
      await _mergeConnectionTracking(
        client,
        trackedIps,
        elapsed,
        sampledAt,
        rates,
        pollTimeout: pollTimeout,
        onlyMissing: false,
      );
    }
  }

  void _upsertPeakRate(
    Map<String, ClientTrafficRate> rates,
    String ip,
    ClientTrafficRate incoming,
  ) {
    final existing = rates[ip];
    if (existing == null) {
      rates[ip] = incoming;
      return;
    }
    final existingTotal = existing.rxBps + existing.txBps;
    final incomingTotal = incoming.rxBps + incoming.txBps;
    if (incomingTotal >= existingTotal) {
      rates[ip] = incoming;
    }
  }

  bool _needsFallbackRate(Map<String, ClientTrafficRate> rates, String ip) {
    final existing = rates[ip];
    if (existing == null) {
      return true;
    }
    return existing.rxBps == 0 && existing.txBps == 0;
  }

  Future<void> _captureBaselines(
    RouterOSClientV2 client,
    Set<String> trackedIps,
    Map<String, String> macToIp,
    Duration pollTimeout,
  ) async {
    if (_caps.queueStats) {
      final rows = await _fetchQueueStats(client, pollTimeout);
      for (final row in rows) {
        final ip = TrafficRateParser.ipFromQueueTarget(row['target']);
        if (ip == null) {
          continue;
        }
        _storeQueueBytes(ip, row['bytes']);
      }
    }

    if (_caps.kidControl) {
      final rows = await _fetchKidControlDevices(client);
      for (final row in rows) {
        final mac = _normalizeMac(row['mac-address']);
        final ip = mac != null ? macToIp[mac] : null;
        if (ip == null) {
          continue;
        }
        _prevKidBytes[ip] = (
          bytesUp: int.tryParse(row['bytes-up'] ?? '') ?? 0,
          bytesDown: int.tryParse(row['bytes-down'] ?? '') ?? 0,
        );
      }
    }

    if (_caps.ipAccounting) {
      await _takeAccountingSnapshot(client, pollTimeout);
    }

    if (_caps.hotspotActive) {
      final rows = await _fetchHotspotActive(client);
      for (final row in rows) {
        final ip = row['address']?.trim();
        if (ip == null || ip.isEmpty) {
          continue;
        }
        _prevHotspotBytes[ip] = (
          bytesIn: int.tryParse(row['bytes-in'] ?? '') ?? 0,
          bytesOut: int.tryParse(row['bytes-out'] ?? '') ?? 0,
        );
      }
    }

    if (_caps.firewallConnection) {
      await _captureConnectionBaselines(client, trackedIps, pollTimeout);
    }
  }

  Future<void> _mergeQueueStats(
    RouterOSClientV2 client,
    Set<String> trackedIps,
    Duration elapsed,
    DateTime sampledAt,
    Map<String, ClientTrafficRate> rates,
    Duration pollTimeout,
  ) async {
    final rows = await _fetchQueueStats(client, pollTimeout);
    for (final row in rows) {
      final ip = TrafficRateParser.ipFromQueueTarget(row['target']);
      if (ip == null || !trackedIps.contains(ip)) {
        continue;
      }

      var parsed = TrafficRateParser.fromQueueStatsRow(row);
      parsed ??= TrafficRateParser.fromQueueBytesDelta(
        bytesField: row['bytes'],
        prevRxBytes: _prevQueueBytes[ip]?.rxBytes ?? 0,
        prevTxBytes: _prevQueueBytes[ip]?.txBytes ?? 0,
        elapsed: elapsed,
      );

      _storeQueueBytes(ip, row['bytes']);

      if (parsed != null) {
        _upsertPeakRate(
          rates,
          ip,
          ClientTrafficRate(
            rxBps: parsed.rxBps,
            txBps: parsed.txBps,
            sampledAt: sampledAt,
          ),
        );
      }
    }
  }

  Future<void> _mergeKidControl(
    RouterOSClientV2 client,
    Map<String, String> macToIp,
    Duration elapsed,
    DateTime sampledAt,
    Map<String, ClientTrafficRate> rates,
  ) async {
    final rows = await _fetchKidControlDevices(client);
    for (final row in rows) {
      final mac = _normalizeMac(row['mac-address']);
      if (mac == null) {
        continue;
      }
      final ip = macToIp[mac];
      if (ip == null) {
        continue;
      }

      final bytesUp = int.tryParse(row['bytes-up'] ?? '') ?? 0;
      final bytesDown = int.tryParse(row['bytes-down'] ?? '') ?? 0;
      final prev = _prevKidBytes[ip];

      if (prev != null) {
        final delta = TrafficRateParser.fromByteDelta(
          prevRxBytes: prev.bytesDown,
          prevTxBytes: prev.bytesUp,
          rxBytes: bytesDown,
          txBytes: bytesUp,
          elapsed: elapsed,
        );
        if (delta != null) {
          _upsertPeakRate(
            rates,
            ip,
            ClientTrafficRate(
              rxBps: delta.rxBps,
              txBps: delta.txBps,
              sampledAt: sampledAt,
            ),
          );
        }
      }

      _prevKidBytes[ip] = (bytesUp: bytesUp, bytesDown: bytesDown);
    }
  }

  Future<void> _mergeAccounting(
    RouterOSClientV2 client,
    Set<String> trackedIps,
    Duration elapsed,
    DateTime sampledAt,
    Map<String, ClientTrafficRate> rates,
    Duration pollTimeout,
  ) async {
    await _takeAccountingSnapshot(client, pollTimeout);
    final rows = await _fetchAccountingSnapshot(client, pollTimeout);
    final totals = TrafficRateParser.aggregateAccountingRows(
      rows: rows,
      isLocalIp: _isLocalIp,
      trackedIps: trackedIps,
    );

    final seconds = elapsed.inMilliseconds / 1000.0;
    if (seconds <= 0) {
      return;
    }

    for (final ip in trackedIps) {
      final current = totals[ip];
      if (current == null) {
        continue;
      }
      final rxBps = (current.rxBytes * 8 / seconds).round();
      final txBps = (current.txBytes * 8 / seconds).round();
      _upsertPeakRate(
        rates,
        ip,
        ClientTrafficRate(
          rxBps: rxBps,
          txBps: txBps,
          sampledAt: sampledAt,
        ),
      );
    }
  }

  Future<void> _mergeHotspot(
    RouterOSClientV2 client,
    Set<String> trackedIps,
    Duration elapsed,
    DateTime sampledAt,
    Map<String, ClientTrafficRate> rates,
  ) async {
    final rows = await _fetchHotspotActive(client);
    for (final row in rows) {
      final ip = row['address']?.trim();
      if (ip == null || !trackedIps.contains(ip) || rates.containsKey(ip)) {
        continue;
      }

      final bytesIn = int.tryParse(row['bytes-in'] ?? '') ?? 0;
      final bytesOut = int.tryParse(row['bytes-out'] ?? '') ?? 0;
      final prev = _prevHotspotBytes[ip];
      if (prev != null) {
        final delta = TrafficRateParser.fromHotspotByteDelta(
          prevBytesIn: prev.bytesIn,
          prevBytesOut: prev.bytesOut,
          bytesIn: bytesIn,
          bytesOut: bytesOut,
          elapsed: elapsed,
        );
        if (delta != null) {
          _upsertPeakRate(
            rates,
            ip,
            ClientTrafficRate(
              rxBps: delta.rxBps,
              txBps: delta.txBps,
              sampledAt: sampledAt,
            ),
          );
        }
      }
      _prevHotspotBytes[ip] = (bytesIn: bytesIn, bytesOut: bytesOut);
    }
  }

  Future<void> _captureConnectionBaselines(
    RouterOSClientV2 client,
    Set<String> trackedIps,
    Duration pollTimeout,
  ) async {
    final totals = await _aggregateConnectionBytes(
      client,
      trackedIps,
      pollTimeout,
    );
    for (final entry in totals.entries) {
      _prevConnectionBytes[entry.key] = entry.value;
    }
  }

  Future<void> _mergeConnectionTracking(
    RouterOSClientV2 client,
    Set<String> trackedIps,
    Duration elapsed,
    DateTime sampledAt,
    Map<String, ClientTrafficRate> rates, {
    bool onlyMissing = false,
    required Duration pollTimeout,
  }) async {
    final totals = await _aggregateConnectionBytes(client, trackedIps, pollTimeout);

    for (final ip in trackedIps) {
      if (onlyMissing && !_needsFallbackRate(rates, ip)) {
        final current = totals[ip];
        if (current != null) {
          _prevConnectionBytes[ip] = current;
        }
        continue;
      }

      final current = totals[ip];
      if (current == null) {
        continue;
      }

      final prev = _prevConnectionBytes[ip];
      if (prev != null) {
        final delta = TrafficRateParser.fromByteDelta(
          prevRxBytes: prev.rxBytes,
          prevTxBytes: prev.txBytes,
          rxBytes: current.rxBytes,
          txBytes: current.txBytes,
          elapsed: elapsed,
        );
        if (delta != null) {
          _upsertPeakRate(
            rates,
            ip,
            ClientTrafficRate(
              rxBps: delta.rxBps,
              txBps: delta.txBps,
              sampledAt: sampledAt,
            ),
          );
        }
      }

      _prevConnectionBytes[ip] = current;
    }
  }

  Future<Map<String, ({int rxBytes, int txBytes})>> _aggregateConnectionBytes(
    RouterOSClientV2 client,
    Set<String> trackedIps,
    Duration pollTimeout,
  ) async {
    final totals = <String, ({int rxBytes, int txBytes})>{
      for (final ip in trackedIps) ip: (rxBytes: 0, txBytes: 0),
    };

    final rows = await _fetchFirewallConnections(client, pollTimeout);
    for (final row in rows) {
      final src = TrafficRateParser.hostFromEndpoint(row['src-address']);
      final dst = TrafficRateParser.hostFromEndpoint(row['dst-address']);
      final origBytes = int.tryParse(row['orig-bytes'] ?? '') ?? 0;
      final replBytes = int.tryParse(row['repl-bytes'] ?? '') ?? 0;

      if (src != null && totals.containsKey(src)) {
        final prev = totals[src]!;
        totals[src] = (
          rxBytes: prev.rxBytes + replBytes,
          txBytes: prev.txBytes + origBytes,
        );
      }
      if (dst != null && totals.containsKey(dst)) {
        final prev = totals[dst]!;
        totals[dst] = (
          rxBytes: prev.rxBytes + origBytes,
          txBytes: prev.txBytes + replBytes,
        );
      }
    }

    return totals;
  }

  Future<LiveTrafficCapabilities> _probeCapabilities(
    RouterOSClientV2 client,
    Duration pollTimeout,
  ) async {
    var queueStats = false;
    var kidControl = false;
    var ipAccounting = false;
    var hotspotActive = false;
    var firewallConnection = false;
    var accountingLocalTraffic = false;
    final localNetworks = <String>[];

    try {
      final queueRows = await _fetchQueueStats(client, pollTimeout);
      queueStats = queueRows.isNotEmpty;
    } catch (_) {}

    try {
      final kidRows = await _fetchKidControlDevices(client);
      kidControl = kidRows.isNotEmpty;
    } catch (_) {}

    try {
      final accounting = await client.talk(
        [
          '/ip/accounting/print',
          '=.proplist=enabled,account-local-traffic',
        ],
        timeout: MikrotikTimeouts.trafficPoll,
      );
      for (final row in accounting) {
        final enabled = row['enabled']?.toLowerCase();
        ipAccounting = enabled == 'true' || enabled == 'yes';
        final local = row['account-local-traffic']?.toLowerCase();
        accountingLocalTraffic = local == 'true' || local == 'yes';
      }
    } catch (_) {}

    try {
      final networks = await client.talk(
        [
          '/ip/dhcp-server/network/print',
          '=.proplist=address',
        ],
        timeout: MikrotikTimeouts.trafficPoll,
      );
      for (final row in networks) {
        final cidr = row['address']?.trim();
        if (cidr != null && cidr.isNotEmpty) {
          localNetworks.add(cidr);
        }
      }
    } catch (_) {}

    try {
      final hotspot = await _fetchHotspotActive(client);
      hotspotActive = hotspot.isNotEmpty;
    } catch (_) {}

    try {
      await _fetchFirewallConnections(client, pollTimeout);
      firewallConnection = true;
    } catch (_) {}

    final primary = queueStats
        ? LiveTrafficSource.queueStats
        : kidControl
            ? LiveTrafficSource.kidControl
            : ipAccounting
                ? LiveTrafficSource.ipAccounting
                : hotspotActive
                    ? LiveTrafficSource.hotspotActive
                    : firewallConnection
                        ? LiveTrafficSource.firewallConnection
                        : LiveTrafficSource.none;

    return LiveTrafficCapabilities(
      primary: primary,
      queueStats: queueStats,
      kidControl: kidControl,
      ipAccounting: ipAccounting,
      hotspotActive: hotspotActive,
      firewallConnection: firewallConnection,
      accountingLocalTraffic: accountingLocalTraffic,
      localNetworkCidrs: localNetworks,
    );
  }

  bool _isLocalIp(String ip) {
    for (final cidr in _caps.localNetworkCidrs) {
      if (TrafficRateParser.isIpInCidr(ip, cidr)) {
        return true;
      }
    }
    return false;
  }

  Future<List<Map<String, String>>> _fetchQueueStats(
    RouterOSClientV2 client,
    Duration pollTimeout,
  ) {
    return client.talk(
      [
        '/queue/simple/print',
        '=stats=',
        '=.proplist=target,rate,rx-rate,tx-rate,bytes',
      ],
      timeout: pollTimeout,
    );
  }

  Future<List<Map<String, String>>> _fetchKidControlDevices(
    RouterOSClientV2 client,
  ) {
    return client.talk(
      [
        '/ip/kid-control/device/print',
        '=.proplist=mac-address,bytes-up,bytes-down,disabled',
      ],
      timeout: MikrotikTimeouts.trafficPoll,
    );
  }

  Future<void> _takeAccountingSnapshot(
    RouterOSClientV2 client,
    Duration pollTimeout,
  ) async {
    await client.talk(
      ['/ip/accounting/snapshot/take'],
      timeout: pollTimeout,
    );
  }

  Future<List<Map<String, String>>> _fetchAccountingSnapshot(
    RouterOSClientV2 client,
    Duration pollTimeout,
  ) {
    return client.talk(
      [
        '/ip/accounting/snapshot/print',
        '=.proplist=src-address,dst-address,bytes',
      ],
      timeout: pollTimeout,
    );
  }

  Future<List<Map<String, String>>> _fetchHotspotActive(
    RouterOSClientV2 client,
  ) {
    return client.talk(
      [
        '/ip/hotspot/active/print',
        '=.proplist=address,bytes-in,bytes-out',
      ],
      timeout: MikrotikTimeouts.trafficPoll,
    );
  }

  Future<List<Map<String, String>>> _fetchFirewallConnections(
    RouterOSClientV2 client,
    Duration pollTimeout,
  ) {
    return client.talk(
      [
        '/ip/firewall/connection/print',
        '=.proplist=src-address,dst-address,orig-bytes,repl-bytes',
      ],
      timeout: pollTimeout,
    );
  }

  void _storeQueueBytes(String ip, String? bytesField) {
    if (bytesField == null || !bytesField.contains('/')) {
      return;
    }
    final parts = bytesField.split('/');
    if (parts.length < 2) {
      return;
    }
    _prevQueueBytes[ip] = (
      rxBytes: int.tryParse(parts[1].trim()) ?? 0,
      txBytes: int.tryParse(parts[0].trim()) ?? 0,
    );
  }

  void _clearBaselines() {
    _prevQueueBytes.clear();
    _prevKidBytes.clear();
    _prevHotspotBytes.clear();
    _prevConnectionBytes.clear();
  }

  String? _normalizeMac(String? mac) => mac?.trim().toUpperCase();

  Future<void> disconnect() async {
    _client?.close();
    _client = null;
    _connection = null;
    _caps = LiveTrafficCapabilities.none;
    _capsProbed = false;
    _warmupPending = true;
    _lastSampleAt = null;
    _queueSync.reset();
    _clearBaselines();
  }
}
