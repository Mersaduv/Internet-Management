import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/client_info.dart';
import '../services/mikrotik_service_manager.dart';
import '../services/network_info_service.dart';
import '../utils/client_display_policy.dart';

enum LoadingPhase { idle, phase1, phase2, phase3, complete }

/// Provider برای مدیریت state کلاینت‌ها به صورت real-time
class ClientsProvider extends ChangeNotifier {
  final MikroTikServiceManager _serviceManager = MikroTikServiceManager();
  static const Duration _autoStaticTimeout = Duration(seconds: 10);
  static const Duration _bannedClientsTimeout = Duration(seconds: 10);
  static const Duration _phase2StepTimeout = Duration(seconds: 18);
  static const Duration _phase3Timeout = Duration(seconds: 15);
  static const Duration _lockStatusCacheTtl = Duration(seconds: 30);
  static const String _banMarker = '[Ariyabod BAN]';

  // State variables
  bool _isLoading = false;
  bool _isDataComplete = false;
  bool _phase1Complete = false;
  bool _phase2Complete = false;
  bool _phase3Complete = false;
  LoadingPhase _currentPhase = LoadingPhase.idle;
  bool _bannedListLoaded = false;
  bool _isBannedListLoading = false;
  DateTime? _lockStatusCachedAt;
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
  Future<void>? _activeRefreshFuture;

  // Getters
  bool get isLoading => _isLoading;
  bool get isDataComplete => _isDataComplete;
  bool get phase1Complete => _phase1Complete;
  bool get phase2Complete => _phase2Complete;
  bool get phase3Complete => _phase3Complete;
  LoadingPhase get currentPhase => _currentPhase;
  bool get bannedListLoaded => _bannedListLoaded;
  bool get isBannedListLoading => _isBannedListLoading;
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

  bool _isBannedComment(String? comment) {
    final value = comment ?? '';
    return value.contains(_banMarker) ||
        value.contains('Banned via Flutter App') ||
        value.startsWith('Auto-banned:') ||
        value.startsWith('Banned:');
  }

  bool _isClientBanned(ClientInfo client) {
    if (client.rawData['is_banned'] == true) {
      return true;
    }
    final blockAccess = client.rawData['block-access']?.toString().toLowerCase();
    return blockAccess == 'yes' || blockAccess == 'true';
  }

  ({Set<String> ips, Set<String> macs}) _bannedTargetSets() {
    final ips = <String>{};
    final macs = <String>{};
    for (final banned in _bannedClients) {
      final ip = banned['address']?.toString().trim();
      final mac = banned['mac_address']?.toString().toUpperCase();
      if (ip != null && ip.isNotEmpty) {
        ips.add(ip);
      }
      if (mac != null && mac.isNotEmpty) {
        macs.add(mac);
      }
    }
    return (ips: ips, macs: macs);
  }

  bool _isTargetInBannedLists({String? ip, String? mac}) {
    final targets = _bannedTargetSets();
    final normalizedMac = mac?.toUpperCase();
    final normalizedIp = ip?.trim();
    if (normalizedIp != null &&
        normalizedIp.isNotEmpty &&
        targets.ips.contains(normalizedIp)) {
      return true;
    }
    return normalizedMac != null &&
        normalizedMac.isNotEmpty &&
        targets.macs.contains(normalizedMac);
  }

  void _filterBannedFromConnectedList() {
    final targets = _bannedTargetSets();
    _clients = _clients.where((client) {
      if (_isClientBanned(client)) {
        return false;
      }
      final mac = client.macAddress?.toUpperCase();
      final ip = client.ipAddress;
      if (mac != null && targets.macs.contains(mac)) {
        return false;
      }
      if (ip != null && targets.ips.contains(ip)) {
        return false;
      }
      return true;
    }).toList();
    _clients = _clients
        .where(ClientDisplayPolicy.shouldShowInConnectedList)
        .toList();
  }

  /// هم‌تراز کردن شمارش تب‌های متصل/مسدود پس از ban یا unban (بدون refresh کامل).
  void reconcileHomeListsAfterBanOrUnban() {
    _filterBannedFromConnectedList();
    _sortClientsForDisplay();
    notifyListeners();
  }

  String? _displayNameFromLease(Map<String, String> lease) {
    var comment = lease['comment']?.trim() ?? '';
    if (comment.isNotEmpty && !_isBannedComment(comment)) {
      comment = comment
          .replaceAll(_banMarker, '')
          .replaceAll('[Ariyabod STATIC]', '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      if (comment.isNotEmpty) {
        return comment;
      }
    }

    final hostName = lease['host-name']?.trim();
    if (hostName != null && hostName.isNotEmpty) {
      return hostName;
    }
    return null;
  }

