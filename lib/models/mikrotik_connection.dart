/// مدل اتصال به MikroTik RouterOS
class MikroTikConnection {
  /// پورت پیش‌فرض RouterOS API (MikroTik)
  static const int apiPort = 8728;

  final String host;
  final int port;
  final String username;
  final String password;
  final bool useSsl;

  MikroTikConnection({
    required this.host,
    this.port = apiPort,
    required this.username,
    required this.password,
    this.useSsl = false,
  });

  /// پورت TCP واقعی برای اتصال API — همیشه 8728
  int get actualPort => apiPort;
}

