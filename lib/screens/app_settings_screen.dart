import 'package:flutter/material.dart';
import '../services/mikrotik_service_manager.dart';
import '../services/settings_service.dart';
import '../providers/clients_provider.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../utils/app_localizations.dart';

/// 应用设置页面
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final MikroTikServiceManager _serviceManager = MikroTikServiceManager();
  final SettingsService _settingsService = SettingsService();
  ThemeMode _selectedThemeMode = ThemeMode.system;
  String _selectedLanguageCode = 'fa';
  bool _isLoading = true;

  static const Color _primaryColor = Color(0xFF428B7C);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载当前设置（语言和主题）
  Future<void> _loadSettings() async {
    try {
      // 加载语言设置
      final languageCode = await _settingsService.getLanguage();
      
      // 加载主题设置
      final themeMode = await _settingsService.getThemeModeEnum();
      
      setState(() {
        _selectedLanguageCode = languageCode;
        _selectedThemeMode = themeMode;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _selectedLanguageCode = 'fa';
        _selectedThemeMode = ThemeMode.system;
        _isLoading = false;
      });
    }
  }

  /// 更改语言
  Future<void> _changeLanguage(String languageCode) async {
    if (_isLoading) return;

    setState(() {
      _selectedLanguageCode = languageCode;
    });

    try {
      // 保存语言设置
      await _settingsService.setLanguage(languageCode);

      // 通知主应用更改语言
      final newLocale = languageCode == 'en'
          ? const Locale('en', 'US')
          : const Locale('fa', 'IR');
      
      // 使用全局回调通知主应用
      if (onLanguageChanged != null) {
        onLanguageChanged!(newLocale);
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.languageChanged ?? 'Language changed'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n?.languageChangeError ?? 'Error'}: $e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 更改主题
  Future<void> _changeTheme(ThemeMode themeMode) async {
    if (_isLoading) return;

    setState(() {
      _selectedThemeMode = themeMode;
    });

    try {
      // 保存主题设置
      await _settingsService.setThemeModeEnum(themeMode);

      // 通知主应用更改主题
      if (onThemeChanged != null) {
        onThemeChanged!(themeMode);
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n?.darkMode ?? 'Theme'} ${_getThemeModeName(themeMode, l10n)}',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n?.error ?? 'Error'}: $e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 获取主题模式名称
  String _getThemeModeName(ThemeMode mode, AppLocalizations? l10n) {
    switch (mode) {
      case ThemeMode.light:
        return l10n?.light ?? 'Light';
      case ThemeMode.dark:
        return l10n?.dark ?? 'Dark';
      case ThemeMode.system:
        return l10n?.system ?? 'System';
    }
  }

  /// 显示主题选择对话框
  void _showThemeSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                l10n?.darkMode ?? 'Theme Mode',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const Divider(),
            // 明亮模式选项
            ListTile(
              leading: const Icon(Icons.light_mode, color: _primaryColor),
              title: Text(l10n?.light ?? 'Light'),
              subtitle: Text(l10n?.lightMode ?? 'Light Mode'),
              trailing: _selectedThemeMode == ThemeMode.light
                  ? const Icon(Icons.check, color: _primaryColor)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (_selectedThemeMode != ThemeMode.light) {
                  _changeTheme(ThemeMode.light);
                }
              },
            ),
            // 暗黑模式选项
            ListTile(
              leading: const Icon(Icons.dark_mode, color: _primaryColor),
              title: Text(l10n?.dark ?? 'Dark'),
              subtitle: Text(l10n?.darkMode ?? 'Dark Mode'),
              trailing: _selectedThemeMode == ThemeMode.dark
                  ? const Icon(Icons.check, color: _primaryColor)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (_selectedThemeMode != ThemeMode.dark) {
                  _changeTheme(ThemeMode.dark);
                }
              },
            ),
            // 跟随系统选项
            ListTile(
              leading: const Icon(Icons.brightness_auto, color: _primaryColor),
              title: Text(l10n?.system ?? 'System'),
              subtitle: Text(l10n?.followSystem ?? 'Follow System'),
              trailing: _selectedThemeMode == ThemeMode.system
                  ? const Icon(Icons.check, color: _primaryColor)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (_selectedThemeMode != ThemeMode.system) {
                  _changeTheme(ThemeMode.system);
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// 显示语言选择对话框
  void _showLanguageSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                l10n?.language ?? 'Language',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const Divider(),
            // 波斯语选项
            ListTile(
              leading: const Icon(Icons.language, color: _primaryColor),
              title: Text(l10n?.persian ?? 'Persian'),
              subtitle: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Text(l10n?.persian ?? 'Persian');
                },
              ),
              trailing: _selectedLanguageCode == 'fa'
                  ? const Icon(Icons.check, color: _primaryColor)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (_selectedLanguageCode != 'fa') {
                  _changeLanguage('fa');
                }
              },
            ),
            // 英语选项
            ListTile(
              leading: const Icon(Icons.language, color: _primaryColor),
              title: Text(l10n?.english ?? 'English'),
              subtitle: const Text('English'),
              trailing: _selectedLanguageCode == 'en'
                  ? const Icon(Icons.check, color: _primaryColor)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (_selectedLanguageCode != 'en') {
                  _changeLanguage('en');
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              l10n?.settings ?? 'Settings',
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
      body: Container(
        color: colorScheme.surfaceContainerHighest,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 通用设置部分
            Card(
              elevation: 2,
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.wifi,
                      color: _primaryColor,
                    ),
                    title: Text(
                      l10n?.wifiSettings ?? 'تنظیمات وایفای',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      l10n?.wifiSettingsSubtitle ??
                          'تغییر نام و رمز شبکه',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: _primaryColor,
                    ),
                    onTap: () {
                      Navigator.of(context).pushNamed('/wifi-settings');
                    },
                  ),
                  const Divider(height: 1),
                  // 语言选择
                  ListTile(
                    leading: Icon(
                      Icons.language,
                      color: _primaryColor,
                    ),
                    title: Text(
                      l10n?.language ?? 'Language',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      _selectedLanguageCode == 'en'
                          ? (l10n?.english ?? 'English')
                          : (l10n?.persian ?? 'Persian'),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedLanguageCode == 'en'
                                    ? (l10n?.english ?? 'English')
                                    : (l10n?.persian ?? 'Persian'),
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: _primaryColor,
                              ),
                            ],
                          ),
                    onTap: _isLoading ? null : () => _showLanguageSelector(context),
                  ),
                  const Divider(height: 1),
                  // 主题模式
                  ListTile(
                    leading: Icon(
                      _selectedThemeMode == ThemeMode.dark
                          ? Icons.dark_mode
                          : _selectedThemeMode == ThemeMode.system
                              ? Icons.brightness_auto
                              : Icons.light_mode,
                      color: _primaryColor,
                    ),
                    title: Text(
                      l10n?.darkMode ?? 'Theme Mode',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      _getThemeModeName(_selectedThemeMode, l10n),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getThemeModeName(_selectedThemeMode, l10n),
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: _primaryColor,
                              ),
                            ],
                          ),
                    onTap: _isLoading ? null : () => _showThemeSelector(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 退出按钮
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                title: Text(
                  l10n?.logout ?? 'Logout',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                subtitle: Text(
                  l10n?.logoutMessage ?? 'Logout from account',
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
                onTap: _handleLogout,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final l10n = AppLocalizations.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.logout ?? 'Logout'),
        content: Text(l10n?.logoutConfirm ?? 'Are you sure you want to logout?'),
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
            child: Text(l10n?.logout ?? 'Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = Provider.of<ClientsProvider>(context, listen: false);
      provider.clear();
      _serviceManager.disconnect();
      
      final settingsService = SettingsService();
      await settingsService.clearCredentials();
      await settingsService.clearLoginTimestamp();

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}
