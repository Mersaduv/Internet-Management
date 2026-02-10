import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client_info.dart';
import '../providers/clients_provider.dart';
import '../services/mikrotik_service_manager.dart';
import '../utils/app_localizations.dart';

/// صفحه جزئیات دستگاه
class DeviceDetailScreen extends StatefulWidget {
  final ClientInfo device;
  final bool isCurrentDevice;
  final bool isBanned;

  const DeviceDetailScreen({
    super.key,
    required this.device,
    required this.isCurrentDevice,
    this.isBanned = false,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> with WidgetsBindingObserver {
  // ignore: unused_field
  bool _isLoading = false; // برای سایر عملیات (ban/unban/static)
  // Telegram 功能已禁用，以下字段保留用于将来的平台支持
  // ignore: unused_field
  Map<String, bool> _platformFilterStatus = {};
  // Map برای مدیریت loading state هر پلتفرم جداگانه
  Map<String, bool> _platformLoadingStatus = {};
  bool _isLoadingStatus = false; // برای جلوگیری از race condition
  bool _hasLoadedOnce = false; // برای بررسی اینکه آیا یک بار بارگذاری شده است
  bool _isDialogOpen = false; // برای جلوگیری از بررسی وضعیت در حین نمایش Dialog
  
  // برای ذخیره سرعت تنظیم شده (برای نمایش سریع)
  String? _currentSpeedLimit; // فرمت: "8M/7M"
  bool _isLoadingSpeed = false; // برای بارگذاری سرعت از RouterOS
  
  // برای Static/Dynamic lease
  bool? _isStaticLease; // true = static, false = dynamic, null = unknown
  bool _isLoadingLeaseStatus = false; // برای بارگذاری وضعیت lease
  
  bool _isDisposed = false; // برای جلوگیری از setState بعد از dispose

  static const Color _primaryColor = Color(0xFF428B7C);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    print('═══════════════════════════════════════════════════════════');
    print('📱 [DEVICE_DETAIL] صفحه جزئیات دستگاه باز شد');
    print('📱 [DEVICE_DETAIL] IP: ${widget.device.ipAddress}');
    print('📱 [DEVICE_DETAIL] MAC: ${widget.device.macAddress}');
    print('📱 [DEVICE_DETAIL] نام: ${widget.device.hostName ?? widget.device.name ?? "نامشخص"}');
    print('📱 [DEVICE_DETAIL] مسدود شده: ${widget.isBanned}');
    print('═══════════════════════════════════════════════════════════');
    
    // Reset همه state ها برای اطمینان از بارگذاری مجدد
    _hasLoadedOnce = false;
    // Initialize platform filter status and loading status
    _platformFilterStatus = {
      'telegram': false,
      'youtube': false,
      'instagram': false,
      'facebook': false,
    };
    _platformLoadingStatus = {
      'telegram': false,
      'youtube': false,
      'instagram': false,
      'facebook': false,
    };
    
    // اگر وضعیت Static/Dynamic در device موجود است، از آن استفاده کن
    // در غیر این صورت null (بعداً از RouterOS بارگذاری می‌شود)
    _isStaticLease = widget.device.isStaticLease;
    
    // فوراً از cache بارگذاری کن (اگر موجود است)
    if (widget.device.ipAddress != null && !widget.isBanned) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ابتدا از cache استفاده کن (سریع)
        _loadPlatformFilterStatus(forceRefresh: false);
      });
    }
    
    // بارگذاری اطلاعات به صورت غیرهمزمان و بدون blocking کردن UI
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // سپس سایر داده‌ها را بارگذاری کن
      _loadAllData();
      _hasLoadedOnce = true;
      
