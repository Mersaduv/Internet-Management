import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../utils/app_localizations.dart';

/// صفحه تنظیمات اتصال MikroTik
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final SettingsService _settingsService = SettingsService();
  
  bool _useSsl = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _successMessage;
  String? _errorMessage;

  static const Color _primaryColor = Color(0xFF428B7C);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await _settingsService.getAllSettings();
      setState(() {
        _hostController.text = settings['host'] as String;
        _portController.text = (settings['port'] as int).toString();
        _useSsl = settings['useSsl'] as bool;
        _isLoading = false;
      });
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = '${l10n?.errorLoadingSettings ?? 'Error loading settings'}: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _successMessage = null;
      _errorMessage = null;
    });

    try {
      await _settingsService.setHost(_hostController.text.trim());
      await _settingsService.setPort(int.parse(_portController.text.trim()));
      await _settingsService.setUseSsl(_useSsl);

      final l10n = AppLocalizations.of(context);
      setState(() {
        _isSaving = false;
        _successMessage = l10n?.settingsSaved ?? 'Settings saved successfully';
      });

      // پاک کردن پیام موفقیت بعد از 3 ثانیه
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isSaving = false;
        _errorMessage = '${l10n?.settingsSaveError ?? 'Error saving settings'}: $e';
      });
    }
  }

  Future<void> _resetToDefaults() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.resetToDefaults ?? 'Reset to Defaults'),
        content: Text(l10n?.resetSettingsConfirm ?? 'Are you sure you want to reset settings to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.reset ?? 'Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _settingsService.resetToDefaults();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.settingsReset ?? 'Settings reset to default')),
        );
      }
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    
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
          child: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return AppBar(
                title: Text(
                  l10n?.connectionSettings ?? 'Connection Settings',
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
              );
            },
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // کارت تنظیمات
                    Card(
                      elevation: 2,
                      color: colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.router, color: _primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  l10n?.mikrotikRouterOS ?? 'MikroTik RouterOS Settings',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // فیلد Host/IP
                            TextFormField(
                              controller: _hostController,
                              decoration: InputDecoration(
                                labelText: l10n?.ipAddressOrHostname ?? 'IP Address or Hostname',
                                hintText: '192.168.88.1',
                                prefixIcon: const Icon(Icons.router),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              textDirection: TextDirection.ltr,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return l10n?.pleaseEnterIP ?? 'Please enter IP address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // فیلد Port
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _portController,
                                    decoration: InputDecoration(
                                      labelText: l10n?.port ?? 'Port',
                                      hintText: '8728',
                                      prefixIcon: const Icon(Icons.numbers),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    textDirection: TextDirection.ltr,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return l10n?.pleaseEnterPort ?? 'Please enter port';
                                      }
                                      final port = int.tryParse(value.trim());
                                      if (port == null || port < 1 || port > 65535) {
                                        return l10n?.portRangeError ?? 'Port must be a number between 1 and 65535';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CheckboxListTile(
                                    title: const Text('SSL'),
                                    value: _useSsl,
                                    onChanged: (value) {
                                      setState(() {
                                        _useSsl = value ?? false;
                                        if (_useSsl && _portController.text == '8728') {
                                          _portController.text = '8729';
                                        } else if (!_useSsl && _portController.text == '8729') {
                                          _portController.text = '8728';
                                        }
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // پیام موفقیت
                    if (_successMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.green.shade900.withOpacity(0.3)
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                                ? Colors.green.shade700
                                : Colors.green.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.green.shade300
                                  : Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: TextStyle(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.green.shade300
                                      : Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // پیام خطا
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.red.shade900.withOpacity(0.3)
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                                ? Colors.red.shade700
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.red.shade300
                                  : Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.red.shade300
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // دکمه ذخیره
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? (l10n?.saving ?? 'Saving...') : (l10n?.saveSettings ?? 'Save Settings')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // دکمه بازنشانی
                    OutlinedButton.icon(
                      onPressed: _resetToDefaults,
                      icon: const Icon(Icons.restore),
                      label: Text(l10n?.resetToDefaults ?? 'Reset to Defaults'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: _primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

