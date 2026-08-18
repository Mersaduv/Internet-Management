import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/mikrotik_connection.dart';
import '../providers/clients_provider.dart';
import '../services/mikrotik_service_manager.dart';
import '../services/settings_service.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';
import '../utils/smart_text_direction.dart';
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
      debugPrint('[WIFI_SETTINGS] opening /wifi-webview at http://10.10.10.2/');
      Navigator.of(context).pushReplacementNamed('/wifi-webview');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _WifiLoadingPlaceholder extends StatefulWidget {
  const _WifiLoadingPlaceholder();

  @override
  State<_WifiLoadingPlaceholder> createState() =>
      _WifiLoadingPlaceholderState();
}

class _WifiLoadingPlaceholderState extends State<_WifiLoadingPlaceholder> {
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
    final primaryColor = AppTheme.primaryFor(Theme.of(context).brightness);
    final provider = Provider.of<ClientsProvider>(context);

    if (provider.routerInfo != null) {
      return const WifiSettingsRouter();
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n?.wifiSettings ?? 'تنظیمات وایفای'),
          backgroundColor: primaryColor,
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
        backgroundColor: primaryColor,
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

class _WifiSaveResult {
  const _WifiSaveResult({
    required this.ssid,
    required this.password,
    required this.hideSsid,
  });

  final String ssid;
  final String password;
  final bool hideSsid;
}

class WifiNativeSettingsScreen extends StatefulWidget {
  const WifiNativeSettingsScreen({super.key});

  @override
  State<WifiNativeSettingsScreen> createState() =>
      _WifiNativeSettingsScreenState();
}

class _WifiNativeSettingsScreenState extends State<WifiNativeSettingsScreen> {
  final MikroTikServiceManager _manager = MikroTikServiceManager();
  final SettingsService _settingsService = SettingsService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isReconnecting = false;
  String? _errorMessage;

  String _interfaceId = '';
  String _interfaceName = 'wlan1';
  String _securityProfileId = '';
  String _securityProfileName = 'default';
  _WifiSaveResult? _saveResult;
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

