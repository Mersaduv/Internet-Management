# نحوه استفاده از NetworkInfoService

این سرویس برای دریافت اطلاعات شبکه دستگاه (IPv4 Address و Default Gateway) استفاده می‌شود.

## روش‌های دریافت Default Gateway

### 1. استفاده از RouterOS API (توصیه می‌شود)

این روش از route table RouterOS استفاده می‌کند و route با destination `0.0.0.0/0` را پیدا می‌کند:

```dart
import 'services/network_info_service.dart';

final networkInfo = NetworkInfoService();

// دریافت Default Gateway از RouterOS
final gateway = await networkInfo.getDefaultGateway();
if (gateway != null) {
  print('Default Gateway: $gateway');
}
```

### 2. دریافت IPv4 Address دستگاه

```dart
final networkInfo = NetworkInfoService();

// دریافت IP محلی دستگاه
final deviceIp = await networkInfo.getDeviceIPv4Address();
if (deviceIp != null) {
  print('Device IP: $deviceIp');
}
```

### 3. دریافت همه اطلاعات شبکه

```dart
final networkInfo = NetworkInfoService();

// دریافت هم IP و هم Gateway
final info = await networkInfo.getNetworkInfo();
print('Device IP: ${info['deviceIp']}');
print('Default Gateway: ${info['defaultGateway']}');
```

### 4. استفاده در initState

```dart
@override
void initState() {
  super.initState();
  _loadNetworkInfo();
}

Future<void> _loadNetworkInfo() async {
  final networkInfo = NetworkInfoService();
  final info = await networkInfo.getNetworkInfo();
  
  // استفاده از اطلاعات
  final deviceIp = info['deviceIp'];
  final gateway = info['defaultGateway'];
  
  // ذخیره یا استفاده از اطلاعات
}
```

## نکات مهم

1. **RouterOS API**: برای دریافت Default Gateway، باید ابتدا به RouterOS متصل باشید
2. **Fallback**: اگر RouterOS API در دسترس نباشد، از IP روتر (host) به عنوان gateway استفاده می‌شود
3. **IPv4 Address**: این متد IP محلی دستگاه را از NetworkInterface می‌گیرد (بدون نیاز به RouterOS)

## مثال کامل

```dart
import 'package:flutter/material.dart';
import 'services/network_info_service.dart';

class NetworkInfoExample extends StatefulWidget {
  const NetworkInfoExample({super.key});

  @override
  State<NetworkInfoExample> createState() => _NetworkInfoExampleState();
}

class _NetworkInfoExampleState extends State<NetworkInfoExample> {
  String? _deviceIp;
  String? _defaultGateway;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
  }

  Future<void> _loadNetworkInfo() async {
    setState(() => _isLoading = true);
    
    try {
      final networkInfo = NetworkInfoService();
      final info = await networkInfo.getNetworkInfo();
      
      setState(() {
        _deviceIp = info['deviceIp'];
        _defaultGateway = info['defaultGateway'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Network Info')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device IP: ${_deviceIp ?? 'Not found'}'),
            const SizedBox(height: 16),
            Text('Default Gateway: ${_defaultGateway ?? 'Not found'}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNetworkInfo,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
```