      // بارگذاری سرعت از cache (سریع) و سپس از RouterOS (در پس‌زمینه)
      if (widget.device.ipAddress != null && !widget.isBanned) {
        // ابتدا از cache بارگذاری کن (سریع)
        _loadSpeedLimitFromCache();
        
        // سپس از RouterOS بارگذاری کن (در پس‌زمینه، بدون blocking)
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposed) {
            _loadSpeedLimit();
            // اگر وضعیت Static/Dynamic در device موجود است، از آن استفاده کن
            // در غیر این صورت، فقط در صورت نیاز بارگذاری کن
            if (widget.device.isStaticLease == null && widget.device.ipAddress != null && !widget.isBanned) {
              _loadLeaseStatus(); // فقط در صورت عدم وجود از RouterOS بارگذاری کن
            } else {
              // از اطلاعات موجود در device استفاده کن
              setState(() {
                _isStaticLease = widget.device.isStaticLease;
              });
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _cancelAllPendingOperations();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  /// لغو همه عملیات در حال اجرا
  /// توجه: این متد فقط برای cleanup استفاده می‌شود و عملیات Static/Dynamic را لغو نمی‌کند
  void _cancelAllPendingOperations() {
    _isDisposed = true;
    
    // فقط عملیات‌های غیرضروری را لغو کن
    // عملیات Static/Dynamic باید ادامه یابد حتی اگر صفحه dispose شود
    _isLoadingStatus = false;
    _platformLoadingStatus.clear();
    // _isLoading را تنظیم نکن - اجازه بده عملیات Static/Dynamic ادامه یابد
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // وقتی اپلیکیشن از background به foreground برمی‌گردد، وضعیت را دوباره بررسی کن
    if (state == AppLifecycleState.resumed && _hasLoadedOnce && mounted) {
      // وضعیت را دوباره بررسی کن
    }
  }

  @override
  void didUpdateWidget(DeviceDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
      // اگر دستگاه تغییر کرد یا IP/MAC تغییر کرد، داده‌ها را دوباره بارگذاری کن
      if (        oldWidget.device.ipAddress != widget.device.ipAddress ||
          oldWidget.device.macAddress != widget.device.macAddress ||
          oldWidget.isBanned != widget.isBanned) {
        // Reset speed limit (cache را نگه داریم، فقط state را reset کن)
        _currentSpeedLimit = null;
        // Reset platform filter status and loading status
        _platformFilterStatus = {
          'telegram': false,
          'youtube': false,
          'instagram': false,
          'facebook': false,
        };
        _platformLoadingStatus = {
          'telegram': false,
          'youtube': false,
          'instagram': false,
          'facebook': false,
        };
        _loadAllData();
      } else {
        // حتی اگر دستگاه تغییر نکرده باشد، وضعیت Platform Filter و سرعت را دوباره بررسی کن
        // این برای اطمینان از به‌روز بودن وضعیت است
        // اما فقط اگر Dialog باز نیست
        if (widget.device.ipAddress != null && !widget.isBanned && !_isDialogOpen) {
          // بارگذاری سرعت از RouterOS
          _loadSpeedLimit();
          // فوراً از cache استفاده کن تا UI سریع به‌روزرسانی شود
          // سپس در پس‌زمینه از سرور به‌روزرسانی کن
          _loadPlatformFilterStatus(forceRefresh: false); // ابتدا از cache استفاده کن (سریع)
          
          // سپس در پس‌زمینه از سرور به‌روزرسانی کن (بدون blocking کردن UI)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_isDisposed) {
              _loadPlatformFilterStatus(forceRefresh: true);
            }
          });
        }
      }
  }

  /// بارگذاری همه داده‌ها به صورت همزمان و صبر برای تمام شدن
  Future<void> _loadAllData() async {
    if (_isDisposed || _isLoadingStatus) return;
    _isLoadingStatus = true;

    try {
      await _loadAllDataInternal();
    } catch (e) {
      // ignore errors
    }
  }

  Future<void> _loadAllDataInternal() async {
    if (_isDisposed) return;

    try {
      // بارگذاری داده‌ها
      await _loadPlatformFilterStatus(forceRefresh: false);
      
      if (_isDisposed) return;
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isDisposed) {
          _loadPlatformFilterStatus(forceRefresh: true);
        }
      });
    } catch (e) {
      // ignore errors
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoadingStatus = false;
        });
      }
    }
  }

  /// بارگذاری وضعیت فیلترینگ شبکه‌های اجتماعی
  Future<void> _loadPlatformFilterStatus({bool forceRefresh = false}) async {
      if (_isDisposed || widget.device.ipAddress == null || widget.isBanned) {
      if (mounted && !_isDisposed) {
        setState(() {
          _platformFilterStatus['telegram'] = false;
          _platformFilterStatus['youtube'] = false;
          _platformFilterStatus['instagram'] = false;
          _platformFilterStatus['facebook'] = false;
        });
      }
      return;
    }

    try {
      await _loadPlatformFilterStatusInternal(forceRefresh);
    } catch (e) {
      if (!_isDisposed) {
      }
    }
  }

  Future<void> _loadPlatformFilterStatusInternal(bool forceRefresh) async {
    if (_isDisposed || widget.device.ipAddress == null || widget.isBanned) {
      return;
    }

    try {
      final provider = Provider.of<ClientsProvider>(context, listen: false);
      final status = await provider.getSocialMediaFilterStatus(widget.device.ipAddress!, forceRefresh: forceRefresh);
      
      if (_isDisposed || !mounted) return;
      
      final platforms = status['platforms'] as Map<String, dynamic>? ?? {};
      final newTelegramStatus = platforms['telegram'] == true;
      final newYoutubeStatus = platforms['youtube'] == true;
      final newInstagramStatus = platforms['instagram'] == true;
      final newFacebookStatus = platforms['facebook'] == true;
      
      if (mounted && !_isDisposed) {
        setState(() {
          _platformFilterStatus['telegram'] = newTelegramStatus;
          _platformFilterStatus['youtube'] = newYoutubeStatus;
          _platformFilterStatus['instagram'] = newInstagramStatus;
          _platformFilterStatus['facebook'] = newFacebookStatus;
        });
      }
    } catch (e) {
      if (_isDisposed) return;
      // در صورت خطا، سعی کن از cache استفاده کن (فقط اگر forceRefresh است)
      if (mounted && !_isDisposed && forceRefresh) {
        try {
          final provider = Provider.of<ClientsProvider>(context, listen: false);
          final cachedStatus = await provider.getSocialMediaFilterStatus(widget.device.ipAddress!, forceRefresh: false);
          
          if (_isDisposed || !mounted) return;
          
          final cachedPlatforms = cachedStatus['platforms'] as Map<String, dynamic>? ?? {};
          if (mounted && !_isDisposed) {
            setState(() {
              _platformFilterStatus['telegram'] = cachedPlatforms['telegram'] == true;
              _platformFilterStatus['youtube'] = cachedPlatforms['youtube'] == true;
              _platformFilterStatus['instagram'] = cachedPlatforms['instagram'] == true;
              _platformFilterStatus['facebook'] = cachedPlatforms['facebook'] == true;
            });
          }
        } catch (e2) {
          // ignore cache errors
        }
      }
    }
  }

  /// تغییر وضعیت فیلترینگ شبکه‌های اجتماعی
  Future<void> _togglePlatformFilter(String platform, String platformName) async {
    if (_isDisposed || widget.device.ipAddress == null || widget.isBanned || (_platformLoadingStatus[platform] ?? false)) {
      return;
    }

    final currentStatus = _platformFilterStatus[platform] ?? false;
    final newStatus = !currentStatus;

    if (!mounted || _isDisposed) return;

    setState(() {
      _platformLoadingStatus[platform] = true;
      _platformFilterStatus[platform] = newStatus;
    });

    try {
      await _togglePlatformFilterInternal(platform, platformName, currentStatus, newStatus);
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _platformFilterStatus[platform] = currentStatus;
          _platformLoadingStatus[platform] = false;
        });
      }
    }
  }

  Future<void> _togglePlatformFilterInternal(String platform, String platformName, bool currentStatus, bool newStatus) async {
    if (_isDisposed) return;

    try {
      final provider = Provider.of<ClientsProvider>(context, listen: false);
      final result = await provider.togglePlatformFilter(
        widget.device.ipAddress!,
        platform,
        deviceMac: widget.device.macAddress,
        deviceName: widget.device.hostName ?? widget.device.name,
        enable: newStatus,
      );

      if (_isDisposed || !mounted) return;

      if (result['success'] == true) {
        setState(() {
          _platformLoadingStatus[platform] = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus ? Icons.check_circle : Icons.remove_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        newStatus
                            ? l10n?.filterEnabledWithPlatform(platformName) ?? 'Filter $platformName enabled'
                            : l10n?.filterDisabledWithPlatform(platformName) ?? 'Filter $platformName disabled',
                      );
                    },
                  ),
                ),
              ],
            ),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // تازه‌سازی کامل داده‌های صفحه و رندر مجدد
        // ابتدا Provider را تازه‌سازی کن تا داده‌های کلی به‌روز شوند
        try {
          provider.refresh();
        } catch (e) {
          // ignore provider refresh errors
        }
        
        // سپس وضعیت فیلتر را از سرور دریافت کن
        _loadPlatformFilterStatus(forceRefresh: true).then((_) {
          if (mounted && !_isDisposed) {
            // رندر مجدد صفحه با داده‌های جدید
            setState(() {});
          }
        }).catchError((error) {
          // حتی اگر خطا رخ داد، سعی کن صفحه را رندر کن
          if (mounted && !_isDisposed) {
            setState(() {});
          }
        });
      } else {
        setState(() {
          _platformFilterStatus[platform] = currentStatus;
          _platformLoadingStatus[platform] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        '${l10n?.error ?? 'Error'}: ${result['error'] ?? (l10n?.errorChangingFilter ?? 'Error changing filter status')}',
                      );
                    },
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // حتی در صورت خطا، وضعیت را از سرور دریافت کن تا مطمئن شویم
        _loadPlatformFilterStatus(forceRefresh: true).then((_) {
          if (mounted && !_isDisposed) {
            setState(() {});
          }
        }).catchError((error) {
          // ignore refresh errors
        });
      }
    } catch (e) {
      if (_isDisposed || !mounted) return;
      
      setState(() {
        _platformFilterStatus[platform] = currentStatus;
        _platformLoadingStatus[platform] = false;
      });
      final l10n = AppLocalizations.of(context);
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      final localizedError = l10n?.localizeServiceError(errorMsg) ?? errorMsg;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('${l10n?.error ?? 'Error'}: $localizedError')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // حتی در صورت خطا، وضعیت را از سرور دریافت کن تا مطمئن شویم
      _loadPlatformFilterStatus(forceRefresh: true).then((_) {
        if (mounted && !_isDisposed) {
          setState(() {});
        }
      }).catchError((error) {
        // ignore refresh errors
      });
    }
  }

  Future<void> _setSpeedLimit() async {
    if (_isDisposed || widget.device.ipAddress == null) return;

    // اگر سرعت قبلاً تنظیم شده، آن را از state بگیر و به فرمت قابل نمایش تبدیل کن
    String? currentDownloadValue;
    String? currentUploadValue;
    String selectedDownloadUnit = 'M';
    String selectedUploadUnit = 'M';
    
    if (_currentSpeedLimit != null) {
      // فرمت: "8M/7M" -> download: 8M, upload: 7M
      final parts = _currentSpeedLimit!.split('/');
      if (parts.length == 2) {
        final uploadPart = parts[0].trim(); // 8M
        final downloadPart = parts[1].trim(); // 7M
        
        // استخراج عدد و واحد
        final uploadMatch = RegExp(r'^(\d+)([KMkm]?)$').firstMatch(uploadPart);
        if (uploadMatch != null) {
          currentUploadValue = uploadMatch.group(1);
          selectedUploadUnit = (uploadMatch.group(2) ?? 'M').toUpperCase();
        }
        
        final downloadMatch = RegExp(r'^(\d+)([KMkm]?)$').firstMatch(downloadPart);
        if (downloadMatch != null) {
          currentDownloadValue = downloadMatch.group(1);
          selectedDownloadUnit = (downloadMatch.group(2) ?? 'M').toUpperCase();
        }
      }
    }
    
    final downloadValueController = TextEditingController(text: currentDownloadValue ?? '');
    final uploadValueController = TextEditingController(text: currentUploadValue ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            constraints: const BoxConstraints(maxWidth: 600, minHeight: 400),
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // هدر
                  Row(
                    children: [
                      const Icon(Icons.speed, color: _primaryColor, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Text(
                              l10n?.setSpeedLimit ?? 'Set Speed Limit',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // فرم
                  Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // فیلد سرعت دانلود
                        Row(
                          children: [
                            const Icon(Icons.download, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(
                                  l10n?.downloadSpeed ?? 'Download Speed',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: TextFormField(
                                controller: downloadValueController,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)?.value ?? 'Value',
                                  hintText: '10',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  helperText: AppLocalizations.of(context)?.pleaseEnterNumber ?? 'Please enter a number',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                                textDirection: TextDirection.ltr,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 16),
                                validator: (value) {
                                  final l10n = AppLocalizations.of(context);
                                  if (value == null || value.trim().isEmpty) {
                                    return l10n?.pleaseEnterNumber ?? 'Please enter a number';
                                  }
                                  final num = int.tryParse(value.trim());
                                  if (num == null || num <= 0) {
                                    return l10n?.numberMustBeGreaterThanZero ?? 'Number must be greater than zero';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: selectedDownloadUnit,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)?.unit ?? 'Unit',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 16),
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'M',
                                    child: Text('Mbps', style: TextStyle(color: Colors.blueGrey),),
                                  ),
                                  DropdownMenuItem(
                                    value: 'K', 
                                    child: Text('Kbps', style: TextStyle(color: Colors.blueGrey),),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      selectedDownloadUnit = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // فیلد سرعت آپلود
                        Row(
                          children: [
                            const Icon(Icons.upload, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(
                                  l10n?.uploadSpeed ?? 'Upload Speed',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: TextFormField(
                                controller: uploadValueController,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)?.value ?? 'Value',
                                  hintText: '10',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  helperText: AppLocalizations.of(context)?.pleaseEnterNumber ?? 'Please enter a number',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                                textDirection: TextDirection.ltr,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 16),
                                validator: (value) {
                                  final l10n = AppLocalizations.of(context);
                                  if (value == null || value.trim().isEmpty) {
                                    return l10n?.pleaseEnterNumber ?? 'Please enter a number';
                                  }
                                  final num = int.tryParse(value.trim());
                                  if (num == null || num <= 0) {
                                    return l10n?.numberMustBeGreaterThanZero ?? 'Number must be greater than zero';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: selectedUploadUnit,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)?.unit ?? 'Unit',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 16),
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'M',
                                    child: Text('Mbps', style: TextStyle(color: Colors.blueGrey),),
                                  ),
                                  DropdownMenuItem(
                                    value: 'K',
                                    child: Text('Kbps', style: TextStyle(color: Colors.blueGrey),), 
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      selectedUploadUnit = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final l10n = AppLocalizations.of(context);
                                        return Text(
                                          l10n?.unitGuide ?? 'Unit Guide:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    Builder(
                                      builder: (context) {
                                        final l10n = AppLocalizations.of(context);
                                        return Text(
                                          l10n?.unitGuideText ?? '• Mbps = Megabits per second\n• Kbps = Kilobits per second',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue.shade700,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // دکمه‌ها
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          minimumSize: const Size(100, 48),
                        ),
                        child: Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Text(
                              l10n?.cancel ?? 'Cancel',
                              style: TextStyle(fontSize: 16),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: isSaving ? null : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isSaving = true;
                            });
                            
                            final downloadValue = downloadValueController.text.trim();
                            final uploadValue = uploadValueController.text.trim();
                            
                            Navigator.pop(context, {
                              'download': '$downloadValue$selectedDownloadUnit',
                              'upload': '$uploadValue$selectedUploadUnit',
                            });
                          }
                        },
                        icon: isSaving 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                        label: Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Text(isSaving ? (l10n?.saving ?? 'Saving...') : (l10n?.save ?? 'Save'));
                          },
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          minimumSize: const Size(120, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // اگر کاربر داده‌ها را وارد کرد، سرعت را تنظیم کن
    if (result != null && !_isDisposed && mounted) {
      final download = result['download'] ?? '';
      final upload = result['upload'] ?? '';
      
      if (download.isNotEmpty && upload.isNotEmpty) {
        // فرمت: 4M/12M (آپلود/دانلود)
        final maxLimit = '$upload/$download';
        
        setState(() {
          _isLoading = true;
        });

        try {
          await _setSpeedLimitInternal(widget.device.ipAddress!, maxLimit);
        } catch (e) {
          if (!_isDisposed && mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    }
  }

  Future<void> _setSpeedLimitInternal(String ipAddress, String maxLimit) async {
    // برای عملیات مهم مانند تنظیم سرعت، حتی اگر dispose شده باشیم،
    // باید عملیات را کامل کنیم (اما UI feedback را فقط اگر mounted باشیم نشان می‌دهیم)
    try {
      final provider = Provider.of<ClientsProvider>(context, listen: false);
      final success = await provider.setClientSpeed(
        ipAddress,
        maxLimit,
      ).timeout(
        const Duration(seconds: 45), // افزایش timeout به 45 ثانیه
        onTimeout: () {
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n?.speedSetTimeout ?? 'Speed limit setting timeout'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return false;
        },
      );

      // فقط اگر mounted باشیم، UI را به‌روزرسانی می‌کنیم
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return Text(l10n?.speedSetSuccessfullyWithSpeed(maxLimit) ?? 'Speed limit set successfully: $maxLimit');
                    },
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // فوراً سرعت را در state ذخیره کن (برای نمایش سریع)
        setState(() {
          _currentSpeedLimit = maxLimit;
        });
        
        // ذخیره در cache برای بارگذاری بعدی
        _saveSpeedLimitToCache(maxLimit);
        
        // تازه‌سازی داده‌ها در پس‌زمینه
        try {
          provider.refresh();
          // در پس‌زمینه از RouterOS بارگذاری کن (برای تأیید)
          // 延迟一点时间，让 RouterOS 有时间创建 queue
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_isDisposed) {
              _loadSpeedLimit();
            }
          });
        } catch (e) {
          // ignore refresh errors
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      final errorMsg = provider.errorMessage ?? (l10n?.errorSettingSpeed ?? 'Error setting speed limit');
                      final localizedError = l10n?.localizeServiceError(errorMsg) ?? errorMsg;
                      return Text('${l10n?.error ?? 'Error'}: $localizedError');
                    },
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // فقط اگر mounted باشیم، خطا را نمایش می‌دهیم
      if (!mounted) return;
      
      final l10n = AppLocalizations.of(context);
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      final localizedError = l10n?.localizeServiceError(errorMsg) ?? errorMsg;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('${l10n?.error ?? 'Error'}: $localizedError')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      // فقط اگر mounted باشیم، loading state را به‌روزرسانی می‌کنیم
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// بارگذاری سرعت از cache (SharedPreferences)
  Future<void> _loadSpeedLimitFromCache() async {
    if (_isDisposed || widget.device.ipAddress == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'speed_limit_${widget.device.ipAddress}';
      final cachedSpeed = prefs.getString(cacheKey);
      
      if (cachedSpeed != null && cachedSpeed.isNotEmpty) {
        // 检查 cache 中的值是否有效（排除 "0K/0K" 或类似的值）
        final isValid = _isValidSpeedLimit(cachedSpeed);
        if (isValid) {
          print('✅ [LOAD_SPEED_CACHE] سرعت از cache بارگذاری شد: $cachedSpeed');
          if (mounted && !_isDisposed) {
            setState(() {
              _currentSpeedLimit = cachedSpeed;
            });
          }
        } else {
          print('⚠️ [LOAD_SPEED_CACHE] مقدار cache نامعتبر است (نادیده گرفته شد): $cachedSpeed');
          // 清除无效的 cache
          await prefs.remove(cacheKey);
        }
      }
    } catch (e) {
      print('⚠️ [LOAD_SPEED_CACHE] خطا در بارگذاری از cache: $e');
      // ignore errors
    }
  }

  /// بررسی اینکه سرعت معتبر است یا نه (مثلاً "0K/0K" نامعتبر است)
  bool _isValidSpeedLimit(String speedLimit) {
    if (speedLimit.isEmpty) return false;
    
    // 检查是否是 "0K/0K" 或类似的值
    if (speedLimit.toLowerCase().contains('0k/0k') || 
        speedLimit.toLowerCase().contains('0m/0m') ||
        speedLimit == '0/0') {
      return false;
    }
    
    // 检查格式是否正确 (应该包含 "/")
    if (!speedLimit.contains('/')) {
      return false;
    }
    
    return true;
  }

  /// ذخیره سرعت در cache (SharedPreferences)
  Future<void> _saveSpeedLimitToCache(String speedLimit) async {
    if (widget.device.ipAddress == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'speed_limit_${widget.device.ipAddress}';
      await prefs.setString(cacheKey, speedLimit);
      print('✅ [SAVE_SPEED_CACHE] سرعت در cache ذخیره شد: $speedLimit');
    } catch (e) {
      print('⚠️ [SAVE_SPEED_CACHE] خطا در ذخیره cache: $e');
      // ignore errors
    }
  }

  /// بارگذاری سرعت از RouterOS (در پس‌زمینه)
  Future<void> _loadSpeedLimit() async {
    if (_isDisposed || widget.device.ipAddress == null || widget.isBanned) {
      return;
    }

    if (_isLoadingSpeed) return; // جلوگیری از بارگذاری همزمان
    _isLoadingSpeed = true;

    try {
      // استفاده از MikroTikServiceManager برای دسترسی مستقیم
      final serviceManager = MikroTikServiceManager();
      if (serviceManager.service == null || !serviceManager.isConnected) {
        return;
      }
      
      // 增加 timeout 并添加日志
      print('🔧 [LOAD_SPEED] در حال بارگذاری سرعت برای IP: ${widget.device.ipAddress}');
      final speedInfo = await serviceManager.service!.getClientSpeed(widget.device.ipAddress!)
          .timeout(const Duration(seconds: 15), onTimeout: () {
            print('⚠️ [LOAD_SPEED] Timeout در بارگذاری سرعت برای IP: ${widget.device.ipAddress}');
            return null;
          });

      if (_isDisposed || !mounted) return;

      if (speedInfo != null && speedInfo['max_limit'] != null) {
        final maxLimit = speedInfo['max_limit'] as String;
        print('✅ [LOAD_SPEED] سرعت از RouterOS دریافت شد: $maxLimit');
        // maxLimit 从 getClientSpeed 已经转换好了（M/K 格式），直接使用
        // getClientSpeed 已经处理了所有格式转换（位格式 -> M/K 格式）
        // 所以这里不需要再次转换
        final formattedLimit = maxLimit;
        
        // فقط اگر از RouterOS 成功获取到值，才更新 state
        setState(() {
          _currentSpeedLimit = formattedLimit;
        });
        
        // ذخیره در cache برای بارگذاری بعدی
        _saveSpeedLimitToCache(formattedLimit);
      } else {
        // اگر queue وجود ندارد，但 _currentSpeedLimit 已经有值（刚刚设置的），不要清空它
        // 因为 queue 可能需要一点时间才能在 RouterOS 中完全可用
        // 只在页面首次加载时（_currentSpeedLimit 为 null）才清空
        if (_currentSpeedLimit == null) {
          setState(() {
            _currentSpeedLimit = null;
          });
        } else {
          // 如果已经有值，保留它（可能是刚刚设置的，RouterOS 还没完全创建）
          print('⚠️ [LOAD_SPEED] Queue 在 RouterOS 中还未找到،但保留本地值: $_currentSpeedLimit');
        }
      }
    } catch (e) {
      // 检查是否是超时错误
      final errorStr = e.toString().toLowerCase();
      final isTimeout = errorStr.contains('timeout') || 
                        errorStr.contains('خطا در دریافت سرعت');
      
      if (isTimeout) {
        print('⚠️ [LOAD_SPEED] Timeout در بارگذاری سرعت - استفاده از cache: ${_currentSpeedLimit ?? "ندارد"}');
      } else {
        print('⚠️ [LOAD_SPEED] خطا در بارگذاری سرعت: $e');
      }
      
      // ignore errors - این یک عملیات پس‌زمینه است
      // 如果已经有值，不要清空它（即使从 RouterOS 加载失败）
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoadingSpeed = false;
        });
      }
    }
  }

  /// بارگذاری وضعیت Static/Dynamic Lease (در پس‌زمینه)
  Future<void> _loadLeaseStatus() async {
    if (_isDisposed || widget.device.ipAddress == null || widget.isBanned) {
      return;
    }

    if (_isLoadingLeaseStatus) return; // جلوگیری از بارگذاری همزمان
    _isLoadingLeaseStatus = true;

    try {
      final serviceManager = MikroTikServiceManager();
      if (serviceManager.service == null || !serviceManager.isConnected) {
        return;
      }
      
      print('🔧 [LOAD_LEASE_STATUS] در حال بارگذاری وضعیت Lease برای IP: ${widget.device.ipAddress}, MAC: ${widget.device.macAddress}');
      // کاهش timeout به 5 ثانیه چون از proplist استفاده می‌کنیم (سریع‌تر است)
      final isStatic = await serviceManager.service!.getLeaseStatus(
        macAddress: widget.device.macAddress,
        ipAddress: widget.device.ipAddress,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        print('⚠️ [LOAD_LEASE_STATUS] Timeout در بارگذاری وضعیت Lease');
        return null;
      });

      if (_isDisposed || !mounted) return;

      if (mounted && !_isDisposed) {
        setState(() {
          _isStaticLease = isStatic;
        });
        print('✅ [LOAD_LEASE_STATUS] وضعیت Lease: ${isStatic == true ? "Static" : (isStatic == false ? "Dynamic" : "Unknown")}');
      }
    } catch (e) {
      print('⚠️ [LOAD_LEASE_STATUS] خطا در بارگذاری وضعیت Lease: $e');
      // ignore errors - این یک عملیات پس‌زمینه است
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoadingLeaseStatus = false;
        });
      }
    }
  }

  /// تبدیل Dynamic Lease به Static Lease
  Future<void> _makeStaticLease() async {
    if (_isDisposed || widget.device.ipAddress == null || widget.isBanned) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n?.makeStaticTitle ?? 'Make Device Static'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.makeStaticConfirmWithIP(widget.device.ipAddress ?? '') ?? 'Are you sure you want to make device ${widget.device.ipAddress} static?',
              ),
              const SizedBox(height: 16),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n?.makeStatic ?? 'Make Static'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && !_isDisposed) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
      });

      try {
        await _makeStaticLeaseInternal();
      } catch (e) {
        if (!_isDisposed && mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  final errorMsg = e.toString().replaceFirst('Exception: ', '');
                  final localizedError = l10n?.localizeServiceError(errorMsg) ?? errorMsg;
                  return Text('${l10n?.errorMakingStatic ?? 'Error making device static'}: $localizedError');
                },
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _makeStaticLeaseInternal() async {
    if (_isDisposed) return;

    try {
      final serviceManager = MikroTikServiceManager();
      if (serviceManager.service == null || !serviceManager.isConnected) {
        final l10n = AppLocalizations.of(context);
        throw Exception(l10n?.connectionNotEstablished ?? 'Connection not established');
      }

      final result = await serviceManager.service!.makeStaticLease(
        macAddress: widget.device.macAddress,
        ipAddress: widget.device.ipAddress,
        hostname: widget.device.hostName,
        comment: widget.device.hostName != null ? 'Static: ${widget.device.hostName}' : 'Static Lease',
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        final l10n = AppLocalizations.of(context);
        throw Exception(l10n?.makeStaticTimeout ?? 'Make static timeout. Please try again.');
      });
      
      if (_isDisposed || !mounted) return;
      
      if (result['status'] == 'success' || result['status'] == 'info') {
        // به‌روزرسانی وضعیت
        if (mounted && !_isDisposed) {
          setState(() {
            _isStaticLease = true;
            _isLoading = false;
          });
        }
        
        final l10n = AppLocalizations.of(context);
        final rawMessage = result['message'] as String? ?? (l10n?.deviceMadeStatic ?? 'Device made static successfully');
        final localizedMessage = l10n?.localizeServiceMessage(rawMessage) ?? rawMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizedMessage),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final l10n = AppLocalizations.of(context);
        throw Exception(result['message'] ?? (l10n?.errorMakingStatic ?? 'Error making device static'));
      }
    } catch (e) {
      if (_isDisposed || !mounted) return;
      rethrow;
    }
  }

  /// حذف Static Lease (برگشت به Dynamic)
  Future<void> _removeStaticLease() async {
    if (_isDisposed || widget.device.ipAddress == null || widget.isBanned) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n?.returnToDynamicTitle ?? 'Return to Dynamic'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.returnToDynamicConfirmWithIP(widget.device.ipAddress ?? '') ?? 'Are you sure you want to return device ${widget.device.ipAddress} to dynamic?',
              ),
              const SizedBox(height: 16),
              Text(
                l10n?.ok ?? 'OK',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(l10n?.returnToDynamicInfo1 ?? '• Static Lease will be removed'),
              Text(l10n?.returnToDynamicInfo2 ?? '• After removal, if the device is still connected and requests DHCP, an address will be assigned from the dynamic pool'),
              Text(l10n?.returnToDynamicInfo3 ?? '• IP address may change'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n?.returnToDynamic ?? 'Return to Dynamic'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && !_isDisposed) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
      });

      try {
        await _removeStaticLeaseInternal();
      } catch (e) {
        if (!_isDisposed && mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Text('${l10n?.errorReturningToDynamic ?? 'Error returning device to dynamic'}: $e');
                },
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeStaticLeaseInternal() async {
    if (_isDisposed) return;

    try {
      final serviceManager = MikroTikServiceManager();
      if (serviceManager.service == null || !serviceManager.isConnected) {
        final l10n = AppLocalizations.of(context);
        throw Exception(l10n?.connectionNotEstablished ?? 'Connection not established');
      }

      final result = await serviceManager.service!.removeStaticLease(
        macAddress: widget.device.macAddress,
        ipAddress: widget.device.ipAddress,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        throw Exception('زمان حذف Static Lease به پایان رسید. لطفاً دوباره تلاش کنید.');
      });
      
      if (_isDisposed || !mounted) return;
      
      if (result['status'] == 'success' || result['status'] == 'info') {
        // حذف از لیست دستگاه‌های تایید شده (اگر قبلاً تایید شده بود)
        if (widget.device.macAddress != null) {
          try {
            // حذف از لیست تایید شده
            final prefs = await SharedPreferences.getInstance();
            final approvedMacsList = prefs.getStringList('approved_devices') ?? [];
            final macUpper = widget.device.macAddress!.toUpperCase();
            if (approvedMacsList.contains(macUpper)) {
              approvedMacsList.remove(macUpper);
              await prefs.setStringList('approved_devices', approvedMacsList);
              print('✅ [REMOVE_STATIC] دستگاه از لیست تایید شده حذف شد: $macUpper');
              
              // به‌روزرسانی Provider state
              final provider = Provider.of<ClientsProvider>(context, listen: false);
              provider.refresh();
            }
          } catch (e) {
            print('⚠️ [REMOVE_STATIC] خطا در حذف از لیست تایید شده: $e');
          }
        }
        
        // به‌روزرسانی وضعیت
        if (mounted && !_isDisposed) {
          setState(() {
            _isStaticLease = false;
            _isLoading = false;
          });
        }
        
        final l10n = AppLocalizations.of(context);
        final rawMessage = result['message'] as String? ?? (l10n?.deviceReturnedToDynamic ?? 'Device returned to dynamic successfully');
        final rawNote = result['note'] as String?;
        final localizedMessage = l10n?.localizeServiceMessage(rawMessage) ?? rawMessage;
        final localizedNote = rawNote != null ? (l10n?.localizeServiceMessage(rawNote) ?? rawNote) : null;
        
        // نمایش پیغام موفقیت با هشدار
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localizedMessage),
                  if (localizedNote != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      localizedNote,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
          
          // نمایش Dialog با پیغام مهم
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_isDisposed) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF428B7C)),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Text(l10n?.ok ?? 'OK');
                        },
                      ),
                    ],
                  ),
                  content: Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        l10n?.locale.languageCode == 'en'
                            ? 'For better dynamic IP identification, turn your device WiFi off and on'
                            : 'برای شناسایی بهتر IP پویا، WiFi دستگاه خود را خاموش و روشن کنید',
                        style: TextStyle(fontSize: 14),
                      );
                    },
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF428B7C),
                        foregroundColor: Colors.white,
                      ),
                      child: Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Text(l10n?.ok ?? 'OK');
                        },
                      ),
                    ),
                  ],
                ),
              );
            }
          });
        }
      } else {
        final l10n = AppLocalizations.of(context);
        throw Exception(result['message'] ?? (l10n?.errorReturningToDynamic ?? 'Error returning device to dynamic'));
      }
    } catch (e) {
      if (_isDisposed || !mounted) return;
      rethrow;
    }
  }

  Future<void> _banDevice() async {
    if (_isDisposed || widget.device.ipAddress == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n?.banDevice ?? 'Ban Device'),
          content: Text(
            l10n?.banDeviceConfirmWithIP(widget.device.ipAddress ?? '') ?? 'Are you sure you want to ban device ${widget.device.ipAddress}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n?.banDevice ?? 'Ban Device'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && !_isDisposed) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
      });

      try {
        await _banDeviceInternal();
      } catch (e) {
        if (!_isDisposed && mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _banDeviceInternal() async {
    if (_isDisposed) return;

    try {
      final provider = Provider.of<ClientsProvider>(context, listen: false);
      
      // اجرای عملیات مسدود کردن
      final success = await provider.banClient(
        widget.device.ipAddress!,
        macAddress: widget.device.macAddress,
        hostname: widget.device.hostName,
        ssid: widget.device.ssid,
      );
      
      if (_isDisposed || !mounted) return;
      
      if (success) {
        // به‌روزرسانی loading state
        if (mounted && !_isDisposed) {
          setState(() {
            _isLoading = false;
          });
        }
        
        // فوراً بستن صفحه و هدایت به صفحه اصلی (بدون تاخیر)
        // این باعث می‌شود UI فوراً پاسخ دهد
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
        
        // هدایت فوری به صفحه اصلی
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
        
        // نمایش پیغام موفقیت در صفحه اصلی (با کمی تاخیر برای اطمینان از navigation)
        Future.delayed(const Duration(milliseconds: 100), () {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context);
                        return Text(l10n?.deviceRejected ?? 'Device rejected and banned');
                      },
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        });
      } else {
        // در صورت خطا، فقط loading را متوقف کن (صفحه باز می‌ماند)
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Text('${l10n?.error ?? 'Error'}: ${provider.errorMessage ?? (l10n?.banDevice ?? 'Error banning device')}');
                },
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (_isDisposed || !mounted) return;
      
      final l10n = AppLocalizations.of(context);
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      final localizedError = l10n?.localizeServiceError(errorMsg) ?? errorMsg;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n?.error ?? 'Error'}: $localizedError'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unbanDevice() async {
    if (_isDisposed || widget.device.ipAddress == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n?.unbanDeviceTitle ?? 'Unban Device'),
          content: Text(
            l10n?.unbanDeviceConfirmTextWithIP(widget.device.ipAddress ?? '') ?? 'Are you sure you want to unban device ${widget.device.ipAddress}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n?.unbanDevice ?? 'Unban Device'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && !_isDisposed) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
      });

      try {
        await _unbanDeviceInternal();
      } catch (e) {
        if (!_isDisposed && mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _unbanDeviceInternal() async {
    if (_isDisposed) return;

    try {
      final provider = Provider.of<ClientsProvider>(context, listen: false);
      
      // اجرای عملیات رفع مسدودیت
      final success = await provider.unbanClient(
        widget.device.ipAddress!,
        macAddress: widget.device.macAddress,
        hostname: widget.device.hostName,
        ssid: widget.device.ssid,
      );
      
      if (_isDisposed || !mounted) return;
      
      if (success) {
        // به‌روزرسانی loading state
        if (mounted && !_isDisposed) {
          setState(() {
            _isLoading = false;
          });
        }
        
        // فوراً بستن صفحه و هویایت به صفحه اصلی (بدون تاخیر)
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
        
        // هدایت فوری به صفحه اصلی
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
        
        // نمایش پیغام موفقیت در صفحه اصلی
        Future.delayed(const Duration(milliseconds: 100), () {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final l10n = AppLocalizations.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n?.deviceUnbannedSuccess ?? 'Device unbanned successfully'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        });
      } else {
        // در صورت خطا، فقط loading را متوقف کن
        if (mounted && !_isDisposed) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n?.error ?? 'Error'}: ${provider.errorMessage ?? (l10n?.errorUnbanning ?? 'Error unbanning device')}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (_isDisposed || !mounted) return;
      
      final l10n = AppLocalizations.of(context);
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      final localizedError = l10n?.localizeServiceError(errorMsg) ?? errorMsg;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n?.error ?? 'Error'}: $localizedError'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          _cancelAllPendingOperations();
          
          Future.microtask(() {
            try {
              final provider = Provider.of<ClientsProvider>(context, listen: false);
              provider.refresh();
            } catch (e) {
              // ignore refresh errors
            }
          });
        }
      },
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          
          return Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? colorScheme.surface
                      : _primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: theme.brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AppBar(
                  title: Text(
                    AppLocalizations.of(context)?.deviceDetails ?? 'Device Details',
                    style: TextStyle(
                      color: theme.brightness == Brightness.dark
                          ? colorScheme.onSurface
                          : Colors.white,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  foregroundColor: colorScheme.onSurface,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                ),
              ),
            ),
        body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // هدر دستگاه
                  Builder(
                    builder: (context) {
                      final theme = Theme.of(context);
                      final colorScheme = theme.colorScheme;
                      
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        color: colorScheme.surface,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: widget.isCurrentDevice
                                  ? _primaryColor.withOpacity(0.2)
                                  : (theme.brightness == Brightness.dark
                                      ? colorScheme.onSurface.withOpacity(0.1)
                                      : Colors.grey.shade200),
                              child: Icon(
                                _getDeviceIcon(widget.device.type),
                                size: 40,
                                color: widget.isCurrentDevice
                                    ? _primaryColor
                                    : (theme.brightness == Brightness.dark
                                        ? colorScheme.onSurface.withOpacity(0.6)
                                        : Colors.grey.shade600),
                              ),
                            ),
                            if (widget.isCurrentDevice)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: _primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.device.hostName ??
                              widget.device.user ??
                              widget.device.name ??
                              AppLocalizations.of(context)?.unknown ?? 'Unknown', 
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (widget.isCurrentDevice) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'شما',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // اطلاعات دستگاه
                  Builder(
                    builder: (context) {
                      final theme = Theme.of(context);
                      final colorScheme = theme.colorScheme;
                      
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Text(
                              l10n?.deviceInformation ?? 'Device Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return _buildInfoRow(
                              l10n?.type ?? 'Type',
                              _getDeviceTypeLabel(widget.device.type),
                            );
                          },
                        ),
                        if (widget.device.ipAddress != null)
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return _buildInfoRow(
                                l10n?.ipAddress ?? 'IP Address',
                                widget.device.ipAddress!,
                              );
                            },
                          ),
                        if (widget.device.macAddress != null)
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return _buildInfoRow(
                                l10n?.macAddress ?? 'MAC Address',
                                widget.device.macAddress!,
                              );
                            },
                          ),
                        if (widget.device.hostName != null)
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return _buildInfoRow(
                                l10n?.hostname ?? 'Hostname',
                                widget.device.hostName!,
                              );
                            },
                          ),
                        if (widget.device.uptime != null)
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return _buildInfoRow(
                                l10n?.connectionTime ?? 'Connection Time',
                                widget.device.uptime!,
                              );
                            },
                          ),
                        if (widget.device.ssid != null)
                          _buildInfoRow('SSID', widget.device.ssid!),
                        if (widget.device.signalStrength != null)
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return _buildInfoRow(
                                l10n?.signalStrength ?? 'Signal Strength',
                                widget.device.signalStrength!,
                              );
                            },
                          ),
                        // نمایش سرعت تنظیم شده (با نمایش بهتر)
                        if (_currentSpeedLimit != null && !widget.isBanned)
                          _buildSpeedLimitRow(_currentSpeedLimit!),
                        // نمایش وضعیت Static/Dynamic Lease
                        if (!widget.isBanned && _isStaticLease != null)
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              final leaseStatus = _isStaticLease == true 
                                ? (l10n?.staticLease ?? 'Static (Static)')
                                : (l10n?.dynamicLease ?? 'Dynamic (Dynamic)');
                              return _buildInfoRow(
                                l10n?.leaseStatus ?? 'Lease Status',
                                leaseStatus,
                              );
                            },
                          ),
                        if (widget.isBanned)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Row(
                                  children: [
                                    const Icon(Icons.block, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n?.thisDeviceIsBanned ?? 'This device is banned',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // دکمه‌های عملیات
                  Builder(
                    builder: (context) {
                      final theme = Theme.of(context);
                      final colorScheme = theme.colorScheme;
                      
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Text(
                              l10n?.operations ?? 'Operations',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _setSpeedLimit,
                          icon: const Icon(Icons.speed), 
                          label: Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return Text(
                                l10n?.setSpeedLimit ?? 'Set Speed Limit',
                                style: const TextStyle(fontSize: 20),
                              );
                            },
                          ),  
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.brightness == Brightness.dark
                                ? _darkenColor(_primaryColor, 0.2)
                                : _primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.isBanned)
                          ElevatedButton.icon(
                            onPressed: _unbanDevice,
                            icon: const Icon(Icons.lock_open),
                            label: Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(
                                  l10n?.unbanDevice ?? 'Unban Device',
                                  style: const TextStyle(fontSize: 20),
                                );
                              },
                            ),  
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.brightness == Brightness.dark
                                  ? _darkenColor(Colors.green, 0.3)
                                  : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _banDevice,
                            icon: const Icon(Icons.block),
                            label: Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(l10n?.banDevice ?? 'Ban Device', style: TextStyle(fontSize: 20));
                              },
                            ),  
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.brightness == Brightness.dark
                                  ? _darkenColor(Colors.red, 0.3)
                                  : Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        // دکمه Static کردن Lease (فقط برای Dynamic)
                        if (!widget.isBanned && _isStaticLease != true)
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _makeStaticLease,
                            icon: const Icon(Icons.lock),
                            label: Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(l10n?.makeStatic ?? 'Make Static', style: TextStyle(fontSize: 16));
                              },
                            ),  
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.brightness == Brightness.dark
                                  ? _darkenColor(_primaryColor, 0.2)
                                  : _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        // دکمه برگشت به Dynamic (فقط برای Static)
                        if (!widget.isBanned && _isStaticLease == true)
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _removeStaticLease,
                            icon: const Icon(Icons.lock_open),
                            label: Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(
                                  l10n?.returnToDynamic ?? 'Return to Dynamic',
                                  style: const TextStyle(fontSize: 16),
                                );
                              },
                            ),  
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.brightness == Brightness.dark
                                  ? _darkenColor(Colors.orange, 0.3)
                                  : Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 12),
                        // فیلتر شبکه‌های اجتماعی (انتخاب تکی هر پلتفرم)
                        if (!widget.isBanned)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? colorScheme.surfaceContainerHighest
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.brightness == Brightness.dark
                                    ? colorScheme.outline.withOpacity(0.2)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final l10n = AppLocalizations.of(context);
                                    return Row(
                                      children: [
                                        const Icon(
                                          Icons.filter_alt,
                                          color: _primaryColor,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          l10n?.socialMediaFilter ?? 'Social Media Filter',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _primaryColor,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                ..._buildPlatformFilterToggles(),
                              ],
                            ),
                          ),
                      ],
                    ),
                      );
                    },
                  ),

                ],
              ),
            ),
          );
        },
      ),
    );
  }


  List<Widget> _buildPlatformFilterToggles() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    
    final platforms = [
      {'key': 'telegram', 'name': l10n?.telegram ?? 'Telegram', 'icon': Icons.telegram, 'color': Colors.blue},
      {'key': 'youtube', 'name': l10n?.youtube ?? 'YouTube', 'icon': Icons.play_circle, 'color': Colors.red},
      {'key': 'instagram', 'name': l10n?.instagram ?? 'Instagram', 'icon': Icons.camera_alt, 'color': Color(0xFFE4405F)},
      {'key': 'facebook', 'name': l10n?.facebook ?? 'Facebook', 'icon': Icons.facebook, 'color': Color(0xFF1877F2)},
    ];

    return platforms.map((platform) {
          final key = platform['key'] as String;
          final name = platform['name'] as String;
          final icon = platform['icon'] as IconData;
          final color = platform['color'] as Color;
          final isFiltered = _platformFilterStatus[key] ?? false;
          final isLoading = _platformLoadingStatus[key] ?? false;

          // محاسبه رنگ‌ها بر اساس loading state و theme
          // در حالت loading: رنگ‌ها را کم‌رنگ‌تر کن (opacity کمتر)
          // در حالت عادی: رنگ‌ها را پررنگ کن
          // در تم تاریک: رنگ‌ها را تاریک‌تر کن اما رنگ خودشون را حفظ کن
          final baseColor = isDark && isFiltered 
              ? _darkenColor(color, 0.3) // در تم تاریک، رنگ را 30% تاریک‌تر کن
              : color;
          
          final iconColor = isLoading 
              ? (isFiltered ? baseColor.withOpacity(0.4) : (isDark ? colorScheme.onSurface.withOpacity(0.4) : Colors.grey.shade400))
              : (isFiltered ? baseColor : (isDark ? colorScheme.onSurface.withOpacity(0.6) : Colors.grey));
          
          final titleColor = isLoading
              ? (isDark ? colorScheme.onSurface.withOpacity(0.5) : Colors.grey.shade500)
              : (isFiltered ? baseColor : (isDark ? colorScheme.onSurface : Colors.black87));
          
          final containerColor = isLoading
              ? (isFiltered ? baseColor.withOpacity(0.05) : (isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100))
              : (isFiltered ? baseColor.withOpacity(0.1) : (isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50));
          
          final borderColor = isLoading
              ? (isFiltered ? baseColor.withOpacity(0.3) : (isDark ? colorScheme.outline.withOpacity(0.2) : Colors.grey.shade300))
              : (isFiltered ? baseColor : (isDark ? colorScheme.outline.withOpacity(0.2) : Colors.grey.shade300));

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor,
                width: isFiltered ? 2 : 1,
              ),
            ),
            child: ListTile(
              leading: Icon(icon, color: iconColor),
              title: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              trailing: Switch(
                value: isFiltered,
                onChanged: isLoading ? null : (value) {
                  _togglePlatformFilter(key, name);
                },
                activeColor: isLoading 
                    ? (isDark ? _darkenColor(color, 0.3).withOpacity(0.5) : color.withOpacity(0.5))
                    : (isDark ? _darkenColor(color, 0.3) : color),
              ),
              onTap: isLoading ? null : () {
                _togglePlatformFilter(key, name);
              },
            ),
          );
        }).toList();
  }

  Widget _buildInfoRow(String label, String value) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: TextStyle(
                    color: theme.brightness == Brightness.dark
                        ? colorScheme.onSurface.withOpacity(0.7)
                        : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// نمایش سرعت با فرمت کاربرپسند (با مشخص کردن دانلود و آپلود)
  Widget _buildSpeedLimitRow(String speedLimit) {
    // پارس کردن سرعت: "8M/7M" -> upload: 8M, download: 7M
    String uploadSpeed = '';
    String downloadSpeed = '';
    
    if (speedLimit.contains('/')) {
      final parts = speedLimit.split('/');
      if (parts.length == 2) {
        uploadSpeed = parts[0].trim();
        downloadSpeed = parts[1].trim();
      }
    } else {
      // اگر فقط یک مقدار است، برای هر دو استفاده می‌شود
      uploadSpeed = speedLimit;
      downloadSpeed = speedLimit;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              AppLocalizations.of(context)?.maximum ?? 'Maximum',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // آپلود
                Row(
                  children: [
                    const Icon(Icons.upload, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)?.upload ?? 'Upload: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      uploadSpeed,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // دانلود
                Row(
                  children: [
                    const Icon(Icons.download, color: Colors.blue, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)?.download ?? 'Download: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      downloadSpeed,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String type) {
    switch (type) {
      case 'wireless':
        return Icons.wifi;
      case 'dhcp':
        return Icons.lan;
      case 'hotspot':
        return Icons.router;
      case 'ppp':
        return Icons.phone;
      default:
        return Icons.device_unknown;
    }
  }

  String _getDeviceTypeLabel(String type) {
    switch (type) {
      case 'wireless':
        return 'Wireless';
      case 'dhcp':
        return 'DHCP';
      case 'hotspot':
        return 'Hotspot';
      case 'ppp':
        return 'PPP';
      default:
        return AppLocalizations.of(context)?.unknown ?? 'Unknown';
    }
  }

  /// تیره کردن رنگ برای تم تاریک
  Color _darkenColor(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness * (1 - amount)).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

}


