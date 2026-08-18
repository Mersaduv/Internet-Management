import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/mikrotik_connection.dart';
import 'connection_heartbeat.dart';
import 'mikrotik_service.dart';
import 'mikrotik_timeouts.dart';
import 'settings_service.dart';
import 'traffic_monitor_service.dart';
import '../models/client_traffic_rate.dart';

/// مدیر سرویس MikroTik - Singleton برای نگه‌داری اتصال در کل برنامه
class MikroTikServiceManager {
  static final MikroTikServiceManager _instance =
      MikroTikServiceManager._internal();
  factory MikroTikServiceManager() => _instance;
  MikroTikServiceManager._internal();

  MikroTikService? _service;
  MikroTikConnection? _currentConnection;
  Map<String, dynamic>? _routerInfo;
  DateTime? _routerInfoCacheTime;
  ConnectionHeartbeat? _heartbeat;
  final TrafficMonitorService _trafficMonitor = TrafficMonitorService();
  bool _progressiveLoadActive = false;

  static const Duration _routerInfoCacheTtl = Duration(minutes: 5);

  /// دریافت سرویس فعلی
  MikroTikService? get service => _service;

  /// بررسی اتصال
  bool get isConnected => _service?.isConnected ?? false;

  /// دریافت اطلاعات اتصال فعلی
  MikroTikConnection? get currentConnection => _currentConnection;

  /// دریافت اطلاعات روتر (کامل - شامل uptime, version, board-name, platform و ...)
  Map<String, dynamic>? get routerInfo => _routerInfo;

