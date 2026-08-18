import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/client_traffic_rate.dart';
import '../models/live_traffic_capabilities.dart';
import '../models/mikrotik_connection.dart';
import 'live_traffic_engine.dart';
import 'mikrotik_timeouts.dart';

/// Isolated RouterOS session dedicated to live traffic sampling.
class TrafficMonitorService {
  final LiveTrafficEngine _engine = LiveTrafficEngine();
  MikroTikConnection? _connection;

  LiveTrafficCapabilities get capabilities => _engine.capabilities;

  Future<void> ensureConnected(MikroTikConnection connection) async {
    if (_connection == connection && _engine.isReady) {
      return;
    }

    await disconnect();
    await _engine.connect(connection);
    _connection = connection;
    debugPrint('[TRAFFIC] monitor ready');
  }

  Future<Map<String, ClientTrafficRate>> sampleRates({
    required Set<String> trackedIps,
    required Map<String, String> macToIp,
  }) async {
    if (!_engine.isReady) {
      return {};
    }

    try {
      return await _engine
          .sample(trackedIps: trackedIps, macToIp: macToIp)
          .timeout(
            MikrotikTimeouts.trafficSampleTimeout(trackedIps.length),
            onTimeout: () {
              debugPrint(
                '[TRAFFIC] sample timeout for ${trackedIps.length} clients',
              );
              return {};
            },
          );
    } catch (e) {
      debugPrint('[TRAFFIC] sample failed: $e');
      await disconnect();
      return {};
    }
  }

  Future<void> disconnect() async {
    await _engine.disconnect();
    _connection = null;
  }
}
