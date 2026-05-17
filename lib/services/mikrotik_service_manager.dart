import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/mikrotik_connection.dart';
import 'connection_heartbeat.dart';
import 'mikrotik_service.dart';
import 'settings_service.dart';

/// مدیر سرویس MikroTik - Singleton برای نگه‌داری اتصال در کل برنامه
class MikroTikServiceManager {
  static final MikroTikServiceManager _instance =
      MikroTikServiceManager._internal();
  factory MikroTikServiceManager() => _instance;
  MikroTikServiceManager._internal();

  MikroTikService? _service;
  MikroTikConnection? _currentConnection;
  Map<String, dynamic>? _routerInfo;
  ConnectionHeartbeat? _heartbeat;

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
        await settingsService.clearCredentials();
        await settingsService.clearLoginTimestamp();
        return false;
      }

      final credentials = await settingsService.getSavedCredentials();
      if (credentials == null) {
        return false;
      }

      final settings = await settingsService.getAllSettings();
      final connection = MikroTikConnection(
        host: settings['host'] as String? ?? '192.168.88.1',
        port: settings['port'] as int? ?? 8728,
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
      } else {
        // دریافت اطلاعات روتر بعد از اتصال موفق
        try {
          _routerInfo = await _service!.getRouterInfo();
        } catch (e) {
          // ignore errors - router info optional است
          _routerInfo = null;
        }

        _heartbeat?.stop();
        _heartbeat = ConnectionHeartbeat(
          healthCheck: () async {
            final service = _service;
            if (service == null) {
              return false;
            }
            return service.ensureConnected();
          },
          reconnect: () async {
            final service = _service;
            if (service == null) {
              return false;
            }
            return service.ensureConnected();
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
    _service?.disconnect();
    _service = null;
    _currentConnection = null;
    _routerInfo = null;
  }

  /// دریافت اطلاعات روتر (با refresh)
  Future<Map<String, dynamic>?> getRouterInfo() async {
    if (_service == null || !isConnected) {
      return null;
    }
    try {
      _routerInfo = await _service!.getRouterInfo();
      return _routerInfo;
    } catch (e) {
      return _routerInfo; // برگرداندن اطلاعات قبلی در صورت خطا
    }
  }

  /// دریافت همه کلاینت‌ها
  Future<Map<String, dynamic>> getAllClients() async {
    if (_service == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }
    return await _service!.getAllClients();
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

  Future<Map<String, String>?> getClientSpeedIsolated(String target) async {
    final connection = _currentConnection;
    if (connection == null) {
      throw Exception('Connection is not established');
    }

    final speedService = MikroTikService();
    try {
      final connected = await speedService
          .connect(connection)
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
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
}