  ClientInfo _clientFromDhcpLease(Map<String, String> lease) {
    final dynamicValue = lease['dynamic']?.toLowerCase();
    final isStatic = dynamicValue == 'false' || dynamicValue == 'no';
    final comment = lease['comment'];
    final isBanned =
        _isBannedComment(comment) ||
        lease['block-access']?.toLowerCase() == 'yes';

    final rawData = Map<String, dynamic>.from(lease)
      ..['is_banned'] = isBanned;

    return ClientInfo(
      type: 'dhcp',
      source: 'dhcp_lease',
      ipAddress: lease['address'],
      macAddress: lease['mac-address']?.toUpperCase(),
      hostName: _displayNameFromLease(lease),
      id: lease['.id'],
      isStaticLease: isStatic,
      rawData: rawData,
    );
  }

  int _clientIndexByMacOrIp({String? mac, String? ip}) {
    final normalizedMac = mac?.toUpperCase();
    for (var i = 0; i < _clients.length; i++) {
      final client = _clients[i];
      if (normalizedMac != null &&
          client.macAddress?.toUpperCase() == normalizedMac) {
        return i;
      }
      if (ip != null && client.ipAddress == ip) {
        return i;
      }
    }
    return -1;
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
        const Duration(seconds: 10),
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
        const Duration(seconds: 8),
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
        const Duration(seconds: 12),
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
        if (!ClientDisplayPolicy.shouldShowInConnectedList(client)) {
          return false;
        }
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
      _bannedListLoaded = true;
      if (notifyChanges) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PROGRESSIVE_LOAD] banned list failed: $e');
    }
  }

  Future<void> ensureBannedListLoaded({bool force = false}) async {
    if (force) {
      _bannedListLoaded = false;
    }
    if (_bannedListLoaded || _isBannedListLoading) {
      return;
    }

    _isBannedListLoading = true;
    notifyListeners();

    try {
      await loadBannedClients(notifyChanges: false);
    } finally {
      _isBannedListLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadPhase1DeviceList() async {
    if (!_serviceManager.isConnected) {
      throw Exception('Connection is not established');
    }

    final leases = await _serviceManager.getPhase1BoundDhcpLeases();

    _clients = leases.map(_clientFromDhcpLease).toList();
    _filterBannedFromConnectedList();
    _clients.sort(_compareClientsByIpOrder);
    _isDataComplete = false;
    _errorMessage = null;
  }

  Future<void> _loadPhase2StatusEnrichment() async {
    if (!_serviceManager.isConnected) {
      return;
    }

    try {
      final banRules = await _serviceManager
          .getPhase2ManagedBanRawRules()
          .timeout(_phase2StepTimeout, onTimeout: () => <Map<String, String>>[]);

      final bannedIps = <String>{};
      final bannedMacs = <String>{};
      for (final rule in banRules) {
        final ip = rule['src-address']?.trim();
        final mac = rule['src-mac-address']?.trim().toUpperCase();
        if (ip != null && ip.isNotEmpty) {
          bannedIps.add(ip);
        }
        if (mac != null && mac.isNotEmpty) {
          bannedMacs.add(mac);
        }
      }

      var banDataChanged = false;
      _clients = _clients.map((client) {
        final ip = client.ipAddress;
        final mac = client.macAddress?.toUpperCase();
        final confirmedBanned =
            (ip != null && bannedIps.contains(ip)) ||
            (mac != null && bannedMacs.contains(mac)) ||
            client.rawData['is_banned'] == true;

        if (confirmedBanned != (client.rawData['is_banned'] == true)) {
          banDataChanged = true;
        }

        if (!confirmedBanned) {
          return client;
        }

        final rawData = Map<String, dynamic>.from(client.rawData)
          ..['is_banned'] = true;
        return client.copyWith(rawData: rawData);
      }).toList();

      _filterBannedFromConnectedList();

      if (banDataChanged) {
        notifyListeners();
      }

      final arpEntries = await _serviceManager
          .getPhase2ArpTable()
          .timeout(_phase2StepTimeout, onTimeout: () => <Map<String, String>>[]);

      var arpChanged = false;
      for (final arp in arpEntries) {
        final mac = arp['mac-address']?.toUpperCase();
        final ip = arp['address'];
        if (mac == null || ip == null || ip.isEmpty) {
          continue;
        }

        final index = _clientIndexByMacOrIp(mac: mac);
        if (index < 0) {
          continue;
        }

        final client = _clients[index];
        if (client.ipAddress == null || client.ipAddress!.isEmpty) {
          _clients[index] = client.copyWith(
            ipAddress: ip,
            rawData: Map<String, dynamic>.from(client.rawData)..['address'] = ip,
          );
          arpChanged = true;
        }
      }

      if (arpChanged) {
        notifyListeners();
      }

      final routerInfoForWireless =
          _routerInfo ?? _serviceManager.routerInfo;
      var wirelessChanged = false;

      if (!ClientDisplayPolicy.shouldSkipWirelessEnrichment(
        routerInfoForWireless,
      )) {
        final wirelessClients = await _serviceManager
            .getPhase2WirelessRegistrations()
            .timeout(
              _phase2StepTimeout,
              onTimeout: () => <Map<String, String>>[],
            );

        for (final wireless in wirelessClients) {
          final mac = wireless['mac-address']?.toUpperCase();
          if (mac == null || mac.isEmpty) {
            continue;
          }

          final signal = wireless['signal-strength'];
          final ssid = wireless['ssid'];
          final lastIp = wireless['last-ip'];
          final index = _clientIndexByMacOrIp(mac: mac);

          if (index >= 0) {
            final client = _clients[index];
            final mergedIp = client.ipAddress ?? lastIp;
            if (!ClientDisplayPolicy.hasValidIp(mergedIp)) {
              continue;
            }
            final rawData = Map<String, dynamic>.from(client.rawData)
              ..addAll(wireless);
            _clients[index] = client.copyWith(
              type: 'wireless',
              ipAddress: mergedIp,
              signalStrength: signal ?? client.signalStrength,
              ssid: ssid ?? client.ssid,
              interface: wireless['interface'] ?? client.interface,
              rawData: rawData,
            );
            wirelessChanged = true;
          } else if (ClientDisplayPolicy.hasValidIp(lastIp) &&
              !_isTargetInBannedLists(ip: lastIp, mac: mac)) {
            _clients.add(
              ClientInfo(
                type: 'wireless',
                source: 'wireless_registration',
                macAddress: mac,
                ipAddress: lastIp,
                ssid: ssid,
                signalStrength: signal,
                interface: wireless['interface'],
                rawData: Map<String, dynamic>.from(wireless),
              ),
            );
            wirelessChanged = true;
          }
        }
      } else {
        debugPrint(
          '[CLIENT_LIST] skipping wireless enrichment for CPE/DHCP-only board',
        );
      }

      _filterBannedFromConnectedList();
      _sortClientsForDisplay();
      _isDataComplete = true;

      if (wirelessChanged || arpChanged) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PROGRESSIVE_LOAD] Phase 2 failed: $e');
      _sortClientsForDisplay();
      _isDataComplete = true;
    }
  }

  Future<void> _loadPhase3SecondaryData() async {
    try {
      String? localIp;
      try {
        localIp = await NetworkInfoService().getDeviceIPv4Address();
      } catch (_) {}

      final isolated = await _serviceManager
          .loadSecondaryDataIsolated()
          .timeout(_phase3Timeout, onTimeout: () => <String, dynamic>{});

      final deviceIp = isolated['deviceIp'] as String? ?? localIp;
      if (deviceIp != null && deviceIp.isNotEmpty) {
        _deviceIp = deviceIp;
      } else if (localIp != null && localIp.isNotEmpty) {
        _deviceIp = localIp;
      }

      final routerInfo = isolated['routerInfo'] as Map<String, dynamic>?;
      if (routerInfo != null) {
        _routerInfo = routerInfo;
        _filterBannedFromConnectedList();
      }

      if (isolated.containsKey('isNewConnectionsLocked')) {
        _isNewConnectionsLocked =
            isolated['isNewConnectionsLocked'] as bool? ?? false;
        _lockStatusCachedAt = DateTime.now();
      }

      if (_clients.isNotEmpty) {
        _sortClientsForDisplay();
      }

      _phase3Complete = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[PROGRESSIVE_LOAD] Phase 3 failed: $e');
    }
  }

  Future<void> _runBackgroundTasks() async {
    // Wait until progressive phases finish using the main API queue.
    await Future<void>.delayed(const Duration(seconds: 8));

    if (!_serviceManager.isConnected) {
      return;
    }

    try {
      await _ensureCurrentDeviceStatic();
    } catch (e) {
      debugPrint('[PROGRESSIVE_LOAD] auto-static failed: $e');
    }

    try {
      if (_serviceManager.service != null) {
        await _serviceManager.service!
            .checkAndBanBannedDevices()
            .timeout(const Duration(seconds: 25), onTimeout: () => []);
      }
    } catch (e) {
      debugPrint('[PROGRESSIVE_LOAD] checkAndBanBannedDevices failed: $e');
    }
  }

  Future<void> _runProgressiveLoad() async {
    if (_serviceManager.service == null) {
      _errorMessage = 'اتصال برقرار نشده است. لطفاً دوباره وارد شوید.';
      _isLoading = false;
      _isDataComplete = false;
      notifyListeners();
      return;
    }

    if (!_serviceManager.isConnected) {
      final restored = await _serviceManager.ensureSession();
      if (!restored) {
        _errorMessage = 'اتصال برقرار نشده است. لطفاً دوباره وارد شوید.';
        _isLoading = false;
        _isDataComplete = false;
        notifyListeners();
        return;
      }
    }

    _phase1Complete = false;
    _phase2Complete = false;
    _phase3Complete = false;
    _currentPhase = LoadingPhase.phase1;
    _isDataComplete = false;
    notifyListeners();

    _serviceManager.beginProgressiveLoad();
    try {
      await _loadPhase1DeviceList();
      _phase1Complete = true;
      _isLoading = false;
      _currentPhase = LoadingPhase.phase2;
      notifyListeners();

      await _loadPhase2StatusEnrichment();
      _phase2Complete = true;
      _currentPhase = LoadingPhase.phase3;
      notifyListeners();

      unawaited(_loadPhase3SecondaryData());
      unawaited(_runBackgroundTasks());

      _currentPhase = LoadingPhase.complete;
    } catch (e) {
      final message = e.toString();
      if (message.contains('Timeout') || message.contains('timeout')) {
        _errorMessage =
            'زمان دریافت لیست دستگاه‌ها تمام شد. اتصال را بررسی کنید و دوباره تلاش کنید.';
      } else {
        _errorMessage = message.replaceAll('Exception: ', '');
      }
      debugPrint('[PROGRESSIVE_LOAD] Error: $e');
      _isDataComplete = false;
    } finally {
      _serviceManager.endProgressiveLoad();
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
      await _runProgressiveLoad();
    } catch (e) {
      _errorMessage = 'Refresh failed.';
      debugPrint('[PROGRESSIVE_LOAD] refresh error: $e');
    } finally {
      _isRefreshing = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _addOptimisticBannedEntry({
    required String ipAddress,
    String? macAddress,
    String? hostname,
  }) {
    final macUpper = macAddress?.toUpperCase();
    final alreadyListed = _bannedClients.any((banned) {
      final bannedIp = banned['address']?.toString();
      final bannedMac = banned['mac_address']?.toString().toUpperCase();
      if (bannedIp == ipAddress) {
        return true;
      }
      return macUpper != null &&
          macUpper.isNotEmpty &&
          bannedMac == macUpper;
    });

    if (alreadyListed) {
      return;
    }

    _bannedClients = [
      ..._bannedClients,
      {
        'address': ipAddress,
        'mac_address': macAddress,
        'host_name': hostname,
        'hostname': hostname,
        'dhcp_blocked': true,
        'wireless_blocked': false,
        'chains': <String>[],
        'rule_ids': <String>[],
      },
    ];
    _bannedListLoaded = true;
  }

  Future<void> _applyBanOnRouterInBackground({
    required String ipAddress,
    String? macAddress,
    String? hostname,
    String? ssid,
  }) async {
    if (!_serviceManager.isConnected || _serviceManager.service == null) {
      return;
    }

    try {
      var success = await _serviceManager.service!
          .banClientWithFingerprint(
            ipAddress,
            macAddress: macAddress,
            hostname: hostname,
            ssid: ssid,
          )
          .timeout(const Duration(seconds: 25), onTimeout: () => false);

      if (!success) {
        success = await _serviceManager.service!
            .banClient(
              ipAddress,
              macAddress: macAddress,
              comment: 'Banned via Flutter App',
            )
            .timeout(const Duration(seconds: 15), onTimeout: () => false);
      }

      if (!success) {
        _errorMessage = 'Client ban failed.';
        notifyListeners();
        return;
      }

      await loadBannedClients(notifyChanges: false);
      _filterBannedFromConnectedList();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[BAN_FAST] background ban failed: $e');
      _errorMessage = 'Error banning client: $e';
      notifyListeners();
    }
  }

  /// مسدودسازی سریع از صفحه جزئیات — UI فوری، API در پس‌زمینه.
  Future<bool> banClientFast({
    required String ipAddress,
    String? macAddress,
    String? hostname,
    String? ssid,
  }) async {
    if (ipAddress.isEmpty) {
      return false;
    }

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

    _removeClientFromList(ipAddress, macAddress: macAddress);
    _addOptimisticBannedEntry(
      ipAddress: ipAddress,
      macAddress: macAddress,
      hostname: hostname,
    );
    _filterBannedFromConnectedList();
    _errorMessage = null;
    notifyListeners();

    unawaited(
      _applyBanOnRouterInBackground(
        ipAddress: ipAddress,
        macAddress: macAddress,
        hostname: hostname,
        ssid: ssid,
      ),
    );

    return true;
  }

  /// مسدود کردن کلاینت به صورت آنی (سریع - الگو از banClient)
  /// این متد فوراً UI را به‌روزرسانی می‌کند و عملیات را در پس‌زمینه انجام می‌دهد
  Future<bool> banClientInstant(String ipAddress, {String? macAddress}) async {
    if (ipAddress.isEmpty) {
      return false;
    }

    _removeClientFromList(ipAddress, macAddress: macAddress);
    notifyListeners();

    unawaited(
      _applyBanOnRouterInBackground(
        ipAddress: ipAddress,
        macAddress: macAddress,
      ),
    );

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

      final banned = await banClientFast(
        ipAddress: client.ipAddress!,
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

    if (_lockStatusCachedAt != null &&
        DateTime.now().difference(_lockStatusCachedAt!) < _lockStatusCacheTtl) {
      if (notifyChanges) {
        notifyListeners();
      }
      return;
    }

    try {
      _isNewConnectionsLocked = await _serviceManager
          .isNewConnectionsLocked()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      _lockStatusCachedAt = DateTime.now();
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

  void _addOptimisticConnectedEntry({
    required String ipAddress,
    String? macAddress,
    String? hostname,
    String? ssid,
  }) {
    final macUpper = macAddress?.toUpperCase();
    final alreadyListed = _clients.any((client) {
      if (client.ipAddress == ipAddress) {
        return true;
      }
      return macUpper != null &&
          macUpper.isNotEmpty &&
          client.macAddress?.toUpperCase() == macUpper;
    });
    if (alreadyListed) {
      return;
    }

    _clients.add(
      ClientInfo(
        type: macUpper != null ? 'wireless' : 'dhcp',
        source: 'unban_restore',
        ipAddress: ipAddress,
        macAddress: macUpper,
        hostName: hostname,
        ssid: ssid,
        rawData: const {'is_banned': false},
      ),
    );
    _sortClientsForDisplay();
  }

  void _removeFromBannedList(String ipAddress, {String? macAddress}) {
    final macUpper = macAddress?.toUpperCase();
    _bannedClients.removeWhere((banned) {
      final bannedIp = banned['address']?.toString();
      final bannedMac = banned['mac_address']?.toString().toUpperCase();
      if (bannedIp == ipAddress) {
        return true;
      }
      return macUpper != null &&
          macUpper.isNotEmpty &&
          bannedMac == macUpper;
    });
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
        _errorMessage =
            'رفع مسدودیت کامل نشد. DHCP یا Wireless هنوز مسدود است — دوباره تلاش کنید.';
        notifyListeners();
        return false;
      }

      Map<String, dynamic>? bannedSnapshot;
      for (final banned in _bannedClients) {
        final bannedIp = banned['address']?.toString();
        final bannedMac = banned['mac_address']?.toString().toUpperCase();
        if (bannedIp == ipAddress ||
            (macAddress != null &&
                macAddress.isNotEmpty &&
                bannedMac == macAddress.toUpperCase())) {
          bannedSnapshot = banned;
          break;
        }
      }

      _removeFromBannedList(ipAddress, macAddress: macAddress);
      _addOptimisticConnectedEntry(
        ipAddress: ipAddress,
        macAddress: macAddress,
        hostname:
            hostname ??
            bannedSnapshot?['host_name']?.toString() ??
            bannedSnapshot?['hostname']?.toString(),
        ssid: ssid ?? bannedSnapshot?['ssid']?.toString(),
      );
      await loadBannedClients(notifyChanges: false);
      _filterBannedFromConnectedList();
      _errorMessage = null;
      notifyListeners();

      unawaited(loadClients(showLoading: false, notifyChanges: true));
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
    _isLoading = false;
    _isDataComplete = false;
    _phase1Complete = false;
    _phase2Complete = false;
    _phase3Complete = false;
    _currentPhase = LoadingPhase.idle;
    _bannedListLoaded = false;
    _isBannedListLoading = false;
    _lockStatusCachedAt = null;
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
    if (_isRefreshing) {
      return;
    }
    if (_isLoading && _phase1Complete) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _runProgressiveLoad();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[PROGRESSIVE_LOAD] initialize error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
