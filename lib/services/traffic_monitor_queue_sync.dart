import 'package:flutter/foundation.dart';

import 'routeros_client_v2.dart';

/// Previously created per-IP monitor Simple Queues. That write path is disabled:
/// company PCQ/group queues already match first, so extra queues stay at 0/0
/// and pollute the router. Home and company both use read-only sampling instead.
class TrafficMonitorQueueSync {
  static const monitorComment = '[Ariyabod TRAFFIC MONITOR]';
  static const namePrefix = 'abmon-';

  Future<void> ensureMonitorQueues({
    required RouterOSClientV2 client,
    required Set<String> trackedIps,
  }) async {
    debugPrint(
      '[LIVE_TRAFFIC] skip monitor-queue write '
      '(read-only sampling, ${trackedIps.length} ips)',
    );
  }

  void reset() {}
}
