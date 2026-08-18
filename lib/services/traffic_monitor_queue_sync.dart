import 'package:flutter/foundation.dart';

import '../utils/traffic_rate_parser.dart';
import 'mikrotik_timeouts.dart';
import 'routeros_client_v2.dart';

/// Ensures every tracked client IP has a Simple Queue so `/queue/simple/print stats`
/// returns real-time rates (Mikhmon / ISP panel pattern).
///
/// Only adds monitor queues for IPs without an existing queue target. Existing
/// rate-limit queues are never modified.
class TrafficMonitorQueueSync {
  static const monitorComment = '[Ariyabod TRAFFIC MONITOR]';
  static const namePrefix = 'abmon-';

  final Set<String> _syncedIps = {};

  Future<void> ensureMonitorQueues({
    required RouterOSClientV2 client,
    required Set<String> trackedIps,
  }) async {
    if (trackedIps.isEmpty) {
      return;
    }

    final pending = trackedIps.difference(_syncedIps);
    if (pending.isEmpty) {
      return;
    }

    final existingTargets = await _fetchQueueTargetIps(client);
    var added = 0;

    for (final ip in pending) {
      if (existingTargets.contains(ip)) {
        _syncedIps.add(ip);
        continue;
      }

      final created = await _addMonitorQueue(client, ip);
      if (created) {
        existingTargets.add(ip);
        added++;
        _syncedIps.add(ip);
      }
    }

    if (added > 0) {
      debugPrint('[LIVE_TRAFFIC] monitor queues added: $added');
    }
  }

  void reset() {
    _syncedIps.clear();
  }

  Future<Set<String>> _fetchQueueTargetIps(RouterOSClientV2 client) async {
    final rows = await client.talk(
      [
        '/queue/simple/print',
        '=.proplist=target',
      ],
      timeout: MikrotikTimeouts.trafficPollForClients(64),
    );

    final targets = <String>{};
    for (final row in rows) {
      final ip = TrafficRateParser.ipFromQueueTarget(row['target']);
      if (ip != null) {
        targets.add(ip);
      }
    }
    return targets;
  }

  Future<bool> _addMonitorQueue(RouterOSClientV2 client, String ip) async {
    final name = '$namePrefix${ip.replaceAll('.', '-')}';
    try {
      await client.talk(
        [
          '/queue/simple/add',
          '=name=$name',
          '=target=$ip/32',
          '=max-limit=0/0',
          '=comment=$monitorComment',
        ],
        timeout: const Duration(seconds: 2),
      );
      return true;
    } catch (e) {
      debugPrint('[LIVE_TRAFFIC] monitor queue add failed for $ip: $e');
      return false;
    }
  }
}
