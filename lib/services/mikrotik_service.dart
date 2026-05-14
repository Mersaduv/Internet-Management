import 'dart:io';
import 'dart:async';
import '../models/mikrotik_connection.dart';
import '../models/client_info.dart';
import '../models/device_fingerprint.dart';
import '../services/device_fingerprint_service.dart';
import 'routeros_client_v2.dart' show RouterOSClientV2;
import 'package:shared_preferences/shared_preferences.dart';

/// سرویس برای مدیریت اتصال و عملیات MikroTik RouterOS
/// مشابه endpointهای /api/clients/* در پروژه Python
class MikroTikService {
  RouterOSClientV2? _client;
  MikroTikConnection? _connection;

  /// اتصال به MikroTik RouterOS
  Future<bool> connect(MikroTikConnection connection) async {
    try {
      _connection = connection;
      _client = RouterOSClientV2(
        address: connection.host,
        user: connection.username,
        password: connection.password,
        useSsl: connection.useSsl,
        port: connection.port,
      );

      final success = await _client!.login();
      if (!success) {
        _client = null;
        _connection = null;
      }
      return success;
    } catch (e) {
      _client = null;
      _connection = null;
      throw Exception('خطا در اتصال: $e');
    }
  }

  /// بررسی اتصال
  bool get isConnected => _client?.isConnected ?? false;

  /// بستن اتصال
  void disconnect() {
    _client?.close();
    _client = null;
    _connection = null;
  }

  /// دریافت همه کاربران و دستگاه‌های متصل
  /// مشابه POST /api/clients/all
  Future<Map<String, dynamic>> getAllClients() async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      final allClients = <ClientInfo>[];

      // 1. Hotspot Active Users
      try {
        final hotspotActive = await _client!.talk(['/ip/hotspot/active/print']);
        for (var user in hotspotActive) {
          allClients.add(
            ClientInfo(
              type: 'hotspot',
              source: 'hotspot_active',
              user: user['user'],
              ipAddress: user['address'],
              macAddress: user['mac-address'],
              uptime: user['uptime'],
              bytesIn: user['bytes-in'],
              bytesOut: user['bytes-out'],
              loginBy: user['login-by'],
              server: user['server'],
              id: user['.id'],
              rawData: user,
            ),
          );
        }
      } catch (e) {
        // Hotspot ممکن است فعال نباشد
      }

      // 2. Wireless Clients
      try {
        final wirelessClients = await _client!.talk([
          '/interface/wireless/registration-table/print',
        ]);
        for (var client in wirelessClients) {
          allClients.add(
            ClientInfo(
              type: 'wireless',
              source: 'wireless_registration',
              macAddress: client['mac-address'],
              interface: client['interface'],
              ssid: client['ssid'],
              signalStrength: client['signal-strength'],
              uptime: client['uptime'],
              rawData: client,
            ),
          );
        }
      } catch (e) {
        // Wireless ممکن است فعال نباشد
      }

      // 3. DHCP Leases (Bound)
      try {
        final dhcpLeases = await _client!.talk(['/ip/dhcp-server/lease/print']);
        for (var lease in dhcpLeases) {
          if (lease['status']?.toLowerCase() == 'bound') {
            // تشخیص Static/Dynamic از DHCP lease
            bool? isStaticLease;
            if (lease.containsKey('dynamic')) {
              final dynamicValue = lease['dynamic']?.toString().toLowerCase();
              isStaticLease =
                  dynamicValue == 'false'; // true = static, false = dynamic
            }

            allClients.add(
              ClientInfo(
                type: 'dhcp',
                source: 'dhcp_lease',
                ipAddress: lease['address'],
                macAddress: lease['mac-address'],
                hostName: lease['host-name'],
                status: lease['status'],
                server: lease['server'],
                expiresAfter: lease['expires-after'],
                id: lease['.id'],
                isStaticLease: isStaticLease,
                rawData: lease,
              ),
            );
          }
        }
      } catch (e) {
        // DHCP ممکن است فعال نباشد
      }

      // 4. PPP Active Users
      try {
        final pppActive = await _client!.talk(['/ppp/active/print']);
        for (var user in pppActive) {
          allClients.add(
            ClientInfo(
              type: 'ppp',
              source: 'ppp_active',
              name: user['name'],
              service: user['service'],
              ipAddress: user['address'],
              uptime: user['uptime'],
              callerId: user['caller-id'],
              bytesIn: user['bytes-in'],
              bytesOut: user['bytes-out'],
              id: user['.id'],
              rawData: user,
            ),
          );
        }
      } catch (e) {
        // PPP ممکن است فعال نباشد
      }

