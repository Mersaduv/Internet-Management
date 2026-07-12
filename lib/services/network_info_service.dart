import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:network_info_plus/network_info_plus.dart';

import 'mikrotik_service_manager.dart';

/// منبع تشخیص Default Gateway دستگاه (کلاینت)
enum DeviceGatewaySource {
  /// جدول مسیریابی / DHCP سیستم‌عامل (دقیق برای هر subnet)
  system,

  /// تشخیص ممکن نبود (مثلاً Web یا محدودیت پلتفرم)
  unavailable,
}

/// نتیجهٔ تشخیص gateway اینترنت دستگاه
class DeviceGatewayDiscovery {
  const DeviceGatewayDiscovery({this.ip, required this.source});

  final String? ip;
  final DeviceGatewaySource source;

  bool get found => ip != null && ip!.isNotEmpty;
}

/// سرویس برای دریافت اطلاعات شبکه دستگاه (IPv4 Address و Default Gateway)
class NetworkInfoService {
  static final NetworkInfoService _instance = NetworkInfoService._internal();
  factory NetworkInfoService() => _instance;
  NetworkInfoService._internal();

  final NetworkInfo _networkInfo = NetworkInfo();

  static final RegExp _ipv4Regex = RegExp(
    r'^(?:\d{1,3}\.){3}\d{1,3}$',
  );

  /// نرمال‌سازی و اعتبارسنجی IPv4 (برای تست و استفاده داخلی)
  static String? normalizeIpv4(String? raw) {
    if (raw == null) {
      return null;
    }
    var value = raw.trim().replaceAll('"', '');
    if (value.isEmpty || value == '0.0.0.0' || value == '255.255.255.255') {
      return null;
    }
    if (!_ipv4Regex.hasMatch(value)) {
      return null;
    }
    final parts = value.split('.');
    for (final part in parts) {
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) {
        return null;
      }
    }
    return value;
  }

  /// Default Gateway واقعی اینترنت دستگاه از OS
  /// (نه حدس subnet و نه route WAN روتر MikroTik)
  Future<DeviceGatewayDiscovery> discoverDeviceDefaultGateway() async {
    if (kIsWeb) {
      return const DeviceGatewayDiscovery(source: DeviceGatewaySource.unavailable);
    }

    try {
      final gateway = normalizeIpv4(await _networkInfo.getWifiGatewayIP());
      if (gateway != null) {
        return DeviceGatewayDiscovery(
          ip: gateway,
          source: DeviceGatewaySource.system,
        );
      }
    } catch (_) {
      // ignore
    }

    return const DeviceGatewayDiscovery(source: DeviceGatewaySource.unavailable);
  }

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

  /// Default Gateway دستگاه — فقط از OS
  Future<String?> getDefaultGatewayOrRouterIp() async {
    final discovery = await discoverDeviceDefaultGateway();
    return discovery.ip;
  }

  /// برچسب فارسی منبع gateway برای لاگ
  String sourceLabel(DeviceGatewaySource source) {
    switch (source) {
      case DeviceGatewaySource.system:
        return 'سیستم‌عامل (جدول مسیریابی / DHCP)';
      case DeviceGatewaySource.unavailable:
        return 'یافت نشد';
    }
  }

  /// دریافت Default Gateway از route table RouterOS (WAN روتر — فقط تشخیصی)
  /// برای تنظیم host اتصال کلاینت استفاده نکنید؛ از [discoverDeviceDefaultGateway] استفاده کنید.
  Future<String?> getDefaultGateway() async {
    try {
      final serviceManager = MikroTikServiceManager();
      if (serviceManager.isConnected) {
        return await serviceManager.getDefaultGateway();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// دریافت همه اطلاعات شبکه (IPv4 Address و Default Gateway)
  Future<Map<String, String?>> getNetworkInfo() async {
    final deviceIp = await getDeviceIPv4Address();
    final discovery = await discoverDeviceDefaultGateway();

    return {
      'deviceIp': deviceIp,
      'defaultGateway': discovery.ip,
      'gatewaySource': sourceLabel(discovery.source),
    };
  }
}
