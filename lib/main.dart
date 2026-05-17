import 'dart:async';

/// Internet Management Application
///
/// Developer: Mersad Karimi
/// Email: mersadkarimi001@gmail.com
///
/// A Flutter application for managing internet connections and MikroTik routers.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/connection_test_screen.dart';
import 'screens/device_detail_screen.dart';
import 'screens/internet_service_screen.dart';
import 'screens/app_settings_screen.dart';
import 'services/mikrotik_service_manager.dart';
import 'services/settings_service.dart';
import 'services/network_info_service.dart';
import 'models/client_info.dart';
import 'providers/clients_provider.dart';
import 'utils/app_localizations.dart';

// 全局回调函数，用于从子组件通知主应用更改语言
Function(Locale)? onLanguageChanged;

// 全局回调函数，用于从子组件通知主应用更改主题
Function(ThemeMode)? onThemeChanged;

final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SettingsService _settingsService = SettingsService();
  Locale _locale = const Locale('fa', 'IR'); // 默认语言：波斯语
  ThemeMode _themeMode = ThemeMode.system; // 默认主题：跟随系统
  bool _isLoading = true;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // 注册全局回调
    onLanguageChanged = (Locale newLocale) {
      changeLanguage(newLocale);
    };
    onThemeChanged = (ThemeMode newThemeMode) {
      changeTheme(newThemeMode);
    };
    _loadSettings();
    _logNetworkInfoOnStartup();
  }

  /// لاگ اطلاعات شبکه به محض باز شدن برنامه
  Future<void> _logNetworkInfoOnStartup() async {
    try {
      print('═══════════════════════════════════════════════════════');
      print('🚀 [APP_STARTUP] برنامه در حال راه‌اندازی...');
      print('═══════════════════════════════════════════════════════');

      final networkInfo = NetworkInfoService();

      // دریافت IPv4 Address دستگاه
      final deviceIp = await networkInfo.getDeviceIPv4Address();
      if (deviceIp != null) {
        print('✅ [APP_STARTUP] IPv4 Address دستگاه کاربر: $deviceIp');
      } else {
        print('⚠️ [APP_STARTUP] IPv4 Address دستگاه کاربر: یافت نشد');
      }

      // دریافت Default Gateway
      // این متد به ترتیب از RouterOS API، حدس از IP دستگاه، یا IP روتر از تنظیمات استفاده می‌کند
      final gateway = await networkInfo.getDefaultGatewayOrRouterIp();
      if (gateway != null) {
        print('✅ [APP_STARTUP] Default Gateway اینترنت: $gateway');

        // بررسی اینکه gateway از کجا آمده
        final serviceManager = MikroTikServiceManager();
        final settings = await _settingsService.getAllSettings();
        final routerHost = settings['host'] as String?;
        final deviceIp = await networkInfo.getDeviceIPv4Address();

        String source = 'نامشخص';
        if (serviceManager.isConnected) {
          source = 'RouterOS API (route table)';
        } else if (deviceIp != null) {
          final parts = deviceIp.split('.');
          if (parts.length == 4) {
            final guessedGateway = '${parts[0]}.${parts[1]}.${parts[2]}.1';
            if (gateway == guessedGateway) {
              source = 'حدس از IP دستگاه (${deviceIp} → ${gateway})';
            } else if (gateway == routerHost) {
              source = 'IP روتر از تنظیمات (${routerHost})';
            } else {
              source = 'IP روتر از تنظیمات (${routerHost}) - در همان subnet';
            }
          }
        } else if (gateway == routerHost) {
          source = 'IP روتر از تنظیمات (${routerHost})';
        }

        print('   └─ منبع: $source');
      } else {
        print('⚠️ [APP_STARTUP] Default Gateway اینترنت: یافت نشد');
      }

      // دریافت تنظیمات اتصال
      final settings = await _settingsService.getAllSettings();
      print('📋 [APP_STARTUP] تنظیمات اتصال:');
      print('   └─ Router Host: ${settings['host']}');
      print('   └─ Router Port: ${settings['port']}');
      print('   └─ Use SSL: ${settings['useSsl']}');

      print('═══════════════════════════════════════════════════════');
    } catch (e) {
      print('❌ [APP_STARTUP] خطا در دریافت اطلاعات شبکه: $e');
    }
  }

  @override
  void dispose() {
    onLanguageChanged = null;
    onThemeChanged = null;
    super.dispose();
  }

  /// 加载保存的设置（语言和主题）
  Future<void> _loadSettings() async {
    try {
      // 加载语言设置
      final languageCode = await _settingsService.getLanguage();
      final locale = languageCode == 'en'
          ? const Locale('en', 'US')
          : const Locale('fa', 'IR');

      // 加载主题设置
      final themeMode = await _settingsService.getThemeModeEnum();

      setState(() {
        _locale = locale;
        _themeMode = themeMode;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _locale = const Locale('fa', 'IR');
        _themeMode = ThemeMode.system;
        _isLoading = false;
      });
    }
  }

  /// 更改语言（供子组件调用）
  Future<void> changeLanguage(Locale newLocale) async {
    await _settingsService.setLanguage(newLocale.languageCode);
    setState(() {
      _locale = newLocale;
    });
  }

  /// 更改主题（供子组件调用）
  Future<void> changeTheme(ThemeMode newThemeMode) async {
    await _settingsService.setThemeModeEnum(newThemeMode);
    setState(() {
      _themeMode = newThemeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // 显示加载指示器，直到语言加载完成
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF428B7C),
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF428B7C),
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.system,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: const Color(0xFF428B7C)),
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ClientsProvider(),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Internet Management',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF428B7C),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          primaryColor: const Color(0xFF428B7C),
          fontFamily: _locale.languageCode == 'fa' ? 'Vazir' : null,
          textTheme: _locale.languageCode == 'fa'
              ? const TextTheme(
                  displayLarge: TextStyle(fontFamily: 'Vazir'),
                  displayMedium: TextStyle(fontFamily: 'Vazir'),
                  displaySmall: TextStyle(fontFamily: 'Vazir'),
                  headlineLarge: TextStyle(fontFamily: 'Vazir'),
                  headlineMedium: TextStyle(fontFamily: 'Vazir'),
                  headlineSmall: TextStyle(fontFamily: 'Vazir'),
                  titleLarge: TextStyle(fontFamily: 'Vazir'),
                  titleMedium: TextStyle(fontFamily: 'Vazir'),
                  titleSmall: TextStyle(fontFamily: 'Vazir'),
                  bodyLarge: TextStyle(fontFamily: 'Vazir'),
                  bodyMedium: TextStyle(fontFamily: 'Vazir'),
                  bodySmall: TextStyle(fontFamily: 'Vazir'),
                  labelLarge: TextStyle(fontFamily: 'Vazir'),
                  labelMedium: TextStyle(fontFamily: 'Vazir'),
                  labelSmall: TextStyle(fontFamily: 'Vazir'),
                )
              : null,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF428B7C),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          primaryColor: const Color(0xFF428B7C),
          fontFamily: _locale.languageCode == 'fa' ? 'Vazir' : null,
          textTheme: _locale.languageCode == 'fa'
              ? const TextTheme(
                  displayLarge: TextStyle(fontFamily: 'Vazir'),
                  displayMedium: TextStyle(fontFamily: 'Vazir'),
                  displaySmall: TextStyle(fontFamily: 'Vazir'),
                  headlineLarge: TextStyle(fontFamily: 'Vazir'),
                  headlineMedium: TextStyle(fontFamily: 'Vazir'),
                  headlineSmall: TextStyle(fontFamily: 'Vazir'),
                  titleLarge: TextStyle(fontFamily: 'Vazir'),
                  titleMedium: TextStyle(fontFamily: 'Vazir'),
                  titleSmall: TextStyle(fontFamily: 'Vazir'),
                  bodyLarge: TextStyle(fontFamily: 'Vazir'),
                  bodyMedium: TextStyle(fontFamily: 'Vazir'),
                  bodySmall: TextStyle(fontFamily: 'Vazir'),
                  labelLarge: TextStyle(fontFamily: 'Vazir'),
                  labelMedium: TextStyle(fontFamily: 'Vazir'),
                  labelSmall: TextStyle(fontFamily: 'Vazir'),
                )
              : null,
        ),
        themeMode: _themeMode,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fa', 'IR'), // فارسی
          Locale('en', 'US'), // انگلیسی
        ],
        locale: _locale,
        navigatorObservers: [routeObserver],
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const MainScaffold(),
          '/test': (context) => const ConnectionTestScreen(),
          '/device-detail': (context) {
            final args =
                ModalRoute.of(context)!.settings.arguments
                    as Map<String, dynamic>;
            return DeviceDetailScreen(
              device: args['device'] as ClientInfo,
              isCurrentDevice: args['isCurrentDevice'] as bool? ?? false,
              isBanned: args['isBanned'] as bool? ?? false,
            );
          },
        },
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.0)),
            child: child!,
          );
        },
      ),
    );
  }
}

