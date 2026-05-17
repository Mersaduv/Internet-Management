import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mikrotik_connection.dart';
import '../providers/clients_provider.dart';
import '../services/mikrotik_service_manager.dart';
import '../services/settings_service.dart';
import '../utils/app_localizations.dart';
import '../utils/wifi_webview_boards.dart';

/// Entry point: routes to WebView or native WiFi form based on router board.
class WifiSettingsRouter extends StatelessWidget {
  const WifiSettingsRouter({super.key});

  static bool isWebViewWifiBoard(Map<String, dynamic>? routerInfo) {
    final matched = isWifiWebViewBoard(routerInfo);
    if (routerInfo != null) {
      debugPrint(
        '[WIFI_SETTINGS] detect board="${routerInfo['board-name']}" '
        'model="${routerInfo['model']}" -> webView=$matched',
      );
    }
    return matched;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClientsProvider>(context);
    final routerInfo =
        provider.routerInfo ?? MikroTikServiceManager().routerInfo;

    if (routerInfo == null) {
      return const _WifiLoadingPlaceholder();
    }

    if (isWebViewWifiBoard(routerInfo)) {
      return const _WifiWebViewRedirect();
    }

    return const WifiNativeSettingsScreen();
  }
}

/// Opens the WebView WiFi panel after the first frame (keeps navigation out of build).
class _WifiWebViewRedirect extends StatefulWidget {
  const _WifiWebViewRedirect();

  @override
  State<_WifiWebViewRedirect> createState() => _WifiWebViewRedirectState();
}

class _WifiWebViewRedirectState extends State<_WifiWebViewRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      debugPrint(
        '[WIFI_SETTINGS] opening /wifi-webview at http://10.10.10.2/',
      );
      Navigator.of(context).pushReplacementNamed('/wifi-webview');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _WifiLoadingPlaceholder extends StatefulWidget {
  const _WifiLoadingPlaceholder();

  @override
  State<_WifiLoadingPlaceholder> createState() => _WifiLoadingPlaceholderState();
}

class _WifiLoadingPlaceholderState extends State<_WifiLoadingPlaceholder> {
  static const Color _primaryColor = Color(0xFF428B7C);
  Timer? _pollTimer;
  int _elapsedMs = 0;
  static const int _maxWaitMs = 10000;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final provider = Provider.of<ClientsProvider>(context, listen: false);
      if (provider.routerInfo == null) {
        unawaited(provider.loadRouterInfo());
      }
    });
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) {
        return;
      }
      _elapsedMs += 500;
      final provider = Provider.of<ClientsProvider>(context, listen: false);
      if (provider.routerInfo != null) {
        _pollTimer?.cancel();
        setState(() {});
        return;
      }
      if (_elapsedMs >= _maxWaitMs) {
        _pollTimer?.cancel();
        setState(() {
          _errorMessage = 'اطلاعات روتر بارگذاری نشد. لطفاً دوباره تلاش کنید.';
        });
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = Provider.of<ClientsProvider>(context);

    if (provider.routerInfo != null) {
      return const WifiSettingsRouter();
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n?.wifiSettings ?? 'تنظیمات وایفای'),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n?.cancel ?? 'بازگشت'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.wifiSettings ?? 'تنظیمات وایفای'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n?.wifiLoading ?? 'در حال خواندن تنظیمات وایفای...'),
          ],
        ),
      ),
    );
  }
}

class WifiNativeSettingsScreen extends StatefulWidget {
  const WifiNativeSettingsScreen({super.key});

  @override
  State<WifiNativeSettingsScreen> createState() => _WifiNativeSettingsScreenState();
}

class _WifiNativeSettingsScreenState extends State<WifiNativeSettingsScreen> {
  static const Color _primaryColor = Color(0xFF428B7C);

  final MikroTikServiceManager _manager = MikroTikServiceManager();
  final SettingsService _settingsService = SettingsService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isReconnecting = false;
  String? _errorMessage;

