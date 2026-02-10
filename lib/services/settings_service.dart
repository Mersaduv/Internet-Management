import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// سرویس برای مدیریت تنظیمات اتصال MikroTik
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyHost = 'mikrotik_host';
  static const String _keyPort = 'mikrotik_port';
  static const String _keyUseSsl = 'mikrotik_use_ssl';
  static const String _keyServiceUrl = 'internet_service_url';
  static const String _keyLoginTimestamp = 'login_timestamp';
  static const String _keyLanguage = 'app_language';
  static const String _keyThemeMode = 'app_theme_mode';

  // مقادیر پیش‌فرض
  static const String _defaultHost = '192.168.88.1';
  static const int _defaultPort = 8728;
  static const bool _defaultUseSsl = false;
  static const String _defaultServiceUrl = 'http://user.ariyabod.af/users/computer/DS_MyInternet.php';
  static const String _defaultLanguage = 'fa'; // 默认语言：波斯语
  static const String _defaultThemeMode = 'system'; // 默认主题：跟随系统

  // Cache برای تنظیمات (برای جلوگیری از خطا در صورت مشکل shared_preferences)
  String? _cachedHost;
  int? _cachedPort;
  bool? _cachedUseSsl;
  String? _cachedServiceUrl;
  String? _cachedLanguage;
  String? _cachedThemeMode;

  /// دریافت Host
  Future<String> getHost() async {
    if (_cachedHost != null) {
      return _cachedHost!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedHost = prefs.getString(_keyHost) ?? _defaultHost;
      return _cachedHost!;
    } catch (e) {
      // در صورت خطا، از مقدار پیش‌فرض استفاده کن
      _cachedHost = _defaultHost;
      return _defaultHost;
    }
  }

  /// ذخیره Host
  Future<void> setHost(String host) async {
    _cachedHost = host;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyHost, host);
    } catch (e) {
      // اگر shared_preferences کار نکرد، فقط در حافظه نگه دار
    }
  }

  /// دریافت Port
  Future<int> getPort() async {
    if (_cachedPort != null) {
      return _cachedPort!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPort = prefs.getInt(_keyPort) ?? _defaultPort;
      return _cachedPort!;
    } catch (e) {
      // در صورت خطا، از مقدار پیش‌فرض استفاده کن
      _cachedPort = _defaultPort;
      return _defaultPort;
    }
  }

  /// ذخیره Port
  Future<void> setPort(int port) async {
    _cachedPort = port;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyPort, port);
    } catch (e) {
      // اگر shared_preferences کار نکرد، فقط در حافظه نگه دار
    }
  }

  /// دریافت UseSsl
  Future<bool> getUseSsl() async {
    if (_cachedUseSsl != null) {
      return _cachedUseSsl!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedUseSsl = prefs.getBool(_keyUseSsl) ?? _defaultUseSsl;
      return _cachedUseSsl!;
    } catch (e) {
      // در صورت خطا، از مقدار پیش‌فرض استفاده کن
      _cachedUseSsl = _defaultUseSsl;
      return _defaultUseSsl;
    }
  }

  /// ذخیره UseSsl
  Future<void> setUseSsl(bool useSsl) async {
    _cachedUseSsl = useSsl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyUseSsl, useSsl);
    } catch (e) {
      // اگر shared_preferences کار نکرد، فقط در حافظه نگه دار
    }
  }

  /// دریافت URL سرویس اینترنت
  Future<String> getServiceUrl() async {
    if (_cachedServiceUrl != null) {
      return _cachedServiceUrl!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedServiceUrl = prefs.getString(_keyServiceUrl) ?? _defaultServiceUrl;
      return _cachedServiceUrl!;
    } catch (e) {
      _cachedServiceUrl = _defaultServiceUrl;
      return _defaultServiceUrl;
    }
  }

  /// ذخیره URL سرویس اینترنت
  Future<void> setServiceUrl(String url) async {
    _cachedServiceUrl = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyServiceUrl, url);
    } catch (e) {
      // اگر shared_preferences کار نکرد، فقط در حافظه نگه دار
    }
  }

  /// دریافت همه تنظیمات
  Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'host': await getHost(),
      'port': await getPort(),
      'useSsl': await getUseSsl(),
      'serviceUrl': await getServiceUrl(),
    };
  }

  /// ذخیره زمان لاگین
  Future<void> setLoginTimestamp() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLoginTimestamp, timestamp);
    } catch (e) {
      // اگر shared_preferences کار نکرد، نادیده بگیر
    }
  }

  /// دریافت زمان لاگین
  Future<int?> getLoginTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyLoginTimestamp);
    } catch (e) {
      return null;
    }
  }

  /// بررسی انقضای لاگین (14 روز)
  Future<bool> isLoginExpired() async {
    final timestamp = await getLoginTimestamp();
    if (timestamp == null) {
      return true; // اگر زمان لاگین وجود نداشته باشد، منقضی شده در نظر بگیر
    }
    
    final loginDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(loginDate);
    
    // اگر 14 روز یا بیشتر گذشته باشد، منقضی شده است
    return difference.inDays >= 14;
  }

  /// پاک کردن زمان لاگین (برای خروج)
  Future<void> clearLoginTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLoginTimestamp);
    } catch (e) {
      // اگر shared_preferences کار نکرد، نادیده بگیر
    }
  }

  /// دریافت زبان برنامه
  Future<String> getLanguage() async {
    if (_cachedLanguage != null) {
      return _cachedLanguage!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedLanguage = prefs.getString(_keyLanguage) ?? _defaultLanguage;
      return _cachedLanguage!;
    } catch (e) {
      // در صورت خطا، از مقدار پیش‌فرض استفاده کن
      _cachedLanguage = _defaultLanguage;
      return _defaultLanguage;
    }
  }

  /// ذخیره زبان برنامه
  Future<void> setLanguage(String languageCode) async {
    _cachedLanguage = languageCode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLanguage, languageCode);
    } catch (e) {
      // اگر shared_preferences کار نکرد، فقط در حافظه نگه دار
    }
  }

  /// دریافت主题模式
  Future<String> getThemeMode() async {
    if (_cachedThemeMode != null) {
      return _cachedThemeMode!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedThemeMode = prefs.getString(_keyThemeMode) ?? _defaultThemeMode;
      return _cachedThemeMode!;
    } catch (e) {
      // در صورت خطا، از مقدار پیش‌فرض استفاده کن
      _cachedThemeMode = _defaultThemeMode;
      return _defaultThemeMode;
    }
  }

  /// 将字符串转换为 ThemeMode
  ThemeMode stringToThemeMode(String mode) {
    switch (mode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.system; // 默认跟随系统
    }
  }

  /// 将 ThemeMode 转换为字符串
  String themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// 保存主题模式
  Future<void> setThemeMode(String themeMode) async {
    _cachedThemeMode = themeMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyThemeMode, themeMode);
    } catch (e) {
      // 如果 shared_preferences 不工作，只在内存中保存
    }
  }

  /// 保存 ThemeMode
  Future<void> setThemeModeEnum(ThemeMode themeMode) async {
    await setThemeMode(themeModeToString(themeMode));
  }

  /// 获取 ThemeMode
  Future<ThemeMode> getThemeModeEnum() async {
    final mode = await getThemeMode();
    return stringToThemeMode(mode);
  }

  /// بازنشانی به تنظیمات پیش‌فرض
  Future<void> resetToDefaults() async {
    _cachedHost = null;
    _cachedPort = null;
    _cachedUseSsl = null;
    _cachedServiceUrl = null;
    _cachedLanguage = null;
    _cachedThemeMode = null;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHost);
      await prefs.remove(_keyPort);
      await prefs.remove(_keyUseSsl);
      await prefs.remove(_keyServiceUrl);
      await prefs.remove(_keyLanguage);
      await prefs.remove(_keyThemeMode);
    } catch (e) {
      // اگر shared_preferences کار نکرد، فقط cache را پاک کن
    }
  }
}