      final interfaces =
          (settings['interfaces'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _interfaces = interfaces;
        _interfaceId = settings['interface_id']?.toString() ?? '';
        _interfaceName = settings['interface_name']?.toString() ?? 'wlan1';
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
        _errorMessage =
            message.contains('هیچ رابط وایرلسی') || message.contains('wireless')
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
        port: MikroTikConnection.apiPort,
        username: credentials['username']!,
        password: credentials['password']!,
        useSsl: settings['useSsl'] as bool? ?? false,
      );
      final ok = await _manager.connect(connection);
      if (!ok) {
        throw Exception('اتصال برقرار نشد');
      }
      await _loadWifiSettings(
        interfaceId: _interfaceId.isEmpty ? null : _interfaceId,
      );
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

    final ssidChanged = _ssidController.text.trim() != _originalSsid;
    final passwordChanged = _passwordController.text.isNotEmpty;
    final hideSsidChanged = _hideSsid != _originalHideSsid;

    if (!ssidChanged && !passwordChanged && !hideSsidChanged) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('هیچ تغییری وجود ندارد')));
      return;
    }

    final l10n = AppLocalizations.of(context);
    setState(() => _isSaving = true);

    try {
      debugPrint('[WIFI_SETTINGS] saveWifiSettingsAtomic (RouterOS script)');
      if (!await _manager.ensureSession()) {
        throw Exception(
          l10n?.wifiConnectionLost ?? 'اتصال به روتر قطع شده است',
        );
      }

      await _manager.saveWifiSettingsAtomic(
        interfaceName: _interfaceName,
        profileName: _securityProfileName,
        ssid: _ssidController.text.trim(),
        hideSsid: _hideSsid,
        password: _passwordController.text.isNotEmpty
            ? _passwordController.text
            : null,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _saveResult = _WifiSaveResult(
          ssid: _ssidController.text.trim(),
          password: _passwordController.text.isNotEmpty
              ? _passwordController.text
              : '(بدون تغییر)',
          hideSsid: _hideSsid,
        );
        _isSaving = false;
      });
    } catch (e) {
      debugPrint('[WIFI_SETTINGS] save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
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
    final isSuccess = _saveResult != null;
    final primaryColor = AppTheme.primaryFor(theme.brightness);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: Text(
          isSuccess
              ? (l10n?.wifiSaveSuccessTitle ?? 'اطلاعات با موفقیت ذخیره شد')
              : (l10n?.wifiSettings ?? 'تنظیمات وایفای'),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !isSuccess,
      ),
      body: _buildBody(l10n, theme),
    );
  }

  Widget _buildBody(AppLocalizations? l10n, ThemeData theme) {
    final primaryColor = AppTheme.primaryFor(theme.brightness);

    if (_saveResult != null) {
      return _buildSuccessScreen(l10n, theme);
    }

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
      final isConnectionLost =
          _errorMessage!.contains('قطع') ||
          _errorMessage!.contains('Connection') ||
          _errorMessage!.contains('connect');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
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
                  final selected = _interfaces.firstWhere(
                    (iface) => iface['id']?.toString() == id,
                    orElse: () => <String, dynamic>{},
                  );
                  _interfaceName =
                      selected['name']?.toString() ?? _interfaceName;
                  _loadWifiSettings(interfaceId: id);
                },
              ),
              const SizedBox(height: 16),
            ],
            SmartDirectionTextFormField(
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
            SmartDirectionTextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              maxLength: 63,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n?.wifiPasswordLabel ?? 'رمز عبور',
                hintText: l10n?.wifiPasswordHint ?? 'رمز عبور جدید',
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
                l10n?.wifiHideSsidSubtitle ?? 'دستگاه‌ها نام شبکه را نمی‌بینند',
              ),
              value: _hideSsid,
              onChanged: (val) => setState(() => _hideSsid = val),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _onSavePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
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

  String _displayPassword(String password) {
    if (password == '(بدون تغییر)' || password.isEmpty) {
      return password;
    }
    if (password.length <= 4) {
      return '•' * password.length;
    }
    return '${password.substring(0, 2)}${'•' * (password.length - 2)}';
  }

  Widget _buildSuccessScreen(AppLocalizations? l10n, ThemeData theme) {
    final result = _saveResult!;
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = AppTheme.primaryFor(theme.brightness);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: isDark ? 2 : 1,
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outline.withOpacity(isDark ? 0.25 : 0.12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withOpacity(isDark ? 0.22 : 0.12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.35),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: primaryColor,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n?.wifiSaveSuccessTitle ??
                          'اطلاعات با موفقیت ذخیره شد',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n?.wifiSaveSuccess ??
                          'تنظیمات وایفای با موفقیت ذخیره شد',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.65),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainerHighest
                            : const Color(0xFFF4F7F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSuccessSummaryRow(
                            theme,
                            icon: Icons.wifi_rounded,
                            label: 'نام وایفای',
                            value: result.ssid,
                          ),
                          Divider(
                            height: 1,
                            color: colorScheme.outline.withOpacity(0.12),
                          ),
                          _buildSuccessSummaryRow(
                            theme,
                            icon: Icons.lock_outline_rounded,
                            label: 'رمز وایفای',
                            value: _displayPassword(result.password),
                          ),
                          Divider(
                            height: 1,
                            color: colorScheme.outline.withOpacity(0.12),
                          ),
                          _buildSuccessSummaryRow(
                            theme,
                            icon: Icons.visibility_outlined,
                            label: 'حالت نمایش',
                            value: result.hideSsid ? 'مخفی' : 'قابل نمایش',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.28),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: primaryColor,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n?.wifiSaveSuccessReconnectBody ??
                                  'برای استفاده مجدد لطفاً برنامه را بسته نمایید، '
                                      'دوباره به وایفای خود متصل شوید، '
                                      'مجدداً برنامه را باز کنید.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.85),
                                height: 1.65,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => SystemNavigator.pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.exit_to_app_rounded, size: 20),
                        label: Text(
                          l10n?.wifiCloseApp ?? 'بستن برنامه',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          l10n?.wifiBackWithoutClose ?? 'بازگشت بدون بستن',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessSummaryRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = theme.colorScheme;
    final primaryColor = AppTheme.primaryFor(theme.brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
