import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/client_info.dart';
import '../services/mikrotik_service_manager.dart';

/// Provider برای مدیریت state کلاینت‌ها به صورت real-time
class ClientsProvider extends ChangeNotifier {
  final MikroTikServiceManager _serviceManager = MikroTikServiceManager();
  static const Duration _deviceIpTimeout = Duration(seconds: 10);
  static const Duration _autoStaticTimeout = Duration(seconds: 10);
  static const Duration _routerInfoTimeout = Duration(seconds: 8);
  static const Duration _lockStatusTimeout = Duration(seconds: 8);
  static const Duration _bannedClientsTimeout = Duration(seconds: 10);
  static const Duration _connectedClientsTimeout = Duration(seconds: 12);

  // State variables
  bool _isLoading = false;
  bool _isDataComplete = false;
  List<ClientInfo> _clients = [];
  List<Map<String, dynamic>> _bannedClients = [];
  String? _errorMessage;
  String? _deviceIp;
  bool _isRefreshing = false;
  Map<String, dynamic>? _routerInfo;
  bool _isNewConnectionsLocked = false;
  bool _isLockUpdating = false;
  bool _isEnsuringCurrentDeviceStatic = false;
  String? _lastAutoStaticIp;
  final Set<String> _approvalActionsInProgress = <String>{};
  bool _isProgressiveLoading = false;
  Timer? _progressiveLoadTimer;
  Future<void>? _activeRefreshFuture;
  bool _isBootstrappingHome = false;

  // برای progressive loading
  // Getters
  bool get isLoading => _isLoading;
  bool get isDataComplete => _isDataComplete;
  List<ClientInfo> get clients => _clients;
  List<Map<String, dynamic>> get bannedClients => _bannedClients;
  String? get errorMessage => _errorMessage;
  String? get deviceIp => _deviceIp;
  bool get isRefreshing => _isRefreshing;
  bool get isConnected => _serviceManager.isConnected;
  Map<String, dynamic>? get routerInfo => _routerInfo;
  bool get isNewConnectionsLocked => _isNewConnectionsLocked;
  bool get isLockUpdating => _isLockUpdating;

  bool _isCurrentDeviceTarget(String ipAddress, {String? macAddress}) {
    final normalizedIp = ipAddress.trim();
    if (_deviceIp != null &&
        _deviceIp!.isNotEmpty &&
        normalizedIp == _deviceIp!.trim()) {
      return true;
    }

    final normalizedMac = macAddress?.trim().toUpperCase();
    if (normalizedMac == null || normalizedMac.isEmpty) {
      return false;
    }

    String? currentDeviceMac;
    for (final client in _clients) {
      if (client.ipAddress != _deviceIp) {
        continue;
      }
      final clientMac = client.macAddress?.trim().toUpperCase();
      if (clientMac != null && clientMac.isNotEmpty) {
        currentDeviceMac = clientMac;
        break;
      }
    }

    return currentDeviceMac != null && currentDeviceMac == normalizedMac;
  }

  int? _lastIpOctet(String? ipAddress) {
    if (ipAddress == null || ipAddress.isEmpty) {
      return null;
    }
    final parts = ipAddress.trim().split('.');
    if (parts.length != 4) {
      return null;
    }
    return int.tryParse(parts.last);
  }

  int? _ipToSortableInt(String? ipAddress) {
    if (ipAddress == null || ipAddress.isEmpty) {
      return null;
    }
    final parts = ipAddress.trim().split('.');
    if (parts.length != 4) {
      return null;
    }

    final numbers = parts.map(int.tryParse).toList();
    if (numbers.any((part) => part == null)) {
      return null;
    }

    return (numbers[0]! << 24) |
        (numbers[1]! << 16) |
        (numbers[2]! << 8) |
        numbers[3]!;
  }

