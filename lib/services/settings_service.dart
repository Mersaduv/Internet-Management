import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mikrotik_connection.dart';

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
  static const String _keyRememberMe = 'remember_me';
  static const String _keyLanguage = 'app_language';
  static const String _keyThemeMode = 'app_theme_mode';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyUsername = 'secure_username';
  static const _keyPassword = 'secure_password';

  // مقادیر پیش‌فرض
  static const String _defaultHost = '192.168.88.1';
  static const bool _defaultUseSsl = false;
  static const String _defaultServiceUrl = 'http://user.ariyabod.af/users';
  static const String _defaultLanguage = 'fa'; // 默认语言：波斯语
  static const String _defaultThemeMode = 'light'; // 默认主题：跟随系统

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

  /// دریافت Port — همیشه پورت API پروژه (2752)
  Future<int> getPort() async {
    if (_cachedPort == MikroTikConnection.apiPort) {
      return MikroTikConnection.apiPort;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_keyPort);
      if (stored != MikroTikConnection.apiPort) {
        await prefs.setInt(_keyPort, MikroTikConnection.apiPort);
      }
    } catch (_) {
      // اگر shared_preferences کار نکرد، همان پورت ثابت را برگردان
    }

    _cachedPort = MikroTikConnection.apiPort;
    return MikroTikConnection.apiPort;
  }

  /// ذخیره Port — پورت API همیشه 2752 است
  Future<void> setPort(int port) async {
    _cachedPort = MikroTikConnection.apiPort;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyPort, MikroTikConnection.apiPort);
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

  /// آیا کاربر «مرا به خاطر بسپار» را فعال کرده است
  Future<bool> getRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyRememberMe) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// ذخیره وضعیت «مرا به خاطر بسپار»
  Future<void> setRememberMe(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRememberMe, value);
    } catch (e) {
      // نادیده
    }
  }

  /// ذخیره اعتبارنامه پس از ورود موفق (Keychain / Keystore)
  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    await _secureStorage.write(key: _keyUsername, value: username);
    await _secureStorage.write(key: _keyPassword, value: password);
  }

  /// بازیابی اعتبارنامه ذخیره‌شده
  Future<Map<String, String>?> getSavedCredentials() async {
    final username = await _secureStorage.read(key: _keyUsername);
    final password = await _secureStorage.read(key: _keyPassword);
    if (username == null || password == null) {
      return null;
    }
    return {'username': username, 'password': password};
  }

  /// پاک کردن اعتبارنامه (خروج یا انقضای session)
  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _keyUsername);
    await _secureStorage.delete(key: _keyPassword);
  }

  /// session معتبر: login_timestamp وجود دارد و کمتر از ۱۴ روز گذشته
  Future<bool> hasValidSession() async {
    final timestamp = await getLoginTimestamp();
    if (timestamp == null) {
      return false;
    }
    final loginTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(loginTime).inDays < 14;
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
        return ThemeMode.light; // Default fallback: light
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