  String _interfaceId = '';
  String _securityProfileId = '';
  String _securityProfileName = 'default';
  String _currentSsid = '';
  bool _hideSsid = false;
  String _originalSsid = '';
  bool _originalHideSsid = false;
  int _sharedProfileCount = 0;

  List<Map<String, dynamic>> _interfaces = [];

  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadWifiSettings();
      }
    });
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadWifiSettings({String? interfaceId}) async {
    debugPrint('[WIFI_SETTINGS] _loadWifiSettings');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!await _manager.ensureSession()) {
        throw Exception('اتصال به روتر قطع شده است');
      }

      final settings = await _manager
          .getWifiSettings(interfaceId: interfaceId)
          .timeout(const Duration(seconds: 10));

      final interfaces = (settings['interfaces'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _interfaces = interfaces;
        _interfaceId = settings['interface_id']?.toString() ?? '';
        _securityProfileId = settings['security_profile_id']?.toString() ?? '';
        _securityProfileName =
            settings['security_profile_name']?.toString() ?? 'default';
        _currentSsid = settings['ssid']?.toString() ?? '';
        _hideSsid = settings['hide_ssid'] == true;
        _originalSsid = _currentSsid;
        _originalHideSsid = _hideSsid;
        _sharedProfileCount = settings['shared_profile_count'] as int? ?? 0;
        _ssidController.text = _currentSsid;
        _passwordController.clear();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[WIFI_SETTINGS] load error: $e');
      if (!mounted) {
        return;
      }
      final message = e.toString().replaceAll('Exception: ', '');
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isLoading = false;
        _errorMessage = message.contains('هیچ رابط وایرلسی') ||
                message.contains('wireless')
            ? (l10n?.wifiNoInterface ?? 'رابط وایرلس یافت نشد')
            : message.contains('اتصال به روتر')
                ? (l10n?.wifiConnectionLost ?? message)
                : message;
      });
    }
  }

  Future<void> _reconnect() async {
    setState(() => _isReconnecting = true);
    try {
      final credentials = await _settingsService.getSavedCredentials();
      final settings = await _settingsService.getAllSettings();
      if (credentials == null) {
        throw Exception('اعتبارنامه ذخیره نشده است');
      }
      final connection = MikroTikConnection(
        host: settings['host'] as String? ?? '192.168.88.1',
        port: settings['port'] as int? ?? 8728,
        username: credentials['username']!,
        password: credentials['password']!,
        useSsl: settings['useSsl'] as bool? ?? false,
      );
      final ok = await _manager.connect(connection);
      if (!ok) {
        throw Exception('اتصال برقرار نشد');
      }
      await _loadWifiSettings(interfaceId: _interfaceId.isEmpty ? null : _interfaceId);
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isReconnecting = false);
      }
    }
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.wifiSaveConfirmTitle ?? 'ذخیره تنظیمات وایفای'),
        content: Text(
          l10n?.wifiSaveConfirmBody ??
              'ممکن است اتصال وایفای چند ثانیه قطع شود. ادامه می‌دهید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n?.cancel ?? 'انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n?.wifiSave ?? 'ذخیره'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _save();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final newSsid = _ssidController.text.trim();
    final newPassword = _passwordController.text;
    final ssidChanged = newSsid != _originalSsid;
    final hideChanged = _hideSsid != _originalHideSsid;

    setState(() => _isSaving = true);

    try {
      debugPrint('[WIFI_SETTINGS] saving changes');
      if (!await _manager.ensureSession()) {
        throw Exception(
          l10n?.wifiConnectionLost ?? 'اتصال به روتر قطع شده است',
        );
      }

      if (ssidChanged || hideChanged) {
        await _manager
            .setWifiSsid(
              interfaceId: _interfaceId,
              ssid: newSsid,
              hideSsid: _hideSsid,
            )
            .timeout(const Duration(seconds: 10));
      }

      if (newPassword.isNotEmpty) {
        if (_securityProfileId.isEmpty) {
          throw Exception('شناسه پروفایل امنیتی یافت نشد');
        }
        await _manager
            .setWifiPassword(
              securityProfileId: _securityProfileId,
              password: newPassword,
            )
            .timeout(const Duration(seconds: 10));
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.wifiSaveSuccess ?? 'تنظیمات وایفای با موفقیت ذخیره شد',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('[WIFI_SETTINGS] save error: $e');
      if (mounted) {
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.error ?? 'خطا'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n?.cancel ?? 'بستن'),
          ),
        ],
      ),
    );
  }

  bool get _showSharedProfileWarning {
    if (_passwordController.text.isEmpty) {
      return false;
    }
    return _securityProfileName == 'default' || _sharedProfileCount > 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.wifiSettings ?? 'تنظیمات وایفای'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(l10n, theme),
    );
  }

  Widget _buildBody(AppLocalizations? l10n, ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n?.wifiLoading ?? 'در حال خواندن تنظیمات وایفای...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      final isConnectionLost = _errorMessage!.contains('قطع') ||
          _errorMessage!.contains('Connection') ||
          _errorMessage!.contains('connect');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (isConnectionLost)
                ElevatedButton(
                  onPressed: _isReconnecting ? null : _reconnect,
                  child: _isReconnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n?.wifiReconnect ?? 'اتصال مجدد'),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _loadWifiSettings(
                  interfaceId: _interfaceId.isEmpty ? null : _interfaceId,
                ),
                child: Text(l10n?.retry ?? 'تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_interfaces.length > 1) ...[
              DropdownButtonFormField<String>(
                value: _interfaceId.isEmpty ? null : _interfaceId,
                decoration: InputDecoration(
                  labelText: l10n?.wifiInterfaceLabel ?? 'رابط وایرلس',
                  border: const OutlineInputBorder(),
                ),
                items: _interfaces.map((iface) {
                  final id = iface['id']?.toString() ?? '';
                  final name = iface['name']?.toString() ?? id;
                  final disabled = iface['disabled'] == true;
                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(disabled ? '$name (غیرفعال)' : name),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id == null || id == _interfaceId) {
                    return;
                  }
                  _loadWifiSettings(interfaceId: id);
                },
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _ssidController,
              maxLength: 32,
              decoration: InputDecoration(
                labelText: l10n?.wifiNameLabel ?? 'نام شبکه (SSID)',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'نام شبکه نمی‌تواند خالی باشد';
                }
                if (v.trim().length > 32) {
                  return 'حداکثر ۳۲ کاراکتر';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              maxLength: 63,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n?.wifiPasswordLabel ?? 'رمز عبور',
                hintText: l10n?.wifiPasswordHint ??
                    'برای حفظ رمز فعلی خالی بگذارید',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return null;
                }
                if (v.length < 8) {
                  return 'رمز عبور باید حداقل ۸ کاراکتر باشد';
                }
                if (v.length > 63) {
                  return 'حداکثر ۶۳ کاراکتر';
                }
                return null;
              },
            ),
            if (_showSharedProfileWarning) ...[
              const SizedBox(height: 8),
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n?.wifiSharedProfileWarning ??
                              'تغییر رمز عبور روی پروفایل \'$_securityProfileName\' اعمال می‌شود که ممکن است روی سایر رابط‌های وایرلس هم تأثیر بگذارد.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(l10n?.wifiHideSsid ?? 'مخفی کردن نام شبکه'),
              subtitle: Text(
                l10n?.wifiHideSsidSubtitle ??
                    'دستگاه‌ها نام شبکه را نمی‌بینند',
              ),
              value: _hideSsid,
              onChanged: (val) => setState(() => _hideSsid = val),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _onSavePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n?.wifiSave ?? 'ذخیره تغییرات'),
            ),
          ],
        ),
      ),
    );
  }
}