  int _compareClientsByIpOrder(ClientInfo a, ClientInfo b) {
    final aLastOctet = _lastIpOctet(a.ipAddress);
    final bLastOctet = _lastIpOctet(b.ipAddress);

    if (aLastOctet != null && bLastOctet != null) {
      final byLastOctet = aLastOctet.compareTo(bLastOctet);
      if (byLastOctet != 0) {
        return byLastOctet;
      }
    } else if (aLastOctet != null) {
      return -1;
    } else if (bLastOctet != null) {
      return 1;
    }

    final aFullIp = _ipToSortableInt(a.ipAddress);
    final bFullIp = _ipToSortableInt(b.ipAddress);
    if (aFullIp != null && bFullIp != null) {
      final byFullIp = aFullIp.compareTo(bFullIp);
      if (byFullIp != 0) {
        return byFullIp;
      }
    } else if (aFullIp != null) {
      return -1;
    } else if (bFullIp != null) {
      return 1;
    }

    final aName = (a.hostName ?? a.name ?? a.user ?? '').toLowerCase();
    final bName = (b.hostName ?? b.name ?? b.user ?? '').toLowerCase();
    return aName.compareTo(bName);
  }

  bool _isStaticClient(ClientInfo client) {
    if (client.isStaticLease == true) {
      return true;
    }
    final dynamicValue = client.rawData['dynamic']?.toString().toLowerCase();
    return dynamicValue == 'false' || dynamicValue == 'no';
  }

  int _compareClientsForDisplay(ClientInfo a, ClientInfo b) {
    if (_deviceIp != null && _deviceIp!.isNotEmpty) {
      final aIsCurrent = a.ipAddress == _deviceIp;
      final bIsCurrent = b.ipAddress == _deviceIp;
      if (aIsCurrent && !bIsCurrent) {
        return -1;
      }
      if (!aIsCurrent && bIsCurrent) {
        return 1;
      }
    }

    final aIsStatic = _isStaticClient(a);
    final bIsStatic = _isStaticClient(b);
    if (aIsStatic != bIsStatic) {
      return aIsStatic ? -1 : 1;
    }

    return _compareClientsByIpOrder(a, b);
  }

  void _sortClientsForDisplay() {
    _clients.sort(_compareClientsForDisplay);
  }

  /// بارگذاری IP دستگاه
  Future<void> loadDeviceIp({
    bool forceRefresh = false,
    bool notifyChanges = true,
  }) async {
    if (_deviceIp != null && !_isRefreshing && !forceRefresh) {
      return;
    }

    try {
      final ip = await _serviceManager.getDeviceIp().timeout(
        _deviceIpTimeout,
        onTimeout: () => null,
      );
      if (ip != null && ip != _deviceIp) {
        _deviceIp = ip;
        if (_clients.isNotEmpty) {
          _sortClientsForDisplay();
        }
        if (notifyChanges) {
          notifyListeners();
        }
      }
    } catch (_) {
      // Keep the previous IP when detection fails.
    }
  }

  /// بارگذاری اطلاعات روتر (board-name و platform)
  Future<void> loadRouterInfo({bool notifyChanges = true}) async {
    if (!_serviceManager.isConnected) {
      return;
    }

    try {
      final routerInfo = await _serviceManager.getRouterInfo().timeout(
        _routerInfoTimeout,
        onTimeout: () => null,
      );
      if (routerInfo != null) {
        _routerInfo = routerInfo;
        if (notifyChanges) {
          notifyListeners();
        }
      }
    } catch (_) {
      // Router info is optional.
    }
  }

  Future<void> _ensureCurrentDeviceStatic() async {
    if (_isEnsuringCurrentDeviceStatic ||
        !_serviceManager.isConnected ||
        _serviceManager.service == null) {
      return;
    }

    final ip = _deviceIp?.trim();
    if (ip == null || ip.isEmpty || _lastAutoStaticIp == ip) {
      return;
    }

    _isEnsuringCurrentDeviceStatic = true;
    try {
      final success = await _serviceManager
          .makeClientStatic(ipAddress: ip)
          .timeout(_autoStaticTimeout, onTimeout: () => false);
      if (success) {
        _lastAutoStaticIp = ip;
      }
    } catch (_) {
      // Ignore auto-static errors and keep the app responsive.
    } finally {
      _isEnsuringCurrentDeviceStatic = false;
    }
  }

