/// اطلاعات کلاینت متصل به MikroTik
class ClientInfo {
  final String type; // hotspot, wireless, dhcp, ppp
  final String source;
  final String? user;
  final String? name;
  final String? ipAddress;
  final String? macAddress;
  final String? hostName;
  final String? uptime;
  final String? bytesIn;
  final String? bytesOut;
  final String? loginBy;
  final String? server;
  final String? id;
  final String? interface;
  final String? ssid;
  final String? signalStrength;
  final String? service;
  final String? callerId;
  final String? status;
  final String? expiresAfter;
  final bool? isStaticLease; // true = static, false = dynamic, null = unknown
  final Map<String, dynamic> rawData;

  ClientInfo({
    required this.type,
    required this.source,
    this.user,
    this.name,
    this.ipAddress,
    this.macAddress,
    this.hostName,
    this.uptime,
    this.bytesIn,
    this.bytesOut,
    this.loginBy,
    this.server,
    this.id,
    this.interface,
    this.ssid,
    this.signalStrength,
    this.service,
    this.callerId,
    this.status,
    this.expiresAfter,
    this.isStaticLease,
    required this.rawData,
  });

  factory ClientInfo.fromMap(Map<String, dynamic> map) {
    return ClientInfo(
      type: map['type'] ?? 'unknown',
      source: map['source'] ?? 'unknown',
      user: map['user'],
      name: map['name'],
      ipAddress: map['ip_address'] ?? map['address'],
      macAddress: map['mac_address'] ?? map['mac-address'],
      hostName: map['host_name'] ?? map['host-name'],
      uptime: map['uptime'],
      bytesIn: map['bytes_in'] ?? map['bytes-in'],
      bytesOut: map['bytes_out'] ?? map['bytes-out'],
      loginBy: map['login_by'] ?? map['login-by'],
      server: map['server'],
      id: map['id'] ?? map['.id'],
      interface: map['interface'],
      ssid: map['ssid'],
      signalStrength: map['signal_strength'] ?? map['signal-strength'],
      service: map['service'],
      callerId: map['caller_id'] ?? map['caller-id'],
      status: map['status'],
      expiresAfter: map['expires_after'] ?? map['expires-after'],
      isStaticLease: _parseStaticLeaseStatus(map),
      rawData: map,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'source': source,
      'user': user,
      'name': name,
      'ip_address': ipAddress,
      'mac_address': macAddress,
      'host_name': hostName,
      'uptime': uptime,
      'bytes_in': bytesIn,
      'bytes_out': bytesOut,
      'login_by': loginBy,
      'server': server,
      'id': id,
      'interface': interface,
      'ssid': ssid,
      'signal_strength': signalStrength,
      'service': service,
      'caller_id': callerId,
      'status': status,
      'expires_after': expiresAfter,
      'is_static_lease': isStaticLease,
      'raw_data': rawData,
    };
  }

  ClientInfo copyWith({
    String? type,
    String? source,
    String? user,
    String? name,
    String? ipAddress,
    String? macAddress,
    String? hostName,
    String? uptime,
    String? bytesIn,
    String? bytesOut,
    String? loginBy,
    String? server,
    String? id,
    String? interface,
    String? ssid,
    String? signalStrength,
    String? service,
    String? callerId,
    String? status,
    String? expiresAfter,
    bool? isStaticLease,
    Map<String, dynamic>? rawData,
  }) {
    return ClientInfo(
      type: type ?? this.type,
      source: source ?? this.source,
      user: user ?? this.user,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      macAddress: macAddress ?? this.macAddress,
      hostName: hostName ?? this.hostName,
      uptime: uptime ?? this.uptime,
      bytesIn: bytesIn ?? this.bytesIn,
      bytesOut: bytesOut ?? this.bytesOut,
      loginBy: loginBy ?? this.loginBy,
      server: server ?? this.server,
      id: id ?? this.id,
      interface: interface ?? this.interface,
      ssid: ssid ?? this.ssid,
      signalStrength: signalStrength ?? this.signalStrength,
      service: service ?? this.service,
      callerId: callerId ?? this.callerId,
      status: status ?? this.status,
      expiresAfter: expiresAfter ?? this.expiresAfter,
      isStaticLease: isStaticLease ?? this.isStaticLease,
      rawData: rawData ?? this.rawData,
    );
  }

  /// پارس کردن وضعیت Static Lease از rawData
  /// dynamic=true → Dynamic (داینامیک) → isStaticLease = false
  /// dynamic=false → Static (استاتیک) → isStaticLease = true
  static bool? _parseStaticLeaseStatus(Map<String, dynamic> map) {
    // بررسی مستقیم در map
    if (map.containsKey('dynamic')) {
      final dynamicValue = map['dynamic']?.toString().toLowerCase();
      if (dynamicValue == 'true' || dynamicValue == 'yes') {
        return false; // Dynamic
      } else if (dynamicValue == 'false' || dynamicValue == 'no') {
        return true; // Static
      }
    }

    // بررسی در is_static_lease (اگر قبلاً ذخیره شده)
    if (map.containsKey('is_static_lease')) {
      return map['is_static_lease'] as bool?;
    }

    return null; // Unknown
  }
}