/// صفحه splash — تلاش auto-login قبل از Login یا Home
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _attemptAutoLogin();
  }

  Future<void> _attemptAutoLogin() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) {
      return;
    }

    final manager = MikroTikServiceManager();
    final success = await manager.autoConnect();

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              isDark
                  ? 'assets/images/logos/logo_dark.png'
                  : 'assets/images/logos/logo.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFF428B7C)),
          ],
        ),
      ),
    );
  }
}

/// MainScaffold با bottom navigation ثابت برای همه صفحات
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  final MikroTikServiceManager _serviceManager = MikroTikServiceManager();
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _checkLoginExpiration();
    _loadNetworkInfo();
  }

  /// بارگذاری اطلاعات شبکه (IPv4 Address و Default Gateway)
  /// این متد هنگام باز شدن برنامه اطلاعات شبکه را دریافت می‌کند
  Future<void> _loadNetworkInfo() async {
    try {
      print('═══════════════════════════════════════════════════════');
      print('🌐 [NETWORK_INFO] در حال دریافت اطلاعات شبکه دستگاه...');
      print('═══════════════════════════════════════════════════════');

      final networkInfo = NetworkInfoService();

      // دریافت IPv4 Address دستگاه
      final deviceIp = await networkInfo.getDeviceIPv4Address();
      if (deviceIp != null) {
        print('✅ [NETWORK_INFO] IPv4 Address دستگاه کاربر: $deviceIp');
      } else {
        print('⚠️ [NETWORK_INFO] IPv4 Address دستگاه کاربر: یافت نشد');
      }

      // دریافت Default Gateway
      final gateway = await networkInfo.getDefaultGatewayOrRouterIp();
      if (gateway != null) {
        print('✅ [NETWORK_INFO] Default Gateway اینترنت: $gateway');
      } else {
        print('⚠️ [NETWORK_INFO] Default Gateway اینترنت: یافت نشد');
      }

      // بررسی وضعیت اتصال RouterOS
      if (_serviceManager.isConnected) {
        print('✅ [NETWORK_INFO] اتصال به RouterOS: برقرار است');
        final routerInfo = _serviceManager.routerInfo;
        if (routerInfo != null) {
          print('   └─ Router Version: ${routerInfo['version']}');
          print('   └─ Router Platform: ${routerInfo['platform']}');
          print('   └─ Router Uptime: ${routerInfo['uptime']}');
        }
      } else {
        print('⚠️ [NETWORK_INFO] اتصال به RouterOS: برقرار نیست');
      }

      // دریافت همه اطلاعات شبکه
      final allInfo = await networkInfo.getNetworkInfo();
      print('📊 [NETWORK_INFO] خلاصه اطلاعات شبکه:');
      print('   └─ Device IPv4: ${allInfo['deviceIp'] ?? 'N/A'}');
      print('   └─ Default Gateway: ${allInfo['defaultGateway'] ?? 'N/A'}');

      print('═══════════════════════════════════════════════════════');
    } catch (e) {
      print('❌ [NETWORK_INFO] خطا در دریافت اطلاعات شبکه: $e');
    }
  }

  /// بررسی انقضای لاگین
  Future<void> _checkLoginExpiration() async {
    final isExpired = await _settingsService.isLoginExpired();
    if (isExpired && mounted) {
      // اگر لاگین منقضی شده باشد، به صفحه ورود هدایت کن
      final provider = Provider.of<ClientsProvider>(context, listen: false);
      provider.clear();
      _serviceManager.disconnect();
      await _settingsService.clearCredentials();
      await _settingsService.clearLoginTimestamp();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    if (index == 0) {
      final provider = Provider.of<ClientsProvider>(context, listen: false);
      unawaited(provider.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomePage(),
          InternetServiceScreen(),
          AppSettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: l10n?.home ?? 'Home',
                      index: 0,
                      isActive: _currentIndex == 0,
                    ),
                    _buildNavItem(
                      icon: Icons.language_outlined,
                      activeIcon: Icons.language,
                      label: l10n?.internetService ?? 'Internet Service',
                      index: 1,
                      isActive: _currentIndex == 1,
                    ),
                    _buildNavItem(
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings,
                      label: l10n?.settings ?? 'Settings',
                      index: 2,
                      isActive: _currentIndex == 2,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Icon(
          isActive ? activeIcon : icon,
          color: isActive ? const Color(0xFF428B7C) : Colors.grey.shade600,
          size: 28,
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final MikroTikServiceManager _serviceManager = MikroTikServiceManager();
  int _selectedTab = 0; // 0: متصل, 1: مسدود
  bool _routeObserverSubscribed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // مقداردهی اولیه Provider
      final provider = Provider.of<ClientsProvider>(context, listen: false);
      provider.initialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeObserverSubscribed) {
      return;
    }

    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      routeObserver.subscribe(this, route);
      _routeObserverSubscribed = true;
    }
  }

  @override
  void dispose() {
    if (_routeObserverSubscribed) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    unawaited(_refreshActiveTabData());
  }

  Future<void> _refreshActiveTabData() async {
    if (!mounted) {
      return;
    }

    final provider = Provider.of<ClientsProvider>(context, listen: false);
    await provider.refresh();
  }

  Widget _buildPullToRefresh({
    required Widget child,
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator.adaptive(
      color: const Color(0xFF428B7C),
      onRefresh: onRefresh,
      child: child,
    );
  }

  void _switchHomeTab(int index) {
    if (_selectedTab == index) {
      return;
    }

    setState(() {
      _selectedTab = index;
    });

    final provider = Provider.of<ClientsProvider>(context, listen: false);
    unawaited(provider.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final connection = _serviceManager.currentConnection;
    final provider = Provider.of<ClientsProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? colorScheme.surface
                : const Color(0xFF428B7C),
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
                  l10n?.appTitle ?? 'Internet Management',
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
      body: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return Container(
            color: colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                // اطلاعات اتصال
                if (connection != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.router,
                              color: Color(0xFF428B7C),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.routerInfo?['identity'] != null &&
                                            provider.routerInfo!['identity'] !=
                                                'Unknown' &&
                                            provider.routerInfo!['identity']!
                                                .toString()
                                                .isNotEmpty
                                        ? provider.routerInfo!['identity']!
                                        : provider.routerInfo?['board-name'] !=
                                                  null &&
                                              provider.routerInfo!['board-name'] !=
                                                  'Unknown'
                                        ? provider.routerInfo!['board-name']!
                                        : '${connection.host}:${connection.port}',
                                    style: TextStyle(
                                      color: theme.brightness == Brightness.dark
                                          ? colorScheme.onSurface
                                          : Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (provider.routerInfo?['platform'] !=
                                          null &&
                                      provider.routerInfo!['platform'] !=
                                          'Unknown') ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      provider.routerInfo!['platform']!,
                                      style: TextStyle(
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (connection.useSsl) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF428B7C),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SSL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Text(
                              '${l10n?.user ?? 'User'}: ${connection.username}',
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? colorScheme.onSurface.withOpacity(0.7)
                                    : Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            );
                          },
                        ),
                        if (provider.deviceIp != null) ...[
                          const SizedBox(height: 4),
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return Text(
                                '${l10n?.yourDeviceIP ?? 'Your Device IP'}: ${provider.deviceIp}',
                                style: TextStyle(
                                  color: theme.brightness == Brightness.dark
                                      ? colorScheme.onSurface.withOpacity(0.6)
                                      : Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                // Tab Bar و لیست دستگاه‌ها
                Expanded(
                  child: Column(
                    children: [
                      // دکمه قفل اتصال جدید
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: colorScheme.surface,
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    provider.isLoading ||
                                        provider.isLockUpdating
                                    ? null
                                    : () async {
                                        final l10n = AppLocalizations.of(
                                          context,
                                        );
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        final activating =
                                            !provider.isNewConnectionsLocked;
                                        final success = await provider
                                            .toggleNewConnectionsLock();
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              success
                                                  ? (activating
                                                        ? (l10n?.lockNewConnectionsEnabled ??
                                                              'New connections locked')
                                                        : (l10n?.lockNewConnectionsDisabled ??
                                                              'New connections unlocked'))
                                                  : (provider.errorMessage ??
                                                        (l10n?.lockStatusError ??
                                                            'Error changing lock status')),
                                            ),
                                            backgroundColor: success
                                                ? const Color(0xFF428B7C)
                                                : Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                icon: provider.isLockUpdating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        provider.isNewConnectionsLocked
                                            ? Icons.lock
                                            : Icons.lock_open,
                                        size: 20,
                                      ),
                                label: Builder(
                                  builder: (context) {
                                    final l10n = AppLocalizations.of(context);
                                    return Text(
                                      provider.isNewConnectionsLocked
                                          ? (l10n?.lockNewConnectionsActive ??
                                                'Lock New Connections (Active)')
                                          : (l10n?.lockNewConnections ??
                                                'Lock New Connections'),
                                      style: const TextStyle(fontSize: 14),
                                    );
                                  },
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      provider.isNewConnectionsLocked
                                      ? Colors.red.shade600
                                      : (theme.brightness == Brightness.dark
                                            ? colorScheme
                                                  .surfaceContainerHighest
                                            : Colors.grey.shade300),
                                  foregroundColor:
                                      provider.isNewConnectionsLocked
                                      ? Colors.white
                                      : (theme.brightness == Brightness.dark
                                            ? colorScheme.onSurface
                                            : Colors.black87),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Tab Bar
                      Builder(
                        builder: (context) {
                          final theme = Theme.of(context);
                          final colorScheme = theme.colorScheme;

                          return Container(
                            width: double.infinity,
                            color: colorScheme.surface,
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Builder(
                                    builder: (context) {
                                      final l10n = AppLocalizations.of(context);
                                      return _buildTabButton(
                                        title:
                                            l10n?.connectedDevices ??
                                            'Connected Devices',
                                        count: provider.clients.length,
                                        icon: Icons.devices,
                                        isActive: _selectedTab == 0,
                                        onTap: () => _switchHomeTab(0),
                                      );
                                    },
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Builder(
                                    builder: (context) {
                                      final l10n = AppLocalizations.of(context);
                                      return _buildTabButton(
                                        title:
                                            l10n?.bannedDevices ??
                                            'Banned Devices',
                                        count: provider.bannedClients.length,
                                        icon: Icons.block,
                                        isActive: _selectedTab == 1,
                                        onTap: () => _switchHomeTab(1),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // محتوای Tab
                      Expanded(
                        child: _selectedTab == 0
                            ? _buildConnectedDevicesTab(provider)
                            : _buildBannedDevicesTab(provider),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required int count,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final primaryColor = const Color(0xFF428B7C);

        // تشخیص اندازه صفحه برای ریسپانسیو کردن
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360; // برای S8 و صفحه‌های کوچک‌تر

        // تنظیم فونت و آیکون بر اساس اندازه صفحه
        // فقط کمی کوچک‌تر می‌کنیم برای صفحه‌های کوچک (S8)
        final fontSize = isSmallScreen ? 13.0 : 15.0;
        final iconSize = isSmallScreen ? 18.0 : 20.0;
        final padding = isSmallScreen
            ? const EdgeInsets.symmetric(vertical: 12, horizontal: 4)
            : const EdgeInsets.symmetric(vertical: 16);
        final spacing = isSmallScreen ? 6.0 : 8.0;

        return InkWell(
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: isActive
                  ? (theme.brightness == Brightness.dark
                        ? primaryColor.withOpacity(0.2)
                        : primaryColor.withOpacity(0.1))
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: isActive ? primaryColor : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: isActive
                      ? primaryColor
                      : (theme.brightness == Brightness.dark
                            ? colorScheme.onSurface.withOpacity(0.6)
                            : Colors.grey.shade600),
                ),
                SizedBox(width: spacing),
                Flexible(
                  child: Text(
                    '$title ($count)',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive
                          ? primaryColor
                          : (theme.brightness == Brightness.dark
                                ? colorScheme.onSurface.withOpacity(0.6)
                                : Colors.grey.shade600),
                    ),
                    overflow: TextOverflow.visible,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectedDevicesTab(ClientsProvider provider) {
    // نمایش skeleton فقط در حالت initial loading
    if (provider.isLoading && provider.clients.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) {
                return _buildSkeletonCard();
              },
            ),
          ),
        ],
      );
    }

    // اگر در حال progressive loading هستیم و لیست خالی نیست، لیست فعلی را نمایش بده
    // (progressive loading در پس‌زمینه ادامه می‌دهد)

    if (provider.errorMessage != null && provider.clients.isEmpty) {
      return Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.brightness == Brightness.dark
                        ? colorScheme.onSurface.withOpacity(0.6)
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage!,
                    style: TextStyle(
                      color: theme.brightness == Brightness.dark
                          ? colorScheme.onSurface.withOpacity(0.7)
                          : Colors.grey.shade700,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return ElevatedButton.icon(
                        onPressed: () => provider.initialize(),
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n?.retry ?? 'Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF428B7C),
                          foregroundColor: Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (provider.clients.isEmpty) {
      return Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return _buildPullToRefresh(
            onRefresh: provider.refresh,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: theme.brightness == Brightness.dark
                              ? colorScheme.onSurface.withOpacity(0.4)
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Text(
                              l10n?.noConnectedDevices ??
                                  'No connected devices found',
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? colorScheme.onSurface.withOpacity(0.6)
                                    : Colors.grey.shade600,
                                fontSize: 18,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return _buildPullToRefresh(
      onRefresh: provider.refresh,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: provider.clients.length,
        itemBuilder: (context, index) {
          final client = provider.clients[index];
          return _buildClientCard(context, client, provider.deviceIp, provider);
        },
      ),
    );
  }

  /// ساخت کارت اسکلتون برای نمایش در حالت بارگذاری
  Widget _buildSkeletonCard() {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.brightness == Brightness.dark
                    ? colorScheme.outline.withOpacity(0.2)
                    : Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // آیکون اسکلتون
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? colorScheme.onSurface.withOpacity(0.1)
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              // متن اسکلتون
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? colorScheme.onSurface.withOpacity(0.1)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 150,
                      height: 12,
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? colorScheme.onSurface.withOpacity(0.1)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBannedDevicesTab(ClientsProvider provider) {
    if (provider.bannedClients.isEmpty) {
      return _buildPullToRefresh(
        onRefresh: provider.refresh,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.block_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)?.noBannedDevices ??
                          'No banned devices found',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildPullToRefresh(
      onRefresh: provider.refresh,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: provider.bannedClients.length,
        itemBuilder: (context, index) {
          final banned = provider.bannedClients[index];
          return _buildBannedClientCard(banned);
        },
      ),
    );
  }

  Widget _buildBannedClientCard(Map<String, dynamic> banned) {
    final ipAddress = banned['address']?.toString();
    final macAddress = banned['mac_address']?.toString();
    final hostName = banned['host_name'] ?? banned['hostname'];

    // ساخت ClientInfo از banned device
    final bannedDevice = ClientInfo(
      type: 'banned',
      source: 'banned',
      ipAddress: ipAddress,
      macAddress: macAddress,
      hostName: hostName?.toString(),
      rawData: banned,
    );

    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Material(
          color: colorScheme.surface,
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/device-detail',
                arguments: {
                  'device': bannedDevice,
                  'isCurrentDevice': false,
                  'isBanned': true,
                },
              );
            },
            splashColor: Colors.red.withOpacity(0.1),
            highlightColor: Colors.red.withOpacity(0.05),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.brightness == Brightness.dark
                        ? colorScheme.outline.withOpacity(0.2)
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // آیکون مسدود شده
                  CircleAvatar(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    child: const Icon(Icons.block, color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 16),
                  // اطلاعات دستگاه
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                hostName ??
                                    ipAddress ??
                                    AppLocalizations.of(
                                      context,
                                    )?.bannedDevice ??
                                    'Banned Device',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                AppLocalizations.of(context)?.banned ??
                                    'Banned',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (ipAddress != null && ipAddress.isNotEmpty)
                          Text(
                            'IP: $ipAddress',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.brightness == Brightness.dark
                                  ? colorScheme.onSurface.withOpacity(0.7)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        if (macAddress != null && macAddress.isNotEmpty)
                          Text(
                            'MAC: $macAddress',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.brightness == Brightness.dark
                                  ? colorScheme.onSurface.withOpacity(0.6)
                                  : Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // دکمه رفع مسدودیت سریع
                  Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return IconButton(
                        icon: const Icon(Icons.lock_open, color: Colors.green),
                        tooltip: l10n?.unbanDeviceTooltip ?? 'Unban Device',
                        onPressed: () async {
                          if (ipAddress == null) return;

                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: colorScheme.surface,
                              title: Text(
                                l10n?.unbanDeviceTitle ?? 'Unban Device',
                                style: TextStyle(color: colorScheme.onSurface),
                              ),
                              content: Text(
                                l10n?.unbanDeviceConfirmTextWithIP(ipAddress) ??
                                    'Are you sure you want to unban device $ipAddress?',
                                style: TextStyle(color: colorScheme.onSurface),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(
                                    l10n?.cancel ?? 'Cancel',
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(l10n?.unban ?? 'Unban'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            try {
                              final provider = Provider.of<ClientsProvider>(
                                context,
                                listen: false,
                              );
                              final success = await provider.unbanClient(
                                ipAddress,
                                macAddress: macAddress,
                                hostname: hostName?.toString(),
                                ssid: banned['ssid']?.toString(),
                              );

                              if (mounted) {
                                final l10n = AppLocalizations.of(context);
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 8),
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
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                  await provider.refresh();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${l10n?.error ?? 'Error'}: ${provider.errorMessage ?? (l10n?.errorUnbanning ?? 'Error unbanning device')}',
                                      ),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                final l10n = AppLocalizations.of(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${l10n?.error ?? 'Error'}: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ); // 结束 return IconButton
                    },
                  ),
                  const SizedBox(width: 4),
                  Builder(
                    builder: (context) {
                      final theme = Theme.of(context);
                      final colorScheme = theme.colorScheme;

                      return Icon(
                        Icons.chevron_right,
                        color: theme.brightness == Brightness.dark
                            ? colorScheme.onSurface.withOpacity(0.4)
                            : Colors.grey,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClientCard(
    BuildContext context,
    ClientInfo client,
    String? deviceIp,
    ClientsProvider provider,
  ) {
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    final bool isCurrentDevice =
        deviceIp != null && client.ipAddress == deviceIp;

    switch (client.type) {
      case 'wireless':
        typeColor = Colors.green;
        typeIcon = Icons.wifi;
        typeLabel = 'Wireless';
        break;
      case 'dhcp':
        typeColor = Colors.orange;
        typeIcon = Icons.lan;
        typeLabel = 'DHCP';
        break;
      case 'hotspot':
        typeColor = Colors.purple;
        typeIcon = Icons.router;
        typeLabel = 'Hotspot';
        break;
      case 'ppp':
        typeColor = Colors.blue;
        typeIcon = Icons.phone;
        typeLabel = 'PPP';
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.device_unknown;
        typeLabel = AppLocalizations.of(context)?.unknown ?? 'Unknown';
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isStatic = _isStaticDevice(client);
    final isPendingApproval = provider.isDevicePendingApproval(
      client,
      isCurrentDevice: isCurrentDevice,
    );
    final isApprovalBusy = provider.isApprovalActionInProgress(client);

    Future<void> openDeviceDetail() async {
      final refreshRequested = await Navigator.pushNamed(
        context,
        '/device-detail',
        arguments: {'device': client, 'isCurrentDevice': isCurrentDevice},
      );

      if (!mounted || refreshRequested != true) {
        return;
      }

      await provider.refresh();
    }

    Future<void> runPendingAction({required bool approve}) async {
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final success = approve
          ? await provider.approveDevice(client)
          : await provider.rejectDevice(client);
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (approve
                      ? (l10n?.deviceApproved ?? 'Device approved')
                      : (l10n?.deviceRejected ?? 'Device rejected'))
                : (provider.errorMessage ??
                      (approve
                          ? (l10n?.approveError ?? 'Error approving device')
                          : (l10n?.rejectError ?? 'Error rejecting device'))),
          ),
          backgroundColor: success
              ? (approve ? const Color(0xFF428B7C) : Colors.red)
              : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    Widget pendingActionButton({
      required bool approve,
      required String label,
      required IconData icon,
    }) {
      final color = approve ? const Color(0xFF428B7C) : Colors.red.shade600;
      return SizedBox(
        height: 38,
        child: ElevatedButton.icon(
          onPressed: isApprovalBusy
              ? null
              : () => runPendingAction(approve: approve),
          icon: isApprovalBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withOpacity(0.45),
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    Widget pendingApprovalPanel() {
      final l10n = AppLocalizations.of(context);
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final approveButton = pendingActionButton(
              approve: true,
              label: l10n?.approve ?? 'Approve',
              icon: Icons.check_circle,
            );
            final rejectButton = pendingActionButton(
              approve: false,
              label: l10n?.reject ?? 'Reject',
              icon: Icons.block,
            );

            if (constraints.maxWidth < 280) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  approveButton,
                  const SizedBox(height: 8),
                  rejectButton,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: approveButton),
                const SizedBox(width: 8),
                Expanded(child: rejectButton),
              ],
            );
          },
        ),
      );
    }

    return Material(
      color: colorScheme.surface,
      child: InkWell(
        onTap: isPendingApproval ? null : openDeviceDetail,
        splashColor: const Color(0xFF428B7C).withOpacity(0.1),
        highlightColor: const Color(0xFF428B7C).withOpacity(0.05),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.brightness == Brightness.dark
                    ? colorScheme.outline.withOpacity(0.2)
                    : Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: isCurrentDevice
                        ? const Color(0xFF428B7C).withOpacity(0.2)
                        : typeColor.withOpacity(0.2),
                    child: Icon(
                      typeIcon,
                      color: isCurrentDevice
                          ? const Color(0xFF428B7C)
                          : typeColor,
                      size: 24,
                    ),
                  ),
                  if (isCurrentDevice)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF428B7C),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDeviceDisplayName(client),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isCurrentDevice
                            ? const Color(0xFF428B7C)
                            : colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isStatic) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF428B7C).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF428B7C),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock,
                                  size: 12,
                                  color: Color(0xFF428B7C),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Static',
                                  style: TextStyle(
                                    color: Color(0xFF428B7C),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isPendingApproval) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.pending_actions,
                                  size: 12,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  AppLocalizations.of(
                                        context,
                                      )?.pendingApproval ??
                                      'Pending Approval',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    if (client.ipAddress != null)
                      Text(
                        'IP: ${client.ipAddress}',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.brightness == Brightness.dark
                              ? colorScheme.onSurface.withOpacity(0.7)
                              : Colors.grey.shade600,
                        ),
                      ),
                    if (client.macAddress != null)
                      Text(
                        'MAC: ${client.macAddress}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.brightness == Brightness.dark
                              ? colorScheme.onSurface.withOpacity(0.6)
                              : Colors.grey.shade500,
                        ),
                      ),
                    if (isPendingApproval) pendingApprovalPanel(),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isPendingApproval) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: theme.brightness == Brightness.dark
                          ? colorScheme.onSurface.withOpacity(0.4)
                          : Colors.grey,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isStaticDevice(ClientInfo client) {
    // 1. بررسی مستقیم isStaticLease
    if (client.isStaticLease == true) {
      return true;
    }

    // 2. اگر isStaticLease null است، از rawData  بررسی کن
    if (client.isStaticLease == null && client.rawData.isNotEmpty) {
      if (client.rawData.containsKey('dynamic')) {
        final dynamicValue = client.rawData['dynamic']
            ?.toString()
            .toLowerCase();
        if (dynamicValue == 'false' || dynamicValue == 'no') {
          return true; // Static
        }
      }
    }

    return false;
  }

  String _getDeviceDisplayName(ClientInfo client) {
    // اولویت: hostName > user > name > IP > MAC
    if (client.hostName != null && client.hostName!.isNotEmpty) {
      return client.hostName!;
    }
    if (client.user != null && client.user!.isNotEmpty) {
      return client.user!;
    }
    if (client.name != null && client.name!.isNotEmpty) {
      return client.name!;
    }
    if (client.ipAddress != null && client.ipAddress!.isNotEmpty) {
      return '${AppLocalizations.of(context)?.device ?? 'Device'} ${client.ipAddress}';
    }
    if (client.macAddress != null && client.macAddress!.isNotEmpty) {
      return '${AppLocalizations.of(context)?.device ?? 'Device'} ${client.macAddress}';
    }
    return AppLocalizations.of(context)?.unknownDevice ?? 'Unknown Device';
  }
}