  /// بارگذاری لیست کلاینت‌های متصل
  Future<void> loadClients({
    bool showLoading = true,
    bool notifyChanges = true,
  }) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = '????? ?????? ???? ???. ???? ?????? ???? ????.';
      _isLoading = false;
      _isDataComplete = false;
      if (notifyChanges) {
        notifyListeners();
      }
      return;
    }

    if (showLoading) {
      _isLoading = true;
      _isDataComplete = false;
      _errorMessage = null;
      if (notifyChanges) {
        notifyListeners();
      }
    }

    try {
      final result = await _serviceManager.getConnectedClients().timeout(
        _connectedClientsTimeout,
      );
      final clientsList = (result['clients'] as List)
          .map((c) => ClientInfo.fromMap(c as Map<String, dynamic>))
          .toList();

      final bannedMacs = <String>{};
      final bannedIps = <String>{};
      for (final banned in _bannedClients) {
        final bannedMac = banned['mac_address']?.toString().toUpperCase();
        final bannedIp = banned['address']?.toString();
        if (bannedMac != null && bannedMac.isNotEmpty) {
          bannedMacs.add(bannedMac);
        }
        if (bannedIp != null && bannedIp.isNotEmpty) {
          bannedIps.add(bannedIp);
        }
      }

      final filteredClientsList = clientsList.where((client) {
        final mac = client.macAddress?.toUpperCase();
        final ip = client.ipAddress;
        return (mac == null || !bannedMacs.contains(mac)) &&
            (ip == null || !bannedIps.contains(ip));
      }).toList();

      _clients = filteredClientsList..sort(_compareClientsForDisplay);
      _isDataComplete = true;
      _isLoading = false;
      _errorMessage = null;
      if (notifyChanges) {
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = '??? ?? ?????? ???? ???????: $e';
      _isLoading = false;
      _isDataComplete = false;
      if (notifyChanges) {
        notifyListeners();
      }
    }
  }

  Future<void> loadBannedClients({bool notifyChanges = true}) async {
    if (!_serviceManager.isConnected) {
      return;
    }

    try {
      final bannedList = await _serviceManager.getBannedClients().timeout(
        _bannedClientsTimeout,
        onTimeout: () => <Map<String, dynamic>>[],
      );
      _bannedClients = bannedList;
      if (notifyChanges) {
        notifyListeners();
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadDeviceIpSafely({bool forceRefresh = false}) {
    return loadDeviceIp(
      forceRefresh: forceRefresh,
      notifyChanges: false,
    ).timeout(_deviceIpTimeout, onTimeout: () {});
  }

  Future<void> _loadRouterInfoSafely() {
    return loadRouterInfo(
      notifyChanges: false,
    ).timeout(_routerInfoTimeout, onTimeout: () {});
  }

  Future<void> _loadLockStatusSafely() {
    return loadNewConnectionsLockStatus(
      notifyChanges: false,
    ).timeout(_lockStatusTimeout, onTimeout: () {});
  }

  Future<void> _loadBannedClientsSafely() {
    return loadBannedClients(
      notifyChanges: false,
    ).timeout(_bannedClientsTimeout, onTimeout: () {});
  }

  Future<void> _ensureCurrentDeviceStaticSafely() {
    return _ensureCurrentDeviceStatic().timeout(
      _autoStaticTimeout,
      onTimeout: () {},
    );
  }

  Future<void> _loadClientsSafely() {
    return loadClients(
      showLoading: false,
      notifyChanges: false,
    ).timeout(_connectedClientsTimeout);
  }

  Future<void> _loadHomeSecondaryData({
    bool forceDeviceIpRefresh = false,
  }) async {
    if (_isBootstrappingHome || !_serviceManager.isConnected) {
      return;
    }

    _isBootstrappingHome = true;
    try {
      await _loadDeviceIpSafely(forceRefresh: forceDeviceIpRefresh);
      notifyListeners();
      await _ensureCurrentDeviceStaticSafely();
      await _loadBannedClientsSafely();
      notifyListeners();
      await _loadRouterInfoSafely();
      notifyListeners();
      await _loadLockStatusSafely();
      notifyListeners();
    } catch (_) {
      // Keep the current state; secondary data is optional.
    } finally {
      _isBootstrappingHome = false;
    }
  }

  /// به‌روزرسانی کامل داده‌ها (برای refresh)
  Future<void> refresh() {
    final activeRefresh = _activeRefreshFuture;
    if (activeRefresh != null) {
      return activeRefresh;
    }

    final future = _performRefresh();
    _activeRefreshFuture = future;
    future.whenComplete(() {
      if (identical(_activeRefreshFuture, future)) {
        _activeRefreshFuture = null;
      }
    });
    return future;
  }

  Future<void> _performRefresh() async {
    _isRefreshing = true;
    notifyListeners();

    try {
      await _loadClientsSafely();
      notifyListeners();
      await _loadHomeSecondaryData(forceDeviceIpRefresh: true);
    } catch (_) {
      _errorMessage = 'Refresh failed.';
      _isLoading = false;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// مسدود کردن کلاینت به صورت آنی (سریع - الگو از banClient)
  /// این متد فوراً UI را به‌روزرسانی می‌کند و عملیات را در پس‌زمینه انجام می‌دهد
  Future<bool> banClientInstant(String ipAddress, {String? macAddress}) async {
    if (ipAddress.isEmpty) {
      return false;
    }

    _removeClientFromList(ipAddress, macAddress: macAddress);
    notifyListeners();

    Future.microtask(() async {
      if (!_serviceManager.isConnected || _serviceManager.service == null) {
        return;
      }
      try {
        await _serviceManager.service!
            .banClient(
              ipAddress,
              macAddress: macAddress,
              comment: 'Banned via Flutter App - Device Detail',
            )
            .timeout(const Duration(seconds: 15), onTimeout: () => false);
        await refresh().timeout(const Duration(seconds: 10), onTimeout: () {});
      } catch (_) {
        // Background ban errors should not block the already-updated UI.
      }
    });

    return true;
  }

  Future<bool> banClient(
    String ipAddress, {
    String? macAddress,
    String? hostname,
    String? ssid,
  }) async {
    if (!_serviceManager.isConnected || _serviceManager.service == null) {
      _errorMessage = 'Connection is not established.';
      notifyListeners();
      return false;
    }

    if (_isCurrentDeviceTarget(ipAddress, macAddress: macAddress)) {
      _errorMessage = 'امکان مسدود کردن دستگاه فعلی وجود ندارد.';
      notifyListeners();
      return false;
    }

    try {
      var success = await _serviceManager.service!
          .banClientWithFingerprint(
            ipAddress,
            macAddress: macAddress,
            hostname: hostname,
            ssid: ssid,
          )
          .timeout(const Duration(seconds: 30), onTimeout: () => false);

      if (!success) {
        success = await _serviceManager.service!
            .banClient(
              ipAddress,
              macAddress: macAddress,
              comment: 'Banned via Flutter App',
            )
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
      }

      if (!success) {
        _errorMessage = 'Client ban failed.';
        notifyListeners();
        return false;
      }

      _removeClientFromList(ipAddress, macAddress: macAddress);
      await refresh();

      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Error banning client: $e';
      notifyListeners();
      return false;
    }
  }

  void _removeClientFromList(String ipAddress, {String? macAddress}) {
    if (macAddress != null) {
      final macUpper = macAddress.toUpperCase();
      _clients.removeWhere(
        (client) =>
            client.macAddress?.toUpperCase() == macUpper ||
            client.ipAddress == ipAddress,
      );
      _isDataComplete = true;
      return;
    }

    _clients.removeWhere((client) => client.ipAddress == ipAddress);
    _isDataComplete = true;
  }

  /// بهینه‌سازی: refresh در پس‌زمینه انجام می‌شود تا UI فوراً پاسخ دهد
  String _clientActionKey(ClientInfo client) {
    return client.macAddress?.toUpperCase() ??
        client.ipAddress ??
        client.id ??
        client.hashCode.toString();
  }

  bool isApprovalActionInProgress(ClientInfo client) {
    return _approvalActionsInProgress.contains(_clientActionKey(client));
  }

  bool isDevicePendingApproval(
    ClientInfo client, {
    bool isCurrentDevice = false,
  }) {
    if (isCurrentDevice || client.isStaticLease == true) {
      return false;
    }
    return client.ipAddress != null &&
        (client.isStaticLease == false || client.macAddress != null);
  }

  void _markClientStatic(ClientInfo target) {
    final key = _clientActionKey(target);
    _clients = _clients.map((client) {
      if (_clientActionKey(client) != key) {
        return client;
      }
      final rawData = Map<String, dynamic>.from(client.rawData)
        ..['dynamic'] = 'false'
        ..['is_static_lease'] = true;
      return client.copyWith(isStaticLease: true, rawData: rawData);
    }).toList();
    _sortClientsForDisplay();
  }

  void _updateClientDisplayName(ClientInfo target, String displayName) {
    final key = _clientActionKey(target);
    _clients = _clients.map((client) {
      if (_clientActionKey(client) != key) {
        return client;
      }
      final rawData = Map<String, dynamic>.from(client.rawData)
        ..['host_name'] = displayName
        ..['host-name'] = displayName
        ..['comment'] = displayName;
      return client.copyWith(hostName: displayName, rawData: rawData);
    }).toList()..sort(_compareClientsForDisplay);
  }

  Future<bool> approveDevice(ClientInfo client) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = 'Connection is not established.';
      notifyListeners();
      return false;
    }

    final key = _clientActionKey(client);
    if (_approvalActionsInProgress.contains(key)) {
      return false;
    }

    _approvalActionsInProgress.add(key);
    notifyListeners();

    try {
      final success = await _serviceManager
          .makeClientStatic(
            ipAddress: client.ipAddress,
            macAddress: client.macAddress,
          )
          .timeout(_autoStaticTimeout, onTimeout: () => false);

      if (!success) {
        _errorMessage = 'Make Static failed.';
        return false;
      }

      _markClientStatic(client);
      _errorMessage = null;
      Future.microtask(refresh);
      return true;
    } catch (e) {
      _errorMessage = 'Error approving device: $e';
      return false;
    } finally {
      _approvalActionsInProgress.remove(key);
      notifyListeners();
    }
  }

  Future<bool> rejectDevice(ClientInfo client) async {
    if (client.ipAddress == null || client.ipAddress!.isEmpty) {
      _errorMessage = 'Device IP was not found.';
      notifyListeners();
      return false;
    }

    final key = _clientActionKey(client);
    if (_approvalActionsInProgress.contains(key)) {
      return false;
    }

    _approvalActionsInProgress.add(key);
    notifyListeners();

    try {
      final staticSuccess = await _serviceManager
          .makeClientStatic(
            ipAddress: client.ipAddress,
            macAddress: client.macAddress,
          )
          .timeout(_autoStaticTimeout, onTimeout: () => false);

      if (!staticSuccess) {
        _errorMessage = 'Make Static failed.';
        return false;
      }

      _markClientStatic(client);

      final banned = await banClient(
        client.ipAddress!,
        macAddress: client.macAddress,
        hostname: client.hostName,
        ssid: client.ssid,
      );
      _errorMessage = banned ? null : 'Device ban failed.';
      return banned;
    } catch (e) {
      _errorMessage = 'Error rejecting device: $e';
      return false;
    } finally {
      _approvalActionsInProgress.remove(key);
      notifyListeners();
    }
  }

  Future<void> loadNewConnectionsLockStatus({bool notifyChanges = true}) async {
    if (!_serviceManager.isConnected) {
      _isNewConnectionsLocked = false;
      return;
    }

    try {
      _isNewConnectionsLocked = await _serviceManager
          .isNewConnectionsLocked()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (notifyChanges) {
        notifyListeners();
      }
    } catch (_) {
      _isNewConnectionsLocked = false;
    }
  }

  Future<bool> lockNewConnections() async {
    if (!_serviceManager.isConnected) {
      _errorMessage = 'Connection is not established.';
      notifyListeners();
      return false;
    }

    _isLockUpdating = true;
    notifyListeners();

    try {
      final success = await _serviceManager.lockNewConnections().timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
      if (success) {
        _isNewConnectionsLocked = true;
        _errorMessage = null;
      } else {
        _errorMessage = 'Lock New Connections failed.';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error locking new connections: $e';
      return false;
    } finally {
      _isLockUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> unlockNewConnections() async {
    if (!_serviceManager.isConnected) {
      _errorMessage = 'Connection is not established.';
      notifyListeners();
      return false;
    }

    _isLockUpdating = true;
    notifyListeners();

    try {
      final success = await _serviceManager.unlockNewConnections().timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
      if (success) {
        _isNewConnectionsLocked = false;
        _errorMessage = null;
      } else {
        _errorMessage = 'Unlock New Connections failed.';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error unlocking new connections: $e';
      return false;
    } finally {
      _isLockUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> toggleNewConnectionsLock() {
    return _isNewConnectionsLocked
        ? unlockNewConnections()
        : lockNewConnections();
  }

  Future<String?> updateClientLeaseDisplayName(
    ClientInfo client,
    String displayName,
  ) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = 'Connection is not established.';
      notifyListeners();
      return null;
    }

    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      _errorMessage = 'Device name is required.';
      notifyListeners();
      return null;
    }

    try {
      final savedName = await _serviceManager
          .setDhcpLeaseDisplayName(
            ipAddress: client.ipAddress,
            macAddress: client.macAddress,
            displayName: normalizedName,
          )
          .timeout(const Duration(seconds: 20));

      _updateClientDisplayName(client, savedName);
      _errorMessage = null;
      notifyListeners();
      return savedName;
    } catch (e) {
      _errorMessage = 'Error saving device name: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> unbanClient(
    String ipAddress, {
    String? macAddress,
    String? hostname,
    String? ssid,
  }) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = 'اتصال برقرار نشده است.';
      notifyListeners();
      return false;
    }

    try {
      final success =
          await _serviceManager.service?.unbanClientWithFingerprint(
            ipAddress,
            macAddress: macAddress,
            hostname: hostname,
            ssid: ssid,
          ) ??
          false;

      if (!success) {
        _errorMessage = 'رفع مسدودیت انجام نشد.';
        notifyListeners();
        return false;
      }

      await refresh();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'خطا در رفع مسدودیت کلاینت: $e';
      notifyListeners();
      return false;
    }
  }

  /// تنظیم سرعت کلاینت و به‌روزرسانی state
  Future<bool> setClientSpeed(String target, String maxLimit) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = '????? ?????? ???? ???.';
      notifyListeners();
      return false;
    }

    try {
      final success = await _serviceManager.service
          ?.setClientSpeed(target, maxLimit)
          .timeout(_autoStaticTimeout, onTimeout: () => false);

      if (success == true) {
        _errorMessage = null;
        return true;
      }

      _errorMessage = '????? ???? ?????? ???.';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = '??? ?? ????? ????: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeClientSpeed(String target) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = '????? ?????? ???? ???.';
      notifyListeners();
      return false;
    }

    try {
      final success = await _serviceManager.service
          ?.removeClientSpeed(target)
          .timeout(_autoStaticTimeout, onTimeout: () => false);

      if (success == true) {
        _errorMessage = null;
        return true;
      }

      _errorMessage = '???? ??????? ???? ??? ???? ???.';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = '??? ?? ??? ????: $e';
      notifyListeners();
      return false;
    }
  }

  void clear() {
    // توقف progressive loading
    _progressiveLoadTimer?.cancel();
    _isProgressiveLoading = false;

    // _cancelAutoBanTimer(); // حذف شده
    _isLoading = false;
    _isDataComplete = false;
    _clients = [];
    _bannedClients = [];
    _errorMessage = null;
    _deviceIp = null;
    _isRefreshing = false;
    _routerInfo = null;
    _isNewConnectionsLocked = false;
    _isLockUpdating = false;
    _isEnsuringCurrentDeviceStatic = false;
    _lastAutoStaticIp = null;
    _isBootstrappingHome = false;
    _approvalActionsInProgress.clear();
    notifyListeners();
  }

  Future<bool> isDeviceBanned(String? macAddress, String? ipAddress) async {
    if (macAddress == null && ipAddress == null) {
      return false;
    }

    for (final banned in _bannedClients) {
      final bannedMac = banned['mac_address']?.toString().toUpperCase();
      final bannedIp = banned['address']?.toString();

      if (macAddress != null &&
          bannedMac != null &&
          macAddress.toUpperCase() == bannedMac) {
        return true;
      }

      if (ipAddress != null && bannedIp != null && ipAddress == bannedIp) {
        return true;
      }
    }

    return false;
  }

  Future<void> initialize() async {
    if (_isLoading || _isRefreshing) {
      return;
    }

    _isLoading = true;
    _isDataComplete = false;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadClientsSafely();
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Initial data loading failed.';
      _isDataComplete = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    Future.microtask(() => _loadHomeSecondaryData(forceDeviceIpRefresh: true));
  }

  // ignore: unused_element
  Future<void> _progressiveLoadClients(
    List<ClientInfo> allClients,
    bool dataComplete,
  ) async {
    // توقف timer قبلی اگر وجود دارد
    _progressiveLoadTimer?.cancel();

    _isProgressiveLoading = true;
    _isLoading = false; // دیگر در حالت loading نیستیم
    _isDataComplete = false;
    _clients = []; // پاک کردن لیست قبلی
    _errorMessage = null;
    notifyListeners();

    // تعداد دستگاه‌هایی که در هر مرحله نمایش داده می‌شوند
    const int batchSize = 5;
    int currentIndex = 0;

    // نمایش اولین batch فوراً
    if (allClients.isNotEmpty) {
      final endIndex = (currentIndex + batchSize).clamp(0, allClients.length);
      _clients = List.from(allClients.sublist(0, endIndex));
      currentIndex = endIndex;
      notifyListeners();
    }

    // نمایش بقیه دستگاه‌ها به صورت تدریجی
    while (currentIndex < allClients.length && _isProgressiveLoading) {
      await Future.delayed(
        const Duration(milliseconds: 80),
      ); // تاخیر کوتاه برای smooth rendering

      final endIndex = (currentIndex + batchSize).clamp(0, allClients.length);
      _clients = List.from(allClients.sublist(0, endIndex));
      currentIndex = endIndex;
      notifyListeners();
    }

    // اطمینان از اینکه همه دستگاه‌ها نمایش داده شده‌اند
    if (_isProgressiveLoading) {
      _clients = List.from(allClients);
      _isDataComplete = dataComplete;
      _isProgressiveLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // توقف progressive loading timer
    _progressiveLoadTimer?.cancel();
    // _cancelAutoBanTimer(); // حذف شده (قفل اتصال جدید حذف شده)
    super.dispose();
  }
}
