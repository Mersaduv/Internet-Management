import 'dart:async';
import 'dart:io';

import 'package:router_os_client/router_os_client.dart';

import '../models/mikrotik_connection.dart';
import 'mikrotik_timeouts.dart';

/// Client wrapper for MikroTik RouterOS API v6.
class RouterOSClientV2 {
  final String address;
  final String user;
  final String password;
  final bool useSsl;
  final int port;

  RouterOSClient? _client;
  bool _loggedIn = false;
  Future<void> _commandQueue = Future<void>.value();

  RouterOSClientV2({
    required this.address,
    required this.user,
    required this.password,
    this.useSsl = false,
    this.port = MikroTikConnection.apiPort,
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

      final ok = await _client!
          .login()
          .timeout(MikrotikTimeouts.login, onTimeout: () => false);
      if (ok) {
        _loggedIn = true;
        _commandQueue = Future<void>.value();
        print('[ROUTEROS_QUEUE] login ok ($address:$port)');
      }
      return ok;
    } catch (e) {
      _resetState();
      throw Exception('خطا در اتصال: $e');
    }
  }

  /// Drops the current socket and clears the command queue.
  void invalidateConnection() => _resetState();

  /// Sends `/system/identity/print` to verify the API socket is still usable.
  Future<bool> isAlive({Duration timeout = const Duration(seconds: 3)}) async {
    if (_client == null || !_loggedIn) {
      return false;
    }

    final completer = Completer<bool>();
    _commandQueue = _commandQueue.catchError((_) {}).then((_) async {
      try {
        if (_client == null || !_loggedIn) {
          completer.complete(false);
          return;
        }
        await _client!
            .talk(['/system/identity/print'])
            .timeout(timeout);
        completer.complete(true);
      } catch (e) {
        print('[ROUTEROS_QUEUE] isAlive failed: $e');
        _resetState();
        completer.complete(false);
      }
    });
    _commandQueue = _commandQueue.catchError((_) {});
    return completer.future;
  }

  Future<List<Map<String, String>>> talk(
    List<String> command, {
    Duration timeout = MikrotikTimeouts.defaultTalk,
  }) {
    if (_client == null || !_loggedIn) {
      throw Exception('اتصال برقرار نشده یا احراز هویت انجام نشده');
    }

    final completer = Completer<List<Map<String, String>>>();
    final summary = _commandSummary(command);
    final shouldLog = _isQueueCommand(command);

    _commandQueue = _commandQueue.catchError((_) {}).then((_) async {
      final stopwatch = Stopwatch()..start();
      if (shouldLog) {
        print('[ROUTEROS_QUEUE] start: $summary');
      }

      try {
        if (_client == null || !_loggedIn) {
          throw Exception('اتصال برقرار نشده یا احراز هویت انجام نشده');
        }

        // The RouterOS API socket is sequential; overlapping talk() calls can
        // corrupt response matching and leave a command waiting until timeout.
        final result = await _client!.talk(command).timeout(timeout);

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
            '[ROUTEROS_QUEUE] done in ${stopwatch.elapsedMilliseconds}ms: $summary',
          );
        }
        completer.complete(convertedResult);
      } on TimeoutException catch (e, stackTrace) {
        print(
          '[ROUTEROS_QUEUE] timeout after ${stopwatch.elapsedMilliseconds}ms: $summary | $e',
        );
        _resetState();
        completer.completeError(
          Exception('خطا در اجرای دستور: $e'),
          stackTrace,
        );
      } catch (e, stackTrace) {
        if (shouldLog || _isSocketError(e)) {
          print(
            '[ROUTEROS_QUEUE] failed after ${stopwatch.elapsedMilliseconds}ms: $summary | $e',
          );
        }
        if (_isSocketError(e)) {
          _resetState();
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
    _resetState();
  }

  bool get isConnected => _loggedIn && _client != null;

  void _resetState() {
    print('[ROUTEROS_QUEUE] resetting connection state');
    _loggedIn = false;
    try {
      _client?.close();
    } catch (_) {
      // ignore close errors
    }
    _client = null;
    _commandQueue = Future<void>.value();
  }

  bool _isSocketError(Object e) {
    if (e is SocketException || e is IOException) {
      return true;
    }
    if (e is StateError) {
      return true;
    }
    final message = e.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('connection reset') ||
        message.contains('connection refused') ||
        message.contains('broken pipe') ||
        message.contains('closed') ||
        message.contains('not open');
  }

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
