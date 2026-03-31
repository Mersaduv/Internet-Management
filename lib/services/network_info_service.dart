import 'dart:io';
import 'mikrotik_service_manager.dart';
import 'settings_service.dart';

/// سرویس برای دریافت اطلاعات شبکه دستگاه (IPv4 Address و Default Gateway)
class NetworkInfoService {
  static final NetworkInfoService _instance = NetworkInfoService._internal();
  factory NetworkInfoService() => _instance;
  NetworkInfoService._internal();
  
  final SettingsService _settingsService = SettingsService();

  /// دریافت IPv4 Address دستگاه از NetworkInterface
  /// این متد IP محلی دستگاه را از interface های فعال برمی‌گرداند
  Future<String?> getDeviceIPv4Address() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            final ip = addr.address;
            // بررسی اینکه آیا IP در subnet محلی است (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
            final parts = ip.split('.');
            if (parts.length == 4) {
              final firstOctet = int.tryParse(parts[0]);
              if (firstOctet != null) {
                if ((firstOctet == 192 && int.tryParse(parts[1]) == 168) ||
                    firstOctet == 10 ||
                    (firstOctet == 172 &&
                        int.tryParse(parts[1]) != null &&
                        int.tryParse(parts[1])! >= 16 &&
                        int.tryParse(parts[1])! <= 31)) {
                  return ip;
                }
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// دریافت Default Gateway از RouterOS API
  /// این متد از MikroTikServiceManager استفاده می‌کند
  /// اگر اتصال به RouterOS برقرار باشد، gateway را از route table می‌گیرد
  Future<String?> getDefaultGateway() async {
    try {
      final serviceManager = MikroTikServiceManager();
      if (serviceManager.isConnected) {
        // استفاده از RouterOS API برای دریافت gateway
        return await serviceManager.getDefaultGateway();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// دریافت Default Gateway یا IP روتر (fallback)
  /// این متد به ترتیب از روش‌های زیر استفاده می‌کند:
  /// 1. RouterOS API (اگر متصل باشد) - دقیق‌ترین روش
  /// 2. حدس زدن gateway از IP دستگاه (اولین IP در subnet) - معمولاً دقیق است
  /// 3. IP روتر از تنظیمات (fallback آخر) - ممکن است با gateway واقعی متفاوت باشد
  Future<String?> getDefaultGatewayOrRouterIp() async {
    try {
      final serviceManager = MikroTikServiceManager();
      
      // روش 1: استفاده از RouterOS API (اگر متصل باشد) - دقیق‌ترین روش
      if (serviceManager.isConnected) {
        final gateway = await serviceManager.getDefaultGatewayOrRouterIp();
        if (gateway != null) {
          return gateway;
        }
      }
      
      // روش 2: حدس زدن gateway از IP دستگاه (اولین IP در subnet)
      // معمولاً gateway اولین IP در subnet است (مثلاً 172.16.0.1 برای 172.16.0.241)
      // این روش معمولاً دقیق‌تر از IP روتر در تنظیمات است
      final deviceIp = await getDeviceIPv4Address();
      if (deviceIp != null) {
        final parts = deviceIp.split('.');
        if (parts.length == 4) {
          // ساخت gateway با استفاده از اولین IP در subnet
          final guessedGateway = '${parts[0]}.${parts[1]}.${parts[2]}.1';
          
          // همیشه از gateway حدس زده شده استفاده کن (معمولاً gateway .1 است)
          // این دقیق‌ترین روش است چون gateway معمولاً اولین IP در subnet است
          return guessedGateway;
        }
      }
      
      // روش 3: استفاده از IP روتر از تنظیمات (fallback آخر)
      try {
        final settings = await _settingsService.getAllSettings();
        final routerHost = settings['host'] as String?;
        if (routerHost != null && routerHost.isNotEmpty) {
          return routerHost;
        }
      } catch (e) {
        // ignore
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// دریافت همه اطلاعات شبکه (IPv4 Address و Default Gateway)
  /// این متد هم IP دستگاه و هم gateway را برمی‌گرداند
  Future<Map<String, String?>> getNetworkInfo() async {
    final deviceIp = await getDeviceIPv4Address();
    final gateway = await getDefaultGatewayOrRouterIp();

    return {
      'deviceIp': deviceIp,
      'defaultGateway': gateway,
    };
  }
}