  /// تلاش برای auto-login با اعتبارنامه و تنظیمات ذخیره‌شده.
  /// هرگز throw نمی‌کند.
  Future<bool> autoConnect() async {
    try {
      final settingsService = SettingsService();

      if (!await settingsService.hasValidSession()) {
        await settingsService.clearLoginTimestamp();
        if (!await settingsService.getRememberMe()) {
          await settingsService.clearCredentials();
        }
        return false;
      }

      final credentials = await settingsService.getSavedCredentials();
      if (credentials == null) {
        return false;
      }

      final settings = await settingsService.getAllSettings();
      final connection = MikroTikConnection(
        host: settings['host'] as String? ?? '192.168.88.1',
        port: MikroTikConnection.apiPort,
        username: credentials['username']!,
        password: credentials['password']!,
        useSsl: settings['useSsl'] as bool? ?? false,
      );

      final success = await connect(connection).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Auto-login timeout');
        },
      );
      return success;
    } catch (e) {
      debugPrint('[AUTO_LOGIN] Failed: $e');
      return false;
    }
  }

  /// اتصال به MikroTik
  Future<bool> connect(MikroTikConnection connection) async {
    try {
      // بستن اتصال قبلی اگر وجود دارد
      disconnect();

      // ایجاد سرویس جدید
      _service = MikroTikService();
      _currentConnection = connection;

      final success = await _service!.connect(connection);
      if (!success) {
        _service = null;
        _currentConnection = null;
        _routerInfo = null;
        _routerInfoCacheTime = null;
      } else {
        _heartbeat?.stop();
        _heartbeat = ConnectionHeartbeat(
          healthCheck: () async {
            if (_progressiveLoadActive) {
              return true;
            }
            final service = _service;
            if (service == null) {
              return false;
            }
            return service.isConnected &&
                await service.ensureConnected(forceHealthCheck: true);
          },
          reconnect: () async {
            final connection = _currentConnection;
            if (connection == null) {
              return false;
            }
            debugPrint('[HEARTBEAT] full reconnect');
            disconnect();
            return connect(connection);
          },
        );
        _heartbeat!.start();
      }
      return success;
    } catch (e) {
      _service = null;
      _currentConnection = null;
      throw Exception('خطا در اتصال: $e');
    }
  }

  /// بستن اتصال
  void disconnect() {
    _heartbeat?.stop();
    _heartbeat = null;
    unawaited(_trafficMonitor.disconnect());
    _service?.disconnect();
    _service = null;
    _currentConnection = null;
    _routerInfo = null;
    _routerInfoCacheTime = null;
    _progressiveLoadActive = false;
  }

  void beginProgressiveLoad() {
    _progressiveLoadActive = true;
    _heartbeat?.stop();
    _service?.beginProgressiveLoad();
  }

  void endProgressiveLoad() {
    _progressiveLoadActive = false;
    _service?.endProgressiveLoad();
    if (_service != null && isConnected) {
      _heartbeat?.start();
    }
  }

  /// Ensures the API session is usable (reconnects if the socket was dropped).
  Future<bool> ensureSession() async {
    final service = _service;
    if (service == null) {
      return false;
    }
    if (service.isConnected) {
      return true;
    }
    return service.ensureConnected(forceHealthCheck: true);
  }

  /// Ping the main API socket and reconnect if it died (common after extra logins).
  Future<bool> ensureSessionHealthy() async {
    final service = _service;
    if (service == null) {
      return false;
    }
    return service.ensureConnected(forceHealthCheck: true);
  }

  /// Router info cache is fresh if younger than 5 minutes.
  bool hasValidCachedRouterInfo() {
    if (_routerInfo == null || _routerInfoCacheTime == null) {
      return false;
    }
    return DateTime.now().difference(_routerInfoCacheTime!) <
        _routerInfoCacheTtl;
  }

  /// دریافت اطلاعات روتر (با refresh)
  Future<Map<String, dynamic>?> getRouterInfo({bool forceRefresh = false}) async {
    if (_service == null || !isConnected) {
      return null;
    }
    if (!forceRefresh && hasValidCachedRouterInfo()) {
      return _routerInfo;
    }
    try {
      _routerInfo = await _service!.getRouterInfo();
      _routerInfoCacheTime = DateTime.now();
      return _routerInfo;
    } catch (e) {
      return _routerInfo; // برگرداندن اطلاعات قبلی در صورت خطا
    }
  }

  /// Phase 3 — device IP, router info, lock status on isolated connection.
  /// Never throws; returns partial map on failure.
  Future<Map<String, dynamic>> loadSecondaryDataIsolated() async {
    final connection = _currentConnection;
    if (connection == null) {
      return {};
    }

    final isolated = MikroTikService();
    try {
      final connected = await isolated
          .connect(connection)
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
      if (!connected) {
        return {};
      }

      final routerInfoFuture = hasValidCachedRouterInfo()
          ? Future<Map<String, dynamic>?>.value(_routerInfo)
          : isolated.getRouterInfoSecondary();

      final results = await Future.wait<dynamic>([
        isolated.getDeviceIp(),
        routerInfoFuture,
        isolated.isNewConnectionsLocked(),
      ]);

      final routerInfo = results[1] as Map<String, dynamic>?;
      if (routerInfo != null && !hasValidCachedRouterInfo()) {
        _routerInfo = routerInfo;
        _routerInfoCacheTime = DateTime.now();
      }

      return {
        'deviceIp': results[0] as String?,
        'routerInfo': routerInfo ?? _routerInfo,
        'isNewConnectionsLocked': results[2] as bool? ?? false,
      };
    } catch (e) {
      debugPrint('[PROGRESSIVE_LOAD] isolated secondary failed: $e');
      return {};
    } finally {
      isolated.disconnect();
    }
  }

  /// دریافت همه کلاینت‌ها
  Future<Map<String, dynamic>> getAllClients() async {
    if (_service == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }
    return await _service!.getAllClients();
  }

  Future<List<Map<String, String>>> getPhase1BoundDhcpLeases() async {
    if (_service == null || !isConnected) {
      throw Exception('Connection is not established');
    }
    return _service!.getPhase1BoundDhcpLeases();
  }

  Future<List<Map<String, String>>> getPhase2ManagedBanRawRules() async {
    if (_service == null || !isConnected) {
      throw Exception('Connection is not established');
    }
    return _service!.getPhase2ManagedBanRawRules();
  }

  Future<int> getBannedDeviceCount() async {
    if (_service == null || !isConnected) {
      return 0;
    }
    return _service!.getBannedDeviceCount();
  }

  Future<List<Map<String, String>>> getPhase2ArpTable() async {
    if (_service == null || !isConnected) {
      throw Exception('Connection is not established');
    }
    return _service!.getPhase2ArpTable();
  }

  Future<List<Map<String, String>>> getPhase2NeighborDiscovery() async {
    if (_service == null || !isConnected) {
      throw Exception('Connection is not established');
    }
    return _service!.getPhase2NeighborDiscovery();
  }

  Future<List<Map<String, String>>> getArpTable() async {
    if (_service == null || !isConnected) {
      throw Exception('Connection is not established');
    }
    return _service!.getArpTable();
  }

  Future<List<Map<String, String>>> getDhcpLastSeen() async {
    if (_service == null || !isConnected) {
      throw Exception('Connection is not established');
    }
    return _service!.getDhcpLastSeen();
  }

  Future<List<Map<String, String>>> getPhase2WirelessRegistrations() async {
    if (_service == null || !isConnected) {
      throw Exception('Connection is not established');
    }
    return _service!.getPhase2WirelessRegistrations();
  }

  /// دریافت کلاینت‌های متصل
  Future<Map<String, dynamic>> getConnectedClients() async {
    if (_service == null || !isConnected) {
      throw Exception('Connection is not established');
    }
    return await _service!.getConnectedClients();
  }

  /// دریافت IP دستگاه کاربر
  Future<String?> getDeviceIp() async {
    if (_service == null || !isConnected) {
      return null;
    }
    return await _service!.getDeviceIp();
  }

  /// دریافت Default Gateway از route table RouterOS
  Future<String?> getDefaultGateway() async {
    if (_service == null || !isConnected) {
      return null;
    }
    return await _service!.getDefaultGateway();
  }

  /// دریافت Default Gateway یا IP روتر (fallback)
  Future<String?> getDefaultGatewayOrRouterIp() async {
    if (_service == null || !isConnected) {
      return null;
    }
    return await _service!.getDefaultGatewayOrRouterIp();
  }

  /// دریافت لیست دستگاه‌های مسدود شده
  Future<List<Map<String, dynamic>>> getBannedClients() async {
    if (_service == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }
    return await _service!.getBannedClients();
  }

  Future<bool> makeClientStatic({String? ipAddress, String? macAddress}) async {
    if (_service == null || !isConnected) {
      throw Exception('Connection is not established');
    }
    return _service!.makeClientStatic(
      ipAddress: ipAddress,
      macAddress: macAddress,
    );
  }

  Future<bool> lockNewConnections() async {
    if (_service == null || !isConnected) {
      throw Exception('Connection is not established');
    }
    return _service!.lockNewConnections();
  }

  Future<bool> unlockNewConnections() async {
    if (_service == null || !isConnected) {
      throw Exception('Connection is not established');
    }
    return _service!.unlockNewConnections();
  }

  Future<bool> isNewConnectionsLocked() async {
    if (_service == null || !isConnected) {
      return false;
    }
    return _service!.isNewConnectionsLocked();
  }

  Future<String> setDhcpLeaseDisplayName({
    String? ipAddress,
    String? macAddress,
    required String displayName,
  }) async {
    if (_service == null || !isConnected) {
      throw Exception('Connection is not established');
    }
    return _service!.setDhcpLeaseDisplayName(
      ipAddress: ipAddress,
      macAddress: macAddress,
      displayName: displayName,
    );
  }

  Future<Map<String, dynamic>> getWifiSettings({String? interfaceId}) async {
    if (_service == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }
    return _service!.getWifiSettings(interfaceId: interfaceId);
  }

  Future<void> saveWifiSettingsAtomic({
    required String interfaceName,
    required String profileName,
    required String ssid,
    required bool hideSsid,
    String? password,
  }) async {
    if (_service == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }
    return _service!.saveWifiSettingsAtomic(
      interfaceName: interfaceName,
      profileName: profileName,
      ssid: ssid,
      hideSsid: hideSsid,
      password: password,
    );
  }

  Future<Map<String, String>?> getClientSpeedIsolated(String target) async {
    final connection = _currentConnection;
    if (connection == null) {
      throw Exception('Connection is not established');
    }

    final speedService = MikroTikService();
    try {
      final connected = await speedService
          .connect(connection)
          .timeout(MikrotikTimeouts.isolatedConnect, onTimeout: () => false);
      if (!connected) {
        return null;
      }

      return await speedService
          .getClientSpeed(target)
          .timeout(const Duration(seconds: 20), onTimeout: () => null);
    } finally {
      speedService.disconnect();
    }
  }

  /// Poll live traffic on an isolated API socket (does not block main queue).
  Future<Map<String, ClientTrafficRate>> pollTrafficRates({
    required Set<String> trackedIps,
    required Map<String, String> macToIp,
  }) async {
    final connection = _currentConnection;
    if (connection == null || !isConnected) {
      return {};
    }

    try {
      await _trafficMonitor.ensureConnected(connection);
      return await _trafficMonitor.sampleRates(
        trackedIps: trackedIps,
        macToIp: macToIp,
      );
    } catch (e) {
      debugPrint('[TRAFFIC] poll failed: $e');
      return {};
    }
  }

  bool get trafficUsesInstantQueueRates => _trafficMonitor.usesInstantQueueRates;

  Future<void> disconnectTrafficMonitor() async {
    await _trafficMonitor.disconnect();
  }
}
