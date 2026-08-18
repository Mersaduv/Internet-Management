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
  int _failures = 0;

  LiveTrafficCapabilities get capabilities => _engine.capabilities;
  bool get usesInstantQueueRates => _engine.usesInstantQueueRates;

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
      final rates = await _engine
          .sample(trackedIps: trackedIps, macToIp: macToIp)
          .timeout(MikrotikTimeouts.trafficSampleTimeout(trackedIps.length));
      _failures = 0;
      return rates;
    } on TimeoutException {
      debugPrint('[TRAFFIC] sample timeout for ${trackedIps.length} clients');
      _failures++;
      if (_failures >= 3) {
        await disconnect();
      }
      return {};
    } catch (e) {
      debugPrint('[TRAFFIC] sample failed: $e');
      _failures++;
      if (_failures >= 3) {
        await disconnect();
      }
      return {};
    }
  }

  Future<void> disconnect() async {
    _failures = 0;
    await _engine.disconnect();
    _connection = null;
  }
}
