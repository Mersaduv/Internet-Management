import 'dart:async';

import 'package:router_os_client/router_os_client.dart';

/// Client wrapper for MikroTik RouterOS API v6.
class RouterOSClientV2 {
  final String address;
  final String user;
  final String password;
  final bool useSsl;
  final int port;

  RouterOSClient? _client;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  Future<void> _commandQueue = Future.value();

  RouterOSClientV2({
    required this.address,
    required this.user,
    required this.password,
    this.useSsl = false,
    this.port = 8728,
  });

  Future<bool> login() async {
    try {
      _client = RouterOSClient(
        address: address,
        user: user,
        password: password,
        useSsl: useSsl,
        port: port,
      );

      final ok = await _client!.login();
      if (ok) {
        _isConnected = true;
        _isAuthenticated = true;
        _commandQueue = Future.value();
      }
      return ok;
    } catch (e) {
      _isConnected = false;
      _isAuthenticated = false;
      throw Exception('خطا در اتصال: $e');
    }
  }

  Future<List<Map<String, String>>> talk(List<String> command) {
    if (_client == null || !_isConnected || !_isAuthenticated) {
      throw Exception('اتصال برقرار نشده یا احراز هویت انجام نشده');
    }

    final completer = Completer<List<Map<String, String>>>();
    final summary = _commandSummary(command);
    final shouldLog = _isQueueCommand(command);

    _commandQueue = _commandQueue.catchError((_) {}).then((_) async {
      final stopwatch = Stopwatch()..start();
      if (shouldLog) {
        print('🔁 [ROUTEROS_QUEUE] start: $summary');
      }

      try {
        if (_client == null || !_isConnected || !_isAuthenticated) {
          throw Exception('اتصال برقرار نشده یا احراز هویت انجام نشده');
        }

        // The RouterOS API socket is sequential; overlapping talk() calls can
        // corrupt response matching and leave a command waiting until timeout.
        final result = await _client!.talk(command);

        final List<Map<String, String>> convertedResult = [];

        for (var item in result) {
          final Map<String, String> convertedItem = {};
          item.forEach((key, value) {
            convertedItem[key.toString()] = value.toString();
          });
          convertedResult.add(convertedItem);
        }

        if (shouldLog) {
          print(
            '✅ [ROUTEROS_QUEUE] done in ${stopwatch.elapsedMilliseconds}ms: $summary',
          );
        }
        completer.complete(convertedResult);
      } catch (e, stackTrace) {
        if (shouldLog) {
          print(
            '❌ [ROUTEROS_QUEUE] failed after ${stopwatch.elapsedMilliseconds}ms: $summary | $e',
          );
        }
        completer.completeError(
          Exception('خطا در اجرای دستور: $e'),
          stackTrace,
        );
      }
    });

    _commandQueue = _commandQueue.catchError((_) {});
    return completer.future;
  }

  void close() {
    _client?.close();
    _client = null;
    _isConnected = false;
    _isAuthenticated = false;
    _commandQueue = Future.value();
  }

  bool get isConnected => _isConnected && _isAuthenticated;

  bool _isQueueCommand(List<String> command) {
    return command.isNotEmpty && command.first.startsWith('/queue/');
  }

  String _commandSummary(List<String> command) {
    return command
        .map((part) {
          if (part.startsWith('=comment=')) {
            return '=comment=<hidden>';
          }
          return part;
        })
        .join(' ');
  }
}
