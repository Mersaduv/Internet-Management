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
import 'models/client_info.dart';
import 'providers/clients_provider.dart';
import 'utils/app_localizations.dart';

// 全局回调函数，用于从子组件通知主应用更改语言
Function(Locale)? onLanguageChanged;

// 全局回调函数，用于从子组件通知主应用更改主题
Function(ThemeMode)? onThemeChanged;

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
            child: CircularProgressIndicator(
              color: const Color(0xFF428B7C),
            ),
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
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginScreen(),
          '/home': (context) => const MainScaffold(),
          '/test': (context) => const ConnectionTestScreen(),
          '/device-detail': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return DeviceDetailScreen(
              device: args['device'] as ClientInfo,
              isCurrentDevice: args['isCurrentDevice'] as bool? ?? false,
              isBanned: args['isBanned'] as bool? ?? false,
            );
          },
        },
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.0),
            ),
            child: child!,
          );
        },
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
  }

  /// بررسی انقضای لاگین
  Future<void> _checkLoginExpiration() async {
    final isExpired = await _settingsService.isLoginExpired();
    if (isExpired && mounted) {
      // اگر لاگین منقضی شده باشد، به صفحه ورود هدایت کن
      final provider = Provider.of<ClientsProvider>(context, listen: false);
      provider.clear();
      _serviceManager.disconnect();
      await _settingsService.clearLoginTimestamp();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
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
          color: isActive
              ? const Color(0xFF428B7C)
              : Colors.grey.shade600,
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

class _HomePageState extends State<HomePage> {
  final MikroTikServiceManager _serviceManager = MikroTikServiceManager();
  int _selectedTab = 0; // 0: متصل, 1: مسدود

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
                                provider.routerInfo?['board-name'] != null && 
                                provider.routerInfo!['board-name'] != 'Unknown'
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
                              if (provider.routerInfo?['board-name'] != null && 
                                  provider.routerInfo!['board-name'] != 'Unknown' &&
                                  provider.routerInfo?['platform'] != null &&
                                  provider.routerInfo!['platform'] != 'Unknown') ...[
                                const SizedBox(height: 2),
                                Text(
                                  provider.routerInfo!['platform']!,
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.6),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: colorScheme.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: provider.isLoading
                                ? null
                                : () async {
                                    // 切换锁定状态
                                    final currentState = provider.isNewConnectionsLocked;
                                    final success = currentState
                                        ? await provider.unlockNewConnections()
                                        : await provider.lockNewConnections();
                                    
                                    if (mounted) {
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(
                                                  currentState ? Icons.lock_open : Icons.lock,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Builder(
                                                    builder: (context) {
                                                      final l10n = AppLocalizations.of(context);
                                                      return Text(
                                                        currentState
                                                            ? (l10n?.lockNewConnectionsDisabled ?? 'Lock disabled')
                                                            : (l10n?.lockNewConnectionsEnabled ?? 'Lock enabled'),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: currentState ? Colors.green : Colors.orange,
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                        // 刷新客户端列表以应用新的锁定状态
                                        provider.refresh();
                                      } else {
                                        final l10n = AppLocalizations.of(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${l10n?.error ?? 'Error'}: ${provider.errorMessage ?? (l10n?.lockStatusError ?? 'Error changing lock status')}',
                                            ),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: Icon(
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
                                      ? (l10n?.lockNewConnectionsActive ?? 'Lock New Connections (Active)')
                                      : (l10n?.lockNewConnections ?? 'Lock New Connections'),
                                  style: const TextStyle(fontSize: 14),
                                );
                              },
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: provider.isNewConnectionsLocked
                                  ? (theme.brightness == Brightness.dark
                                      ? Colors.orange.shade800
                                      : Colors.orange)
                                  : (theme.brightness == Brightness.dark
                                      ? colorScheme.surfaceContainerHighest
                                      : Colors.grey.shade300),
                              foregroundColor: provider.isNewConnectionsLocked
                                  ? Colors.white
                                  : (theme.brightness == Brightness.dark
                                      ? colorScheme.onSurface
                                      : Colors.black87),
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return _buildTabButton(
                                title: l10n?.connectedDevices ?? 'Connected Devices',
                                count: provider.clients.length,
                                icon: Icons.devices,
                                isActive: _selectedTab == 0,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 0;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return _buildTabButton(
                                title: l10n?.bannedDevices ?? 'Banned Devices',
                                count: provider.bannedClients.length,
                                icon: Icons.block,
                                isActive: _selectedTab == 1,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 1;
                                  });
                                  provider.loadBannedClients();
                                },
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
        
        return InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
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
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive 
                      ? primaryColor
                      : (theme.brightness == Brightness.dark
                          ? colorScheme.onSurface.withOpacity(0.6)
                          : Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                Text(
                  '$title ($count)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive 
                        ? primaryColor
                        : (theme.brightness == Brightness.dark
                            ? colorScheme.onSurface.withOpacity(0.6)
                            : Colors.grey.shade600),
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
    if (provider.isLoading || !provider.isDataComplete) {
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

    if (provider.errorMessage != null) {
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
                        onPressed: () => provider.loadClients(),
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
          
          return Center(
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
                      l10n?.noConnectedDevices ?? 'No connected devices found',
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
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      color: const Color(0xFF428B7C),
      child: ListView.builder(
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
      return Center(
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
              AppLocalizations.of(context)?.noBannedDevices ?? 'No banned devices found',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadBannedClients(),
      color: const Color(0xFF428B7C),
      child: ListView.builder(
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
                    child: const Icon(
                      Icons.block,
                      color: Colors.red,
                      size: 24,
                    ),
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
                                hostName ?? ipAddress ?? AppLocalizations.of(context)?.bannedDevice ?? 'Banned Device',
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
                                AppLocalizations.of(context)?.banned ?? 'Banned',
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
                        // نمایش نوع مسدودیت (Auto-banned یا Manual)
                        if (banned['comment'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  banned['comment'].toString().contains('Auto-banned: New connection while locked')
                                      ? Icons.auto_fix_high
                                      : Icons.block,
                                  size: 14,
                                  color: banned['comment'].toString().contains('Auto-banned: New connection while locked')
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Builder(
                                  builder: (context) {
                                    final l10n = AppLocalizations.of(context);
                                    final isAutoBanned = banned['comment'].toString().contains('Auto-banned: New connection while locked');
                                    return Text(
                                      isAutoBanned
                                          ? (l10n?.autoBanned ?? 'Auto-banned (New connection lock)')
                                          : (l10n?.manualBanned ?? 'Manual Ban'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isAutoBanned
                                            ? Colors.orange.shade700
                                            : Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
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
                            l10n?.unbanDeviceConfirmTextWithIP(ipAddress!) ?? 'Are you sure you want to unban device $ipAddress?',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                l10n?.cancel ?? 'Cancel',
                                style: TextStyle(color: colorScheme.primary),
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
                      final provider = Provider.of<ClientsProvider>(context, listen: false);
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
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(l10n?.deviceUnbannedSuccess ?? 'Device unbanned successfully'),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 3),
                            ),
                          );
                          // به‌روزرسانی لیست
                          provider.loadBannedClients();
                          // هدایت به صفحه اصلی
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/home',
                                (route) => false,
                              );
                            }
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${l10n?.error ?? 'Error'}: ${provider.errorMessage ?? (l10n?.errorUnbanning ?? 'Error unbanning device')}'),
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
                            content: Text('${l10n?.error ?? 'Error'}: $e'),
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

  Widget _buildClientCard(BuildContext context, ClientInfo client, String? deviceIp, ClientsProvider provider) {
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    final bool isCurrentDevice = deviceIp != null && client.ipAddress == deviceIp;

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
    return Material(
      color: theme.colorScheme.surface,
      child: FutureBuilder<bool>(
        future: provider.isDeviceAllowed(client.macAddress, client.ipAddress, client: client),
        builder: (context, snapshot) {
          final isAllowed = snapshot.hasData && snapshot.data == true;
          
          // 如果设备未被允许且不是 static 设备，禁用点击
          final shouldDisableClick = provider.isNewConnectionsLocked && 
                                     !_isStaticDevice(client) && 
                                     !isCurrentDevice && 
                                     !isAllowed;
          
          return GestureDetector(
            onTap: shouldDisableClick ? null : () {
              Navigator.pushNamed(
                context,
                '/device-detail',
                arguments: {
                  'device': client,
                  'isCurrentDevice': isCurrentDevice,
                },
              );
            },
            onLongPress: () {
              // نمایش منوی dropdown
              _showDeviceContextMenu(context, client, provider, isCurrentDevice);
            },
            child: InkWell(
              onTap: shouldDisableClick ? null : () {
                Navigator.pushNamed(
                  context,
                  '/device-detail',
                  arguments: {
                    'device': client,
                    'isCurrentDevice': isCurrentDevice,
                  },
                );
              },
              splashColor: shouldDisableClick ? Colors.transparent : const Color(0xFF428B7C).withOpacity(0.1),
              highlightColor: shouldDisableClick ? Colors.transparent : const Color(0xFF428B7C).withOpacity(0.05),
              child: Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  final colorScheme = theme.colorScheme;
                  
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 1),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                  children: [
                    // آیکون دستگاه
                    Opacity(
                      opacity: shouldDisableClick ? 0.6 : 1.0,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: isCurrentDevice
                                ? const Color(0xFF428B7C).withOpacity(0.2)
                                : typeColor.withOpacity(0.2),
                            child: Icon(
                              typeIcon,
                              color: isCurrentDevice ? const Color(0xFF428B7C) : typeColor,
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
                    ),
                    const SizedBox(width: 16),
                    // اطلاعات دستگاه
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 设备名称 - 单独一行，完整显示
                          Opacity(
                            opacity: shouldDisableClick ? 0.6 : 1.0,
                            child: Builder(
                              builder: (context) {
                                final theme = Theme.of(context);
                                final colorScheme = theme.colorScheme;
                                
                                return Text(
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
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Badge 行
                          Opacity(
                            opacity: shouldDisableClick ? 0.6 : 1.0,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                // Static Lease Badge
                                if (_isStaticDevice(client))
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
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lock,
                                          size: 12,
                                          color: const Color(0xFF428B7C),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Static',
                                          style: TextStyle(
                                            color: const Color(0xFF428B7C),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Pending Approval Badge - 显示新设备待批准状态
                                if (!_isStaticDevice(client) && !isCurrentDevice)
                                  FutureBuilder<bool>(
                                    key: ValueKey('pending_${client.macAddress}_${client.ipAddress}'),
                                    future: provider.isDevicePendingApproval(client.macAddress, client.ipAddress, client: client),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const SizedBox.shrink();
                                      }
                                      
                                      final isPending = snapshot.hasData && snapshot.data == true;
                                      
                                      if (!isPending) {
                                        return const SizedBox.shrink();
                                      }
                                      
                                      return Container(
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
                                            Icon(
                                              Icons.pending,
                                              size: 12,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 3),
                                            Builder(
                                              builder: (context) {
                                                final l10n = AppLocalizations.of(context);
                                                return Text(
                                                  l10n?.pendingApproval ?? 'Pending Approval',
                                                  style: TextStyle(
                                                    color: Colors.orange,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                // Lock New Connections Pending Badge (原有逻辑保留)
                                if (provider.isNewConnectionsLocked && 
                                    !_isStaticDevice(client) && 
                                    !isCurrentDevice)
                                  FutureBuilder<bool>(
                                    key: ValueKey('allowed_${client.macAddress}_${client.ipAddress}'),
                                    future: provider.isDeviceAllowed(client.macAddress, client.ipAddress),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting || 
                                          (snapshot.hasData && snapshot.data == true)) {
                                        return const SizedBox.shrink();
                                      }
                                      
                                      // 检查是否已经显示新设备待批准badge
                                      return FutureBuilder<bool>(
                                        future: provider.isDevicePendingApproval(client.macAddress, client.ipAddress),
                                        builder: (context, pendingSnapshot) {
                                          // 如果已经显示新设备待批准badge，不显示这个
                                          if (pendingSnapshot.hasData && pendingSnapshot.data == true) {
                                            return const SizedBox.shrink();
                                          }
                                          
                                          return Container(
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
                                                Icon(
                                                  Icons.pending,
                                                  size: 12,
                                                  color: Colors.orange,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Pending',
                                                  style: TextStyle(
                                                    color: Colors.orange,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                // Current Device Badge
                                if (isCurrentDevice)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF428B7C),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      AppLocalizations.of(context)?.you ?? 'You',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Opacity(
                            opacity: shouldDisableClick ? 0.6 : 1.0,
                            child: Builder(
                              builder: (context) {
                                final theme = Theme.of(context);
                                final colorScheme = theme.colorScheme;
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                  ],
                                );
                              },
                            ),
                          ),
                          // Approve/Reject 按钮 - 显示在设备名称下方（不受Opacity影响）
                          FutureBuilder<bool>(
                            future: provider.isDevicePendingApproval(client.macAddress, client.ipAddress, client: client),
                            builder: (context, pendingSnapshot) {
                              final isPendingApproval = pendingSnapshot.hasData && pendingSnapshot.data == true;
                              final isLoadingPending = pendingSnapshot.connectionState == ConnectionState.waiting;
                              
                              // 如果设备待批准，显示 approve/reject 按钮
                              if (isPendingApproval) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      // Approve 按钮
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: isLoadingPending ? null : () async {
                                            if (client.macAddress == null) return;
                                            
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (dialogContext) {
                                                final theme = Theme.of(dialogContext);
                                                final colorScheme = theme.colorScheme;
                                                
                                                final l10n = AppLocalizations.of(dialogContext);
                                                final deviceName = client.hostName ?? client.ipAddress ?? (l10n?.unknownDevice ?? 'Unknown');
                                                return AlertDialog(
                                                  backgroundColor: colorScheme.surface,
                                                  title: Text(
                                                    l10n?.approveDevice ?? 'Approve Device',
                                                    style: TextStyle(color: colorScheme.onSurface),
                                                  ),
                                                  content: Text(
                                                    l10n?.approveDeviceConfirmWithDevice(deviceName) ?? 'Do you want to approve device "$deviceName"?\n\nThis device will be able to connect to the network and use the internet.',
                                                    style: TextStyle(color: colorScheme.onSurface),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(dialogContext, false),
                                                      child: Text(
                                                        l10n?.cancel ?? 'Cancel',
                                                        style: TextStyle(color: colorScheme.primary),
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(dialogContext, true),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.green,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                      child: Text(l10n?.approve ?? 'Approve'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );

                                            if (confirmed == true && mounted) {
                                              try {
                                                final success = await provider.approveDevice(
                                                  client.macAddress!,
                                                  ipAddress: client.ipAddress,
                                                );
                                                
                                                if (mounted) {
                                                  final l10n = AppLocalizations.of(context);
                                                  if (success) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Row(
                                                          children: [
                                                            Icon(Icons.check_circle, color: Colors.white),
                                                            SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(l10n?.deviceApproved ?? 'Device approved successfully'),
                                                            ),
                                                          ],
                                                        ),
                                                        backgroundColor: Colors.green,
                                                        behavior: SnackBarBehavior.floating,
                                                        duration: Duration(seconds: 3),
                                                      ),
                                                    );
                                                    provider.refresh();
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('${l10n?.error ?? 'Error'}: ${provider.errorMessage ?? (l10n?.approveError ?? 'Error approving device')}'),
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
                                                      content: Text('${l10n?.error ?? 'Error'}: $e'),
                                                      backgroundColor: Colors.red,
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                          icon: const Icon(Icons.check_circle, size: 20),
                                          label: Builder(
                                            builder: (context) {
                                              final l10n = AppLocalizations.of(context);
                                              return Text(l10n?.approve ?? 'Approve');
                                            },
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Reject 按钮
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: isLoadingPending ? null : () async {
                                            if (client.macAddress == null) return;
                                            
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (context) {
                                                final l10n = AppLocalizations.of(context);
                                                final deviceName = client.hostName ?? client.ipAddress ?? (l10n?.unknownDevice ?? 'Unknown');
                                                return AlertDialog(
                                                  title: Text(l10n?.rejectDevice ?? 'Reject Device'),
                                                  content: Text(
                                                    l10n?.rejectDeviceConfirmWithDevice(deviceName) ?? 'Do you want to reject device "$deviceName"?\n\nThis device will be banned and removed from the network.',
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
                                                      child: Text(l10n?.reject ?? 'Reject'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );

                                            if (confirmed == true && mounted) {
                                              try {
                                                final success = await provider.rejectDevice(
                                                  client.macAddress!,
                                                  ipAddress: client.ipAddress,
                                                );
                                                
                                                if (mounted) {
                                                  final l10n = AppLocalizations.of(context);
                                                  if (success) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Row(
                                                          children: [
                                                            Icon(Icons.cancel, color: Colors.white),
                                                            SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(l10n?.deviceRejected ?? 'Device rejected and banned'),
                                                            ),
                                                          ],
                                                        ),
                                                        backgroundColor: Colors.orange,
                                                        behavior: SnackBarBehavior.floating,
                                                        duration: Duration(seconds: 3),
                                                      ),
                                                    );
                                                    provider.refresh();
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('${l10n?.error ?? 'Error'}: ${provider.errorMessage ?? (l10n?.rejectError ?? 'Error rejecting device')}'),
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
                                                      content: Text('${l10n?.error ?? 'Error'}: $e'),
                                                      backgroundColor: Colors.red,
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                          icon: const Icon(Icons.cancel, size: 20),
                                          label: Builder(
                                            builder: (context) {
                                              final l10n = AppLocalizations.of(context);
                                              return Text(l10n?.reject ?? 'Reject');
                                            },
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              // 不再显示重复的批准/拒绝按钮
                              // 只使用上面的 isDevicePendingApproval() 逻辑
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                    // نوع دستگاه (只在设备已批准时显示)
                    Opacity(
                      opacity: shouldDisableClick ? 0.6 : 1.0,
                      child:                           FutureBuilder<bool>(
                            future: provider.isDeviceAllowed(client.macAddress, client.ipAddress, client: client),
                        builder: (context, snapshot) {
                          final isAllowed = snapshot.hasData && snapshot.data == true;
                          
                          // 如果设备未被允许且不是 static 设备，不显示类型标签
                          final shouldShowButtons = provider.isNewConnectionsLocked && 
                                                    !_isStaticDevice(client) && 
                                                    !isCurrentDevice && 
                                                    !isAllowed;
                          
                          if (shouldShowButtons) {
                            return const SizedBox.shrink();
                          }
                          
                          // 如果设备已被允许或是 static 设备，显示类型标签
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              const SizedBox(width: 8),
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
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  ),
    );
  }

  /// نمایش منوی context برای دستگاه
  void _showDeviceContextMenu(BuildContext context, ClientInfo client, ClientsProvider provider, bool isCurrentDevice) async {
    // بررسی اینکه آیا دستگاه در لیست مجاز است
    final isAllowed = await provider.isDeviceAllowed(client.macAddress, client.ipAddress);
    
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    if (button == null) return;
    
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final String? value = await showMenu<String>(
      context: context,
      position: position,
      items: [
        // اگر设备在允许列表中，显示"从允许列表删除"
        if (provider.isNewConnectionsLocked && !isCurrentDevice && isAllowed)
          const PopupMenuItem<String>(
            value: 'remove_from_allowed',
            child: Row(
              children: [
                Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                SizedBox(width: 12),
                Text('Remove from Allowed List'),
              ],
            ),
          ),
        // 如果设备不在允许列表中且不是 static，显示"添加到允许列表"
        if (provider.isNewConnectionsLocked && 
            !_isStaticDevice(client) && 
            !isCurrentDevice &&
            !isAllowed)
          const PopupMenuItem<String>(
            value: 'add_to_allowed',
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                SizedBox(width: 12),
                Text('Add to Allowed List'),
              ],
            ),
          ),
      ],
    );

    if (value == null) return;

    if (value == 'remove_from_allowed') {
      // 从允许列表中删除
      if (client.macAddress == null) return;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final colorScheme = theme.colorScheme;
          
          return AlertDialog(
            backgroundColor: colorScheme.surface,
            title: Text(
              'Remove from Allowed List',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            content: Text(
              'Are you sure you want to remove device ${client.hostName ?? client.ipAddress ?? "Unknown"} from the allowed list?',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Remove'),
              ),
            ],
          );
        },
      );

      if (confirmed == true && mounted) {
        try {
          final success = await provider.removeFromAllowedList(
            client.macAddress!,
            ipAddress: client.ipAddress,
          );
          
          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Device has been removed from allowed list'),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 3),
                ),
              );
              // 更新列表
              provider.refresh();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('خطا: ${provider.errorMessage ?? "خطا در حذف از لیست مجاز"}'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('خطا: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } else if (value == 'add_to_allowed') {
      // 添加到允许列表
      if (client.macAddress == null) return;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final colorScheme = theme.colorScheme;
          
          return AlertDialog(
            backgroundColor: colorScheme.surface,
            title: Text(
              'Add to Allowed List',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            content: Text(
              'Allow device ${client.hostName ?? client.ipAddress ?? "Unknown"} to fully connect to WiFi?',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Allow'),
              ),
            ],
          );
        },
      );

      if (confirmed == true && mounted) {
        try {
          final success = await provider.allowNonStaticDevice(
            client.macAddress!,
            ipAddress: client.ipAddress,
          );
          
          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Device has been allowed access and can now fully connect to WiFi'),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 3),
                ),
              );
              // 更新列表
              provider.refresh();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('خطا: ${provider.errorMessage ?? "خطا در اجازه دادن به دستگاه"}'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('خطا: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    }
  }

  /// بررسی اینکه آیا دستگاه Static است
  /// بررسی هم از isStaticLease و هم از rawData
  bool _isStaticDevice(ClientInfo client) {
    // 1. بررسی مستقیم isStaticLease
    if (client.isStaticLease == true) {
      return true;
    }
    
    // 2. اگر isStaticLease null است، از rawData  بررسی کن
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
