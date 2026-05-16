import 'mikrotik_service.dart';
import '../models/mikrotik_connection.dart';

/// مدیر سرویس MikroTik - Singleton برای نگه‌داری اتصال در کل برنامه
class MikroTikServiceManager {
  static final MikroTikServiceManager _instance =
      MikroTikServiceManager._internal();
  factory MikroTikServiceManager() => _instance;
  MikroTikServiceManager._internal();

  MikroTikService? _service;
  MikroTikConnection? _currentConnection;
  Map<String, dynamic>? _routerInfo;

  /// دریافت سرویس فعلی
  MikroTikService? get service => _service;

  /// بررسی اتصال
  bool get isConnected => _service?.isConnected ?? false;

  /// دریافت اطلاعات اتصال فعلی
  MikroTikConnection? get currentConnection => _currentConnection;

  /// دریافت اطلاعات روتر (کامل - شامل uptime, version, board-name, platform و ...)
  Map<String, dynamic>? get routerInfo => _routerInfo;

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
      throw Exception('اتصال برقرار نشده');
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
}
