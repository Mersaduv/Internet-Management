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

class _DeviceDetailScreenState extends State<DeviceDetailScreen>
    with WidgetsBindingObserver {
  // ignore: unused_field
  bool _isLoading = false; // برای عملیات ban/unban
  bool _hasLoadedOnce = false; // برای بررسی اینکه آیا یک بار بارگذاری شده است

  // برای ذخیره سرعت تنظیم شده (برای نمایش سریع)
  String? _currentSpeedLimit; // فرمت: "8M/7M"
  bool _isLoadingSpeed = false; // برای بارگذاری سرعت از RouterOS

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
    print(
      '📱 [DEVICE_DETAIL] نام: ${widget.device.hostName ?? widget.device.name ?? "نامشخص"}',
    );
    print('📱 [DEVICE_DETAIL] مسدود شده: ${widget.isBanned}');
    print('═══════════════════════════════════════════════════════════');

    _hasLoadedOnce = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
      _hasLoadedOnce = true;
    });
  }

  @override
  void dispose() {
    _cancelAllPendingOperations();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// لغو همه عملیات در حال اجرا
  void _cancelAllPendingOperations() {
    _isDisposed = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _hasLoadedOnce && mounted) {
      _loadAllData();
    }
  }

  @override
  void didUpdateWidget(DeviceDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.ipAddress != widget.device.ipAddress ||
        oldWidget.device.macAddress != widget.device.macAddress ||
        oldWidget.isBanned != widget.isBanned) {
      _currentSpeedLimit = null;
      _loadAllData();
      return;
    }

    if (widget.device.ipAddress != null && !widget.isBanned) {
      _loadSpeedLimit();
    }
  }

  /// بارگذاری اطلاعات صفحه
  Future<void> _loadAllData() async {
    if (_isDisposed || widget.device.ipAddress == null || widget.isBanned)
      return;

    _loadSpeedLimitFromCache();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _isDisposed) return;
    await _loadSpeedLimit();
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

        final downloadMatch = RegExp(
          r'^(\d+)([KMkm]?)$',
        ).firstMatch(downloadPart);
        if (downloadMatch != null) {
          currentDownloadValue = downloadMatch.group(1);
          selectedDownloadUnit = (downloadMatch.group(2) ?? 'M').toUpperCase();
        }
      }
    }

    final downloadValueController = TextEditingController(
      text: currentDownloadValue ?? '',
    );
    final uploadValueController = TextEditingController(
      text: currentUploadValue ?? '',
    );
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
                            const Icon(
                              Icons.download,
                              color: Colors.blue,
                              size: 20,
                            ),
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
                                  labelText:
                                      AppLocalizations.of(context)?.value ??
                                      'Value',
                                  hintText: '10',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  helperText:
                                      AppLocalizations.of(
                                        context,
                                      )?.pleaseEnterNumber ??
                                      'Please enter a number',
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
                                    return l10n?.pleaseEnterNumber ??
                                        'Please enter a number';
                                  }
                                  final num = int.tryParse(value.trim());
                                  if (num == null || num <= 0) {
                                    return l10n?.numberMustBeGreaterThanZero ??
                                        'Number must be greater than zero';
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
                                  labelText:
                                      AppLocalizations.of(context)?.unit ??
                                      'Unit',
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
                                    child: Text(
                                      'Mbps',
                                      style: TextStyle(color: Colors.blueGrey),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'K',
                                    child: Text(
                                      'Kbps',
                                      style: TextStyle(color: Colors.blueGrey),
                                    ),
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
                            const Icon(
                              Icons.upload,
                              color: Colors.green,
                              size: 20,
                            ),
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
                                  labelText:
                                      AppLocalizations.of(context)?.value ??
                                      'Value',
                                  hintText: '10',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  helperText:
                                      AppLocalizations.of(
                                        context,
                                      )?.pleaseEnterNumber ??
                                      'Please enter a number',
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
                                    return l10n?.pleaseEnterNumber ??
                                        'Please enter a number';
                                  }
                                  final num = int.tryParse(value.trim());
                                  if (num == null || num <= 0) {
                                    return l10n?.numberMustBeGreaterThanZero ??
                                        'Number must be greater than zero';
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
                                  labelText:
                                      AppLocalizations.of(context)?.unit ??
                                      'Unit',
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
                                    child: Text(
                                      'Mbps',
                                      style: TextStyle(color: Colors.blueGrey),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'K',
                                    child: Text(
                                      'Kbps',
                                      style: TextStyle(color: Colors.blueGrey),
                                    ),
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
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final l10n = AppLocalizations.of(
                                          context,
                                        );
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
                                        final l10n = AppLocalizations.of(
                                          context,
                                        );
                                        return Text(
                                          l10n?.unitGuideText ??
                                              '• Mbps = Megabits per second\n• Kbps = Kilobits per second',
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: TextButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            minimumSize: const Size(100, 48),
                          ),
                          child: Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return Text(
                                l10n?.cancel ?? 'Cancel',
                                style: TextStyle(fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    setDialogState(() {
                                      isSaving = true;
                                    });

                                    final downloadValue =
                                        downloadValueController.text.trim();
                                    final uploadValue = uploadValueController
                                        .text
                                        .trim();

                                    Navigator.pop(context, {
                                      'download':
                                          '$downloadValue$selectedDownloadUnit',
                                      'upload':
                                          '$uploadValue$selectedUploadUnit',
                                    });
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return Text(
                                isSaving
                                    ? (l10n?.saving ?? 'Saving...')
                                    : (l10n?.save ?? 'Save'),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            minimumSize: const Size(120, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
      final success = await provider
          .setClientSpeed(ipAddress, maxLimit)
          .timeout(
            const Duration(seconds: 45), // افزایش timeout به 45 ثانیه
            onTimeout: () {
              if (mounted) {
                final l10n = AppLocalizations.of(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n?.speedSetTimeout ?? 'Speed limit setting timeout',
                    ),
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
                      return Text(
                        l10n?.speedSetSuccessfullyWithSpeed(maxLimit) ??
                            'Speed limit set successfully: $maxLimit',
                      );
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
                      final errorMsg =
                          provider.errorMessage ??
                          (l10n?.errorSettingSpeed ??
                              'Error setting speed limit');
                      final localizedError =
                          l10n?.localizeServiceError(errorMsg) ?? errorMsg;
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
              Expanded(
                child: Text('${l10n?.error ?? 'Error'}: $localizedError'),
              ),
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
          print(
            '⚠️ [LOAD_SPEED_CACHE] مقدار cache نامعتبر است (نادیده گرفته شد): $cachedSpeed',
          );
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
      print(
        '🔧 [LOAD_SPEED] در حال بارگذاری سرعت برای IP: ${widget.device.ipAddress}',
      );
      final speedInfo = await serviceManager.service!
          .getClientSpeed(widget.device.ipAddress!)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print(
                '⚠️ [LOAD_SPEED] Timeout در بارگذاری سرعت برای IP: ${widget.device.ipAddress}',
              );
              return null;
            },
          );

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
          print(
            '⚠️ [LOAD_SPEED] Queue 在 RouterOS 中还未找到،但保留本地值: $_currentSpeedLimit',
          );
        }
      }
    } catch (e) {
      // 检查是否是超时错误
      final errorStr = e.toString().toLowerCase();
      final isTimeout =
          errorStr.contains('timeout') ||
          errorStr.contains('خطا در دریافت سرعت');

      if (isTimeout) {
        print(
          '⚠️ [LOAD_SPEED] Timeout در بارگذاری سرعت - استفاده از cache: ${_currentSpeedLimit ?? "ندارد"}',
        );
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

  /// مسدود کردن دستگاه
  /// الگو برداری از _unbanDevice و rejectDevice
  Future<void> _banDevice() async {
    if (_isDisposed || widget.device.ipAddress == null || widget.isBanned)
      return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.banDevice ?? 'Ban Device',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            l10n?.banDeviceConfirmWithIP(widget.device.ipAddress ?? '') ??
                'Are you sure you want to ban device ${widget.device.ipAddress}?\n\nThis device will be blocked and removed from the network.',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                l10n?.cancel ?? 'Cancel',
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(l10n?.banDevice ?? 'Ban Device'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && !_isDisposed) {
      if (!mounted) return;

      // بدون loading state - فوراً عملیات را انجام می‌دهیم (الگو از rejectDevice)
      try {
        await _banDeviceInternal();
      } catch (e) {
        // ignore - UI قبلاً به‌روزرسانی شده است
        print('⚠️ [BAN_DEVICE] خطا در _banDevice: $e');
      }
    }
  }

  Future<void> _banDeviceInternal() async {
    if (_isDisposed) return;

    try {
      final provider = Provider.of<ClientsProvider>(context, listen: false);

      // الگو برداری از rejectDevice: فوراً UI را به‌روزرسانی می‌کنیم و عملیات را در پس‌زمینه انجام می‌دهیم
      // استفاده از banClientInstant که فوراً UI را به‌روزرسانی می‌کند
      provider.banClientInstant(
        widget.device.ipAddress!,
        macAddress: widget.device.macAddress,
      );

      // فوراً صفحه را می‌بندیم و به صفحه اصلی می‌رویم (بدون انتظار)
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }

      // هدایت فوری به صفحه اصلی
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);

      // به‌روزرسانی داده‌های صفحه اصلی بعد از navigation (فقط یک بار)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          final homeProvider = Provider.of<ClientsProvider>(
            context,
            listen: false,
          );
          homeProvider.refresh();
        }
      });

      // نمایش پیغام موفقیت فوری
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final l10n = AppLocalizations.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n?.deviceBannedSuccess ?? 'Device banned successfully',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    } catch (e) {
      // در صورت خطا، فقط log می‌کنیم - UI قبلاً به‌روزرسانی شده است
      print('⚠️ [BAN_DEVICE] خطا در _banDeviceInternal: $e');
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
            l10n?.unbanDeviceConfirmTextWithIP(widget.device.ipAddress ?? '') ??
                'Are you sure you want to unban device ${widget.device.ipAddress}?',
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
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);

        // به‌روزرسانی داده‌های صفحه اصلی بعد از navigation
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            final homeProvider = Provider.of<ClientsProvider>(
              context,
              listen: false,
            );
            // فقط یک بار refresh بعد از عملیات
            homeProvider.refresh();
          }
        });

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
                    child: Text(
                      l10n?.deviceUnbannedSuccess ??
                          'Device unbanned successfully',
                    ),
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
              content: Text(
                '${l10n?.error ?? 'Error'}: ${provider.errorMessage ?? (l10n?.errorUnbanning ?? 'Error unbanning device')}',
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          _cancelAllPendingOperations();
          // حذف refresh - فقط بعد از عملیات ban/unban refresh می‌کنیم
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
                    AppLocalizations.of(context)?.deviceDetails ??
                        'Device Details',
                    style: TextStyle(
                      color: theme.brightness == Brightness.dark
                          ? colorScheme.onSurface
                          : Colors.white,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  foregroundColor: theme.brightness == Brightness.dark
                      ? colorScheme.onSurface
                      : Colors.white,
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
                                            ? colorScheme.onSurface.withOpacity(
                                                0.1,
                                              )
                                            : Colors.grey.shade200),
                                  child: Icon(
                                    _getDeviceIcon(widget.device.type),
                                    size: 40,
                                    color: widget.isCurrentDevice
                                        ? _primaryColor
                                        : (theme.brightness == Brightness.dark
                                              ? colorScheme.onSurface
                                                    .withOpacity(0.6)
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
                                  AppLocalizations.of(context)?.unknown ??
                                  'Unknown',
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
                                  l10n?.deviceInformation ??
                                      'Device Information',
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
                            if (widget.isBanned)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final l10n = AppLocalizations.of(context);
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.block,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            l10n?.thisDeviceIsBanned ??
                                                'This device is banned',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
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
                                backgroundColor:
                                    theme.brightness == Brightness.dark
                                    ? _darkenColor(_primaryColor, 0.2)
                                    : _primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // دکمه مسدود کردن دستگاه (فقط برای دستگاه‌های غیر مسدود شده)
                            if (!widget.isBanned)
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _banDevice,
                                icon: const Icon(Icons.block),
                                label: Builder(
                                  builder: (context) {
                                    final l10n = AppLocalizations.of(context);
                                    return Text(
                                      l10n?.banDevice ?? 'Ban Device',
                                      style: const TextStyle(fontSize: 20),
                                    );
                                  },
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      theme.brightness == Brightness.dark
                                      ? _darkenColor(Colors.red, 0.3)
                                      : Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            if (!widget.isBanned) const SizedBox(height: 12),
                            // دکمه رفع مسدودیت (فقط برای دستگاه‌های مسدود شده)
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
                                  backgroundColor:
                                      theme.brightness == Brightness.dark
                                      ? _darkenColor(Colors.green, 0.3)
                                      : Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            if (widget.isBanned) const SizedBox(height: 12),
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
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