      return {
        'status': 'success',
        'total_count': allClients.length,
        'by_type': {
          'hotspot': allClients.where((c) => c.type == 'hotspot').length,
          'wireless': allClients.where((c) => c.type == 'wireless').length,
          'dhcp': allClients.where((c) => c.type == 'dhcp').length,
          'ppp': allClients.where((c) => c.type == 'ppp').length,
        },
        'clients': allClients.map((c) => c.toMap()).toList(),
      };
    } catch (e) {
      throw Exception('خطا در دریافت لیست کلاینت‌ها: $e');
    }
  }

  /// دریافت جزئیات کامل همه کاربران
  /// مشابه POST /api/clients/detailed
  Future<Map<String, dynamic>> getClientsDetailed() async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      // دریافت ARP table
      final arpTable = <String, String>{};
      try {
        final arpEntries = await _client!.talk(['/ip/arp/print']);
        for (var arp in arpEntries) {
          final ip = arp['address'];
          final mac = arp['mac-address']?.toUpperCase();
          if (ip != null && mac != null) {
            arpTable[ip] = mac;
            arpTable[mac] = ip;
          }
        }
      } catch (e) {
        // ARP ممکن است در دسترس نباشد
      }

      // دریافت Queue information
      final queues = <String, Map<String, String>>{};
      try {
        final queueList = await _client!.talk(['/queue/simple/print']);
        for (var queue in queueList) {
          final target = queue['target'];
          if (target != null) {
            queues[target] = {
              'name': queue['name'] ?? 'N/A',
              'max_limit': queue['max-limit'] ?? 'N/A',
              'bytes': queue['bytes'] ?? '0',
              'packets': queue['packets'] ?? '0',
              'rate': queue['rate'] ?? 'N/A',
            };
          }
        }
      } catch (e) {
        // Queue ممکن است فعال نباشد
      }

      // دریافت همه کلاینت‌ها (مشابه getAllClients)
      final allClientsResult = await getAllClients();
      final clients = (allClientsResult['clients'] as List)
          .map((c) => ClientInfo.fromMap(c as Map<String, dynamic>))
          .toList();

      // افزودن اطلاعات ARP و Queue
      final enrichedClients = <ClientInfo>[];
      for (var client in clients) {
        var enrichedClient = client;
        var enrichedRawData = Map<String, dynamic>.from(client.rawData);

        if (client.ipAddress != null &&
            arpTable.containsKey(client.ipAddress)) {
          if (client.macAddress == null) {
            enrichedClient = ClientInfo(
              type: client.type,
              source: client.source,
              user: client.user,
              name: client.name,
              ipAddress: client.ipAddress,
              macAddress: arpTable[client.ipAddress],
              hostName: client.hostName,
              uptime: client.uptime,
              bytesIn: client.bytesIn,
              bytesOut: client.bytesOut,
              loginBy: client.loginBy,
              server: client.server,
              id: client.id,
              interface: client.interface,
              ssid: client.ssid,
              signalStrength: client.signalStrength,
              service: client.service,
              callerId: client.callerId,
              status: client.status,
              expiresAfter: client.expiresAfter,
              rawData: enrichedRawData
                ..['arp_mac'] = arpTable[client.ipAddress],
            );
          }
        }

        if (enrichedClient.ipAddress != null &&
            queues.containsKey(enrichedClient.ipAddress)) {
          final queueInfo = queues[enrichedClient.ipAddress]!;
          enrichedRawData = Map<String, dynamic>.from(enrichedClient.rawData);
          enrichedRawData['queue_name'] = queueInfo['name'];
          enrichedRawData['queue_max_limit'] = queueInfo['max_limit'];
          enrichedRawData['queue_bytes'] = queueInfo['bytes'];
          enrichedRawData['queue_packets'] = queueInfo['packets'];
          enrichedRawData['queue_rate'] = queueInfo['rate'];

          enrichedClient = ClientInfo(
            type: enrichedClient.type,
            source: enrichedClient.source,
            user: enrichedClient.user,
            name: enrichedClient.name,
            ipAddress: enrichedClient.ipAddress,
            macAddress: enrichedClient.macAddress,
            hostName: enrichedClient.hostName,
            uptime: enrichedClient.uptime,
            bytesIn: enrichedClient.bytesIn,
            bytesOut: enrichedClient.bytesOut,
            loginBy: enrichedClient.loginBy,
            server: enrichedClient.server,
            id: enrichedClient.id,
            interface: enrichedClient.interface,
            ssid: enrichedClient.ssid,
            signalStrength: enrichedClient.signalStrength,
            service: enrichedClient.service,
            callerId: enrichedClient.callerId,
            status: enrichedClient.status,
            expiresAfter: enrichedClient.expiresAfter,
            rawData: enrichedRawData,
          );
        }

        enrichedClients.add(enrichedClient);
      }

      return {
        'status': 'success',
        'total_count': enrichedClients.length,
        'clients': enrichedClients.map((c) => c.toMap()).toList(),
      };
    } catch (e) {
      throw Exception('خطا در دریافت جزئیات کلاینت‌ها: $e');
    }
  }

  /// دریافت لیست کاربران متصل
  /// مشابه POST /api/clients/connected
  Future<Map<String, dynamic>> getConnectedClients() async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      final connectedClients = <ClientInfo>[];

      // دریافت DHCP leases برای hostname
      final dhcpLeasesDict = <String, Map<String, String>>{};
      try {
        final dhcpLeases = await _client!.talk(['/ip/dhcp-server/lease/print']);
        for (var lease in dhcpLeases) {
          if (lease['status']?.toLowerCase() == 'bound') {
            final mac = lease['mac-address']?.toUpperCase();
            if (mac != null) {
              dhcpLeasesDict[mac] = lease;
            }
          }
        }
      } catch (e) {
        // DHCP ممکن است فعال نباشد
      }

      // دریافت ARP table برای تکمیل اطلاعات IP
      final arpTable = <String, Map<String, String>>{};
      try {
        final arpEntries = await _client!.talk(['/ip/arp/print']);
        for (var arp in arpEntries) {
          final mac = arp['mac-address']?.toUpperCase();
          if (mac != null) {
            arpTable[mac] = arp;
          }
        }
      } catch (e) {
        // ARP ممکن است در دسترس نباشد
      }

      // 1. Wireless Clients
      try {
        final wirelessClients = await _client!.talk([
          '/interface/wireless/registration-table/print',
        ]);
        for (var client in wirelessClients) {
          final mac = client['mac-address']?.toUpperCase();
          final dhcpInfo = mac != null ? dhcpLeasesDict[mac] : null;
          final arpInfo = mac != null ? arpTable[mac] : null;

          // اولویت: DHCP > ARP
          final ipAddress = dhcpInfo?['address'] ?? arpInfo?['address'];
          final hostName = dhcpInfo?['host-name'];

          // تشخیص Static/Dynamic از DHCP lease
          bool? isStaticLease;
          if (dhcpInfo != null && dhcpInfo.containsKey('dynamic')) {
            final dynamicValue = dhcpInfo['dynamic']?.toString().toLowerCase();
            isStaticLease =
                dynamicValue == 'false'; // true = static, false = dynamic
          }

          connectedClients.add(
            ClientInfo(
              type: 'wireless',
              source: 'wireless_registration',
              macAddress: mac,
              ipAddress: ipAddress,
              hostName: hostName,
              interface: client['interface'],
              ssid: client['ssid'],
              signalStrength: client['signal-strength'],
              uptime: client['uptime'],
              isStaticLease: isStaticLease,
              rawData: client,
            ),
          );
        }
      } catch (e) {
        // Wireless ممکن است فعال نباشد
      }

      // 2. DHCP Leases (Bound) که wireless نیستند
      try {
        final dhcpLeases = await _client!.talk(['/ip/dhcp-server/lease/print']);
        for (var lease in dhcpLeases) {
          if (lease['status']?.toLowerCase() == 'bound') {
            final mac = lease['mac-address']?.toUpperCase();
            // اگر قبلاً به عنوان wireless اضافه نشده
            if (mac != null &&
                !connectedClients.any(
                  (c) => c.macAddress?.toUpperCase() == mac,
                )) {
              // تشخیص Static/Dynamic از DHCP lease
              bool? isStaticLease;
              if (lease.containsKey('dynamic')) {
                final dynamicValue = lease['dynamic']?.toString().toLowerCase();
                isStaticLease =
                    dynamicValue == 'false'; // true = static, false = dynamic
              }

              connectedClients.add(
                ClientInfo(
                  type: 'dhcp',
                  source: 'dhcp_lease',
                  ipAddress: lease['address'],
                  macAddress: mac,
                  hostName: lease['host-name'],
                  status: lease['status'],
                  id: lease['.id'],
                  isStaticLease: isStaticLease,
                  rawData: lease,
                ),
              );
            }
          }
        }
      } catch (e) {
        // DHCP ممکن است فعال نباشد
      }

      // 3. Hotspot Active
      try {
        final hotspotActive = await _client!.talk(['/ip/hotspot/active/print']);
        for (var user in hotspotActive) {
          final ip = user['address'];
          final mac = user['mac-address']?.toUpperCase();
          // اگر قبلاً اضافه نشده
          if (!connectedClients.any(
            (c) =>
                c.ipAddress == ip ||
                (mac != null && c.macAddress?.toUpperCase() == mac),
          )) {
            connectedClients.add(
              ClientInfo(
                type: 'hotspot',
                source: 'hotspot_active',
                ipAddress: ip,
                macAddress: mac,
                user: user['user'],
                uptime: user['uptime'],
                bytesIn: user['bytes-in'],
                bytesOut: user['bytes-out'],
                id: user['.id'],
                rawData: user,
              ),
            );
          }
        }
      } catch (e) {
        // Hotspot ممکن است فعال نباشد
      }

      return {
        'status': 'success',
        'total_count': connectedClients.length,
        'clients': connectedClients.map((c) => c.toMap()).toList(),
      };
    } catch (e) {
      throw Exception('خطا در دریافت کلاینت‌های متصل: $e');
    }
  }

  /// مسدود کردن کلاینت با استفاده از Device Fingerprint
  /// این تابع Device Fingerprint را محاسبه می‌کند و ذخیره می‌کند
  /// تا حتی با تغییر IP/MAC، دستگاه شناسایی شود
  Future<bool> banClientWithFingerprint(
    String ipAddress, {
    String? macAddress,
    String? hostname,
    String? ssid,
  }) async {
    print('═══════════════════════════════════════════════════════════');
    print('🚫 [BAN_WITH_FINGERPRINT] شروع عملیات مسدود کردن با Fingerprint');
    print('═══════════════════════════════════════════════════════════');
    print('📋 [BAN_WITH_FINGERPRINT] اطلاعات ورودی:');
    print('   └─ IP Address: $ipAddress');
    print('   └─ MAC Address: ${macAddress ?? "null"}');
    print('   └─ Hostname: ${hostname ?? "null"}');
    print('   └─ SSID: ${ssid ?? "null"}');

    // بررسی اتصال
    print('🔍 [BAN_WITH_FINGERPRINT] بررسی اتصال...');
    print('   └─ _client: ${_client != null ? "موجود" : "null"}');
    print('   └─ isConnected: $isConnected');
    if (_connection != null) {
      print('   └─ Connection Host: ${_connection!.host}');
      print('   └─ Connection Port: ${_connection!.port}');
      print('   └─ Connection User: ${_connection!.username}');
      print('   └─ Connection SSL: ${_connection!.useSsl}');
    } else {
      print('   └─ ⚠️ Connection: null');
    }

    if (_client == null || !isConnected) {
      print('❌ [BAN_WITH_FINGERPRINT] اتصال برقرار نیست!');
      print('═══════════════════════════════════════════════════════════');
      throw Exception('اتصال برقرار نشده');
    }

    try {
      // ایجاد Device Fingerprint
      print('🔍 [BAN_WITH_FINGERPRINT] ایجاد Device Fingerprint...');
      final fingerprint = DeviceFingerprint.fromClientInfo(
        ipAddress,
        macAddress,
        hostname,
        ssid,
      );
      print('   └─ Fingerprint ID: ${fingerprint.fingerprintId}');
      print('   └─ Hostname: ${fingerprint.hostname ?? "null"}');
      print('   └─ MAC Vendor: ${fingerprint.macVendor ?? "null"}');
      print('   └─ Device Type: ${fingerprint.deviceType ?? "null"}');

      // ذخیره Device Fingerprint
      print('💾 [BAN_WITH_FINGERPRINT] ذخیره Device Fingerprint...');
      final fingerprintService = DeviceFingerprintService();
      await fingerprintService.saveBannedFingerprint(fingerprint);
      print('   └─ ✅ Device Fingerprint ذخیره شد');

      // ایجاد comment با Device Fingerprint
      final fingerprintComment = 'Banned: ${fingerprint.fingerprintId}';
      print('📝 [BAN_WITH_FINGERPRINT] Comment: $fingerprintComment');

      // مسدود کردن با استفاده از banClient اصلی
      print('🔄 [BAN_WITH_FINGERPRINT] فراخوانی banClient()...');
      final result = await banClient(
        ipAddress,
        macAddress: macAddress,
        comment: fingerprintComment,
      );

      print('═══════════════════════════════════════════════════════════');
      print(
        '${result ? "✅" : "❌"} [BAN_WITH_FINGERPRINT] نتیجه نهایی: ${result ? "موفق" : "ناموفق"}',
      );
      print('═══════════════════════════════════════════════════════════');
      return result;
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ [BAN_WITH_FINGERPRINT] خطا در مسدود کردن:');
      print('   └─ Error: $e');
      print('   └─ Type: ${e.runtimeType}');
      print('   └─ Stack Trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      rethrow;
    }
  }

  /// مسدود کردن کلاینت
  /// مشابه POST /api/clients/ban
  /// از Raw rules استفاده می‌کند (بهتر از filter rules برای تعداد زیاد)
  /// از چند بخش مسدود می‌کند:
  /// 1. Firewall Raw Prerouting Chain (بر اساس IP)
  /// 2. Firewall Raw Prerouting Chain (بر اساس MAC - مستقل از IP)
  /// 3. DHCP Block Access
  /// 4. Wireless Access List
  Future<bool> banClient(
    String ipAddress, {
    String? macAddress,
    String? comment,
  }) async {
    print('═══════════════════════════════════════════════════════════');
    print('🚫 [BAN_CLIENT] شروع عملیات مسدود کردن');
    print('═══════════════════════════════════════════════════════════');
    print('📋 [BAN_CLIENT] اطلاعات ورودی:');
    print('   └─ IP Address: $ipAddress');
    print('   └─ MAC Address: ${macAddress ?? "null"}');
    print('   └─ Comment: ${comment ?? "null"}');

    // بررسی اتصال
    print('🔍 [BAN_CLIENT] بررسی اتصال...');
    print('   └─ _client: ${_client != null ? "موجود" : "null"}');
    print('   └─ isConnected: $isConnected');

    if (_client == null || !isConnected) {
      print('❌ [BAN_CLIENT] اتصال برقرار نیست!');
      print('═══════════════════════════════════════════════════════════');
      throw Exception('اتصال برقرار نشده');
    }

    print('✅ [BAN_CLIENT] اتصال برقرار است');

    try {
      // حذف بررسی اتصال دستگاه (مثل rejectDevice)
      // این بررسی باعث timeout و خطا می‌شود
      // در rejectDevice این بررسی انجام نمی‌شود و همیشه موفق است
      print('ℹ️ [BAN_CLIENT] بررسی اتصال دستگاه حذف شد (مثل rejectDevice)');

      // پیدا کردن MAC address از IP اگر داده نشده باشد
      String? macToUse = macAddress;
      print('🔍 [BAN_CLIENT] بررسی MAC Address...');
      print('   └─ MAC ورودی: ${macAddress ?? "null"}');

      if (macToUse == null) {
        print('   └─ MAC پیدا نشد، جستجو در DHCP و ARP...');
        try {
          // جستجو در DHCP leases
          print('   └─ جستجو در DHCP leases...');
          final dhcpLeases = await _client!.talk([
            '/ip/dhcp-server/lease/print',
          ]);
          print('   └─ تعداد DHCP leases: ${dhcpLeases.length}');
          for (var lease in dhcpLeases) {
            if (lease['address'] == ipAddress) {
              macToUse = lease['mac-address'];
              print('   └─ ✅ MAC در DHCP پیدا شد: $macToUse');
              break;
            }
          }

          // اگر در DHCP پیدا نشد، در ARP table جستجو کن
          if (macToUse == null) {
            print('   └─ MAC در DHCP پیدا نشد، جستجو در ARP table...');
            final arpEntries = await _client!.talk(['/ip/arp/print']);
            print('   └─ تعداد ARP entries: ${arpEntries.length}');
            for (var arp in arpEntries) {
              if (arp['address'] == ipAddress) {
                macToUse = arp['mac-address'];
                print('   └─ ✅ MAC در ARP پیدا شد: $macToUse');
                break;
              }
            }
          }

          if (macToUse == null) {
            print('   └─ ⚠️ MAC پیدا نشد!');
          }
        } catch (e) {
          print('   └─ ❌ خطا در جستجوی MAC: $e');
        }
      } else {
        print('   └─ ✅ MAC استفاده می‌شود: $macToUse');
      }

      print('📋 [BAN_CLIENT] MAC نهایی: ${macToUse ?? "null"}');

      // استفاده از comment داده شده یا comment پیش‌فرض
      final banComment = comment ?? 'Banned via Flutter App';
      print('📝 [BAN_CLIENT] Comment: $banComment');

      // حذف بررسی وضعیت فعلی (مثل rejectDevice)
      // این بررسی باعث timeout و توقف کد می‌شود
      // در rejectDevice این بررسی انجام نمی‌شود
      print('ℹ️ [BAN_CLIENT] بررسی وضعیت فعلی حذف شد (مثل rejectDevice)');

      // 1. Firewall Raw Prerouting Chain - مسدود کردن ترافیک بر اساس IP
      print('═══════════════════════════════════════════════════════════');
      print('1️⃣ [BAN_CLIENT] مرحله 1: Firewall Raw Rule (IP)');
      print('═══════════════════════════════════════════════════════════');
      // Raw rules قبل از connection tracking پردازش می‌شوند و سریع‌تر هستند
      // همیشه rule را اضافه می‌کنیم (مثل rejectDevice) - بررسی وضعیت حذف شد
      try {
        print('   └─ ایجاد Firewall Raw Rule برای IP: $ipAddress');
        final rawCommand = [
          '/ip/firewall/raw/add',
          '=chain=prerouting',
          '=src-address=$ipAddress',
          '=action=drop',
          '=comment=$banComment - IP',
        ];
        if (macToUse != null) {
          rawCommand.add('=src-mac-address=$macToUse');
          print('   └─ با MAC: $macToUse');
        }
        print('   └─ Command: ${rawCommand.join(" ")}');
        final result = await _client!.talk(rawCommand);
        print('   └─ Response: $result');
        print('✅ [BAN_CLIENT] Firewall Raw Rule (IP) اضافه شد: $ipAddress');
      } catch (e, stackTrace) {
        print('❌ [BAN_CLIENT] خطا در اضافه کردن Firewall Raw Rule (IP):');
        print('   └─ Error: $e');
        print('   └─ Type: ${e.runtimeType}');
        print('   └─ Stack Trace: $stackTrace');
        // 继续执行其他步骤 (مثل rejectDevice)
      }

      // 2. Firewall Raw Prerouting MAC Chain - مسدود کردن بر اساس MAC (مستقل از IP)
      print('═══════════════════════════════════════════════════════════');
      print('2️⃣ [BAN_CLIENT] مرحله 2: Firewall Raw Rule (MAC)');
      print('═══════════════════════════════════════════════════════════');
      // این rule حتی اگر IP تغییر کند، دستگاه را مسدود می‌کند
      // همیشه rule را اضافه می‌کنیم (مثل rejectDevice) - بررسی وضعیت حذف شد
      if (macToUse != null) {
        try {
          print('   └─ ایجاد Firewall Raw Rule برای MAC: $macToUse');
          final macCommand = [
            '/ip/firewall/raw/add',
            '=chain=prerouting',
            '=src-mac-address=$macToUse',
            '=action=drop',
            '=comment=$banComment - MAC',
          ];
          print('   └─ Command: ${macCommand.join(" ")}');
          final result = await _client!.talk(macCommand);
          print('   └─ Response: $result');
          print('✅ [BAN_CLIENT] Firewall Raw Rule (MAC) اضافه شد: $macToUse');
        } catch (e, stackTrace) {
          print('❌ [BAN_CLIENT] خطا در اضافه کردن Firewall Raw Rule (MAC):');
          print('   └─ Error: $e');
          print('   └─ Type: ${e.runtimeType}');
          print('   └─ Stack Trace: $stackTrace');
          // 继续执行其他步骤 (مثل rejectDevice)
        }
      } else {
        print('⚠️ [BAN_CLIENT] MAC Address موجود نیست، این مرحله رد می‌شود');
      }

      // 3. DHCP Block Access - Block کردن DHCP lease
      print('═══════════════════════════════════════════════════════════');
      print('3️⃣ [BAN_CLIENT] مرحله 3: DHCP Block Access');
      print('═══════════════════════════════════════════════════════════');
      // 确保 DHCP lease 被 block，即使之前已经 block
      if (macToUse != null) {
        try {
          print('   └─ جستجوی DHCP lease برای MAC: $macToUse');
          final dhcpLeases = await _client!.talk([
            '/ip/dhcp-server/lease/print',
          ]);
          print('   └─ تعداد DHCP leases: ${dhcpLeases.length}');
          bool found = false;
          for (var lease in dhcpLeases) {
            final leaseMac = lease['mac-address']?.toString().toUpperCase();
            if (leaseMac == macToUse.toUpperCase()) {
              found = true;
              final leaseId = lease['.id'];
              final currentBlockAccess = lease['block-access']
                  ?.toString()
                  .toLowerCase();
              print('   └─ ✅ DHCP lease پیدا شد:');
              print('      └─ ID: $leaseId');
              print('      └─ IP: ${lease['address']}');
              print('      └─ Block Access فعلی: $currentBlockAccess');
              if (leaseId != null) {
                // 即使已经 block，也确保设置（可能之前设置失败）
                if (currentBlockAccess != 'yes' &&
                    currentBlockAccess != 'true') {
                  print('   └─ تنظیم block-access=yes...');
                  final setCommand = [
                    '/ip/dhcp-server/lease/set',
                    '=.id=$leaseId',
                    '=block-access=yes',
                  ];
                  print('   └─ Command: ${setCommand.join(" ")}');
                  final result = await _client!.talk(setCommand);
                  print('   └─ Response: $result');
                  print('✅ [BAN_CLIENT] DHCP Block Access تنظیم شد: $macToUse');
                } else {
                  print(
                    'ℹ️ [BAN_CLIENT] DHCP Block Access از قبل فعال است: $macToUse',
                  );
                }
              }
              break;
            }
          }
          if (!found) {
            print('   └─ ⚠️ DHCP lease برای MAC پیدا نشد: $macToUse');
          }
        } catch (e, stackTrace) {
          print('❌ [BAN_CLIENT] خطا در تنظیم DHCP Block Access:');
          print('   └─ Error: $e');
          print('   └─ Type: ${e.runtimeType}');
          print('   └─ Stack Trace: $stackTrace');
          // 继续执行其他步骤
        }
      } else {
        print('⚠️ [BAN_CLIENT] MAC Address موجود نیست، این مرحله رد می‌شود');
      }

      // 4. Wireless Access List - مسدود کردن اتصال وای‌فای
      print('═══════════════════════════════════════════════════════════');
      print('4️⃣ [BAN_CLIENT] مرحله 4: Wireless Access List');
      print('═══════════════════════════════════════════════════════════');
      // 确保 Wireless Access List 被 block，即使之前已经 block
      if (macToUse != null) {
        try {
          // بررسی اینکه آیا MAC قبلاً در access list block شده
          print('   └─ بررسی Wireless Access List...');
          final accessList = await _client!.talk([
            '/interface/wireless/access-list/print',
          ]);
          print('   └─ تعداد Access List entries: ${accessList.length}');
          bool macExists = false;
          String? existingAclId;
          String? existingAction;

          for (var acl in accessList) {
            final aclMac = acl['mac-address']?.toString().toUpperCase();
            if (aclMac == macToUse.toUpperCase()) {
              macExists = true;
              existingAclId = acl['.id']?.toString();
              existingAction = acl['action']?.toString().toLowerCase();
              print('   └─ ✅ MAC در Access List پیدا شد:');
              print('      └─ ID: $existingAclId');
              print('      └─ Action فعلی: $existingAction');
              break;
            }
          }

          if (!macExists) {
            print('   └─ MAC در Access List پیدا نشد');
          }

          // 如果 MAC 已存在，确保它是 block 状态
          if (macExists && existingAclId != null) {
            // 如果当前不是 reject 或 deny，设置为 reject
            if (existingAction != 'reject' && existingAction != 'deny') {
              try {
                await _client!.talk([
                  '/interface/wireless/access-list/set',
                  '=.id=$existingAclId',
                  '=action=reject',
                ]);
                print(
                  '✅ [BAN_CLIENT] Wireless Access List به reject تغییر یافت: $macToUse',
                );
              } catch (e) {
                print('⚠️ [BAN_CLIENT] خطا در تغییر Wireless Access List: $e');
                // 尝试添加新的（如果设置失败）
                try {
                  await _client!.talk([
                    '/interface/wireless/access-list/add',
                    '=mac-address=$macToUse',
                    '=action=reject',
                  ]);
                  print(
                    '✅ [BAN_CLIENT] Wireless Access List (reject) اضافه شد: $macToUse',
                  );
                } catch (e2) {
                  print(
                    '⚠️ [BAN_CLIENT] خطا در اضافه کردن Wireless Access List: $e2',
                  );
                }
              }
            } else {
              print(
                'ℹ️ [BAN_CLIENT] Wireless Access List از قبل block است: $macToUse',
              );
            }
          } else {
            // 如果 MAC 不存在，添加它
            try {
              await _client!.talk([
                '/interface/wireless/access-list/add',
                '=mac-address=$macToUse',
                '=action=deny',
              ]);
              print(
                '✅ [BAN_CLIENT] Wireless Access List (deny) اضافه شد: $macToUse',
              );
            } catch (e) {
              // 如果 deny 不工作，尝试 reject
              try {
                await _client!.talk([
                  '/interface/wireless/access-list/add',
                  '=mac-address=$macToUse',
                  '=action=reject',
                ]);
                print(
                  '✅ [BAN_CLIENT] Wireless Access List (reject) اضافه شد: $macToUse',
                );
              } catch (e2) {
                print(
                  '⚠️ [BAN_CLIENT] خطا در اضافه کردن Wireless Access List: $e2',
                );
              }
            }
          }
        } catch (e) {
          print('⚠️ [BAN_CLIENT] خطا در تنظیم Wireless Access List: $e');
          // 继续执行其他步骤
        }
      }

      // مثل rejectDevice: همیشه true برمی‌گردانیم
      // بررسی وضعیت نهایی حذف شد چون باعث timeout می‌شود
      print('═══════════════════════════════════════════════════════════');
      print('✅ [BAN_CLIENT] عملیات مسدود کردن انجام شد (مثل rejectDevice)');
      print('═══════════════════════════════════════════════════════════');
      return true; // همیشه true (مثل rejectDevice)
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ [BAN_CLIENT] خطا در مسدود کردن کلاینت:');
      print('   └─ Error: $e');
      print('   └─ Type: ${e.runtimeType}');
      print('   └─ Stack Trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      throw Exception('خطا در مسدود کردن کلاینت: $e');
    }
  }

  /// رفع مسدودیت کلاینت با استفاده از Device Fingerprint
  Future<bool> unbanClientWithFingerprint(
    String ipAddress, {
    String? macAddress,
    String? hostname,
    String? ssid,
  }) async {
    // ایجاد Device Fingerprint
    final fingerprint = DeviceFingerprint.fromClientInfo(
      ipAddress,
      macAddress,
      hostname,
      ssid,
    );

    // ابتدا حذف همه rule های firewall مربوط به این Device Fingerprint
    // این اطمینان می‌دهد که rule ها قبل از حذف Device Fingerprint حذف می‌شوند
    try {
      if (_client != null && isConnected) {
        final fingerprintId = fingerprint.fingerprintId;

        // حذف همه rule های firewall که comment آن‌ها شامل fingerprintId است
        final rawRules = await _client!.talk(['/ip/firewall/raw/print']);
        for (var rule in rawRules) {
          final ruleComment = rule['comment']?.toString() ?? '';
          if (ruleComment.contains('Auto-banned:') &&
              ruleComment.contains(fingerprintId)) {
            final ruleId = rule['.id']?.toString();
            if (ruleId != null) {
              try {
                await _client!.talk([
                  '/ip/firewall/raw/remove',
                  '=.id=$ruleId',
                ]);
              } catch (e) {
                // ignore
              }
            }
          }
        }
      }
    } catch (e) {
      // ignore
    }

    // حذف Device Fingerprint
    final fingerprintService = DeviceFingerprintService();
    await fingerprintService.removeBannedFingerprint(fingerprint);

    // رفع مسدودیت با استفاده از unbanClient اصلی
    final success = await unbanClient(ipAddress, macAddress: macAddress);

    // قفل اتصال جدید حذف شده - نیازی به بررسی نیست
    // این بخش حذف شده - قفل اتصال جدید حذف شده

    return success;
  }

  /// رفع مسدودیت کلاینت
  /// مشابه POST /api/clients/unban
  Future<bool> unbanClient(String ipAddress, {String? macAddress}) async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      // پیدا کردن MAC address از IP اگر داده نشده باشد
      String? macToUse = macAddress;
      if (macToUse == null) {
        try {
          final dhcpLeases = await _client!.talk([
            '/ip/dhcp-server/lease/print',
          ]);
          for (var lease in dhcpLeases) {
            if (lease['address'] == ipAddress) {
              macToUse = lease['mac-address'];
              break;
            }
          }
          if (macToUse == null) {
            final arpEntries = await _client!.talk(['/ip/arp/print']);
            for (var arp in arpEntries) {
              if (arp['address'] == ipAddress) {
                macToUse = arp['mac-address'];
                break;
              }
            }
          }
        } catch (e) {
          // ignore
        }
      }

      int removedCount = 0;

      // 1. حذف Raw Firewall Rules (همه rule های مربوط به این IP/MAC)
      // حذف همه rule های auto-banned و rule های دستی مربوط به این دستگاه
      // شامل rule هایی که فقط IP دارند، فقط MAC دارند، یا هر دو
      // حذف همه rule ها بدون توجه به action یا chain (برای اطمینان از حذف کامل)
      try {
        final rawRules = await _client!.talk(['/ip/firewall/raw/print']);
        final rulesToRemove = <String>[];

        for (var rule in rawRules) {
          bool shouldRemove = false;
          final ruleIp = rule['src-address']?.toString();
          final ruleMac = rule['src-mac-address']?.toString();

          // بررسی تطابق IP
          if (ruleIp != null && ruleIp.isNotEmpty && ruleIp == ipAddress) {
            shouldRemove = true;
          }

          // بررسی تطابق MAC (حتی اگر IP متفاوت باشد)
          if (macToUse != null &&
              ruleMac != null &&
              ruleMac.toUpperCase() == macToUse.toUpperCase()) {
            shouldRemove = true;
          }

          // حذف همه rule های مربوط به این IP/MAC (بدون توجه به comment، action یا chain)
          // این شامل rule های auto-banned (با همه comment های ممکن) و rule های دستی می‌شود
          // comment های auto-banned ممکن است شامل:
          // - "Auto-banned: New connection while locked"
          // - "Auto-banned: New connection while locked - IP"
          // - "Auto-banned: New connection while locked - MAC"
          // - "Banned:" یا "Banned via Flutter App" (مسدود دستی)
          if (shouldRemove) {
            final ruleId = rule['.id']?.toString();
            if (ruleId != null && !rulesToRemove.contains(ruleId)) {
              rulesToRemove.add(ruleId);
            }
          }
        }

        // حذف همه rule ها
        for (var ruleId in rulesToRemove) {
          try {
            await _client!.talk(['/ip/firewall/raw/remove', '=.id=$ruleId']);
            removedCount++;
          } catch (e) {
            // ignore
          }
        }
      } catch (e) {
        // ignore
      }

      // 2. رفع Block از DHCP Lease و حذف Static Lease (اگر به خاطر ban ایجاد شده)
      // رفع block از همه lease هایی که comment آن‌ها مربوط به auto-banned است یا بدون comment
      // همچنین حذف static lease هایی که به خاطر ban ایجاد شده‌اند (برای auto-banned devices)
      if (macToUse != null) {
        try {
          final dhcpLeases = await _client!.talk([
            '/ip/dhcp-server/lease/print',
          ]);
          for (var lease in dhcpLeases) {
            final leaseMac = lease['mac-address']?.toString().toUpperCase();
            final leaseIp = lease['address']?.toString();
            if (leaseMac == macToUse.toUpperCase() || leaseIp == ipAddress) {
              final leaseId = lease['.id'];
              final leaseComment = lease['comment']?.toString() ?? '';
              final isStatic =
                  lease['dynamic']?.toString().toLowerCase() == 'false';

              // بررسی اینکه آیا این static lease به خاطر auto-ban ایجاد شده است
              // فقط static lease هایی که به خاطر auto-ban ایجاد شده‌اند را حذف می‌کنیم
              // static lease هایی که به خاطر manual ban ایجاد شده‌اند را نگه می‌داریم
              bool isAutoBannedStatic =
                  isStatic &&
                  leaseComment.contains(
                    'Auto-banned: New connection while locked',
                  ) &&
                  leaseComment.contains('Static IP');

              // اگر static lease به خاطر auto-ban ایجاد شده است، حذف کن (تبدیل به dynamic)
              if (leaseId != null && isAutoBannedStatic) {
                try {
                  await _client!.talk([
                    '/ip/dhcp-server/lease/remove',
                    '=.id=$leaseId',
                  ]);
                  // بعد از حذف، از loop خارج شو (چون lease حذف شده است)
                  break;
                } catch (e) {
                  // ignore
                }
              }

              // رفع block از lease (اگر block شده است)
              if (leaseId != null &&
                  lease['block-access']?.toString().toLowerCase() == 'yes') {
                try {
                  await _client!.talk([
                    '/ip/dhcp-server/lease/set',
                    '=.id=$leaseId',
                    '=block-access=no',
                  ]);
                } catch (e) {
                  // ignore
                }
              }

              if (!isAutoBannedStatic) {
                break;
              }
            }
          }
        } catch (e) {
          // ignore
        }
      }

      // 3. رفع Block از Wireless Access List
      // حذف یا allow کردن همه rule های مربوط به این MAC (بدون توجه به action)
      if (macToUse != null) {
        try {
          final accessList = await _client!.talk([
            '/interface/wireless/access-list/print',
          ]);
          for (var acl in accessList) {
            final aclMac = acl['mac-address']?.toString().toUpperCase();
            if (aclMac == macToUse.toUpperCase()) {
              final aclId = acl['.id'];
              final aclComment = acl['comment']?.toString();
              final aclAction = acl['action']?.toString();

              if (aclId != null) {
                try {
                  // اگر action deny یا reject است، باید رفع مسدودیت شود
                  if (aclAction == 'deny' || aclAction == 'reject') {
                    // اگر comment مربوط به قفل است (auto-banned)، حذف کن
                    // اما اگر comment مربوط به مسدود دستی است، فقط action را allow کن (نه حذف)
                    bool isAutoBanned =
                        aclComment != null &&
                        (aclComment.contains(
                              'Auto-banned: New connection while locked',
                            ) ||
                            aclComment ==
                                'Lock New Connections - Allowed Device');

                    if (isAutoBanned) {
                      // حذف از access list (auto-banned)
                      await _client!.talk([
                        '/interface/wireless/access-list/remove',
                        '=.id=$aclId',
                      ]);
                    } else {
                      // فقط action را allow کن (مسدود دستی - نباید حذف شود)
                      await _client!.talk([
                        '/interface/wireless/access-list/set',
                        '=.id=$aclId',
                        '=action=allow',
                      ]);
                    }
                  } else if (aclAction == 'allow') {
                    // اگر قبلاً allow است، نیازی به تغییر نیست
                    // اما اگر comment مربوط به قفل است، حذف کن (برای پاکسازی)
                    bool isLockRelated =
                        aclComment != null &&
                        aclComment == 'Lock New Connections - Allowed Device';
                    if (isLockRelated) {
                      await _client!.talk([
                        '/interface/wireless/access-list/remove',
                        '=.id=$aclId',
                      ]);
                    }
                  }
                } catch (e) {
                  // ignore
                }
              }
            }
          }
        } catch (e) {
          // ignore
        }
      }

      // اگر هیچ rule ای حذف نشد اما MAC یا IP وجود دارد، باز هم true برگردان
      // چون ممکن است rule های دیگر (DHCP, Wireless) حذف شده باشند
      if (removedCount > 0 || macToUse != null || ipAddress.isNotEmpty) {
        return true;
      }

      return false;
    } catch (e) {
      throw Exception('خطا در رفع مسدودیت کلاینت: $e');
    }
  }

  /// دریافت لیست کلاینت‌های مسدود شده
  /// مشابه POST /api/clients/banned
  /// از Raw firewall rules استفاده می‌کند (بهتر از filter rules برای تعداد زیاد)
  Future<List<Map<String, dynamic>>> getBannedClients() async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      // پیدا کردن Raw firewall rules با action=drop
      final rawRules = await _client!.talk(['/ip/firewall/raw/print']);

      // فیلتر کردن rules با action=drop و chain=prerouting
      final banRules = <Map<String, dynamic>>[];
      for (var rule in rawRules) {
        // فقط rules با action=drop و chain=prerouting که مربوط به ban هستند
        if (rule['action'] == 'drop' && rule['chain'] == 'prerouting') {
          banRules.add(rule);
        }
      }

      // گروه‌بندی rules بر اساس IP و MAC
      // توجه: ممکن است rule هایی فقط با MAC (بدون IP) وجود داشته باشند
      final ipToRules = <String, Map<String, dynamic>>{};
      final macToRules = <String, Map<String, dynamic>>{};

      for (var rule in banRules) {
        final ip = rule['src-address']?.toString();
        final mac = rule['src-mac-address']?.toString();

        // اگر IP وجود دارد، بر اساس IP گروه‌بندی کن
        if (ip != null && ip.isNotEmpty) {
          if (!ipToRules.containsKey(ip)) {
            ipToRules[ip] = {
              'address': ip,
              'mac_address': mac,
              'chains': <String>[],
              'rule_ids': <String>[],
              'comment': rule['comment'] ?? '',
            };
          }

          final chain = rule['chain']?.toString();
          if (chain != null && !ipToRules[ip]!['chains'].contains(chain)) {
            (ipToRules[ip]!['chains'] as List).add(chain);
          }

          final ruleId = rule['.id']?.toString();
          if (ruleId != null && !ipToRules[ip]!['rule_ids'].contains(ruleId)) {
            (ipToRules[ip]!['rule_ids'] as List).add(ruleId);
          }

          if (mac != null && ipToRules[ip]!['mac_address'] == null) {
            ipToRules[ip]!['mac_address'] = mac;
          }
        }
        // اگر فقط MAC وجود دارد (بدون IP)، بر اساس MAC گروه‌بندی کن
        else if (mac != null && mac.isNotEmpty) {
          if (!macToRules.containsKey(mac)) {
            macToRules[mac] = {
              'address': null,
              'mac_address': mac,
              'chains': <String>[],
              'rule_ids': <String>[],
              'comment': rule['comment'] ?? '',
            };
          }

          final chain = rule['chain']?.toString();
          if (chain != null && !macToRules[mac]!['chains'].contains(chain)) {
            (macToRules[mac]!['chains'] as List).add(chain);
          }

          final ruleId = rule['.id']?.toString();
          if (ruleId != null &&
              !macToRules[mac]!['rule_ids'].contains(ruleId)) {
            (macToRules[mac]!['rule_ids'] as List).add(ruleId);
          }
        }
      }

      // تبدیل به لیست (اول IP-based، سپس MAC-only)
      final bannedClients = <Map<String, dynamic>>[];
      bannedClients.addAll(ipToRules.values);

      // برای MAC-only rules، سعی کن IP را از DHCP یا ARP پیدا کن
      for (var macRule in macToRules.values) {
        final mac = macRule['mac_address'] as String?;
        if (mac != null) {
          // بررسی اینکه آیا این MAC قبلاً در لیست IP-based اضافه شده
          bool alreadyAdded = false;
          for (var client in bannedClients) {
            if (client['mac_address']?.toString().toUpperCase() ==
                mac.toUpperCase()) {
              alreadyAdded = true;
              break;
            }
          }

          // اگر اضافه نشده، IP را از DHCP یا ARP پیدا کن
          if (!alreadyAdded) {
            String? foundIp;
            try {
              final dhcpLeases = await _client!.talk([
                '/ip/dhcp-server/lease/print',
              ]);
              for (var lease in dhcpLeases) {
                final leaseMac = lease['mac-address']?.toString().toUpperCase();
                if (leaseMac == mac.toUpperCase()) {
                  foundIp = lease['address'];
                  break;
                }
              }

              if (foundIp == null) {
                final arpEntries = await _client!.talk(['/ip/arp/print']);
                for (var arp in arpEntries) {
                  final arpMac = arp['mac-address']?.toString().toUpperCase();
                  if (arpMac == mac.toUpperCase()) {
                    foundIp = arp['address'];
                    break;
                  }
                }
              }
            } catch (e) {
              // ignore
            }

            macRule['address'] = foundIp;
            bannedClients.add(macRule);
          }
        }
      }

      // بررسی اینکه آیا IP/MAC واقعاً متصل هستند
      // اگر IP/MAC در DHCP leases یا ARP table وجود نداشته باشد،
      // یعنی دستگاه دیگر متصل نیست و نباید در لیست نشان داده شود
      final actuallyConnectedBanned = <Map<String, dynamic>>[];

      // دریافت لیست دستگاه‌های واقعاً متصل
      final dhcpLeases = <String, Map<String, dynamic>>{};
      final arpEntries = <String, Map<String, dynamic>>{};

      try {
        final leases = await _client!.talk(['/ip/dhcp-server/lease/print']);
        for (var lease in leases) {
          final leaseIp = lease['address']?.toString();
          final leaseMac = lease['mac-address']?.toString();
          if (leaseIp != null) {
            dhcpLeases[leaseIp] = lease;
          }
          if (leaseMac != null) {
            dhcpLeases[leaseMac.toUpperCase()] = lease;
          }
        }
      } catch (e) {
        // ignore
      }

      try {
        final arps = await _client!.talk(['/ip/arp/print']);
        for (var arp in arps) {
          final arpIp = arp['address']?.toString();
          final arpMac = arp['mac-address']?.toString();
          if (arpIp != null) {
            arpEntries[arpIp] = arp;
          }
          if (arpMac != null) {
            arpEntries[arpMac.toUpperCase()] = arp;
          }
        }
      } catch (e) {
        // ignore
      }

      // افزودن اطلاعات DHCP و Wireless و بررسی اتصال واقعی
      for (var client in bannedClients) {
        final ip = client['address'] as String?;
        final mac = client['mac_address'] as String?;
        bool isActuallyConnected = false;

        // بررسی اینکه آیا IP/MAC واقعاً متصل است
        if (ip != null && ip.isNotEmpty) {
          // بررسی در DHCP leases
          if (dhcpLeases.containsKey(ip)) {
            final lease = dhcpLeases[ip]!;
            final leaseMac = lease['mac-address']?.toString();

            // اگر MAC در rule وجود دارد، باید با MAC در DHCP مطابقت داشته باشد
            if (mac != null && mac.isNotEmpty) {
              if (leaseMac?.toUpperCase() == mac.toUpperCase()) {
                isActuallyConnected = true;
                client['mac_address'] = leaseMac;
              }
            } else {
              // اگر MAC در rule نیست، فقط IP کافی است
              isActuallyConnected = true;
              if (leaseMac != null) {
                client['mac_address'] = leaseMac;
              }
            }
          }

          // اگر در DHCP پیدا نشد، در ARP بررسی کن
          if (!isActuallyConnected && arpEntries.containsKey(ip)) {
            final arp = arpEntries[ip]!;
            final arpMac = arp['mac-address']?.toString();

            if (mac != null && mac.isNotEmpty) {
              if (arpMac?.toUpperCase() == mac.toUpperCase()) {
                isActuallyConnected = true;
                client['mac_address'] = arpMac;
              }
            } else {
              isActuallyConnected = true;
              if (arpMac != null) {
                client['mac_address'] = arpMac;
              }
            }
          }
        } else if (mac != null && mac.isNotEmpty) {
          // اگر فقط MAC داریم (بدون IP)، بررسی کن که آیا این MAC متصل است
          final macUpper = mac.toUpperCase();

          // بررسی در DHCP leases
          for (var lease in dhcpLeases.values) {
            final leaseMac = lease['mac-address']?.toString().toUpperCase();
            if (leaseMac == macUpper) {
              isActuallyConnected = true;
              client['address'] = lease['address'];
              break;
            }
          }

          // بررسی در ARP
          if (!isActuallyConnected) {
            for (var arp in arpEntries.values) {
              final arpMac = arp['mac-address']?.toString().toUpperCase();
              if (arpMac == macUpper) {
                isActuallyConnected = true;
                client['address'] = arp['address'];
                break;
              }
            }
          }
        }

        // فقط اگر واقعاً متصل است، به لیست اضافه کن
        if (isActuallyConnected) {
          // بررسی DHCP Block Access
          final finalMac = client['mac_address']?.toString();
          if (finalMac != null) {
            try {
              // استفاده از dhcpLeases که قبلاً لود شده
              if (dhcpLeases.containsKey(finalMac.toUpperCase())) {
                final lease = dhcpLeases[finalMac.toUpperCase()]!;
                client['dhcp_blocked'] = lease['block-access'] == 'yes';
              }

              // بررسی Wireless Access List
              final accessList = await _client!.talk([
                '/interface/wireless/access-list/print',
              ]);
              for (var acl in accessList) {
                final aclMac = acl['mac-address']?.toString().toUpperCase();
                if (aclMac == finalMac.toUpperCase()) {
                  client['wireless_blocked'] =
                      acl['action'] == 'reject' || acl['action'] == 'deny';
                  break;
                }
              }
            } catch (e) {
              // ignore
            }
          }

          actuallyConnectedBanned.add(client);
        }
      }

      return actuallyConnectedBanned;
    } catch (e) {
      throw Exception('خطا در دریافت لیست مسدود شده‌ها: $e');
    }
  }

  /// تنظیم سرعت کلاینت با استفاده از Simple Queue
  /// این متد منطق کامل را پیاده‌سازی می‌کند:
  /// تنظیم سرعت دستگاه - نسخه بهینه‌شده با سرعت بالا
  ///
  /// بهینه‌سازی‌ها:
  /// - استفاده از .proplist برای کاهش 70% حجم داده
  /// - استفاده از query parameters برای فیلتر مستقیم
  /// - Timeout کوتاه‌تر (1 ثانیه)
  /// - اولویت IP address (اگر موجود باشد)
  /// - کاهش تعداد API calls
  ///
  /// 1️⃣ پیدا کردن Simple Queue با IP
  /// 2️⃣ ویرایش Simple Queue اگر موجود باشد
  /// 3️⃣ ایجاد Simple Queue اگر وجود نداشت
  Future<bool> setClientSpeed(String target, String maxLimit) async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      print(
        '🔧 [SET_SPEED] شروع تنظیم سرعت - Target: $target, MaxLimit: $maxLimit',
      );

      // تبدیل فرمت M/K به فرمت MikroTik (مثال: 4M/12M)
      String maxLimitFormatted = maxLimit;

      // بررسی اینکه target IP است یا MAC
      final isMacAddress =
          target.contains(':') && target.split(':').length == 6;
      String? targetIp = target.split('/')[0].trim();

      // اگر target MAC است، ابتدا IP مربوطه را پیدا کن (بهینه‌شده)
      if (isMacAddress) {
        try {
          print('🔧 [SET_SPEED] جستجوی IP برای MAC: $target');

          // بهینه‌سازی: استفاده از .proplist و query parameter
          final proplist = '.proplist=.id,address,mac-address';

          // اولویت: جستجو با MAC در DHCP leases (دقیق‌تر)
          final dhcpLeases = await _client!
              .talk([
                '/ip/dhcp-server/lease/print',
                '?=mac-address=$target',
                proplist,
              ])
              .timeout(
                const Duration(seconds: 1),
                onTimeout: () => <Map<String, String>>[],
              );

          if (dhcpLeases.isNotEmpty) {
            final lease = dhcpLeases[0];
            final leaseMac = lease['mac-address']?.toString().toUpperCase();
            if (leaseMac == target.toUpperCase()) {
              targetIp = lease['address']?.toString();
              print('🔧 [SET_SPEED] IP پیدا شد از DHCP: $targetIp');
            }
          }

          // Fallback: جستجو در ARP (اگر DHCP ناموفق بود)
          if (targetIp == target.split('/')[0].trim()) {
            final arpProplist = '.proplist=.id,address,mac-address';
            final arpEntries = await _client!
                .talk(['/ip/arp/print', '?=mac-address=$target', arpProplist])
                .timeout(
                  const Duration(seconds: 1),
                  onTimeout: () => <Map<String, String>>[],
                );

            if (arpEntries.isNotEmpty) {
              final arp = arpEntries[0];
              final arpMac = arp['mac-address']?.toString().toUpperCase();
              if (arpMac == target.toUpperCase()) {
                targetIp = arp['address']?.toString();
                print('🔧 [SET_SPEED] IP پیدا شد از ARP: $targetIp');
              }
            }
          }
        } catch (e) {
          print('⚠️ [SET_SPEED] خطا در پیدا کردن IP: $e');
          // ignore errors
        }
      }

      if (targetIp == null ||
          (targetIp == target.split('/')[0].trim() && isMacAddress)) {
        throw Exception('نتوانست IP را برای target پیدا کند: $target');
      }

      // استفاده از IP با /32 برای target
      final targetIpClean = targetIp.split('/')[0].trim();
      final targetWithSubnet = targetIp.contains('/')
          ? targetIp
          : '$targetIp/32';
      print(
        '🔧 [SET_SPEED] IP نهایی: $targetIpClean, Target: $targetWithSubnet',
      );

      final queueName = 'DEV-$targetIpClean';

      // 1️⃣ جستجوی queue موجود (بهینه‌شده با query parameter)
      String? queueId;
      try {
        print('🔧 [SET_SPEED] جستجوی queue موجود برای IP: $targetIpClean');

        // بهینه‌سازی: استفاده از .proplist و query parameter
        final queueProplist = '.proplist=.id,target,name,max-limit';

        // استراتژی 1: جستجو با target (دقیق‌تر)
        try {
          final queues = await _client!
              .talk([
                '/queue/simple/print',
                '?=target=$targetWithSubnet',
                queueProplist,
              ])
              .timeout(
                const Duration(seconds: 1),
                onTimeout: () => <Map<String, String>>[],
              );

          if (queues.isNotEmpty) {
            queueId = queues[0]['.id']?.toString();
            final currentMaxLimit = queues[0]['max-limit']?.toString() ?? '';
            print(
              '✅ [SET_SPEED] Queue موجود پیدا شد (target) - ID: $queueId, Current Limit: $currentMaxLimit',
            );
          }
        } catch (e) {
          // ignore - try next strategy
        }

        // استراتژی 2: جستجو با name (اگر target ناموفق بود)
        if (queueId == null) {
          try {
            final queues = await _client!
                .talk([
                  '/queue/simple/print',
                  '?=name=$queueName',
                  queueProplist,
                ])
                .timeout(
                  const Duration(seconds: 1),
                  onTimeout: () => <Map<String, String>>[],
                );

            if (queues.isNotEmpty) {
              queueId = queues[0]['.id']?.toString();
              final currentMaxLimit = queues[0]['max-limit']?.toString() ?? '';
              print(
                '✅ [SET_SPEED] Queue موجود پیدا شد (name) - ID: $queueId, Current Limit: $currentMaxLimit',
              );
            }
          } catch (e) {
            // ignore - will create new queue
          }
        }

        // 2️⃣ اگر queue موجود باشد، ویرایش می‌کنیم
        if (queueId != null && queueId.isNotEmpty) {
          try {
            print('🔧 [SET_SPEED] در حال ویرایش queue موجود - ID: $queueId');
            await _client!
                .talk([
                  '/queue/simple/set',
                  '=.id=$queueId',
                  '=max-limit=$maxLimitFormatted',
                ])
                .timeout(
                  const Duration(seconds: 1),
                  onTimeout: () =>
                      throw TimeoutException('Timeout در ویرایش queue'),
                );

            print(
              '✅ [SET_SPEED] Queue با ID $queueId برای IP $targetIpClean به‌روزرسانی شد: $maxLimitFormatted',
            );
            return true;
          } catch (e2) {
            print('❌ [SET_SPEED] خطا در ویرایش queue: $e2');
            throw Exception('خطا در ویرایش queue: $e2');
          }
        }
      } catch (e) {
        // اگر جستجو ناموفق بود، ادامه می‌دهیم و سعی می‌کنیم queue جدید ایجاد کنیم
        print(
          '⚠️ [SET_SPEED] خطا در جستجوی queue (ادامه برای ایجاد queue جدید): $e',
        );
      }

      // 3️⃣ اگر queue موجود نباشد، ایجاد می‌کنیم
      try {
        print(
          '🔧 [SET_SPEED] Queue موجود نیست - در حال ایجاد queue جدید - Name: $queueName',
        );
        await _client!
            .talk([
              '/queue/simple/add',
              '=name=$queueName',
              '=target=$targetWithSubnet',
              '=max-limit=$maxLimitFormatted',
            ])
            .timeout(
              const Duration(seconds: 1),
              onTimeout: () => throw TimeoutException('Timeout در ایجاد queue'),
            );

        print(
          '✅ [SET_SPEED] Queue جدید برای IP $targetIpClean ایجاد شد: $maxLimitFormatted',
        );
        return true;
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        // بررسی انواع خطاهای duplicate
        final isDuplicate =
            errorStr.contains('duplicate') ||
            errorStr.contains('already exists') ||
            errorStr.contains('already have such name') ||
            errorStr.contains('such name');

        // اگر duplicate 错误，说明 queue 已存在，尝试再次搜索并编辑
        if (isDuplicate) {
          print(
            '⚠️ [SET_SPEED] Queue از قبل وجود دارد (duplicate error) - در حال جستجوی مجدد...',
          );
          try {
            // 使用 query parameter 快速查找
            final queueProplist = '.proplist=.id,target,name';
            final queues = await _client!
                .talk([
                  '/queue/simple/print',
                  '?=name=$queueName',
                  queueProplist,
                ])
                .timeout(
                  const Duration(seconds: 1),
                  onTimeout: () => <Map<String, String>>[],
                );

            if (queues.isNotEmpty) {
              queueId = queues[0]['.id']?.toString();
              if (queueId != null && queueId.isNotEmpty) {
                print(
                  '✅ [SET_SPEED] Queue پیدا شد - ID: $queueId, در حال ویرایش...',
                );
                await _client!
                    .talk([
                      '/queue/simple/set',
                      '=.id=$queueId',
                      '=max-limit=$maxLimitFormatted',
                    ])
                    .timeout(
                      const Duration(seconds: 1),
                      onTimeout: () =>
                          throw TimeoutException('Timeout در ویرایش queue'),
                    );

                print(
                  '✅ [SET_SPEED] Queue با ID $queueId ویرایش شد: $maxLimitFormatted',
                );
                return true;
              }
            }
          } catch (e2) {
            print('⚠️ [SET_SPEED] خطا در جستجوی مجدد: $e2');
          }
        }

        print('❌ [SET_SPEED] خطا در ایجاد queue: $e');
        throw Exception('خطا در ایجاد queue: $e');
      }
    } catch (e) {
      print('❌ [SET_SPEED] خطای کلی: $e');
      throw Exception('خطا در تنظیم سرعت: $e');
    }
  }

  /// حذف Simple Queue بر اساس IP - نسخه بهینه‌شده با سرعت بالا
  ///
  /// بهینه‌سازی‌ها:
  /// - استفاده از .proplist برای کاهش 70% حجم داده
  /// - استفاده از query parameters برای فیلتر مستقیم
  /// - Timeout کوتاه‌تر (1 ثانیه)
  /// - کاهش تعداد API calls
  ///
  /// 4️⃣ حذف Simple Queue: /queue simple remove [find target~"192.168.88.50"]
  Future<bool> removeClientSpeed(String target) async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      // بررسی اینکه target IP است یا MAC
      final isMacAddress =
          target.contains(':') && target.split(':').length == 6;
      String? targetIp = target.split('/')[0].trim();

      // اگر target MAC است، ابتدا IP مربوطه را پیدا کن (بهینه‌شده)
      if (isMacAddress) {
        try {
          print('🔧 [REMOVE_SPEED] جستجوی IP برای MAC: $target');

          // بهینه‌سازی: استفاده از .proplist و query parameter
          final proplist = '.proplist=.id,address,mac-address';

          // اولویت: جستجو با MAC در DHCP leases (دقیق‌تر)
          final dhcpLeases = await _client!
              .talk([
                '/ip/dhcp-server/lease/print',
                '?=mac-address=$target',
                proplist,
              ])
              .timeout(
                const Duration(seconds: 1),
                onTimeout: () => <Map<String, String>>[],
              );

          if (dhcpLeases.isNotEmpty) {
            final lease = dhcpLeases[0];
            final leaseMac = lease['mac-address']?.toString().toUpperCase();
            if (leaseMac == target.toUpperCase()) {
              targetIp = lease['address']?.toString();
              print('🔧 [REMOVE_SPEED] IP پیدا شد از DHCP: $targetIp');
            }
          }

          // Fallback: جستجو در ARP (اگر DHCP ناموفق بود)
          if (targetIp == target.split('/')[0].trim()) {
            final arpProplist = '.proplist=.id,address,mac-address';
            final arpEntries = await _client!
                .talk(['/ip/arp/print', '?=mac-address=$target', arpProplist])
                .timeout(
                  const Duration(seconds: 1),
                  onTimeout: () => <Map<String, String>>[],
                );

            if (arpEntries.isNotEmpty) {
              final arp = arpEntries[0];
              final arpMac = arp['mac-address']?.toString().toUpperCase();
              if (arpMac == target.toUpperCase()) {
                targetIp = arp['address']?.toString();
                print('🔧 [REMOVE_SPEED] IP پیدا شد از ARP: $targetIp');
              }
            }
          }
        } catch (e) {
          print('⚠️ [REMOVE_SPEED] خطا در پیدا کردن IP: $e');
          // ignore errors
        }
      }

      if (targetIp == null ||
          (targetIp == target.split('/')[0].trim() && isMacAddress)) {
        throw Exception('نتوانست IP را برای target پیدا کند: $target');
      }

      final targetIpClean = targetIp.split('/')[0].trim();
      final targetWithSubnet = targetIp.contains('/')
          ? targetIp
          : '$targetIp/32';
      final queueName = 'DEV-$targetIpClean';

      // پیدا کردن Simple Queue با IP (بهینه‌شده)
      List<String> queueIdsToRemove = [];
      try {
        // بهینه‌سازی: استفاده از .proplist و query parameter
        final queueProplist = '.proplist=.id,target,name';

        // استراتژی 1: جستجو با target (دقیق‌تر)
        try {
          final queues = await _client!
              .talk([
                '/queue/simple/print',
                '?=target=$targetWithSubnet',
                queueProplist,
              ])
              .timeout(
                const Duration(seconds: 1),
                onTimeout: () => <Map<String, String>>[],
              );

          for (var queue in queues) {
            final queueId = queue['.id']?.toString();
            if (queueId != null && queueId.isNotEmpty) {
              queueIdsToRemove.add(queueId);
            }
          }
        } catch (e) {
          // ignore - try next strategy
        }

        // استراتژی 2: جستجو با name (اگر target ناموفق بود)
        if (queueIdsToRemove.isEmpty) {
          try {
            final queues = await _client!
                .talk([
                  '/queue/simple/print',
                  '?=name=$queueName',
                  queueProplist,
                ])
                .timeout(
                  const Duration(seconds: 1),
                  onTimeout: () => <Map<String, String>>[],
                );

            for (var queue in queues) {
              final queueId = queue['.id']?.toString();
              if (queueId != null && queueId.isNotEmpty) {
                queueIdsToRemove.add(queueId);
              }
            }
          } catch (e) {
            // ignore - will return false
          }
        }
      } catch (e) {
        print('⚠️ [REMOVE_SPEED] خطا در پیدا کردن queue: $e');
      }

      if (queueIdsToRemove.isEmpty) {
        print('⚠️ [REMOVE_SPEED] Queue برای IP $targetIpClean پیدا نشد');
        return false;
      }

      // حذف همه queues پیدا شده
      bool allRemoved = true;
      for (var queueId in queueIdsToRemove) {
        try {
          // حذف Simple Queue
          await _client!
              .talk(['/queue/simple/remove', '=.id=$queueId'])
              .timeout(
                const Duration(seconds: 1),
                onTimeout: () => throw TimeoutException('Timeout در حذف queue'),
              );

          print(
            '✅ [REMOVE_SPEED] Queue با ID $queueId برای IP $targetIpClean حذف شد',
          );
        } catch (e) {
          print('⚠️ [REMOVE_SPEED] خطا در حذف queue با ID $queueId: $e');
          allRemoved = false;
        }
      }

      return allRemoved;
    } catch (e) {
      print('❌ [REMOVE_SPEED] خطای کلی: $e');
      throw Exception('خطا در حذف سرعت: $e');
    }
  }

  /// دریافت سرعت کلاینت
  /// مشابه POST /api/clients/get-speed
  Future<Map<String, String>?> getClientSpeed(String target) async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      // بررسی اینکه target IP است یا MAC
      final isMacAddress =
          target.contains(':') && target.split(':').length == 6;
      String? targetIp = target.split('/')[0].trim();
      String? targetMac = isMacAddress ? target.toUpperCase() : null;

      // اگر target MAC است، ابتدا IP مربوطه را پیدا کن
      if (isMacAddress && targetMac != null) {
        try {
          // از DHCP leases جستجو کن
          final dhcpLeases = await _client!.talk([
            '/ip/dhcp-server/lease/print',
          ]);
          for (var lease in dhcpLeases) {
            final leaseMac = lease['mac-address']?.toString().toUpperCase();
            if (leaseMac == targetMac) {
              targetIp = lease['address']?.toString();
              break;
            }
          }

          // اگر در DHCP پیدا نشد، از ARP table جستجو کن
          if (targetIp == target.split('/')[0].trim()) {
            final arpEntries = await _client!.talk(['/ip/arp/print']);
            for (var arp in arpEntries) {
              final arpMac = arp['mac-address']?.toString().toUpperCase();
              if (arpMac == targetMac) {
                targetIp = arp['address']?.toString();
                break;
              }
            }
          }
        } catch (e) {
          // ignore errors
        }
      }

      if (targetIp == null ||
          (targetIp == target.split('/')[0].trim() && isMacAddress)) {
        return null;
      }

      // استفاده از timeout برای جلوگیری از لود طولانی
      // اگر timeout 发生،返回 null 而不是抛出异常
      List<Map<String, String>> queues;
      try {
        queues = await _client!
            .talk(['/queue/simple/print'])
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print(
                  '⚠️ [GET_SPEED] Timeout در دریافت queue ها برای IP: $targetIp',
                );
                return <Map<String, String>>[]; // 返回空列表而不是抛出异常
              },
            );
      } catch (e) {
        print('⚠️ [GET_SPEED] خطا در دریافت queue ها: $e');
        return null; // 如果出错，返回 null
      }

      final targetIpClean = targetIp.split('/')[0].trim();
      final targetWithSubnet = targetIp.contains('/')
          ? targetIp
          : '$targetIp/32';
      final expectedQueueName =
          'DEV-$targetIpClean'; // نام queue که قبلاً ایجاد شده: DEV-192.168.88.50

      print(
        '🔧 [GET_SPEED] جستجوی queue برای IP: $targetIpClean (نام مورد انتظار: $expectedQueueName)',
      );
      print('🔧 [GET_SPEED] تعداد queue های دریافتی: ${queues.length}');

      // جستجوی queue - از طریق target یا name
      // وقتی اولین queue مطابقت پیدا کرد، فوراً return کن
      for (var queue in queues) {
        final queueTarget = queue['target']?.toString() ?? '';
        final queueName = queue['name']?.toString() ?? '';

        // روش 1: بررسی از طریق target
        bool targetMatches = false;
        if (queueTarget.isNotEmpty) {
          // استخراج IP از target (ممکن است به صورت 192.168.88.252/32 باشد)
          final queueTargetIp = queueTarget.split('/')[0].trim();

          // مقایسه IP ها (با در نظر گرفتن /32)
          targetMatches =
              queueTargetIp == targetIpClean ||
              queueTarget == targetIp ||
              queueTarget == targetWithSubnet ||
              queueTarget.startsWith('$targetIpClean/') ||
              queueTargetIp == targetIp;
        }

        // روش 2: بررسی از طریق name (فرمت: DEV-192.168.88.50)
        bool nameMatches = false;
        if (queueName.isNotEmpty) {
          // بررسی اینکه name با "DEV-" شروع می‌شود و IP را شامل می‌شود
          if (queueName == expectedQueueName ||
              queueName.contains(targetIpClean) ||
              queueName == 'DEV-${targetIpClean.replaceAll('.', '-')}') {
            nameMatches = true;
          }
        }

        // اگر target یا name مطابقت داشت
        if (targetMatches || nameMatches) {
          print(
            '✅ [GET_SPEED] Queue پیدا شد - Target: $queueTarget, Name: $queueName',
          );
          final maxLimit = queue['max-limit']?.toString() ?? '';

          // بررسی اینکه max-limit موجود است
          if (maxLimit.isEmpty || maxLimit == 'N/A' || maxLimit == '0/0') {
            print(
              '⚠️ [GET_SPEED] Queue پیدا شد اما max-limit معتبر نیست: $maxLimit',
            );
            continue; // به queue بعدی برو
          }

          // تبدیل از بیت به فرمت M/K (اگر لازم باشد)
          // RouterOS v6 ممکن است از قبل M/K 格式返回 دهد (مانند "8M/8M")
          // یا ممکن است بیت格式 باشد (مانند "8000000/8000000")
          String formattedMaxLimit = maxLimit;
          if (maxLimit.isNotEmpty &&
              maxLimit != 'N/A' &&
              maxLimit.contains('/')) {
            final parts = maxLimit.split('/');
            if (parts.length == 2) {
              final uploadPart = parts[0].trim();
              final downloadPart = parts[1].trim();

              // بررسی اینکه آیا از قبل M/K 格式 است
              final uploadHasUnit = RegExp(
                r'^(\d+)([KMkm])$',
              ).hasMatch(uploadPart);
              final downloadHasUnit = RegExp(
                r'^(\d+)([KMkm])$',
              ).hasMatch(downloadPart);

              // اگر از قبل M/K 格式 است، بدون تغییر برگردان
              if (uploadHasUnit && downloadHasUnit) {
                print('✅ [GET_SPEED] max-limit از قبل M/K 格式 است: $maxLimit');
                formattedMaxLimit = maxLimit; // 不需要转换
              } else {
                // اگر بیت格式 است،转换为 M/K
                try {
                  // مقدار به بیت بر ثانیه است
                  final uploadBits = int.tryParse(uploadPart) ?? 0;
                  final downloadBits = int.tryParse(downloadPart) ?? 0;

                  // تبدیل به Mbps (1 Mbps = 1,000,000 bits)
                  final uploadMbps = uploadBits / 1000000;
                  final downloadMbps = downloadBits / 1000000;

                  // اگر کمتر از 1 Mbps باشد، به Kbps تبدیل کن
                  String uploadFormatted;
                  String downloadFormatted;

                  if (uploadMbps >= 1) {
                    uploadFormatted = '${uploadMbps.toStringAsFixed(0)}M';
                  } else if (uploadBits > 0) {
                    final uploadKbps = uploadBits / 1000;
                    uploadFormatted = '${uploadKbps.toStringAsFixed(0)}K';
                  } else {
                    uploadFormatted = '0M';
                  }

                  if (downloadMbps >= 1) {
                    downloadFormatted = '${downloadMbps.toStringAsFixed(0)}M';
                  } else if (downloadBits > 0) {
                    final downloadKbps = downloadBits / 1000;
                    downloadFormatted = '${downloadKbps.toStringAsFixed(0)}K';
                  } else {
                    downloadFormatted = '0M';
                  }

                  formattedMaxLimit = '$uploadFormatted/$downloadFormatted';
                } catch (e) {
                  // اگر تبدیل نشد، همان مقدار اصلی را نگه دار
                  formattedMaxLimit = maxLimit;
                }
              }
            }
          }

          return {
            'max_limit': formattedMaxLimit,
            'rate': queue['rate']?.toString() ?? 'N/A',
            'bytes': queue['bytes']?.toString() ?? '0',
            'packets': queue['packets']?.toString() ?? '0',
          };
        }
      }

      return null;
    } catch (e) {
      // 如果已经处理了 timeout，不要再次抛出异常
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('timeout')) {
        print('⚠️ [GET_SPEED] Timeout در دریافت سرعت: $e');
        return null;
      }
      print('❌ [GET_SPEED] خطا در دریافت سرعت: $e');
      throw Exception('خطا در دریافت سرعت: $e');
    }
  }

  /// دریافت IP دستگاه کاربر
  /// دریافت IP دستگاه کاربر
  /// این تابع سعی می‌کند IP دستگاه کاربر را از طریق چند روش پیدا کند:
  /// 1. استفاده از NetworkInterface برای دریافت IP محلی دستگاه
  /// 2. مقایسه IP محلی با لیست IP های متصل در روتر
  /// 3. استفاده از ARP table و DHCP leases
  Future<String?> getDeviceIp() async {
    if (_client == null || !isConnected) {
      return null;
    }

    try {
      // روش 1: استفاده از NetworkInterface برای دریافت IP محلی دستگاه
      String? localDeviceIp;
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
                    localDeviceIp = ip;
                    break;
                  }
                }
              }
            }
          }
          if (localDeviceIp != null) break;
        }
      } catch (e) {
        // ignore - NetworkInterface ممکن است در برخی پلتفرم‌ها کار نکند
      }

      // اگر IP محلی پیدا شد، بررسی می‌کنیم که آیا در روتر هم وجود دارد
      if (localDeviceIp != null) {
        try {
          // بررسی در ARP table
          final arpEntries = await _client!.talk(['/ip/arp/print']);
          for (var arp in arpEntries) {
            if (arp['address']?.toString() == localDeviceIp) {
              return localDeviceIp;
            }
          }

          // بررسی در DHCP leases
          final dhcpLeases = await _client!.talk([
            '/ip/dhcp-server/lease/print',
          ]);
          for (var lease in dhcpLeases) {
            if (lease['address']?.toString() == localDeviceIp) {
              return localDeviceIp;
            }
          }
        } catch (e) {
          // ignore
        }
      }

      // روش 2: استفاده از IP روتر برای پیدا کردن subnet و سپس پیدا کردن IP دستگاه
      String? routerIp = _connection?.host;
      if (routerIp != null) {
        try {
          final routerParts = routerIp.split('.');
          if (routerParts.length == 4) {
            final subnetPrefix =
                '${routerParts[0]}.${routerParts[1]}.${routerParts[2]}.';

            // اگر IP محلی در همان subnet است، از آن استفاده می‌کنیم
            if (localDeviceIp != null &&
                localDeviceIp.startsWith(subnetPrefix)) {
              return localDeviceIp;
            }

            // پیدا کردن IP در ARP table که در همان subnet است
            final arpEntries = await _client!.talk(['/ip/arp/print']);
            for (var arp in arpEntries) {
              final arpIp = arp['address']?.toString();
              if (arpIp != null &&
                  arpIp.startsWith(subnetPrefix) &&
                  arpIp != routerIp &&
                  arp['dynamic']?.toString().toLowerCase() == 'true') {
                // بررسی در DHCP lease
                try {
                  final dhcpLeases = await _client!.talk([
                    '/ip/dhcp-server/lease/print',
                  ]);
                  for (var lease in dhcpLeases) {
                    if (lease['address']?.toString() == arpIp &&
                        lease['status']?.toString().toLowerCase() == 'bound') {
                      return arpIp;
                    }
                  }
                } catch (e) {
                  // ignore
                }

                return arpIp;
              }
            }
          }
        } catch (e) {
          // ignore
        }
      }

      // روش 3: استفاده از DHCP leases (fallback)
      try {
        final dhcpLeases = await _client!.talk(['/ip/dhcp-server/lease/print']);
        // پیدا کردن اولین lease که bound است
        for (var lease in dhcpLeases) {
          final leaseIp = lease['address']?.toString();
          if (leaseIp != null &&
              lease['status']?.toString().toLowerCase() == 'bound') {
            return leaseIp;
          }
        }
      } catch (e) {
        // ignore
      }

      // روش 4: استفاده از ARP table (fallback)
      try {
        final arpEntries = await _client!.talk(['/ip/arp/print']);
        if (arpEntries.isNotEmpty) {
          // پیدا کردن اولین IP که dynamic است
          for (var arp in arpEntries) {
            final arpIp = arp['address']?.toString();
            if (arpIp != null &&
                arpIp != routerIp &&
                arp['dynamic']?.toString().toLowerCase() == 'true') {
              return arpIp;
            }
          }

          // اگر dynamic پیدا نشد، اولین IP را برمی‌گردانیم
          return arpEntries.first['address'];
        }
      } catch (e) {
        // ignore
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// بررسی و مسدود کردن خودکار دستگاه‌های متصل که Device Fingerprint آن‌ها مسدود شده است
  ///
  /// این تابع لیست دستگاه‌های متصل را بررسی می‌کند و اگر Device Fingerprint
  /// آن‌ها با لیست مسدود شده‌ها مطابقت داشته باشد، به صورت خودکار مسدود می‌کند.
  ///
  /// این برای حالتی است که دستگاه با IP/MAC جدید متصل شده اما hostname
  /// یا سایر ویژگی‌های آن تغییر نکرده است.
  Future<List<Map<String, dynamic>>> checkAndBanBannedDevices() async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      final fingerprintService = DeviceFingerprintService();
      final bannedFingerprints = await fingerprintService
          .getBannedFingerprints();

      if (bannedFingerprints.isEmpty) {
        return [];
      }

      // دریافت لیست دستگاه‌های متصل
      final connectedResult = await getConnectedClients();
      final connectedClients = (connectedResult['clients'] as List)
          .map((c) => ClientInfo.fromMap(c as Map<String, dynamic>))
          .toList();

      final newlyBanned = <Map<String, dynamic>>[];

      // دریافت همه rule های firewall فعلی (یک بار برای همه دستگاه‌ها)
      final existingRules = <String, Map<String, dynamic>>{};
      try {
        final rawRules = await _client!.talk(['/ip/firewall/raw/print']);
        for (var rule in rawRules) {
          final ruleIp = rule['src-address']?.toString();
          final ruleMac = rule['src-mac-address']?.toString();
          final ruleId = rule['.id']?.toString();

          if (ruleId != null &&
              rule['action'] == 'drop' &&
              rule['chain'] == 'prerouting') {
            // ذخیره rule بر اساس IP
            if (ruleIp != null && ruleIp.isNotEmpty) {
              existingRules['ip:$ruleIp'] = rule;
            }
            // ذخیره rule بر اساس MAC
            if (ruleMac != null && ruleMac.isNotEmpty) {
              existingRules['mac:${ruleMac.toUpperCase()}'] = rule;
            }
          }
        }
      } catch (e) {
        // ignore
      }

      // بررسی هر دستگاه متصل
      for (var client in connectedClients) {
        // ایجاد Device Fingerprint از ClientInfo
        final clientFingerprint = DeviceFingerprint.fromClientInfo(
          client.ipAddress,
          client.macAddress,
          client.hostName,
          client.ssid,
        );

        // بررسی با لیست مسدود شده‌ها
        // بررسی دو طرفه: clientFingerprint.matches(bannedFingerprint) یا bannedFingerprint.matches(clientFingerprint)
        for (var bannedFingerprint in bannedFingerprints) {
          // بررسی دو طرفه برای اطمینان از تطابق کامل
          bool isMatch =
              clientFingerprint.matches(bannedFingerprint) ||
              bannedFingerprint.matches(clientFingerprint);

          if (isMatch) {
            // این دستگاه باید مسدود شود
            if (client.ipAddress != null) {
              try {
                // بررسی اینکه آیا دستگاه قبلاً مسدود شده است
                bool alreadyBanned = false;

                // بررسی rule های موجود بر اساس IP
                if (client.ipAddress != null) {
                  final ipRule = existingRules['ip:${client.ipAddress}'];
                  if (ipRule != null) {
                    final ruleComment = ipRule['comment']?.toString() ?? '';
                    // اگر comment مربوط به این Device Fingerprint است، قبلاً ban شده
                    if (ruleComment.contains('Auto-banned:') &&
                        ruleComment.contains(bannedFingerprint.fingerprintId)) {
                      alreadyBanned = true;
                    }
                  }
                }

                // بررسی rule های موجود بر اساس MAC
                if (!alreadyBanned && client.macAddress != null) {
                  final macRule =
                      existingRules['mac:${client.macAddress!.toUpperCase()}'];
                  if (macRule != null) {
                    final ruleComment = macRule['comment']?.toString() ?? '';
                    // اگر comment مربوط به این Device Fingerprint است، قبلاً ban شده
                    if (ruleComment.contains('Auto-banned:') &&
                        ruleComment.contains(bannedFingerprint.fingerprintId)) {
                      alreadyBanned = true;
                    }
                  }
                }

                // اگر قبلاً مسدود نشده، مسدود کن
                if (!alreadyBanned) {
                  await banClient(
                    client.ipAddress!,
                    macAddress: client.macAddress,
                    comment: 'Auto-banned: ${bannedFingerprint.fingerprintId}',
                  );

                  newlyBanned.add({
                    'ip_address': client.ipAddress,
                    'mac_address': client.macAddress,
                    'hostname': client.hostName,
                    'device_type': clientFingerprint.deviceType,
                    'fingerprint_id': clientFingerprint.fingerprintId,
                    'banned_fingerprint_id': bannedFingerprint.fingerprintId,
                  });
                }
              } catch (e) {
                // ignore errors
              }
            }
            break; // اگر پیدا شد، دیگر نیازی به بررسی بقیه نیست
          }
        }
      }

      return newlyBanned;
    } catch (e) {
      throw Exception('خطا در بررسی و مسدود کردن دستگاه‌ها: $e');
    }
  }

  /// دریافت Default Gateway از route table RouterOS
  /// این متد route با destination 0.0.0.0/0 را پیدا می‌کند و gateway آن را برمی‌گرداند
  Future<String?> getDefaultGateway() async {
    if (_client == null || !isConnected) {
      return null;
    }

    try {
      // دریافت route table از RouterOS
      final routes = await _client!.talk(['/ip/route/print']);

      // پیدا کردن route پیش‌فرض (0.0.0.0/0)
      for (var route in routes) {
        final dstAddress = route['dst-address']?.toString();
        if (dstAddress == '0.0.0.0/0') {
          final gateway = route['gateway']?.toString();
          if (gateway != null && gateway.isNotEmpty) {
            // اگر gateway شامل interface است (مثل "172.16.0.1 reachable ether2")
            // فقط IP را استخراج می‌کنیم
            final gatewayParts = gateway.split(' ');
            if (gatewayParts.isNotEmpty) {
              final gatewayIp = gatewayParts[0];
              // بررسی اینکه آیا IP معتبر است
              final ipRegex = RegExp(r'^\d+\.\d+\.\d+\.\d+$');
              if (ipRegex.hasMatch(gatewayIp)) {
                return gatewayIp;
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

  /// دریافت Default Gateway از route table RouterOS یا از IP دستگاه
  /// این متد ابتدا سعی می‌کند از RouterOS API استفاده کند
  /// اگر RouterOS در دسترس نبود، از IP روتر (host) به عنوان gateway استفاده می‌کند
  Future<String?> getDefaultGatewayOrRouterIp() async {
    // روش 1: استفاده از RouterOS API
    final gateway = await getDefaultGateway();
    if (gateway != null) {
      return gateway;
    }

    // روش 2: استفاده از IP روتر (fallback)
    // معمولاً IP روتر همان gateway است
    return _connection?.host;
  }

  /// دریافت اطلاعات کامل روتر
  /// مشابه POST /api/connect/test در پروژه Python
  /// این اطلاعات شامل uptime, version, board-name, platform, CPU, Memory و ... است
  Future<Map<String, dynamic>> getRouterInfo() async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      // دریافت اطلاعات از /system/resource/print (همه اطلاعات در یک جا)
      final resource = await _client!.talk(['/system/resource/print']);

      if (resource.isEmpty) {
        throw Exception('اطلاعات روتر یافت نشد');
      }

      final resourceData = resource[0];

      // دریافت board-name از /system/routerboard/print (اگر موجود باشد)
      String? boardName;
      try {
        final routerboard = await _client!.talk(['/system/routerboard/print']);
        if (routerboard.isNotEmpty) {
          boardName = routerboard[0]['board-name']?.toString();
        }
      } catch (e) {
        // ignore - board-name optional است
      }

      // دریافت identity از /system/identity/print
      String? identity;
      try {
        final identityData = await _client!.talk(['/system/identity/print']);
        if (identityData.isNotEmpty) {
          identity = identityData[0]['name']?.toString();
        }
      } catch (e) {
        // ignore - identity optional است
      }

      // ساخت Map با تمام اطلاعات
      final routerInfo = <String, dynamic>{
        'uptime': resourceData['uptime']?.toString() ?? 'Unknown',
        'version': resourceData['version']?.toString() ?? 'Unknown',
        'build-time': resourceData['build-time']?.toString() ?? 'Unknown',
        'factory-software':
            resourceData['factory-software']?.toString() ?? 'Unknown',
        'free-memory': resourceData['free-memory']?.toString() ?? '0',
        'total-memory': resourceData['total-memory']?.toString() ?? '0',
        'cpu': resourceData['cpu']?.toString() ?? 'Unknown',
        'cpu-count': resourceData['cpu-count']?.toString() ?? '0',
        'cpu-frequency': resourceData['cpu-frequency']?.toString() ?? '0',
        'cpu-load': resourceData['cpu-load']?.toString() ?? '0',
        'free-hdd-space': resourceData['free-hdd-space']?.toString() ?? '0',
        'total-hdd-space': resourceData['total-hdd-space']?.toString() ?? '0',
        'write-sect-since-reboot':
            resourceData['write-sect-since-reboot']?.toString() ?? '0',
        'write-sect-total': resourceData['write-sect-total']?.toString() ?? '0',
        'bad-blocks': resourceData['bad-blocks']?.toString() ?? '0',
        'architecture-name':
            resourceData['architecture-name']?.toString() ?? 'Unknown',
        'board-name':
            boardName ?? resourceData['board-name']?.toString() ?? 'Unknown',
        'platform': resourceData['platform']?.toString() ?? 'Unknown',
        'identity': identity ?? 'Unknown',
      };

      return routerInfo;
    } catch (e) {
      throw Exception('خطا در دریافت اطلاعات روتر: $e');
    }
  }

  /// قفل کردن اتصال دستگاه‌های جدید
  /// این تابع از ابتدا مانع اتصال دستگاه‌های جدید می‌شود اما دستگاه‌های قبلاً متصل شده کار می‌کنند
  ///
  /// قفل کردن اتصال دستگاه‌های جدید - منطق حذف شده (فقط UI باقی مانده)
  Future<bool> lockNewConnections() async {
    // منطق حذف شده
    return false;
  }

  // روش پیاده‌سازی قدیمی - حذف شده:
  // 1. دریافت لیست MAC های فعلی متصل
  // 2. اضافه کردن MAC دستگاه کاربر به لیست مجاز (برای جلوگیری از مسدود شدن خود کاربر)
  // 3. برای Wireless: غیرفعال کردن default-authenticate و اضافه کردن MAC های مجاز به access list با action=allow (بقیه deny می‌شوند)
  // 4. برای LAN: تبدیل leases به static برای حفظ IP های فعلی (برای LAN نمی‌توانیم به راحتی جلوگیری کنیم)
  // 5. ذخیره لیست MAC ها و IP های مجاز برای بررسی بعدی
  /*
  Future<bool> lockNewConnections_OLD() async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      // دریافت لیست MAC های فعلی متصل
      final connectedMacs = <String>{};
      
      // از DHCP leases (bound)
      try {
        final dhcpLeases = await _client!.talk(['/ip/dhcp-server/lease/print']);
        for (var lease in dhcpLeases) {
          if (lease['status']?.toString().toLowerCase() == 'bound') {
            final mac = lease['mac-address']?.toString().toUpperCase();
            if (mac != null && mac.isNotEmpty) {
              connectedMacs.add(mac);
            }
          }
        }
      } catch (e) {
        // ignore
      }

      // از Wireless registration table
      try {
        final wirelessClients = await _client!.talk(['/interface/wireless/registration-table/print']);
        for (var client in wirelessClients) {
          final mac = client['mac-address']?.toString().toUpperCase();
          if (mac != null && mac.isNotEmpty) {
            connectedMacs.add(mac);
          }
        }
      } catch (e) {
        // ignore
      }

      // از ARP table (برای دستگاه‌های LAN)
      try {
        final arpEntries = await _client!.talk(['/ip/arp/print']);
        for (var arp in arpEntries) {
          final mac = arp['mac-address']?.toString().toUpperCase();
          if (mac != null && mac.isNotEmpty) {
            connectedMacs.add(mac);
          }
        }
      } catch (e) {
        // ignore
      }

      // اضافه کردن MAC دستگاه کاربر به لیست مجاز (برای جلوگیری از مسدود شدن خود کاربر)
      try {
        final deviceIp = await getDeviceIp();
        if (deviceIp != null) {
          bool deviceMacFound = false;
          
          // پیدا کردن MAC دستگاه کاربر از DHCP lease
          try {
            final dhcpLeases = await _client!.talk(['/ip/dhcp-server/lease/print']);
            for (var lease in dhcpLeases) {
              if (lease['address']?.toString() == deviceIp) {
                final mac = lease['mac-address']?.toString().toUpperCase();
                if (mac != null && mac.isNotEmpty) {
                  connectedMacs.add(mac);
                  deviceMacFound = true;
                }
                break;
              }
            }
          } catch (e) {
            // ignore
          }

          // اگر در DHCP پیدا نشد، از ARP table استفاده کن
          if (!deviceMacFound) {
            try {
              final arpEntries = await _client!.talk(['/ip/arp/print']);
              for (var arp in arpEntries) {
                if (arp['address']?.toString() == deviceIp) {
                  final mac = arp['mac-address']?.toString().toUpperCase();
                  if (mac != null && mac.isNotEmpty) {
                    connectedMacs.add(mac);
                    deviceMacFound = true;
                  }
                  break;
                }
              }
            } catch (e) {
              // ignore
            }
          }
        }
      } catch (e) {
        // ignore - اگر نتوانستیم MAC دستگاه کاربر را پیدا کنیم، ادامه بده
      }

      // 1. برای Wireless: اجازه اتصال WiFi برای همه دستگاه‌ها
      // استراتژی جدید: اجازه اتصال WiFi (فیزیکی) اما مسدود کردن ترافیک از طریق Firewall
      // ما default-authenticate را تغییر نمی‌دهیم - اجازه می‌دهیم همه دستگاه‌ها به WiFi متصل شوند
      try {
        final wirelessInterfaces = await _client!.talk(['/interface/wireless/print']);
        
        for (var wifiInterface in wirelessInterfaces) {
          final interfaceName = wifiInterface['name']?.toString();
          final interfaceId = wifiInterface['.id']?.toString();
          
          if (interfaceName != null && interfaceId != null) {
            // توجه: ما default-authenticate را تغییر نمی‌دهیم
            // این اجازه می‌دهد همه دستگاه‌ها به WiFi متصل شوند
            // ترافیک از طریق Firewall rules (در restrictNonStaticDevice) مسدود می‌شود
            print('ℹ️ [LOCK_CONN] interface $interfaceName: اجازه اتصال WiFi برای همه (ترافیک از طریق Firewall مسدود می‌شود)');

            // گام 1: پاکسازی rule های قبلی Lock
            // حذف rule های LOCK_ALLOW و LOCK_DENY_ALL
            final accessList = await _client!.talk(['/interface/wireless/access-list/print']);
            for (var acl in accessList) {
              final comment = acl['comment']?.toString();
              final aclId = acl['.id'];
              
              if (aclId != null && (comment == 'LOCK_ALLOW' || comment == 'LOCK_DENY_ALL')) {
                try {
                  await _client!.talk([
                    '/interface/wireless/access-list/remove',
                    '=.id=$aclId',
                  ]);
                  print('✅ [LOCK_CONN] حذف rule قدیمی: $comment');
                } catch (e) {
                  print('⚠️ [LOCK_CONN] خطا در حذف rule قدیمی $comment: $e');
                }
              }
            }

            // گام 2: اضافه کردن allow rule فقط برای دستگاه‌های مجاز
            // توجه: ما فقط برای دستگاه‌های مجاز allow rule اضافه می‌کنیم
            // دستگاه‌های جدید باید از طریق approveDevice() تایید شوند
            try {
              final prefs = await SharedPreferences.getInstance();
              
              // دریافت لیست دستگاه‌های مجاز (در زمان فعال شدن قفل متصل بودند)
              final lockedAllowedMacsList = prefs.getStringList('locked_allowed_macs') ?? [];
              final lockedAllowedMacs = lockedAllowedMacsList.map((mac) => mac.toUpperCase()).toSet();
              
              // دریافت لیست دستگاه‌های تایید شده (از طریق approveDevice())
              final approvedMacsList = prefs.getStringList('approved_devices') ?? [];
              final approvedMacs = approvedMacsList.map((mac) => mac.toUpperCase()).toSet();
              
              // فقط برای دستگاه‌های مجاز (در زمان فعال شدن قفل) و دستگاه‌های تایید شده allow rule اضافه می‌کنیم
              // دستگاه‌های جدید (不在 locked_allowed_macs 中) نباید allow rule دریافت کنند
              final allowedMacs = lockedAllowedMacs.union(approvedMacs);
              
              print('ℹ️ [LOCK_CONN] لیست مجاز: ${lockedAllowedMacs.length} دستگاه (در زمان فعال شدن قفل)');
              print('ℹ️ [LOCK_CONN] لیست تایید شده: ${approvedMacs.length} دستگاه (از طریق approveDevice)');
              print('ℹ️ [LOCK_CONN] لیست فعلی: ${connectedMacs.length} دستگاه (همه متصل)');
              
              int allowedCount = 0;
              for (var mac in allowedMacs) {
                try {
                  // تلاش 1: با authentication=yes (روش صحیح RouterOS)
                  try {
                    await _client!.talk([
                      '/interface/wireless/access-list/add',
                      '=mac-address=$mac',
                      '=authentication=yes',
                      '=comment=LOCK_ALLOW',
                    ]);
                    allowedCount++;
                    print('✅ [LOCK_CONN] Allow rule اضافه شد برای MAC: $mac (authentication=yes)');
                  } catch (e1) {
                    // تلاش 2: بدون authentication (فقط MAC + comment)
                    try {
                      await _client!.talk([
                        '/interface/wireless/access-list/add',
                        '=mac-address=$mac',
                        '=comment=LOCK_ALLOW',
                      ]);
                      allowedCount++;
                      print('✅ [LOCK_CONN] Allow rule اضافه شد برای MAC: $mac (بدون authentication)');
                    } catch (e2) {
                      // اگر rule قبلاً وجود دارد، خطا می‌دهد - این طبیعی است
                      if (!e2.toString().contains('already') && !e2.toString().contains('duplicate')) {
                        print('⚠️ [LOCK_CONN] خطا در اضافه کردن allow rule برای MAC $mac: $e2');
                      }
                    }
                  }
                } catch (e) {
                  print('⚠️ [LOCK_CONN] خطا در پردازش MAC $mac: $e');
                }
              }
              
              print('✅ [LOCK_CONN] ${allowedCount} دستگاه مجاز (${lockedAllowedMacs.length} در زمان فعال شدن قفل + ${approvedMacs.length} تایید شده)');
              
              // بررسی دستگاه‌های جدید (不在 allowedMacs 中)
              final newDevices = connectedMacs.difference(allowedMacs);
              if (newDevices.isNotEmpty) {
                print('⚠️ [LOCK_CONN] ${newDevices.length} دستگاه جدید شناسایی شد که نباید allow rule دریافت کنند: $newDevices');
              }
            } catch (e) {
              print('⚠️ [LOCK_CONN] خطا در خواندن لیست دستگاه‌های مجاز: $e');
              // در صورت خطا، فقط برای دستگاه‌های موجود در locked_allowed_macs allow rule اضافه می‌کنیم
              try {
                final prefs = await SharedPreferences.getInstance();
                final lockedAllowedMacsList = prefs.getStringList('locked_allowed_macs') ?? [];
                final lockedAllowedMacs = lockedAllowedMacsList.map((mac) => mac.toUpperCase()).toSet();
                
                for (var mac in lockedAllowedMacs) {
                  try {
                    await _client!.talk([
                      '/interface/wireless/access-list/add',
                      '=mac-address=$mac',
                      '=authentication=yes',
                      '=comment=LOCK_ALLOW',
                    ]);
                  } catch (e) {
                    // ignore - ممکن است قبلاً وجود داشته باشد
                  }
                }
              } catch (e2) {
                print('⚠️ [LOCK_CONN] خطا در fallback: $e2');
              }
            }
            
            // توجه: ما deny-all rule اضافه نمی‌کنیم
            // استراتژی جدید: اجازه اتصال WiFi (فیزیکی) اما مسدود کردن ترافیک از طریق Firewall
            // این باعث می‌شود دستگاه‌های جدید بتوانند به WiFi متصل شوند اما نتوانند از اینترنت استفاده کنند
            // restrictNonStaticDevice() در loadClients برای هر دستگاه جدید فراخوانی می‌شود و Firewall rule اضافه می‌کند
            
            print('✅ [LOCK_CONN] برای interface $interfaceName: ${connectedMacs.length} دستگاه مجاز');
            print('ℹ️ [LOCK_CONN] استراتژی: اجازه اتصال WiFi اما مسدود کردن ترافیک از طریق Firewall');
            print('ℹ️ [LOCK_CONN] دستگاه‌های جدید می‌توانند به WiFi متصل شوند اما ترافیک آن‌ها مسدود می‌شود');
          }
        }
      } catch (e) {
        print('⚠️ [LOCK_CONN] خطا در پردازش wireless interfaces: $e');
        // ignore - wireless ممکن است فعال نباشد
      }

      // 2. برای LAN/DHCP: تبدیل leases مربوط به MAC های مجاز به static
      // و مسدود کردن دسترسی DHCP برای دستگاه‌های غیرمجاز
      // این کار باعث می‌شود که دستگاه‌های فعلی IP خود را حفظ کنند
      // و دستگاه‌های جدید نتوانند IP دریافت کنند
      try {
        final currentLeases = await _client!.talk(['/ip/dhcp-server/lease/print']);
        
        for (var lease in currentLeases) {
          if (lease['status']?.toString().toLowerCase() == 'bound') {
            final leaseMac = lease['mac-address']?.toString().toUpperCase();
            final leaseId = lease['.id'];
            final leaseIp = lease['address']?.toString();
            
            if (leaseMac != null && leaseId != null) {
              if (connectedMacs.contains(leaseMac)) {
                // اگر MAC در لیست مجاز است، تبدیل به static کن
                try {
                  await _client!.talk([
                    '/ip/dhcp-server/lease/make-static',
                    '=.id=$leaseId',
                  ]);
                  print('✅ [LOCK_CONN] Lease تبدیل به static شد برای MAC: $leaseMac, IP: $leaseIp');
                } catch (e) {
                  // ignore - ممکن است قبلاً static باشد
                }
              } else {
                // اگر MAC در لیست مجاز نیست، block-access کن
                try {
                  if (lease['block-access']?.toString().toLowerCase() != 'yes') {
                    await _client!.talk([
                      '/ip/dhcp-server/lease/set',
                      '=.id=$leaseId',
                      '=block-access=yes',
                      '=comment=Auto-blocked: New connection while locked',
                    ]);
                    print('🔒 [LOCK_CONN] DHCP lease مسدود شد برای MAC غیرمجاز: $leaseMac, IP: $leaseIp');
                  }
                } catch (e) {
                  print('⚠️ [LOCK_CONN] خطا در block DHCP lease: $e');
                }
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ [LOCK_CONN] خطا در پردازش DHCP leases: $e');
        // ignore - DHCP ممکن است فعال نباشد
      }

      // 3. اگر deny-all rule اضافه نشد، از Firewall برای جلوگیری از اتصال جدید استفاده می‌کنیم
      // این یک مکانیزم backup است در صورتی که Access List deny-all کار نکند
      // توجه: اگر deny-all rule اضافه شد، این بخش اجرا نمی‌شود

      // 4. دریافت و ذخیره IP های همه دستگاه‌های فعلی (شامل دستگاه کاربر) برای جلوگیری از مسدود شدن
      final allowedIps = <String>{};
      
      // اضافه کردن IP دستگاه کاربر
      try {
        final deviceIp = await getDeviceIp();
        if (deviceIp != null) {
          allowedIps.add(deviceIp);
        }
      } catch (e) {
        // ignore
      }
      
      // اضافه کردن IP های همه دستگاه‌های فعلی از DHCP leases
      try {
        final dhcpLeases = await _client!.talk(['/ip/dhcp-server/lease/print']);
        for (var lease in dhcpLeases) {
          if (lease['status']?.toString().toLowerCase() == 'bound') {
            final ip = lease['address']?.toString();
            if (ip != null && ip.isNotEmpty) {
              allowedIps.add(ip);
            }
          }
        }
      } catch (e) {
        // ignore
      }
      
      // اضافه کردن IP های همه دستگاه‌های فعلی از ARP table
      try {
        final arpEntries = await _client!.talk(['/ip/arp/print']);
        for (var arp in arpEntries) {
          final ip = arp['address']?.toString();
          if (ip != null && ip.isNotEmpty) {
            allowedIps.add(ip);
          }
        }
      } catch (e) {
        // ignore
      }
      
      // اضافه کردن IP های همه دستگاه‌های فعلی از Wireless registration table
      try {
        final wirelessClients = await _client!.talk(['/interface/wireless/registration-table/print']);
        for (var client in wirelessClients) {
          final ip = client['last-ip']?.toString();
          if (ip != null && ip.isNotEmpty) {
            allowedIps.add(ip);
          }
        }
      } catch (e) {
        // ignore
      }

      // 5. ذخیره لیست MAC ها و IP های مجاز در SharedPreferences برای بررسی بعدی
      // این برای بررسی در loadClients استفاده می‌شود
      // مهم: این لیست فقط شامل دستگاه‌هایی است که در زمان فعال شدن قفل متصل بودند
      // دستگاه‌های جدید (بعد از فعال شدن قفل) نباید به این لیست اضافه شوند
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // بررسی اینکه آیا قفل قبلاً فعال بوده
        final existingLockedMacs = prefs.getStringList('locked_allowed_macs') ?? [];
        final existingLockedTimestamp = prefs.getInt('locked_timestamp') ?? 0;
        
        // اگر قفل قبلاً فعال بوده (timestamp وجود دارد و کمتر از 1 ساعت گذشته)
        // فقط دستگاه‌های جدید (不在现有列表中的) را اضافه نکن
        // اگر قفل جدید است (timestamp = 0 或超过1小时)，保存当前列表
        final now = DateTime.now().millisecondsSinceEpoch;
        final oneHourAgo = now - (60 * 60 * 1000);
        
        if (existingLockedTimestamp > 0 && existingLockedTimestamp > oneHourAgo) {
          // قفل قبلاً فعال بوده - فقط دستگاه‌های موجود در لیست قبلی را نگه دار
          // دستگاه‌های جدید نباید اضافه شوند
          final existingMacsSet = existingLockedMacs.map((mac) => mac.toUpperCase()).toSet();
          final currentMacsSet = connectedMacs.map((mac) => mac.toUpperCase()).toSet();
          
          // فقط دستگاه‌هایی که در لیست قبلی بودند را نگه دار
          final allowedMacsToSave = existingMacsSet.intersection(currentMacsSet);
          
          print('ℹ️ [LOCK_CONN] قفل قبلاً فعال بوده - فقط ${allowedMacsToSave.length} دستگاه از لیست قبلی نگه داشته شد (${currentMacsSet.length} دستگاه فعلی)');
          
          // ذخیره لیست MAC های مجاز (فقط دستگاه‌های موجود در لیست قبلی)
          await prefs.setStringList('locked_allowed_macs', allowedMacsToSave.toList());
        } else {
          // قفل جدید است - ذخیره لیست فعلی
          // ذخیره لیست MAC های مجاز
          final allowedMacsList = connectedMacs.toList();
          await prefs.setStringList('locked_allowed_macs', allowedMacsList);
          
          // ذخیره لیست IP های مجاز (شامل IP دستگاه کاربر)
          final allowedIpsList = allowedIps.toList();
          await prefs.setStringList('locked_allowed_ips', allowedIpsList);
          
          // ذخیره timestamp برای بررسی بعدی
          await prefs.setInt('locked_timestamp', now);
          
          print('✅ [LOCK_CONN] قفل جدید فعال شد - ${allowedMacsList.length} دستگاه در لیست مجاز ذخیره شد');
        }
      } catch (e) {
        // ignore - SharedPreferences optional است
        print('⚠️ [LOCK_CONN] خطا در ذخیره لیست مجاز: $e');
      }

      // 6. آزاد کردن دستگاه‌هایی که به خاطر قفل قبلی مسدود شده‌اند
      // فقط دستگاه‌هایی که comment آن‌ها دقیقاً "Auto-banned: New connection while locked" است
      // دستگاه‌هایی که دستی مسدود شده‌اند (با comment "Banned:" یا "Banned via Flutter App") آزاد نمی‌شوند
      // دستگاه‌هایی که به خاطر Device Fingerprint مسدود شده‌اند (با comment "Auto-banned: [fingerprint]") نیز آزاد نمی‌شوند
      try {
        // حذف rule های firewall که مربوط به قفل قبلی هستند
        // حذف همه rule های auto-banned که مربوط به قفل هستند (با همه comment های ممکن)
        final rawRules = await _client!.talk(['/ip/firewall/raw/print']);
        for (var rule in rawRules) {
          final ruleComment = rule['comment']?.toString() ?? '';
          
          // بررسی اینکه آیا comment مربوط به قفل است (نه Device Fingerprint یا مسدود دستی)
          // comment های مربوط به قفل: "Auto-banned: New connection while locked" یا هر comment که شامل این متن باشد
          // comment های مربوط به Device Fingerprint: "Auto-banned: [fingerprint]" یا "Banned: [fingerprint]"
          // comment های مربوط به مسدود دستی: "Banned via Flutter App" یا "Banned: [fingerprint]"
          bool isLockBan = ruleComment.contains('Auto-banned: New connection while locked') ||
                          ruleComment.contains('New connection while locked');
          
          // بررسی اینکه آیا comment مربوط به Device Fingerprint یا مسدود دستی است
          bool isManualBan = ruleComment.startsWith('Banned:') ||
                           ruleComment.startsWith('Banned via Flutter App') ||
                           (ruleComment.contains('fingerprint') && 
                            !ruleComment.contains('New connection while locked'));
          
          // اگر مربوط به قفل است و نه Device Fingerprint یا مسدود دستی، حذف کن
          if (isLockBan && !isManualBan &&
              rule['action'] == 'drop' &&
              rule['chain'] == 'prerouting') {
            final ruleId = rule['.id'];
            if (ruleId != null) {
              try {
                await _client!.talk([
                  '/ip/firewall/raw/remove',
                  '=.id=$ruleId',
                ]);
              } catch (e) {
                // ignore
              }
            }
          }
        }
        
        // رفع block از DHCP leases که به خاطر قفل block شده‌اند
        // حذف block از همه leases که comment آن‌ها مربوط به قفل است
        try {
          final dhcpLeases = await _client!.talk(['/ip/dhcp-server/lease/print']);
          for (var lease in dhcpLeases) {
            if (lease['block-access']?.toString().toLowerCase() == 'yes') {
              final leaseComment = lease['comment']?.toString() ?? '';
              
              // بررسی اینکه آیا comment مربوط به قفل است
              bool isLockBan = leaseComment.contains('Auto-banned: New connection while locked') ||
                              leaseComment.contains('New connection while locked');
              
              // بررسی اینکه آیا comment مربوط به Device Fingerprint یا مسدود دستی است
              bool isManualBan = leaseComment.startsWith('Banned:') ||
                               leaseComment.startsWith('Banned via Flutter App') ||
                               (leaseComment.contains('fingerprint') && 
                                !leaseComment.contains('New connection while locked'));
              
              // اگر مربوط به قفل است و نه Device Fingerprint یا مسدود دستی، unblock کن
              if (isLockBan && !isManualBan) {
                final leaseId = lease['.id'];
                if (leaseId != null) {
                  try {
                    await _client!.talk([
                      '/ip/dhcp-server/lease/set',
                      '=.id=$leaseId',
                      '=block-access=no',
                    ]);
                  } catch (e) {
                    // ignore
                  }
                }
              }
            }
          }
        } catch (e) {
          // ignore
        }
        
        // حذف rule های wireless که به خاطر قفل deny/reject شده‌اند
        // حذف همه rule هایی که comment آن‌ها مربوط به قفل است
        try {
          final accessList = await _client!.talk(['/interface/wireless/access-list/print']);
          for (var acl in accessList) {
            final aclComment = acl['comment']?.toString() ?? '';
            final aclAction = acl['action']?.toString();
            
            // اگر action deny یا reject است و comment مربوط به قفل است، حذف کن
            // rule هایی که comment آن‌ها "Banned:" است را نگه دار (مسدود دستی)
            if ((aclAction == 'deny' || aclAction == 'reject')) {
              // بررسی اینکه آیا comment مربوط به قفل است
              bool isLockBan = aclComment.contains('Auto-banned: New connection while locked') ||
                              aclComment.contains('New connection while locked');
              
              // بررسی اینکه آیا comment مربوط به Device Fingerprint یا مسدود دستی است
              bool isManualBan = aclComment.startsWith('Banned:') ||
                               aclComment.startsWith('Banned via Flutter App') ||
                               (aclComment.contains('fingerprint') && 
                                !aclComment.contains('New connection while locked'));
              
              // اگر مربوط به قفل است و نه Device Fingerprint یا مسدود دستی، حذف کن
              if (isLockBan && !isManualBan) {
                final aclId = acl['.id'];
                if (aclId != null) {
                  try {
                    await _client!.talk([
                      '/interface/wireless/access-list/remove',
                      '=.id=$aclId',
                    ]);
                  } catch (e) {
                    // ignore
                  }
                }
              }
            }
          }
        } catch (e) {
          // ignore
        }
      } catch (e) {
        // ignore
      }
      
      // 7. حذف rule های firewall که IP دستگاه‌های فعلی (شامل دستگاه کاربر) را مسدود می‌کنند
      // این برای اطمینان از اینکه IP دستگاه‌های فعلی مسدود نشده‌اند
      // اما فقط rule هایی که مربوط به قفل هستند (نه مسدود دستی)
      try {
        // بررسی و حذف rule های firewall که IP دستگاه‌های فعلی را مسدود می‌کنند
        final rawRules = await _client!.talk(['/ip/firewall/raw/print']);
        for (var rule in rawRules) {
          final ruleIp = rule['src-address']?.toString();
          final ruleComment = rule['comment']?.toString();
          
          // اگر rule مربوط به IP یکی از دستگاه‌های فعلی است و comment مربوط به lock است، حذف کن
          // rule هایی که comment آن‌ها "Banned:" یا "Banned via Flutter App" است را نگه دار
          if (ruleIp != null && 
              allowedIps.contains(ruleIp) &&
              ruleComment != null) {
            // بررسی اینکه آیا comment مربوط به قفل است
            bool isLockBan = ruleComment == 'Auto-banned: New connection while locked' ||
                            ruleComment == 'Auto-banned: New connection while locked - IP' ||
                            ruleComment == 'Auto-banned: New connection while locked - MAC';
            
            // اگر مربوط به قفل است و نه Device Fingerprint یا مسدود دستی، حذف کن
            if (isLockBan && 
                !ruleComment.startsWith('Banned:') &&
                !ruleComment.startsWith('Banned via Flutter App') &&
                !ruleComment.contains('fingerprint')) {
              final ruleId = rule['.id'];
              if (ruleId != null) {
                try {
                  await _client!.talk([
                    '/ip/firewall/raw/remove',
                    '=.id=$ruleId',
                  ]);
                } catch (e) {
                  // ignore
                }
              }
            }
          }
        }
      } catch (e) {
        // ignore
      }

      // 8. ذخیره marker در system identity
      try {
        // استفاده از system identity برای ذخیره marker
        final identity = await _client!.talk(['/system/identity/print']);
        if (identity.isNotEmpty) {
          final currentName = identity[0]['name']?.toString() ?? '';
          // اضافه کردن marker به identity (اگر وجود ندارد)
          if (!currentName.contains('[LOCKED_NEW_CONN]')) {
            final originalName = currentName.replaceAll(' [LOCKED_NEW_CONN]', '');
            await _client!.talk([
              '/system/identity/set',
              '=name=$originalName [LOCKED_NEW_CONN]',
            ]);
          }
        }
      } catch (e) {
        // ignore - marker optional است
      }

      return true;
    } catch (e) {
      throw Exception('خطا در قفل کردن اتصال جدید: $e');
    }
  }

  /// رفع قفل اتصال دستگاه‌های جدید
  Future<bool> unlockNewConnections() async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      // 1. برگرداندن default-authenticate به حالت پیش‌فرض (اگر پشتیبانی شود) و حذف rule های wireless access list مربوط به lock
      try {
        final wirelessInterfaces = await _client!.talk(['/interface/wireless/print']);
        for (var wifiInterface in wirelessInterfaces) {
          final interfaceId = wifiInterface['.id']?.toString();
          final interfaceName = wifiInterface['name']?.toString();
          if (interfaceId != null) {
            try {
              // بررسی اینکه آیا پارامتر default-authenticate پشتیبانی می‌شود
              final currentSettings = await _client!.talk([
                '/interface/wireless/print',
                '?.id=$interfaceId',
              ]);
              
              if (currentSettings.isNotEmpty && currentSettings[0].containsKey('default-authenticate')) {
                // پارامتر پشتیبانی می‌شود، برگرداندن به yes
                await _client!.talk([
                  '/interface/wireless/set',
                  '=.id=$interfaceId',
                  '=default-authenticate=yes',
                ]);
                print('✅ [UNLOCK_CONN] default-authenticate=yes برای interface $interfaceName تنظیم شد');
                
                // برگرداندن default-forwarding به yes (اگر تنظیم شده بود)
                try {
                  if (currentSettings[0].containsKey('default-forwarding')) {
                    await _client!.talk([
                      '/interface/wireless/set',
                      '=.id=$interfaceId',
                      '=default-forwarding=yes',
                    ]);
                  }
                } catch (e) {
                  // ignore - ممکن است در برخی نسخه‌ها این تنظیم متفاوت باشد
                }
              }
            } catch (e) {
              // ignore - ممکن است پارامتر پشتیبانی نشود
            }
          }
        }

        // حذف همه rule های access list مربوط به lock
        // شامل: LOCK_ALLOW, LOCK_DENY_ALL, و سایر rule های قدیمی
        final accessList = await _client!.talk(['/interface/wireless/access-list/print']);
        List<String> rulesToRemove = [];
        
        for (var acl in accessList) {
          final comment = acl['comment']?.toString() ?? '';
          final aclId = acl['.id']?.toString();
          
          // حذف rule های مربوط به lock
          // شامل: LOCK_ALLOW, LOCK_DENY_ALL, و rule های قدیمی
          if (aclId != null && (
            comment == 'LOCK_ALLOW' ||
            comment == 'LOCK_DENY_ALL' ||
            comment == 'Lock New Connections - Allowed Device' ||
            comment == 'Static Device - Lock Allowed' ||
            comment == 'Lock New Connections - Block New MACs'
          )) {
            rulesToRemove.add(aclId);
          }
        }
        
        // حذف همه rule های پیدا شده
        for (var ruleId in rulesToRemove) {
          try {
            await _client!.talk([
              '/interface/wireless/access-list/remove',
              '=.id=$ruleId',
            ]);
            print('✅ [UNLOCK_CONN] حذف Access List rule: $ruleId');
          } catch (e) {
            print('⚠️ [UNLOCK_CONN] خطا در حذف Access List rule $ruleId: $e');
          }
        }
        
        if (rulesToRemove.isNotEmpty) {
          print('✅ [UNLOCK_CONN] ${rulesToRemove.length} Access List rule حذف شد');
        }
      } catch (e) {
        // ignore
      }

      // 2. حذف Raw rules مربوط به lock (در حال حاضر استفاده نمی‌شود، اما برای اطمینان)
      // توجه: در پیاده‌سازی جدید، از Raw rules استفاده نمی‌کنیم
      // اما این بخش برای پاکسازی rule های قدیمی (اگر وجود داشته باشند) نگه داشته شده
      try {
        final rawRules = await _client!.talk(['/ip/firewall/raw/print']);
        for (var rule in rawRules) {
          final comment = rule['comment']?.toString();
          if (comment == 'Lock New Connections - Allow MAC' ||
              comment == 'Lock New Connections - Block New MACs') {
            final ruleId = rule['.id'];
            if (ruleId != null) {
              try {
                await _client!.talk([
                  '/ip/firewall/raw/remove',
                  '=.id=$ruleId',
                ]);
              } catch (e) {
                // ignore
              }
            }
          }
        }
      } catch (e) {
        // ignore
      }

      // 3. پاک کردن لیست MAC ها و IP های مجاز از SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('locked_allowed_macs');
        await prefs.remove('locked_allowed_ips');
        await prefs.remove('locked_timestamp');
      } catch (e) {
        // ignore
      }

      // 4. بازگرداندن system identity به حالت عادی
      try {
        final identity = await _client!.talk(['/system/identity/print']);
        if (identity.isNotEmpty) {
          final currentName = identity[0]['name']?.toString() ?? '';
          if (currentName.contains('[LOCKED_NEW_CONN]')) {
            final originalName = currentName.replaceAll(' [LOCKED_NEW_CONN]', '');
            await _client!.talk([
              '/system/identity/set',
              '=name=$originalName',
            ]);
          }
        }
      } catch (e) {
        // ignore
      }

      // 5. رفع مسدودیت خودکار دستگاه‌هایی که به خاطر قفل مسدود شده‌اند
      // حذف همه rule های auto-banned که مربوط به قفل هستند (با همه comment های ممکن)
      // دستگاه‌هایی که دستی مسدود شده‌اند (با comment "Banned:" یا "Banned via Flutter App") آزاد نمی‌شوند
      // دستگاه‌هایی که به خاطر Device Fingerprint مسدود شده‌اند (با comment "Auto-banned: [fingerprint]") نیز آزاد نمی‌شوند
      // توجه: دستگاه‌های auto-banned نباید به static تبدیل شوند - فقط unblock می‌شوند
      try {
        // حذف rule های firewall که مربوط به قفل هستند
        final rawRules = await _client!.talk(['/ip/firewall/raw/print']);
        for (var rule in rawRules) {
          final ruleComment = rule['comment']?.toString() ?? '';
          
          // بررسی اینکه آیا comment مربوط به قفل است (نه Device Fingerprint یا مسدود دستی)
          // comment های مربوط به قفل: "Auto-banned: New connection while locked" یا هر comment که شامل این متن باشد
          // شامل: "Auto-banned: New connection while locked", "Auto-banned: New connection while locked - IP", "Auto-banned: New connection while locked - MAC"
          // comment های مربوط به Device Fingerprint: "Auto-banned: [fingerprint]" یا "Banned: [fingerprint]"
          // comment های مربوط به مسدود دستی: "Banned via Flutter App" یا "Banned: [fingerprint]"
          bool isLockBan = ruleComment.contains('Auto-banned: New connection while locked') ||
                          ruleComment.contains('New connection while locked') ||
                          ruleComment == 'Auto-banned: New connection while locked - IP' ||
                          ruleComment == 'Auto-banned: New connection while locked - MAC';
          
          // بررسی اینکه آیا comment مربوط به Device Fingerprint یا مسدود دستی است
          bool isManualBan = ruleComment.startsWith('Banned:') ||
                           ruleComment.startsWith('Banned via Flutter App') ||
                           (ruleComment.contains('fingerprint') && 
                            !ruleComment.contains('New connection while locked'));
          
          // اگر مربوط به قفل است و نه Device Fingerprint یا مسدود دستی، حذف کن
          // حذف همه rule های مربوط به قفل (بدون توجه به action یا chain)
          if (isLockBan && !isManualBan) {
            final ruleId = rule['.id'];
            if (ruleId != null) {
              try {
                await _client!.talk([
                  '/ip/firewall/raw/remove',
                  '=.id=$ruleId',
                ]);
              } catch (e) {
                // ignore
              }
            }
          }
        }
        
        // رفع block از DHCP leases و حذف Static leases که به خاطر قفل ایجاد شده‌اند
        // دستگاه‌های auto-banned نباید به static تبدیل شوند - فقط unblock می‌شوند
        try {
          final dhcpLeases = await _client!.talk(['/ip/dhcp-server/lease/print']);
          for (var lease in dhcpLeases) {
            final leaseComment = lease['comment']?.toString() ?? '';
            final isStatic = lease['dynamic']?.toString().toLowerCase() == 'false';
            final isBlocked = lease['block-access']?.toString().toLowerCase() == 'yes';
            
            // بررسی اینکه آیا comment مربوط به قفل است
            bool isLockBan = leaseComment.contains('Auto-banned: New connection while locked') ||
                            leaseComment.contains('New connection while locked');
            
            // بررسی اینکه آیا comment مربوط به Device Fingerprint یا مسدود دستی است
            bool isManualBan = leaseComment.startsWith('Banned:') ||
                             leaseComment.startsWith('Banned via Flutter App') ||
                             (leaseComment.contains('fingerprint') && 
                              !leaseComment.contains('New connection while locked'));
            
            // اگر مربوط به قفل است و نه Device Fingerprint یا مسدود دستی
            if (isLockBan && !isManualBan) {
              final leaseId = lease['.id'];
              if (leaseId != null) {
                // اگر static lease است که به خاطر auto-ban ایجاد شده، حذف کن (نباید static باشد)
                if (isStatic && leaseComment.contains('Static IP')) {
                  try {
                    await _client!.talk([
                      '/ip/dhcp-server/lease/remove',
                      '=.id=$leaseId',
                    ]);
                    continue; // بعد از حذف، به lease بعدی برو
                  } catch (e) {
                    // ignore
                  }
                }
                
                // رفع block از lease (اگر block شده است)
                if (isBlocked) {
                  try {
                    await _client!.talk([
                      '/ip/dhcp-server/lease/set',
                      '=.id=$leaseId',
                      '=block-access=no',
                    ]);
                  } catch (e) {
                    // ignore
                  }
                }
              }
            }
          }
        } catch (e) {
          // ignore
        }
        
        // حذف rule های wireless که به خاطر قفل deny/reject شده‌اند
        // حذف همه rule هایی که comment آن‌ها مربوط به قفل است
        try {
          final accessList = await _client!.talk(['/interface/wireless/access-list/print']);
          for (var acl in accessList) {
            final aclComment = acl['comment']?.toString() ?? '';
            final aclAction = acl['action']?.toString();
            
            // اگر action deny یا reject است و comment مربوط به قفل است، حذف کن
            // rule هایی که comment آن‌ها "Banned:" است را نگه دار (مسدود دستی)
            if ((aclAction == 'deny' || aclAction == 'reject')) {
              // بررسی اینکه آیا comment مربوط به قفل است
              bool isLockBan = aclComment.contains('Auto-banned: New connection while locked') ||
                              aclComment.contains('New connection while locked');
              
              // بررسی اینکه آیا comment مربوط به Device Fingerprint یا مسدود دستی است
              bool isManualBan = aclComment.startsWith('Banned:') ||
                               aclComment.startsWith('Banned via Flutter App') ||
                               (aclComment.contains('fingerprint') && 
                                !aclComment.contains('New connection while locked'));
              
              // اگر مربوط به قفل است و نه Device Fingerprint یا مسدود دستی، حذف کن
              if (isLockBan && !isManualBan) {
                final aclId = acl['.id'];
                if (aclId != null) {
                  try {
                    await _client!.talk([
                      '/interface/wireless/access-list/remove',
                      '=.id=$aclId',
                    ]);
                  } catch (e) {
                    // ignore
                  }
                }
              }
            }
          }
        } catch (e) {
          // ignore
        }
      } catch (e) {
        // ignore
      }

      return true;
    } catch (e) {
      throw Exception('خطا در رفع قفل اتصال جدید: $e');
    }
  }

  /// بررسی وضعیت قفل اتصال جدید
  Future<bool> isNewConnectionsLocked() async {
    if (_client == null || !isConnected) {
      return false;
    }

    try {
      // بررسی marker در system identity
      final identity = await _client!.talk(['/system/identity/print']);
      if (identity.isNotEmpty) {
        final currentName = identity[0]['name']?.toString() ?? '';
        if (currentName.contains('[LOCKED_NEW_CONN]')) {
          return true;
        }
      }

      // بررسی وجود rule های lock در wireless access list
      final accessList = await _client!.talk(['/interface/wireless/access-list/print']);
      for (var acl in accessList) {
        final comment = acl['comment']?.toString();
        if (comment == 'Lock New Connections - Allowed Device') {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }
  */

  /// دریافت لیست MAC های مجاز برای قفل - منطق حذف شده
  Future<Set<String>> getAllowedMacsForLock() async {
    // منطق حذف شده
    return <String>{};
  }

  /*
  Future<Set<String>> getAllowedMacsForLock_OLD() async {
    final allowedMacs = <String>{};
    
    try {
      // دریافت از SharedPreferences (لیست اولیه در زمان فعال شدن قفل)
      final prefs = await SharedPreferences.getInstance();
      final allowedMacsList = prefs.getStringList('locked_allowed_macs');
      if (allowedMacsList != null) {
        for (var mac in allowedMacsList) {
          if (mac.isNotEmpty) {
            allowedMacs.add(mac.toUpperCase());
          }
        }
      }
    } catch (e) {
      // ignore
    }

    return allowedMacs;
  }
  */

  /// دریافت لیست IP های مجاز برای قفل - منطق حذف شده
  Future<Set<String>> getAllowedIpsForLock() async {
    // منطق حذف شده
    return <String>{};
  }

  /*
  Future<Set<String>> getAllowedIpsForLock_OLD() async {
    final allowedIps = <String>{};
    
    try {
      // دریافت از SharedPreferences (لیست اولیه در زمان فعال شدن قفل)
      final prefs = await SharedPreferences.getInstance();
      final allowedIpsList = prefs.getStringList('locked_allowed_ips');
      if (allowedIpsList != null) {
        for (var ip in allowedIpsList) {
          if (ip.isNotEmpty) {
            allowedIps.add(ip);
          }
        }
      }
    } catch (e) {
      // ignore
    }

    return allowedIps;
  }
  */

  /// محدود کردن دسترسی WiFi برای دستگاه non-static
  /// 只使用 Access List 限制访问，不使用 Firewall rules 或 DHCP block-access
  ///
  /// این تابع:
  /// - 使用 Wireless Access List 限制设备访问（deny/reject）
  /// - 不使用 Firewall rules
  /// - 不使用 DHCP block-access
  Future<void> restrictNonStaticDevice(
    String macAddress, {
    String? ipAddress,
  }) async {
    if (_client == null || !isConnected) {
      return;
    }

    try {
      final macUpper = macAddress.toUpperCase();

      // 使用 Wireless Access List 限制访问
      try {
        // 检查是否已经存在 access list 规则
        final accessList = await _client!.talk([
          '/interface/wireless/access-list/print',
        ]);
        bool ruleExists = false;
        for (var acl in accessList) {
          final aclMac = acl['mac-address']?.toString().toUpperCase();
          if (aclMac == macUpper) {
            final aclAction = acl['action']?.toString();
            // 如果已经是 deny 或 reject，说明已经限制
            if (aclAction == 'deny' || aclAction == 'reject') {
              ruleExists = true;
              print(
                'ℹ️ [RESTRICT] Access List rule قبلاً وجود دارد (deny/reject) برای MAC: $macUpper',
              );
              break;
            }
          }
        }

        // 如果不存在限制规则，添加 deny 规则
        if (!ruleExists) {
          try {
            // 尝试添加 deny 规则
            await _client!.talk([
              '/interface/wireless/access-list/add',
              '=mac-address=$macUpper',
              '=action=deny',
              '=comment=Restricted: Non-Static Device - Pending Approval',
            ]);
            print(
              '✅ [RESTRICT] Access List deny rule اضافه شد برای MAC: $macUpper',
            );
          } catch (e1) {
            // 如果 deny 失败，尝试 reject
            try {
              await _client!.talk([
                '/interface/wireless/access-list/add',
                '=mac-address=$macUpper',
                '=action=reject',
                '=comment=Restricted: Non-Static Device - Pending Approval',
              ]);
              print(
                '✅ [RESTRICT] Access List reject rule اضافه شد برای MAC: $macUpper',
              );
            } catch (e2) {
              // 如果 rule 已存在，这是正常的
              if (e2.toString().contains('already') ||
                  e2.toString().contains('duplicate')) {
                print(
                  'ℹ️ [RESTRICT] Access List rule قبلاً وجود دارد برای MAC: $macUpper',
                );
              } else {
                print('⚠️ [RESTRICT] خطا در اضافه کردن Access List rule: $e2');
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ [RESTRICT] خطا در خواندن/اضافه کردن Access List: $e');
      }
    } catch (e) {
      print('❌ [RESTRICT] خطا در restrictNonStaticDevice: $e');
    }
  }

  /// اجازه دادن به دستگاه non-static برای استفاده از ترافیک اینترنت
  /// 只使用 Access List 允许访问（移除 deny/reject 规则，添加 allow 规则）
  Future<bool> allowNonStaticDevice(
    String macAddress, {
    String? ipAddress,
  }) async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      final macUpper = macAddress.toUpperCase();

      // 1. 移除 Access List 中的 deny/reject 规则
      try {
        final accessList = await _client!.talk([
          '/interface/wireless/access-list/print',
        ]);
        for (var acl in accessList) {
          final aclMac = acl['mac-address']?.toString().toUpperCase();
          if (aclMac == macUpper) {
            final aclAction = acl['action']?.toString();
            final aclComment = acl['comment']?.toString() ?? '';

            // 如果是限制规则（deny/reject），移除它
            if ((aclAction == 'deny' || aclAction == 'reject') &&
                aclComment.contains('Restricted: Non-Static Device')) {
              final aclId = acl['.id']?.toString();
              if (aclId != null) {
                try {
                  await _client!.talk([
                    '/interface/wireless/access-list/remove',
                    '=.id=$aclId',
                  ]);
                  print(
                    '✅ [ALLOW_DEVICE] Access List deny/reject rule حذف شد برای MAC: $macUpper',
                  );
                } catch (e) {
                  print('⚠️ [ALLOW_DEVICE] خطا در حذف Access List rule: $e');
                }
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ [ALLOW_DEVICE] خطا در خواندن Access List: $e');
      }

      // 2. 添加 allow 规则到 Access List
      try {
        // 检查是否已经存在 allow 规则
        final accessList = await _client!.talk([
          '/interface/wireless/access-list/print',
        ]);
        bool allowRuleExists = false;
        for (var acl in accessList) {
          final aclMac = acl['mac-address']?.toString().toUpperCase();
          if (aclMac == macUpper) {
            final aclAction = acl['action']?.toString();
            // 如果 action 是 allow 或 null（默认 allow），说明已经允许
            if (aclAction == null || aclAction == 'allow') {
              allowRuleExists = true;
              print(
                'ℹ️ [ALLOW_DEVICE] Access List allow rule قبلاً وجود دارد برای MAC: $macUpper',
              );
              break;
            }
          }
        }

        // 如果不存在 allow 规则，添加它
        if (!allowRuleExists) {
          try {
            // 尝试添加 allow 规则（带 authentication）
            await _client!.talk([
              '/interface/wireless/access-list/add',
              '=mac-address=$macUpper',
              '=authentication=yes',
              '=comment=Approved: Non-Static Device - Full Access',
            ]);
            print(
              '✅ [ALLOW_DEVICE] Access List allow rule اضافه شد برای MAC: $macUpper',
            );
          } catch (e1) {
            // 如果带 authentication 失败，尝试不带 authentication
            try {
              await _client!.talk([
                '/interface/wireless/access-list/add',
                '=mac-address=$macUpper',
                '=comment=Approved: Non-Static Device - Full Access',
              ]);
              print(
                '✅ [ALLOW_DEVICE] Access List allow rule اضافه شد (بدون authentication) برای MAC: $macUpper',
              );
            } catch (e2) {
              // 如果 rule 已存在，这是正常的
              if (e2.toString().contains('already') ||
                  e2.toString().contains('duplicate')) {
                print(
                  'ℹ️ [ALLOW_DEVICE] Access List allow rule قبلاً وجود دارد برای MAC: $macUpper',
                );
              } else {
                print(
                  '⚠️ [ALLOW_DEVICE] خطا در اضافه کردن Access List allow rule: $e2',
                );
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ [ALLOW_DEVICE] خطا در اضافه کردن Access List allow rule: $e');
      }

      // 3. اضافه کردن به لیست مجاز در SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();

        // اضافه کردن MAC به لیست مجاز
        final allowedMacsList =
            prefs.getStringList('locked_allowed_macs') ?? [];
        if (!allowedMacsList.contains(macUpper)) {
          allowedMacsList.add(macUpper);
          await prefs.setStringList('locked_allowed_macs', allowedMacsList);
        }

        // اضافه کردن IP به لیست مجاز (اگر داده شده)
        if (ipAddress != null && ipAddress.isNotEmpty) {
          final allowedIpsList =
              prefs.getStringList('locked_allowed_ips') ?? [];
          if (!allowedIpsList.contains(ipAddress)) {
            allowedIpsList.add(ipAddress);
            await prefs.setStringList('locked_allowed_ips', allowedIpsList);
          }
        }
      } catch (e) {
        // ignore errors in SharedPreferences
        print('⚠️ [ALLOW_DEVICE] خطا در ذخیره در SharedPreferences: $e');
      }

      return true;
    } catch (e) {
      print('❌ [ALLOW_DEVICE] خطا در اجازه دادن به دستگاه: $e');
      throw Exception('خطا در اجازه دادن به دستگاه: $e');
    }
  }

  /// حذف دستگاه از لیست مجاز
  /// این تابع دستگاه را از لیست مجاز حذف می‌کند و دسترسی WiFi را محدود می‌کند
  Future<bool> removeFromAllowedList(
    String macAddress, {
    String? ipAddress,
  }) async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      final macUpper = macAddress.toUpperCase();

      // 1. حذف همه rule های allow مربوط به این MAC از wireless access list
      // مهم: باید همه rule های allow را حذف کنیم، نه فقط با comment خاص
      try {
        final accessList = await _client!.talk([
          '/interface/wireless/access-list/print',
        ]);
        List<String> rulesToRemove = [];

        for (var acl in accessList) {
          final aclMac = acl['mac-address']?.toString().toUpperCase();
          if (aclMac == macUpper) {
            final aclId = acl['.id']?.toString();
            final aclAction = acl['action']?.toString();

            // حذف همه rule های allow (بدون توجه به comment)
            // این شامل rule های اضافه شده توسط allowNonStaticDevice هم می‌شود
            if (aclId != null && (aclAction == 'allow' || aclAction == null)) {
              // در MikroTik، اگر action مشخص نشده باشد، معمولاً allow است
              rulesToRemove.add(aclId);
            }
          }
        }

        // حذف همه rule های پیدا شده
        for (var ruleId in rulesToRemove) {
          try {
            await _client!.talk([
              '/interface/wireless/access-list/remove',
              '=.id=$ruleId',
            ]);
            print(
              '✅ [REMOVE_ALLOWED] حذف rule allow برای MAC: $macUpper, Rule ID: $ruleId',
            );
          } catch (e) {
            print('⚠️ [REMOVE_ALLOWED] خطا در حذف rule $ruleId: $e');
          }
        }
      } catch (e) {
        print('⚠️ [REMOVE_ALLOWED] خطا در خواندن access list: $e');
      }

      // 2. محدود کردن دسترسی در تمام سطوح: Wireless + DHCP + Firewall
      try {
        await restrictNonStaticDevice(macAddress, ipAddress: ipAddress);
      } catch (e) {
        print('⚠️ [REMOVE_ALLOWED] خطا در restrictNonStaticDevice: $e');
      }

      // 3. حذف از لیست مجاز در SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();

        // حذف MAC از لیست مجاز
        final allowedMacsList =
            prefs.getStringList('locked_allowed_macs') ?? [];
        allowedMacsList.remove(macUpper);
        await prefs.setStringList('locked_allowed_macs', allowedMacsList);

        // حذف IP از لیست مجاز (اگر داده شده)
        if (ipAddress != null && ipAddress.isNotEmpty) {
          final allowedIpsList =
              prefs.getStringList('locked_allowed_ips') ?? [];
          allowedIpsList.remove(ipAddress);
          await prefs.setStringList('locked_allowed_ips', allowedIpsList);
        }
      } catch (e) {
        // ignore errors in SharedPreferences
        print('⚠️ [REMOVE_ALLOWED] خطا در حذف از SharedPreferences: $e');
      }

      return true;
    } catch (e) {
      print('❌ [REMOVE_ALLOWED] خطا در حذف از لیست مجاز: $e');
      throw Exception('خطا در حذف از لیست مجاز: $e');
    }
  }

  /// بررسی IP
  /// مشابه POST /api/clients/check-ip
  Future<Map<String, dynamic>> checkIp(String ipAddress) async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      final result = <String, dynamic>{'ip': ipAddress, 'found': false};

      // بررسی در ARP
      try {
        final arpEntries = await _client!.talk(['/ip/arp/print']);
        for (var arp in arpEntries) {
          if (arp['address'] == ipAddress) {
            result['found'] = true;
            result['mac_address'] = arp['mac-address'];
            result['interface'] = arp['interface'];
            break;
          }
        }
      } catch (e) {
        // ARP ممکن است در دسترس نباشد
      }

      // بررسی در DHCP leases
      try {
        final dhcpLeases = await _client!.talk(['/ip/dhcp-server/lease/print']);
        for (var lease in dhcpLeases) {
          if (lease['address'] == ipAddress) {
            result['found'] = true;
            result['mac_address'] = lease['mac-address'];
            result['host_name'] = lease['host-name'];
            result['status'] = lease['status'];
            break;
          }
        }
      } catch (e) {
        // DHCP ممکن است فعال نباشد
      }

      return result;
    } catch (e) {
      throw Exception('خطا در بررسی IP: $e');
    }
  }

}
