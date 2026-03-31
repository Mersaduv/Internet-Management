import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client_info.dart';
import '../services/mikrotik_service_manager.dart';

/// Provider برای مدیریت state کلاینت‌ها به صورت real-time
class ClientsProvider extends ChangeNotifier {
  final MikroTikServiceManager _serviceManager = MikroTikServiceManager();

  // State variables
  bool _isLoading = false;
  bool _isDataComplete = false;
  List<ClientInfo> _clients = [];
  List<Map<String, dynamic>> _bannedClients = [];
  String? _errorMessage;
  String? _deviceIp;
  bool _isRefreshing = false;
  Map<String, dynamic>? _routerInfo;
  // قفل اتصال جدید - 状态变量
  bool _isNewConnectionsLocked = false;
  // Map برای ذخیره وضعیت فیلترینگ شبکه‌های اجتماعی (key: deviceIp, value: Map<String, bool>)
  final Map<String, Map<String, bool>> _deviceFilterStatus = {};
  
  // Set برای跟踪已批准的设备 (MAC addresses)
  Set<String> _approvedDevices = {};
  // Set برای跟踪已见过的设备 (用于检测新设备)
  Set<String> _seenDevices = {};
  // Set برای跟踪待批准的新设备 (首次出现的设备，等待用户批准)
  Set<String> _pendingApprovalDevices = {};
  
  // برای progressive loading
  bool _isProgressiveLoading = false;
  Timer? _progressiveLoadTimer;

  // Timer برای بررسی دوره‌ای دستگاه‌های جدید - حذف شده (قفل اتصال جدید حذف شده)
  // Timer? _autoBanCheckTimer;
  // static const Duration _autoBanCheckInterval = Duration(seconds: 5);

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
  // قفل اتصال جدید - Getter
  bool get isNewConnectionsLocked => _isNewConnectionsLocked;

  /// بارگذاری IP دستگاه
  Future<void> loadDeviceIp({bool forceRefresh = false}) async {
    // اگر IP قبلاً لود شده و force refresh نیست، دوباره لود نکن
    if (_deviceIp != null && !_isRefreshing && !forceRefresh) {
      return;
    }

    try {
      final ip = await _serviceManager.getDeviceIp().timeout(
        const Duration(seconds: 10), // افزایش timeout برای اطمینان از تشخیص صحیح
        onTimeout: () => null,
      );
      if (ip != null) {
        // همیشه IP را به‌روزرسانی کن (حتی اگر تغییر نکرده باشد)
        // چون ممکن است IP قبلی اشتباه تشخیص داده شده باشد
        _deviceIp = ip;
        notifyListeners();
      }
    } catch (e) {
      // در صورت خطا، IP قبلی را حفظ کن
    }
  }

  /// بارگذاری اطلاعات روتر (board-name و platform)
  Future<void> loadRouterInfo() async {
    if (!_serviceManager.isConnected) {
      return;
    }

    try {
      final routerInfo = await _serviceManager.getRouterInfo();
      if (routerInfo != null) {
        _routerInfo = routerInfo;
        notifyListeners();
      }
    } catch (e) {
      // ignore errors - router info optional است
    }
  }

  /// بارگذاری لیست کلاینت‌های متصل
  Future<void> loadClients({bool showLoading = true}) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = 'اتصال برقرار نشده است. لطفاً دوباره وارد شوید.';
      _isLoading = false;
      _isDataComplete = false;
      notifyListeners();
      return;
    }

    if (showLoading) {
      _isLoading = true;
      _isDataComplete = false;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final result = await _serviceManager.getConnectedClients();
      final clientsList = (result['clients'] as List)
          .map((c) => ClientInfo.fromMap(c as Map<String, dynamic>))
          .toList();

      // 检测新设备并标记为待批准
      // 更新已见过的设备列表
      final currentMacs = clientsList
          .where((client) => client.macAddress != null && client.macAddress!.isNotEmpty)
          .map((client) => client.macAddress!.toUpperCase())
          .toSet();
      
      // 检测新设备（首次出现的 MAC）
      final newDevices = currentMacs.where((mac) => !_seenDevices.contains(mac)).toSet();
      
      // 只有当"新连接锁定"激活时，才限制动态设备
      if (_isNewConnectionsLocked) {
        // 检查所有已连接的设备（不仅仅是新设备），限制动态设备
        for (var client in clientsList) {
          // 跳过静态设备 - 静态设备总是允许完全连接
          if (_isStaticDevice(client)) {
            continue;
          }
          
          // 跳过当前设备
          if (_deviceIp != null && client.ipAddress == _deviceIp) {
            continue;
          }
          
          // 跳过已批准的设备
          if (client.macAddress != null && _approvedDevices.contains(client.macAddress!.toUpperCase())) {
            continue;
          }
          
          // 跳过被封禁的设备（它们不应该显示批准/拒绝消息）
          // 检查设备是否被封禁 - بهینه‌سازی: استفاده از Set به جای async call
          bool isBanned = false;
          if (client.macAddress != null) {
            isBanned = _bannedClients.any((banned) => 
              banned['mac_address']?.toString().toUpperCase() == client.macAddress!.toUpperCase()
            );
          }
          if (!isBanned && client.ipAddress != null) {
            isBanned = _bannedClients.any((banned) => 
              banned['address']?.toString() == client.ipAddress
            );
          }
          if (isBanned) {
            continue; // 跳过被封禁的设备
          }
          
          // 如果是动态设备，需要限制访问
          if (client.macAddress != null) {
            final macUpper = client.macAddress!.toUpperCase();
            
            // استفاده از همان بررسی banned که قبلاً انجام دادیم
            if (isBanned) {
              continue; // 如果被封禁，跳过
            }
            
            // 检查是否是新设备
            final isNewDevice = newDevices.contains(macUpper);
            
            // 如果是新设备，添加到待批准列表
            if (isNewDevice) {
              // 确保设备没有被封禁
              if (!isBanned) {
                _pendingApprovalDevices.add(macUpper);
                print('🔔 [NEW_DEVICE] دستگاه جدید (Dynamic) شناسایی شد: MAC=$macUpper, IP=${client.ipAddress}');
              }
            } else {
              // 如果是已存在的动态设备，也添加到待批准列表（如果还没有批准且没有被封禁）
              if (!_pendingApprovalDevices.contains(macUpper) && !isBanned) {
                _pendingApprovalDevices.add(macUpper);
                print('🔔 [EXISTING_DEVICE] دستگاه موجود (Dynamic) نیاز به تایید: MAC=$macUpper, IP=${client.ipAddress}');
              }
            }
            
            // 限制动态设备的访问（只对未封禁的设备）
            if (!isBanned) {
              try {
                print('🔒 [LOCK_DYNAMIC] محدود کردن دسترسی دستگاه Dynamic: MAC=$macUpper, IP=${client.ipAddress}');
                await _serviceManager.restrictNonStaticDevice(
                  client.macAddress!,
                  ipAddress: client.ipAddress,
                );
              } catch (e) {
                print('⚠️ [LOCK_DYNAMIC] خطا در محدود کردن دسترسی: $e');
              }
            }
          }
        }
        
        if (newDevices.isNotEmpty) {
          print('🔔 [NEW_DEVICES] ${newDevices.length} دستگاه جدید شناسایی شد (قفل فعال): $newDevices');
        }
      } else if (newDevices.isNotEmpty) {
        // 如果锁定未激活，所有设备直接完全连接（不需要限制）
        print('🔔 [NEW_DEVICES] ${newDevices.length} دستگاه جدید شناسایی شد (قفل غیرفعال - دسترسی کامل): $newDevices');
      }
      
      // 清理已断开连接的设备（在更新_seenDevices之前）
      // 这样当设备重新连接时，会被识别为新设备，需要重新批准
      
      // 清理已断开连接的已批准设备
      // 如果已批准的设备不在当前连接列表中，从批准列表中移除
      if (_approvedDevices.isNotEmpty) {
        final disconnectedApprovedDevices = <String>[];
        for (var approvedMac in _approvedDevices) {
          // 检查这个已批准的设备是否还在当前连接列表中
          final isStillConnected = clientsList.any(
            (client) => client.macAddress?.toUpperCase() == approvedMac,
          );
          
          // 如果设备不在连接列表中，标记为需要移除
          if (!isStillConnected) {
            disconnectedApprovedDevices.add(approvedMac);
          }
        }
        
        // 从批准列表中移除已断开连接的设备
        if (disconnectedApprovedDevices.isNotEmpty) {
          for (var mac in disconnectedApprovedDevices) {
            _approvedDevices.remove(mac);
            _pendingApprovalDevices.remove(mac);
            // 同时从_seenDevices中移除，这样重新连接时会被识别为新设备
            _seenDevices.remove(mac);
            print('🗑️ [CLEANUP_APPROVED] دستگاه تایید شده از لیست حذف شد (قطع اتصال): MAC=$mac');
          }
          
          // 保存更新后的批准列表
          await _saveApprovedDevices();
          
          if (disconnectedApprovedDevices.length > 0) {
            print('✅ [CLEANUP_APPROVED] ${disconnectedApprovedDevices.length} دستگاه تایید شده از لیست حذف شدند (باید دوباره تایید شوند)');
          }
        }
      }
      
      // 清理待批准列表中已断开连接的设备
      if (_pendingApprovalDevices.isNotEmpty) {
        final disconnectedPendingDevices = <String>[];
        for (var pendingMac in _pendingApprovalDevices) {
          // 检查这个待批准设备是否还在当前连接列表中
          final isStillConnected = clientsList.any(
            (client) => client.macAddress?.toUpperCase() == pendingMac,
          );
          
          // 如果设备不在连接列表中，标记为需要移除
          if (!isStillConnected) {
            disconnectedPendingDevices.add(pendingMac);
          }
        }
        
        // 从待批准列表中移除已断开连接的设备
        if (disconnectedPendingDevices.isNotEmpty) {
          for (var mac in disconnectedPendingDevices) {
            _pendingApprovalDevices.remove(mac);
            // 同时从_seenDevices中移除，这样重新连接时会被识别为新设备
            _seenDevices.remove(mac);
            print('🗑️ [CLEANUP_PENDING] دستگاه待批准 از لیست حذف شد (قطع اتصال): MAC=$mac');
          }
          
          if (disconnectedPendingDevices.length > 0) {
            print('✅ [CLEANUP_PENDING] ${disconnectedPendingDevices.length} دستگاه待批准 از لیست حذف شدند');
          }
        }
      }
      
      // 更新已见过的设备列表（在清理之后，只保留当前连接的设备）
      // 这样断开连接的设备会被移除，重新连接时会被识别为新设备
      _seenDevices = currentMacs;

      // بررسی کامل بودن داده‌ها
      bool dataComplete = true;
      if (clientsList.isEmpty) {
        dataComplete = true;
      } else {
        int completeCount = 0;
        for (var client in clientsList) {
          if ((client.ipAddress != null && client.ipAddress!.isNotEmpty) ||
              (client.hostName != null && client.hostName!.isNotEmpty) ||
              (client.user != null && client.user!.isNotEmpty) ||
              (client.name != null && client.name!.isNotEmpty)) {
            completeCount++;
          }
        }

        if (completeCount < (clientsList.length * 0.5).ceil() &&
            clientsList.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 800));
          final retryResult = await _serviceManager.getConnectedClients();
          final retryClientsList = (retryResult['clients'] as List)
              .map((c) => ClientInfo.fromMap(c as Map<String, dynamic>))
              .toList();

          completeCount = 0;
          for (var client in retryClientsList) {
            if ((client.ipAddress != null && client.ipAddress!.isNotEmpty) ||
                (client.hostName != null && client.hostName!.isNotEmpty) ||
                (client.user != null && client.user!.isNotEmpty) ||
                (client.name != null && client.name!.isNotEmpty)) {
              completeCount++;
            }
          }

          if (completeCount >= (retryClientsList.length * 0.5).ceil() ||
              retryClientsList.isEmpty) {
            clientsList.clear();
            clientsList.addAll(retryClientsList);
            dataComplete = true;
          } else {
            await Future.delayed(const Duration(milliseconds: 500));
            final finalResult = await _serviceManager.getConnectedClients();
            final finalClientsList = (finalResult['clients'] as List)
                .map((c) => ClientInfo.fromMap(c as Map<String, dynamic>))
                .toList();
            clientsList.clear();
            clientsList.addAll(finalClientsList);
            dataComplete = true;
          }
        }
      }

      // 不使用自动封禁功能 - 只使用 Access List 限制访问
      // 设备不会被封禁，只会被限制访问（通过 Access List）

      // مرتب‌سازی: دستگاه کاربر در صدر لیست
      // اگر IP دستگاه کاربر هنوز تشخیص داده نشده، دوباره تلاش کن
      if (_deviceIp == null) {
        try {
          await loadDeviceIp(forceRefresh: true);
        } catch (e) {
          // ignore
        }
      }

      // 过滤掉所有被封禁的设备（无论"新连接锁定"是否激活）
      // 确保被封禁的设备不会显示在连接列表中
      // بهینه‌سازی: بررسی banned devices به صورت batch
      final filteredClientsList = <ClientInfo>[];
      
      // ساخت Set از banned MAC و IP برای بررسی سریع‌تر
      final bannedMacs = <String>{};
      final bannedIps = <String>{};
      for (var banned in _bannedClients) {
        final bannedMac = banned['mac_address']?.toString().toUpperCase();
        final bannedIp = banned['address']?.toString();
        if (bannedMac != null) bannedMacs.add(bannedMac);
        if (bannedIp != null) bannedIps.add(bannedIp);
      }
      
      // فیلتر کردن دستگاه‌های banned
      for (var client in clientsList) {
        bool isBanned = false;
        if (client.macAddress != null) {
          isBanned = bannedMacs.contains(client.macAddress!.toUpperCase());
        }
        if (!isBanned && client.ipAddress != null) {
          isBanned = bannedIps.contains(client.ipAddress);
        }
        if (!isBanned) {
          filteredClientsList.add(client);
        } else {
          print('🚫 [FILTER_BANNED] دستگاه مسدود شده از لیست حذف شد: MAC=${client.macAddress}, IP=${client.ipAddress}');
        }
      }

      // مرتب‌سازی: دستگاه کاربر در صدر لیست
      filteredClientsList.sort((a, b) {
        if (_deviceIp != null) {
          final aIsDevice = a.ipAddress == _deviceIp;
          final bIsDevice = b.ipAddress == _deviceIp;
          if (aIsDevice && !bIsDevice) return -1;
          if (!aIsDevice && bIsDevice) return 1;
        }
        return 0;
      });

      // Progressive loading: نمایش تدریجی دستگاه‌ها
      if (showLoading && filteredClientsList.isNotEmpty) {
        await _progressiveLoadClients(filteredClientsList, dataComplete);
      } else {
        _clients = filteredClientsList;
        _isDataComplete = dataComplete;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'خطا در دریافت لیست کاربران: $e';
      _isLoading = false;
      _isDataComplete = false;
      notifyListeners();
    }
  }

  /// بارگذاری لیست دستگاه‌های مسدود شده
  Future<void> loadBannedClients() async {
    if (!_serviceManager.isConnected) {
      return;
    }

    try {
      final bannedList = await _serviceManager.getBannedClients();
      _bannedClients = bannedList;
      notifyListeners();
    } catch (e) {
      // ignore
    }
  }

  /// به‌روزرسانی کامل داده‌ها (برای refresh)
  Future<void> refresh() async {
    // توقف progressive loading قبلی
    _progressiveLoadTimer?.cancel();
    _isProgressiveLoading = false;
    
    _isRefreshing = true;
    notifyListeners();

    try {
      // بارگذاری banned clients اول (برای استفاده در فیلتر)
      await loadBannedClients();
      await loadDeviceIp();
      await loadRouterInfo();
      // در refresh از progressive loading استفاده نمی‌کنیم (برای سرعت بیشتر)
      await loadClients(showLoading: false);
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// مسدود کردن کلاینت به صورت آنی (سریع - الگو از rejectDevice)
  /// این متد فوراً UI را به‌روزرسانی می‌کند و عملیات را در پس‌زمینه انجام می‌دهد
  Future<bool> banClientInstant(String ipAddress, {String? macAddress}) async {
    if (ipAddress.isEmpty) {
      return false;
    }

    try {
      // فوراً دستگاه را از لیست حذف می‌کنیم (بدون انتظار)
      if (macAddress != null) {
        final macUpper = macAddress.toUpperCase();
        _clients.removeWhere((client) => 
          client.macAddress?.toUpperCase() == macUpper ||
          client.ipAddress == ipAddress
        );
      } else {
        _clients.removeWhere((client) => client.ipAddress == ipAddress);
      }
      
      // فوراً UI را به‌روزرسانی می‌کنیم
      notifyListeners();
      
      // عملیات مسدود کردن را در پس‌زمینه انجام می‌دهیم (non-blocking)
      Future.microtask(() async {
        try {
          if (_serviceManager.isConnected && ipAddress.isNotEmpty) {
            // استفاده از banClient ساده (مثل rejectDevice) برای سرعت بیشتر
            await _serviceManager.service?.banClient(
              ipAddress,
              macAddress: macAddress,
              comment: 'Banned via Flutter App - Device Detail',
            ).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                print('⚠️ [BAN_INSTANT] Timeout در banClient - ادامه می‌دهیم');
                return false;
              },
            );
            print('✅ [BAN_INSTANT] دستگاه مسدود شد: IP=$ipAddress, MAC=$macAddress');
            
            // به‌روزرسانی لیست banned clients در پس‌زمینه
            Future.microtask(() async {
              try {
                await loadBannedClients().timeout(
                  const Duration(seconds: 10),
                  onTimeout: () {
                    print('⚠️ [BAN_INSTANT] Timeout در loadBannedClients');
                  },
                );
              } catch (e) {
                print('⚠️ [BAN_INSTANT] خطا در loadBannedClients: $e');
                // ignore
              }
            });
          }
        } catch (e) {
          print('⚠️ [BAN_INSTANT] خطا در مسدود کردن دستگاه (پس‌زمینه): $e');
          // ignore - UI قبلاً به‌روزرسانی شده است
        }
      });
      
      return true;
    } catch (e) {
      print('⚠️ [BAN_INSTANT] خطا در banClientInstant: $e');
      return false;
    }
  }

  /// مسدود کردن کلاینت با استفاده از Device Fingerprint
  /// این تابع Device Fingerprint را محاسبه و ذخیره می‌کند
  /// بهینه‌سازی: refresh در پس‌زمینه انجام می‌شود تا UI فوراً پاسخ دهد
  /// منطق مشابه rejectDevice: بدون بررسی اتصال دستگاه و ignore کردن خطاها
  Future<bool> banClient(String ipAddress, {String? macAddress, String? hostname, String? ssid}) async {
    print('═══════════════════════════════════════════════════════════');
    print('🚫 [PROVIDER_BAN] شروع عملیات مسدود کردن در Provider');
    print('═══════════════════════════════════════════════════════════');
    print('📋 [PROVIDER_BAN] اطلاعات ورودی:');
    print('   └─ IP Address: $ipAddress');
    print('   └─ MAC Address: ${macAddress ?? "null"}');
    print('   └─ Hostname: ${hostname ?? "null"}');
    print('   └─ SSID: ${ssid ?? "null"}');
    
    // بررسی اتصال Service Manager
    print('🔍 [PROVIDER_BAN] بررسی اتصال Service Manager...');
    print('   └─ isConnected: ${_serviceManager.isConnected}');
    print('   └─ Service: ${_serviceManager.service != null ? "موجود" : "null"}');
    
    if (!_serviceManager.isConnected || _serviceManager.service == null) {
      print('❌ [PROVIDER_BAN] اتصال Service Manager برقرار نیست!');
      _errorMessage = 'اتصال برقرار نشده است.';
      notifyListeners();
      return false;
    }

    try {
      // استفاده از banClient ساده (مثل rejectDevice) برای اطمینان از عدم timeout
      // استفاده از banClientWithFingerprint برای ذخیره fingerprint
      print('🔄 [PROVIDER_BAN] فراخوانی banClientWithFingerprint...');
      
      // استفاده از banClientWithFingerprint برای ذخیره fingerprint
      // اما خطاها را ignore می‌کنیم تا timeout ندهد
      try {
        final success = await _serviceManager.service!.banClientWithFingerprint(
          ipAddress,
          macAddress: macAddress,
          hostname: hostname,
          ssid: ssid,
        ).timeout(
          const Duration(seconds: 30), // timeout کوتاه‌تر
          onTimeout: () {
            print('⚠️ [PROVIDER_BAN] Timeout در banClientWithFingerprint، استفاده از banClient ساده...');
            return false;
          },
        );
        
        print('📊 [PROVIDER_BAN] نتیجه از banClientWithFingerprint: ${success == true ? "✅ موفق" : "❌ ناموفق"}');
        
        if (success == true) {
          // موفق بود
        } else {
          // اگر ناموفق بود، از banClient ساده استفاده کن (مثل rejectDevice)
          print('🔄 [PROVIDER_BAN] banClientWithFingerprint ناموفق بود، استفاده از banClient ساده...');
          try {
            await _serviceManager.service!.banClient(
              ipAddress,
              macAddress: macAddress,
              comment: 'Banned via Flutter App',
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                print('⚠️ [PROVIDER_BAN] Timeout در banClient ساده');
                return false;
              },
            );
            print('✅ [PROVIDER_BAN] banClient ساده موفق بود');
          } catch (e) {
            print('⚠️ [PROVIDER_BAN] خطا در banClient ساده: $e');
            // ادامه می‌دهیم حتی اگر خطا داد
          }
        }
      } catch (e) {
        print('⚠️ [PROVIDER_BAN] خطا در banClientWithFingerprint: $e');
        // اگر خطا داد، از banClient ساده استفاده کن
        try {
          print('🔄 [PROVIDER_BAN] استفاده از banClient ساده به عنوان fallback...');
          await _serviceManager.service!.banClient(
            ipAddress,
            macAddress: macAddress,
            comment: 'Banned via Flutter App',
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ [PROVIDER_BAN] Timeout در banClient ساده (fallback)');
              return false;
            },
          );
          print('✅ [PROVIDER_BAN] banClient ساده (fallback) موفق بود');
        } catch (e2) {
          print('⚠️ [PROVIDER_BAN] خطا در banClient ساده (fallback): $e2');
          // حتی اگر خطا داد، ادامه می‌دهیم (مثل rejectDevice)
        }
      }

      // همیشه true برمی‌گردانیم (مثل rejectDevice) حتی اگر برخی مراحل ناموفق باشند
      print('✅ [PROVIDER_BAN] مسدود کردن انجام شد، به‌روزرسانی state...');
      
      // 立即从连接列表中移除设备（不等待后台刷新）
      final beforeCount = _clients.length;
      if (macAddress != null) {
        final macUpper = macAddress.toUpperCase();
        _clients.removeWhere((client) => 
          client.macAddress?.toUpperCase() == macUpper ||
          client.ipAddress == ipAddress
        );
      } else {
        _clients.removeWhere((client) => client.ipAddress == ipAddress);
      }
      final afterCount = _clients.length;
      print('   └─ تعداد clients قبل: $beforeCount');
      print('   └─ تعداد clients بعد: $afterCount');
      print('   └─ تعداد حذف شده: ${beforeCount - afterCount}');
      
      // 立即刷新封禁列表
      print('   └─ بارگذاری لیست banned clients...');
      try {
        await loadBannedClients();
        print('   └─ تعداد banned clients: ${_bannedClients.length}');
      } catch (e) {
        print('   └─ ⚠️ خطا در loadBannedClients: $e');
        // ignore
      }
      
      // 立即通知UI更新
      notifyListeners();
      print('   └─ ✅ UI به‌روزرسانی شد');
      
      // بررسی و مسدود کردن خودکار دستگاه‌های دیگر (در پس‌زمینه)
      // این عملیات را non-blocking می‌کنیم تا UI فوراً پاسخ دهد
      print('   └─ شروع عملیات پس‌زمینه...');
      Future.microtask(() async {
        try {
          print('   └─ بررسی و مسدود کردن خودکار دستگاه‌های دیگر...');
          await _serviceManager.service?.checkAndBanBannedDevices();
        } catch (e) {
          print('   └─ ⚠️ خطا در auto-ban: $e');
          // ignore errors in auto-ban
        }
        
        // حذف refresh - UI قبلاً به‌روزرسانی شده است
        // refresh فقط بعد از عملیات ban/unban در DeviceDetailScreen انجام می‌شود
      });
      
      print('✅ [PROVIDER_BAN] عملیات با موفقیت کامل شد');
      print('═══════════════════════════════════════════════════════════');
      // همیشه true برمی‌گردانیم (مثل rejectDevice)
      return true;
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ [PROVIDER_BAN] خطا در مسدود کردن کلاینت:');
      print('   └─ Error: $e');
      print('   └─ Type: ${e.runtimeType}');
      print('   └─ Stack Trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      _errorMessage = 'خطا در مسدود کردن کلاینت: $e';
      notifyListeners();
      return false;
    }
  }

  /// رفع مسدودیت کلاینت با استفاده از Device Fingerprint
  /// 解除封禁后，如果锁定激活且设备是动态的，应该再次显示批准/拒绝消息
  /// بهینه‌سازی: refresh در پس‌زمینه انجام می‌شود تا UI فوراً پاسخ دهد
  Future<bool> unbanClient(String ipAddress, {String? macAddress, String? hostname, String? ssid}) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = 'اتصال برقرار نشده است.';
      notifyListeners();
      return false;
    }

    try {
      final success = await _serviceManager.service?.unbanClientWithFingerprint(
        ipAddress,
        macAddress: macAddress,
        hostname: hostname,
        ssid: ssid,
      );

      if (success == true) {
        // 如果锁定激活且有 MAC 地址，将设备添加到待批准列表（如果设备是动态的）
        // 这样当设备重新连接时，会显示批准/拒绝消息
        if (_isNewConnectionsLocked && macAddress != null && macAddress.isNotEmpty) {
          final macUpper = macAddress.toUpperCase();
          
          // 从_seenDevices中移除，这样重新连接时会被识别为新设备
          _seenDevices.remove(macUpper);
          
          // 添加到待批准列表（如果设备是动态的，会在loadClients中确认）
          // 先添加到待批准列表，在loadClients中会检查设备是否是动态的
          _pendingApprovalDevices.add(macUpper);
          print('🔔 [UNBAN_DEVICE] دستگاه解除封禁 - 添加到待批准列表: MAC=$macUpper, IP=$ipAddress');
        }
        
        // به‌روزرسانی state در پس‌زمینه (non-blocking)
        // این عملیات را non-blocking می‌کنیم تا UI فوراً پاسخ دهد
        Future.microtask(() async {
          try {
            // ابتدا لیست banned clients را به‌روزرسانی کن تا دستگاه از لیست حذف شود
            await loadBannedClients();
            // سپس لیست متصل را به‌روزرسانی کن
            await loadClients(showLoading: false);
            // اطمینان از به‌روزرسانی UI
            notifyListeners();
          } catch (e) {
            // ignore errors in refresh
          }
        });
        
        // فوراً return true تا UI بتواند navigation کند
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'خطا در رفع مسدودیت کلاینت: $e';
      notifyListeners();
      return false;
    }
  }

  /// تنظیم سرعت کلاینت و به‌روزرسانی state
  Future<bool> setClientSpeed(String target, String maxLimit) async {
    print('═══════════════════════════════════════════════════════════');
    print('📦 [PROVIDER_SET_SPEED] شروع تنظیم سرعت در Provider');
    print('📦 [PROVIDER_SET_SPEED] Target: $target');
    print('📦 [PROVIDER_SET_SPEED] Max Limit: $maxLimit');
    
    if (!_serviceManager.isConnected) {
      print('📦 [PROVIDER_SET_SPEED] ✗ اتصال برقرار نیست');
      _errorMessage = 'اتصال برقرار نشده است.';
      notifyListeners();
      return false;
    }

    print('📦 [PROVIDER_SET_SPEED] ✓ اتصال برقرار است');
    print('📦 [PROVIDER_SET_SPEED] در حال فراخوانی MikroTikService.setClientSpeed()...');

    try {
      // افزایش timeout به 45 ثانیه برای اطمینان از تکمیل عملیات
      final success = await _serviceManager.service?.setClientSpeed(
        target,
        maxLimit,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          print('📦 [PROVIDER_SET_SPEED] ✗✗✗ Timeout در تنظیم سرعت (45 ثانیه) ✗✗✗');
          _errorMessage = 'زمان تنظیم سرعت به پایان رسید. لطفاً دوباره تلاش کنید.';
          notifyListeners();
          return false;
        },
      );

      print('═══════════════════════════════════════════════════════════');
      print('📦 [PROVIDER_SET_SPEED] نتیجه از MikroTikService: ${success == true ? "✓✓✓ موفق" : "✗✗✗ ناموفق"}');

      if (success == true) {
        print('📦 [PROVIDER_SET_SPEED] ✓✓✓ تنظیم سرعت با موفقیت کامل شد');
        print('📦 [PROVIDER_SET_SPEED] به‌روزرسانی state در پس‌زمینه انجام می‌شود...');
        print('═══════════════════════════════════════════════════════════');
        
        // به‌روزرسانی state در پس‌زمینه (بدون انتظار)
        refresh().catchError((e) {
          print('⚠️ [PROVIDER_SET_SPEED] خطا در refresh: $e');
        });
        
        return true;
      }
      
      print('📦 [PROVIDER_SET_SPEED] ✗ تنظیم سرعت ناموفق بود (success = false)');
      _errorMessage = 'تنظیم سرعت ناموفق بود. لطفاً دوباره تلاش کنید.';
      notifyListeners();
      print('═══════════════════════════════════════════════════════════');
      return false;
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════');
      print('📦 [PROVIDER_SET_SPEED] ✗✗✗✗✗ خطای استثنا در تنظیم سرعت ✗✗✗✗✗');
      print('📦 [PROVIDER_SET_SPEED] خطا: $e');
      print('📦 [PROVIDER_SET_SPEED] نوع خطا: ${e.runtimeType}');
      if (e is TimeoutException) {
        print('📦 [PROVIDER_SET_SPEED] این یک TimeoutException است');
      }
      print('📦 [PROVIDER_SET_SPEED] Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      
      String errorMsg = 'خطا در تنظیم سرعت';
      if (e is TimeoutException) {
        errorMsg = 'زمان تنظیم سرعت به پایان رسید. لطفاً دوباره تلاش کنید.';
      } else if (e.toString().contains('اتصال')) {
        errorMsg = 'اتصال به روتر برقرار نیست. لطفاً اتصال را بررسی کنید.';
      } else {
        errorMsg = 'خطا در تنظیم سرعت: ${e.toString()}';
      }
      
      _errorMessage = errorMsg;
      notifyListeners();
      return false;
    }
  }

  /// پاک کردن state (برای logout)
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
    // 不清除锁定状态，保持用户设置
    // _isNewConnectionsLocked = false;
    _deviceFilterStatus.clear(); // پاک کردن cache وضعیت فیلترینگ
    _pendingApprovalDevices.clear(); // 清除待批准设备列表
    notifyListeners();
  }

  /// بارگذاری لیست دستگاه‌های مجاز از SharedPreferences
  Future<void> _loadApprovedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final approvedMacsList = prefs.getStringList('approved_devices') ?? [];
      _approvedDevices = approvedMacsList.map((mac) => mac.toUpperCase()).toSet();
    } catch (e) {
      _approvedDevices = {};
    }
  }

  /// 加载锁定状态从 SharedPreferences
  Future<void> _loadLockStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isNewConnectionsLocked = prefs.getBool('new_connections_locked') ?? false;
      print('📋 [LOAD_LOCK_STATUS] قفل اتصال جدید: ${_isNewConnectionsLocked ? "فعال" : "غیرفعال"}');
    } catch (e) {
      _isNewConnectionsLocked = false;
      print('⚠️ [LOAD_LOCK_STATUS] خطا در بارگذاری وضعیت قفل: $e');
    }
  }

  /// 保存锁定状态到 SharedPreferences
  Future<void> _saveLockStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('new_connections_locked', _isNewConnectionsLocked);
      print('💾 [SAVE_LOCK_STATUS] وضعیت قفل ذخیره شد: $_isNewConnectionsLocked');
    } catch (e) {
      print('⚠️ [SAVE_LOCK_STATUS] خطا در ذخیره وضعیت قفل: $e');
    }
  }

  /// ذخیره لیست دستگاه‌های مجاز در SharedPreferences
  Future<void> _saveApprovedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('approved_devices', _approvedDevices.toList());
    } catch (e) {
      // ignore errors
    }
  }

  /// بررسی اینکه آیا دستگاه مجاز است (已批准)
  Future<bool> isDeviceApproved(String? macAddress) async {
    if (macAddress == null || macAddress.isEmpty) {
      return false;
    }
    
    // اگر لیست مجاز خالی است، از SharedPreferences بارگذاری کن
    if (_approvedDevices.isEmpty) {
      await _loadApprovedDevices();
    }
    
    return _approvedDevices.contains(macAddress.toUpperCase());
  }

  /// بررسی اینکه آیا دستگاه نیاز به تایید دارد
  /// 只有当"新连接锁定"激活时，动态设备才需要批准
  /// 静态设备总是允许，不需要批准
  /// 如果设备被封禁，不需要批准（直到解除封禁）
  Future<bool> isDevicePendingApproval(String? macAddress, String? ipAddress, {ClientInfo? client}) async {
    // 如果锁定未激活，不需要批准
    if (!_isNewConnectionsLocked) {
      return false;
    }
    
    if (macAddress == null || macAddress.isEmpty) {
      return false;
    }
    
    final macUpper = macAddress.toUpperCase();
    
    // 如果设备被封禁，不需要批准（直到解除封禁）
    if (await isDeviceBanned(macAddress, ipAddress)) {
      return false;
    }
    
    // 如果设备是静态设备，不需要批准
    if (client != null && _isStaticDevice(client)) {
      return false;
    }
    
    // 如果无法从client判断，尝试从clients列表中查找
    if (client == null) {
      final foundClient = _clients.firstWhere(
        (c) => c.macAddress?.toUpperCase() == macUpper,
        orElse: () => ClientInfo(type: 'unknown', source: 'unknown', rawData: {}),
      );
      if (foundClient.type != 'unknown' && _isStaticDevice(foundClient)) {
        return false;
      }
    }
    
    // 如果设备是当前设备，不需要批准
    if (ipAddress != null && ipAddress == _deviceIp) {
      return false;
    }
    
    // 如果设备已批准，不需要批准
    if (await isDeviceApproved(macAddress)) {
      return false;
    }
    
    // 如果设备在待批准列表中，需要批准
    return _pendingApprovalDevices.contains(macUpper);
  }
  
  /// 检查设备是否被封禁
  Future<bool> isDeviceBanned(String? macAddress, String? ipAddress) async {
    if (macAddress == null && ipAddress == null) {
      return false;
    }
    
    // 检查封禁列表
    for (var banned in _bannedClients) {
      final bannedMac = banned['mac_address']?.toString().toUpperCase();
      final bannedIp = banned['address']?.toString();
      
      // 检查 MAC 地址
      if (macAddress != null && bannedMac != null) {
        if (macAddress.toUpperCase() == bannedMac) {
          return true;
        }
      }
      
      // 检查 IP 地址
      if (ipAddress != null && bannedIp != null) {
        if (ipAddress == bannedIp) {
          return true;
        }
      }
    }
    
    return false;
  }
  
  /// 检查设备是否是静态设备
  bool _isStaticDevice(ClientInfo client) {
    // 1. 直接检查 isStaticLease
    if (client.isStaticLease == true) {
      return true;
    }
    
    // 2. 如果 isStaticLease 为 null，从 rawData 检查
    if (client.isStaticLease == null && client.rawData.isNotEmpty) {
      if (client.rawData.containsKey('dynamic')) {
        final dynamicValue = client.rawData['dynamic']?.toString().toLowerCase();
        if (dynamicValue == 'false' || dynamicValue == 'no') {
          return true; // Static
        }
      }
    }
    
    return false;
  }

  /// تایید دستگاه (批准设备)
  Future<bool> approveDevice(String macAddress, {String? ipAddress}) async {
    if (macAddress.isEmpty) {
      _errorMessage = 'MAC address خالی است';
      notifyListeners();
      return false;
    }

    try {
      final macUpper = macAddress.toUpperCase();
      
      // اضافه کردن به لیست مجاز
      _approvedDevices.add(macUpper);
      await _saveApprovedDevices();
      
      // 从待批准列表中移除
      _pendingApprovalDevices.remove(macUpper);
      
      // 允许设备完整访问（移除限制）
      if (_serviceManager.isConnected) {
        try {
          final success = await _serviceManager.allowNonStaticDevice(
            macAddress,
            ipAddress: ipAddress,
          );
          if (success) {
            print('✅ [APPROVE_DEVICE] دستگاه با موفقیت تایید شد و دسترسی کامل داده شد: MAC=$macUpper, IP=$ipAddress');
          } else {
            print('⚠️ [APPROVE_DEVICE] دستگاه تایید شد اما حذف محدودیت ناموفق بود: MAC=$macUpper');
          }
        } catch (e) {
          print('⚠️ [APPROVE_DEVICE] خطا در حذف محدودیت دستگاه: $e');
          // 即使移除限制失败，也继续（因为设备已经在批准列表中）
        }
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'خطا در تایید دستگاه: $e';
      notifyListeners();
      return false;
    }
  }

  /// رد دستگاه (拒绝设备)
  /// 当拒绝设备时，封禁设备
  /// 确保设备不会再次显示为待批准状态
  Future<bool> rejectDevice(String macAddress, {String? ipAddress}) async {
    if (macAddress.isEmpty) {
      _errorMessage = 'MAC address خالی است';
      notifyListeners();
      return false;
    }

    try {
      final macUpper = macAddress.toUpperCase();
      
      // 从批准列表中移除（如果存在）
      _approvedDevices.remove(macUpper);
      await _saveApprovedDevices();
      
      // 从待批准列表中移除（确保不会再次显示）
      _pendingApprovalDevices.remove(macUpper);
      
      // 从_seenDevices中移除，这样即使重新连接也不会立即显示为待批准
      // 只有当解除封禁后，才会再次显示
      _seenDevices.remove(macUpper);
      
      // 封禁设备
      if (_serviceManager.isConnected && ipAddress != null && ipAddress.isNotEmpty) {
        try {
          // 使用 banClient 封禁设备 (با timeout برای جلوگیری از hang)
          await _serviceManager.service?.banClient(
            ipAddress,
            macAddress: macAddress,
            comment: 'Rejected by user - New connection lock',
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('⚠️ [REJECT_DEVICE] Timeout در banClient - ادامه می‌دهیم');
              return false;
            },
          );
          print('✅ [REJECT_DEVICE] دستگاه reject و مسدود شد: MAC=$macUpper, IP=$ipAddress');
          
          // 刷新封禁列表 (non-blocking - در پس‌زمینه)
          // این عملیات را non-blocking می‌کنیم تا UI فوراً پاسخ دهد
          Future.microtask(() async {
            try {
              await loadBannedClients().timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  print('⚠️ [REJECT_DEVICE] Timeout در loadBannedClients');
                },
              );
            } catch (e) {
              print('⚠️ [REJECT_DEVICE] خطا در loadBannedClients: $e');
              // ignore - این عملیات optional است
            }
          });
        } catch (e) {
          print('⚠️ [REJECT_DEVICE] خطا در مسدود کردن دستگاه: $e');
          // 即使封禁失败，也继续（因为设备已经从批准列表中移除）
        }
      } else {
        print('⚠️ [REJECT_DEVICE] IP address داده نشده - فقط MAC: $macUpper - مسدود نشد');
      }
      
      // 从连接列表中移除设备（因为设备已被封禁）
      _clients.removeWhere((client) => 
        client.macAddress?.toUpperCase() == macUpper
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'خطا در رد دستگاه: $e';
      notifyListeners();
      return false;
    }
  }

  /// مقداردهی اولیه (برای بعد از login)
  Future<void> initialize() async {
    await _loadApprovedDevices();
    await _loadLockStatus(); // 加载锁定状态
    await loadDeviceIp();
    await loadRouterInfo();
    await loadClients();
    await loadBannedClients();
  }

  /// قفل کردن اتصال دستگاه‌های جدید
  Future<bool> lockNewConnections() async {
    try {
      _isNewConnectionsLocked = true;
      await _saveLockStatus();
      notifyListeners();
      print('✅ [LOCK_NEW_CONNECTIONS] قفل اتصال جدید فعال شد');
      return true;
    } catch (e) {
      _errorMessage = 'خطا در فعال کردن قفل: $e';
      notifyListeners();
      return false;
    }
  }

  /// رفع قفل اتصال دستگاه‌های جدید
  Future<bool> unlockNewConnections() async {
    try {
      _isNewConnectionsLocked = false;
      await _saveLockStatus();
      notifyListeners();
      print('✅ [UNLOCK_NEW_CONNECTIONS] قفل اتصال جدید غیرفعال شد');
      return true;
    } catch (e) {
      _errorMessage = 'خطا در غیرفعال کردن قفل: $e';
      notifyListeners();
      return false;
    }
  }

  /// فعال‌سازی فیلترینگ شبکه‌های اجتماعی برای یک دستگاه
  Future<Map<String, dynamic>> enableSocialMediaFilter(
    String deviceIp, {
    String? deviceMac,
    String? deviceName,
    List<String>? platforms,
  }) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = 'اتصال برقرار نشده است.';
      notifyListeners();
      return {'success': false, 'error': _errorMessage};
    }

    try {
      final result = await _serviceManager.service?.enableSocialMediaFilter(
        deviceIp,
        deviceMac: deviceMac,
        deviceName: deviceName,
        platforms: platforms,
      );

      if (result != null && result['success'] == true) {
        await refresh();
        return result;
      } else {
        _errorMessage = result?['errors']?.join(', ') ?? 'خطا در فعال‌سازی فیلتر';
        notifyListeners();
        return result ?? {'success': false, 'error': 'خطای نامشخص'};
      }
    } catch (e) {
      _errorMessage = 'خطا در فعال‌سازی فیلتر شبکه‌های اجتماعی: $e';
      notifyListeners();
      return {'success': false, 'error': _errorMessage};
    }
  }

  /// غیرفعال‌سازی فیلترینگ شبکه‌های اجتماعی برای یک دستگاه
  Future<bool> disableSocialMediaFilter(String deviceIp) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = 'اتصال برقرار نشده است.';
      notifyListeners();
      return false;
    }

    try {
      final success = await _serviceManager.service?.disableSocialMediaFilter(deviceIp);
      if (success == true) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'خطا در غیرفعال‌سازی فیلتر: $e';
      notifyListeners();
      return false;
    }
  }

  /// بررسی وضعیت فیلترینگ شبکه‌های اجتماعی برای یک دستگاه
  /// با استفاده از cache برای بهبود عملکرد و حفظ حالت
  Future<Map<String, dynamic>> getSocialMediaFilterStatus(String deviceIp, {bool forceRefresh = false}) async {
    if (!_serviceManager.isConnected) {
      // اگر cache موجود است، از آن استفاده کن
      if (_deviceFilterStatus.containsKey(deviceIp)) {
        final cached = _deviceFilterStatus[deviceIp]!;
        return {
          'is_active': cached.values.any((v) => v == true),
          'platforms': Map<String, dynamic>.from(cached),
        };
      }
      return {'is_active': false, 'error': 'اتصال برقرار نشده است.'};
    }

    // اگر forceRefresh نیست و cache موجود است، از cache استفاده کن
    if (!forceRefresh && _deviceFilterStatus.containsKey(deviceIp)) {
      final cached = _deviceFilterStatus[deviceIp]!;
      print('[Filter Status] استفاده از cache برای $deviceIp: $cached');
      // در پس‌زمینه به‌روزرسانی کن (بدون blocking کردن UI)
      _refreshFilterStatusInBackground(deviceIp);
      return {
        'is_active': cached.values.any((v) => v == true),
        'platforms': Map<String, dynamic>.from(cached),
      };
    }

    try {
      final status = await _serviceManager.service?.getSocialMediaFilterStatus(deviceIp);
      final platforms = status?['platforms'] as Map<String, dynamic>? ?? {};
      
      // به‌روزرسانی cache
      final platformStatus = <String, bool>{
        'telegram': platforms['telegram'] == true,
        'facebook': platforms['facebook'] == true,
        'tiktok': platforms['tiktok'] == true,
        'whatsapp': platforms['whatsapp'] == true,
        'youtube': platforms['youtube'] == true,
        'instagram': platforms['instagram'] == true,
      };
      _deviceFilterStatus[deviceIp] = platformStatus;
      print('[Filter Status] به‌روزرسانی cache برای $deviceIp: $platformStatus');
      
      return status ?? {'is_active': false, 'platforms': {}};
    } catch (e) {
      // در صورت خطا، اگر cache موجود است، از آن استفاده کن
      if (_deviceFilterStatus.containsKey(deviceIp)) {
        final cached = _deviceFilterStatus[deviceIp]!;
        print('[Filter Status] خطا در دریافت وضعیت، استفاده از cache: $e');
        return {
          'is_active': cached.values.any((v) => v == true),
          'platforms': Map<String, dynamic>.from(cached),
          'error': e.toString(),
        };
      }
      return {'is_active': false, 'error': e.toString(), 'platforms': {}};
    }
  }

  /// به‌روزرسانی وضعیت فیلتر در پس‌زمینه
  Future<void> _refreshFilterStatusInBackground(String deviceIp) async {
    try {
      final status = await _serviceManager.service?.getSocialMediaFilterStatus(deviceIp);
      final platforms = status?['platforms'] as Map<String, dynamic>? ?? {};
      
      final platformStatus = <String, bool>{
        'telegram': platforms['telegram'] == true,
        'facebook': platforms['facebook'] == true,
        'tiktok': platforms['tiktok'] == true,
        'whatsapp': platforms['whatsapp'] == true,
        'youtube': platforms['youtube'] == true,
        'instagram': platforms['instagram'] == true,
      };
      
      // بررسی تغییرات با مقایسه عمیق
      final cached = _deviceFilterStatus[deviceIp];
      bool hasChanges = false;
      if (cached == null) {
        hasChanges = true;
      } else {
        for (final key in platformStatus.keys) {
          if (cached[key] != platformStatus[key]) {
            hasChanges = true;
            break;
          }
        }
      }
      
      if (hasChanges) {
        _deviceFilterStatus[deviceIp] = platformStatus;
        print('[Filter Status] پس‌زمینه به‌روزرسانی cache برای $deviceIp: $platformStatus');
        notifyListeners(); // اطلاع دادن به listeners که وضعیت تغییر کرده است
      }
    } catch (e) {
      // ignore errors in background refresh
      print('[Filter Status] خطا در به‌روزرسانی پس‌زمینه: $e');
    }
  }

  /// فیلتر/رفع فیلتر یک پلتفرم خاص برای یک دستگاه
  Future<Map<String, dynamic>> togglePlatformFilter(
    String deviceIp,
    String platform, {
    String? deviceMac,
    String? deviceName,
    bool enable = true,
  }) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = 'اتصال برقرار نشده است.';
      notifyListeners();
      return {'success': false, 'error': _errorMessage};
    }

    try {
      final result = await _serviceManager.service?.togglePlatformFilter(
        deviceIp,
        platform,
        deviceMac: deviceMac,
        deviceName: deviceName,
        enable: enable,
      );

      if (result != null && result['success'] == true) {
        // به‌روزرسانی cache فوری
        if (!_deviceFilterStatus.containsKey(deviceIp)) {
          _deviceFilterStatus[deviceIp] = {
            'telegram': false,
            'facebook': false,
            'tiktok': false,
            'whatsapp': false,
            'youtube': false,
            'instagram': false,
          };
        }
        _deviceFilterStatus[deviceIp]![platform.toLowerCase()] = enable;
        print('[Filter Status] به‌روزرسانی cache بعد از toggle برای $deviceIp: ${_deviceFilterStatus[deviceIp]}');
        
        // به‌روزرسانی کامل از سرور (برای اطمینان)
        Future.delayed(const Duration(milliseconds: 500), () {
          _refreshFilterStatusInBackground(deviceIp);
        });
        
        await refresh();
        notifyListeners(); // اطلاع دادن به listeners
        return result;
      } else {
        _errorMessage = result?['error']?.toString() ?? 'خطا در تغییر وضعیت فیلتر';
        notifyListeners();
        return result ?? {'success': false, 'error': 'خطای نامشخص'};
      }
    } catch (e) {
      _errorMessage =   'خطا در تغییر وضعیت فیلتر: $e';
      notifyListeners();
      return {'success': false, 'error': _errorMessage};
    }
  }


  /// بررسی اینکه آیا دستگاه در لیست مجاز است
  /// 静态设备总是允许，动态设备需要检查是否已批准
  Future<bool> isDeviceAllowed(String? macAddress, String? ipAddress, {ClientInfo? client}) async {
    // 如果锁定未激活，所有设备都允许
    if (!_isNewConnectionsLocked) {
      return true;
    }
    
    if (macAddress == null || macAddress.isEmpty) {
      return false;
    }
    
    // 如果是当前设备，总是允许
    if (ipAddress != null && ipAddress == _deviceIp) {
      return true;
    }
    
    // 如果设备是静态设备，总是允许
    if (client != null && _isStaticDevice(client)) {
      return true;
    }
    
    // 如果无法从client判断，尝试从clients列表中查找
    if (client == null) {
      final foundClient = _clients.firstWhere(
        (c) => c.macAddress?.toUpperCase() == macAddress.toUpperCase(),
        orElse: () => ClientInfo(type: 'unknown', source: 'unknown', rawData: {}),
      );
      if (foundClient.type != 'unknown' && _isStaticDevice(foundClient)) {
        return true;
      }
    }
    
    // 对于动态设备，检查是否已批准
    return await isDeviceApproved(macAddress);
  }

  /// اجازه دادن به دستگاه non-static برای اتصال کامل به WiFi
  Future<bool> allowNonStaticDevice(String macAddress, {String? ipAddress}) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = 'اتصال برقرار نشده است.';
      notifyListeners();
      return false;
    }

    try {
      final success = await _serviceManager.allowNonStaticDevice(macAddress, ipAddress: ipAddress);
      if (success) {
        // به‌روزرسانی لیست
        await refresh();
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'خطا در اجازه دادن به دستگاه: عملیات ناموفق بود';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'خطا در اجازه دادن به دستگاه: $e';
      notifyListeners();
      return false;
    }
  }

  /// حذف دستگاه از لیست مجاز
  Future<bool> removeFromAllowedList(String macAddress, {String? ipAddress}) async {
    if (!_serviceManager.isConnected) {
      _errorMessage = 'اتصال برقرار نشده است.';
      notifyListeners();
      return false;
    }

    try {
      final success = await _serviceManager.removeFromAllowedList(macAddress, ipAddress: ipAddress);
      if (success) {
        // به‌روزرسانی لیست
        await refresh();
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'خطا در حذف از لیست مجاز: عملیات ناموفق بود';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'خطا در حذف از لیست مجاز: $e';
      notifyListeners();
      return false;
    }
  }

  /// Progressive loading: نمایش تدریجی دستگاه‌ها برای جلوگیری از گیر کردن UI
  Future<void> _progressiveLoadClients(List<ClientInfo> allClients, bool dataComplete) async {
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
      await Future.delayed(const Duration(milliseconds: 80)); // تاخیر کوتاه برای smooth rendering
      
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
