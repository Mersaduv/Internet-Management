import 'dart:io';
import 'dart:async';
import '../models/mikrotik_connection.dart';
import '../models/client_info.dart';
import '../models/device_fingerprint.dart';
import '../services/device_fingerprint_service.dart';
import 'routeros_client_v2.dart' show RouterOSClientV2;

/// سرویس برای مدیریت اتصال و عملیات MikroTik RouterOS
/// مشابه endpointهای /api/clients/* در پروژه Python
class MikroTikService {
  RouterOSClientV2? _client;
  MikroTikConnection? _connection;
  Map<String, dynamic>? _routerInfoCache;
  bool? _wirelessFeaturesEnabled;

  static const Duration _apiTimeout = Duration(seconds: 5);
  static const String _appPrefix = 'Ariyabod';
  static const String _banMarker = '[$_appPrefix BAN]';
  static const String _staticOnlyPool = 'static-only';
  static const String _staticMarker = '[$_appPrefix STATIC]';
  static const Set<String> _wirelessUnsupportedBoardKeys = {
    'lhg5',
    'rblhg5nd',
    'sxtsqlite5',
    'rbsxtsq5nd',
    'sxtlite5',
    'sxt5ndr2',
    'lhg5ac',
    'rblhgg5acd',
    'qrt5',
    '911g5hpnd',
    'qrt5ac',
    '911g5hpacd',
    'lhg5xl',
    'sextant5',
    'sxt6',
    'rbsxtg6hpnd',
  };

  String _proplist(List<String> fields) => '=.proplist=${fields.join(',')}';

  String _normalizeBoardKey(String? value) {
    return (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _isWirelessUnsupportedRouter(Map<String, dynamic>? routerInfo) {
    if (routerInfo == null) {
      return false;
    }

    final keys = <String>{
      _normalizeBoardKey(routerInfo['board-name']?.toString()),
      _normalizeBoardKey(routerInfo['model']?.toString()),
    }..removeWhere((item) => item.isEmpty);

    return keys.any(_wirelessUnsupportedBoardKeys.contains);
  }

  Future<Map<String, dynamic>?> _ensureRouterInfoCache() async {
    if (_routerInfoCache != null) {
      return _routerInfoCache;
    }

    try {
      return await getRouterInfo();
    } catch (_) {
      return _routerInfoCache;
    }
  }

  Future<bool> _supportsWirelessFeatures() async {
    if (_wirelessFeaturesEnabled != null) {
      return _wirelessFeaturesEnabled!;
    }

    final routerInfo = await _ensureRouterInfoCache();
    _wirelessFeaturesEnabled = !_isWirelessUnsupportedRouter(routerInfo);
    return _wirelessFeaturesEnabled!;
  }

  String? _normalizeMac(String? macAddress) {
    final mac = macAddress?.trim().toUpperCase();
    if (mac == null || mac.isEmpty) {
      return null;
    }
    return mac;
  }

  bool _isTruthy(String? value) {
    final normalized = value?.toLowerCase();
    return normalized == 'yes' || normalized == 'true';
  }

  bool _isDenyLikeAccessRule(Map<String, String> rule) {
    final action = rule['action']?.toLowerCase();
    return action == 'deny' ||
        action == 'reject' ||
        rule['authentication']?.toLowerCase() == 'no' ||
        rule['forwarding']?.toLowerCase() == 'no';
  }

  bool _isManagedBanComment(String? comment) {
    final value = comment ?? '';
    return value.contains(_banMarker) ||
        value.contains('Banned via Flutter App') ||
        value.startsWith('Auto-banned:') ||
        value.startsWith('Banned:');
  }

  String _withMarker(String? comment, String marker) {
    final value = comment?.trim() ?? '';
    if (value.contains(marker)) {
      return value;
    }
    if (value.isEmpty) {
      return marker;
    }
    return '$value $marker';
  }

  String _withoutMarker(String? comment, String marker) {
    return (comment ?? '')
        .replaceAll(marker, '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  bool _isDisabledFlag(String? value) {
    final normalized = value?.toLowerCase();
    return normalized == 'true' || normalized == 'yes';
  }

  String? _displayNameFromLease(Map<String, String>? lease) {
    if (lease == null) {
      return null;
    }

    var comment = lease['comment']?.trim() ?? '';
    if (comment.isNotEmpty) {
      comment = _withoutMarker(comment, _banMarker);
      comment = _withoutMarker(comment, _staticMarker);
      if (comment.isNotEmpty &&
          !comment.startsWith('Auto-banned:') &&
          comment != 'Banned via Flutter App') {
        return comment;
      }
    }

    final hostName = lease['host-name']?.trim();
    if (hostName != null && hostName.isNotEmpty) {
      return hostName;
    }

    return null;
  }

  String _commandSummary(List<String> command) {
    return command
        .map((part) {
          if (!part.startsWith('=')) {
            return part;
          }
          if (part.startsWith('=comment=')) {
            return '=comment=<omitted>';
          }
          return part;
        })
        .join(' ');
  }

  Future<List<Map<String, String>>> _talk(
    List<String> command, {
    Duration timeout = _apiTimeout,
  }) async {
    final summary = _commandSummary(command);

    try {
      return await _client!.talk(command).timeout(timeout);
    } on TimeoutException catch (e) {
      throw Exception('Timeout در اجرای دستور MikroTik: $summary | $e');
    } catch (e) {
      throw Exception('خطا در اجرای دستور MikroTik: $summary | $e');
    }
  }

  Future<String?> _findMacForIp(String ipAddress) async {
    try {
      final leases = await _talk([
        '/ip/dhcp-server/lease/print',
        '?=address=$ipAddress',
        _proplist(['.id', 'address', 'mac-address']),
      ]);
      for (final lease in leases) {
        final mac = _normalizeMac(lease['mac-address']);
        if (mac != null) {
          return mac;
        }
      }
    } catch (_) {
      // DHCP may be disabled.
    }

    try {
      final arps = await _talk([
        '/ip/arp/print',
        '?=address=$ipAddress',
        _proplist(['.id', 'address', 'mac-address']),
      ]);
      for (final arp in arps) {
        final mac = _normalizeMac(arp['mac-address']);
        if (mac != null) {
          return mac;
        }
      }
    } catch (_) {
      // ARP may be unavailable.
    }

    return null;
  }

  Future<List<Map<String, String>>> _rawRulesFor({
    String? ipAddress,
    String? macAddress,
  }) async {
    final rulesById = <String, Map<String, String>>{};
    final proplist = _proplist([
      '.id',
      'chain',
      'action',
      'src-address',
      'src-mac-address',
      'comment',
    ]);

    Future<void> addMatches(String query) async {
      final rules = await _talk(['/ip/firewall/raw/print', query, proplist]);
      for (final rule in rules) {
        final id = rule['.id'];
        if (id != null) {
          rulesById[id] = rule;
        }
      }
    }

    if (ipAddress != null && ipAddress.isNotEmpty) {
      try {
        await addMatches('?=src-address=$ipAddress');
      } catch (_) {}
    }

    final normalizedMac = _normalizeMac(macAddress);
    if (normalizedMac != null) {
      try {
        await addMatches('?=src-mac-address=$normalizedMac');
      } catch (_) {}
    }

    return rulesById.values.toList();
  }

  Future<void> _ensureRawDropRule({
    String? ipAddress,
    String? macAddress,
    required String comment,
  }) async {
    if ((ipAddress == null || ipAddress.isEmpty) &&
        (macAddress == null || macAddress.isEmpty)) {
      return;
    }

    final normalizedMac = _normalizeMac(macAddress);
    final rules = await _rawRulesFor(
      ipAddress: ipAddress,
      macAddress: normalizedMac,
    );
    for (final rule in rules) {
      final sameIp = ipAddress != null && rule['src-address'] == ipAddress;
      final sameMac =
          normalizedMac != null &&
          _normalizeMac(rule['src-mac-address']) == normalizedMac;
      final sameSelector = ipAddress != null ? sameIp : sameMac;
      if (!sameSelector) {
        continue;
      }

      if (rule['chain'] == 'prerouting' &&
          rule['action'] == 'drop' &&
          (_isManagedBanComment(rule['comment']) ||
              rule['comment'] == comment)) {
        final id = rule['.id'];
        if (id != null && rule['comment'] != comment) {
          await _talk([
            '/ip/firewall/raw/set',
            '=.id=$id',
            '=comment=$comment',
          ]);
        }
        return;
      }
    }

    final command = [
      '/ip/firewall/raw/add',
      '=chain=prerouting',
      '=action=drop',
      '=comment=$comment',
    ];
    if (ipAddress != null && ipAddress.isNotEmpty) {
      command.add('=src-address=$ipAddress');
    } else if (normalizedMac != null) {
      command.add('=src-mac-address=$normalizedMac');
    }
    await _talk(command);
  }

  Future<List<Map<String, String>>> _accessListForMac(String macAddress) async {
    if (!await _supportsWirelessFeatures()) {
      return <Map<String, String>>[];
    }

    final mac = _normalizeMac(macAddress);
    if (mac == null) {
      return <Map<String, String>>[];
    }

    return _talk([
      '/interface/wireless/access-list/print',
      '?=mac-address=$mac',
      _proplist([
        '.id',
        'mac-address',
        'comment',
        'authentication',
        'forwarding',
        'action',
        'disabled',
      ]),
    ]);
  }

  Future<void> _addAccessRule(
    String macAddress, {
    required bool allow,
    required String comment,
  }) async {
    final mac = _normalizeMac(macAddress);
    if (mac == null) {
      return;
    }

    final command = [
      '/interface/wireless/access-list/add',
      '=mac-address=$mac',
      '=authentication=${allow ? 'yes' : 'no'}',
      '=forwarding=${allow ? 'yes' : 'no'}',
      '=comment=$comment',
    ];

    try {
      await _talk(command);
    } catch (_) {
      await _talk([
        '/interface/wireless/access-list/add',
        '=mac-address=$mac',
        '=authentication=${allow ? 'yes' : 'no'}',
        '=comment=$comment',
      ]);
    }
  }

  Future<void> _setAccessRule(
    String id, {
    required bool allow,
    required String comment,
  }) async {
    try {
      await _talk([
        '/interface/wireless/access-list/set',
        '=.id=$id',
        '=authentication=${allow ? 'yes' : 'no'}',
        '=forwarding=${allow ? 'yes' : 'no'}',
        '=disabled=no',
        '=comment=$comment',
      ]);
    } catch (_) {
      await _talk([
        '/interface/wireless/access-list/set',
        '=.id=$id',
        '=authentication=${allow ? 'yes' : 'no'}',
        '=disabled=no',
        '=comment=$comment',
      ]);
    }
  }

  Future<void> _ensureWirelessAccessRule(
    String macAddress, {
    required bool allow,
    required String comment,
  }) async {
    if (!await _supportsWirelessFeatures()) {
      return;
    }

    final mac = _normalizeMac(macAddress);
    if (mac == null) {
      return;
    }

    final rules = await _accessListForMac(mac);
    for (final rule in rules) {
      final id = rule['.id'];
      if (id == null) {
        continue;
      }

      final ruleComment = rule['comment'];
      final managed =
          _isManagedBanComment(ruleComment) || ruleComment == comment;

      if (managed) {
        await _setAccessRule(id, allow: allow, comment: comment);
        return;
      }
    }

    await _addAccessRule(mac, allow: allow, comment: comment);
  }

  Future<void> _removeManagedAccessRules(
    String macAddress, {
    bool includeLegacyEmptyDeny = false,
  }) async {
    if (!await _supportsWirelessFeatures()) {
      return;
    }

    final rules = await _accessListForMac(macAddress);
    for (final rule in rules) {
      final id = rule['.id'];
      if (id == null) {
        continue;
      }

      final comment = rule['comment'];
      final shouldRemove =
          _isManagedBanComment(comment) ||
          (includeLegacyEmptyDeny &&
              (comment == null || comment.isEmpty) &&
              _isDenyLikeAccessRule(rule));
      if (shouldRemove) {
        try {
          await _talk(['/interface/wireless/access-list/remove', '=.id=$id']);
        } catch (_) {}
      }
    }
  }

  Future<void> _setDhcpBlockForMac(
    String macAddress, {
    required bool block,
    bool allowLegacyUnblock = false,
  }) async {
    final mac = _normalizeMac(macAddress);
    if (mac == null) {
      return;
    }

    final leases = await _talk([
      '/ip/dhcp-server/lease/print',
      '?=mac-address=$mac',
      _proplist([
        '.id',
        'address',
        'mac-address',
        'block-access',
        'comment',
        'status',
        'dynamic',
      ]),
    ]);

    for (final lease in leases) {
      final id = lease['.id'];
      if (id == null) {
        continue;
      }

      final comment = lease['comment'];
      final isBlocked = _isTruthy(lease['block-access']);
      final hasMarker = (comment ?? '').contains(_banMarker);

      if (block) {
        if (isBlocked && !hasMarker) {
          continue;
        }
        await _talk([
          '/ip/dhcp-server/lease/set',
          '=.id=$id',
          '=block-access=yes',
          '=comment=${_withMarker(comment, _banMarker)}',
        ]);
      } else if (hasMarker || allowLegacyUnblock) {
        final restoredComment = _withoutMarker(comment, _banMarker);
        await _talk([
          '/ip/dhcp-server/lease/set',
          '=.id=$id',
          '=block-access=no',
          '=comment=$restoredComment',
        ]);
      }
    }
  }

  int? _ipv4ToInt(String address) {
    final parts = address.trim().split('.');
    if (parts.length != 4) {
      return null;
    }

    var result = 0;
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) {
        return null;
      }
      result = (result << 8) + value;
    }
    return result;
  }

  bool _hasUsableMaxLimit(String? maxLimit) {
    final value = maxLimit?.trim();
    return value != null &&
        value.isNotEmpty &&
        value != '0/0' &&
        value.toLowerCase() != 'n/a';
  }

  String _formatRatePart(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final hasUnit = RegExp(r'^\d+(\.\d+)?[KMGkmg]$').hasMatch(trimmed);
    if (hasUnit || trimmed == '0') {
      return trimmed.toUpperCase();
    }

    final numeric = int.tryParse(trimmed);
    if (numeric == null) {
      return trimmed;
    }

    if (numeric >= 1000000000) {
      final value = numeric / 1000000000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}G';
    }
    if (numeric >= 1000000) {
      final value = numeric / 1000000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}M';
    }
    if (numeric >= 1000) {
      final value = numeric / 1000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}K';
    }
    return numeric.toString();
  }

  String _formatRatePair(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return raw;
    }

    final parts = raw.split('/');
    if (parts.length != 2) {
      return _formatRatePart(raw);
    }
    return '${_formatRatePart(parts[0])}/${_formatRatePart(parts[1])}';
  }

  String _firstUsableRateValue(String? primary, [String? secondary]) {
    if (_hasUsableMaxLimit(primary)) {
      return _formatRatePair(primary);
    }
    if (_hasUsableMaxLimit(secondary)) {
      return _formatRatePair(secondary);
    }
    return '';
  }

  String _formatSingleRateValue(String? value) {
    if (!_hasUsableMaxLimit(value)) {
      return '';
    }
    return _formatRatePart(value!.trim());
  }

  Map<String, String> _splitFormattedRatePair(String value) {
    final parts = value.split('/');
    if (parts.length != 2) {
      final normalized = value.trim();
      return {'upload': normalized, 'download': normalized};
    }

    return {'upload': parts[0].trim(), 'download': parts[1].trim()};
  }

  String _mergeRatePair(String? upload, String? download) {
    final normalizedUpload = upload?.trim() ?? '';
    final normalizedDownload = download?.trim() ?? '';
    if (normalizedUpload.isEmpty && normalizedDownload.isEmpty) {
      return '';
    }
    if (normalizedUpload.isEmpty) {
      return normalizedDownload;
    }
    if (normalizedDownload.isEmpty) {
      return normalizedUpload;
    }
    return '$normalizedUpload/$normalizedDownload';
  }

  bool _queueTargetContainsIp(String? target, String ipAddress) {
    final rawTarget = target?.trim() ?? '';
    if (rawTarget.isEmpty) {
      return false;
    }

    final ipValue = _ipv4ToInt(ipAddress);
    if (ipValue == null) {
      return false;
    }

    for (final item in rawTarget.split(',')) {
      final normalized = item.trim();
      if (normalized.isEmpty) {
        continue;
      }

      final parts = normalized.split('/');
      final baseAddress = parts.first.trim();
      if (baseAddress == ipAddress) {
        return true;
      }

      if (parts.length == 2) {
        final networkValue = _ipv4ToInt(baseAddress);
        final prefixLength = int.tryParse(parts[1].trim());
        if (networkValue == null ||
            prefixLength == null ||
            prefixLength < 0 ||
            prefixLength > 32) {
          continue;
        }

        final mask = prefixLength == 0
            ? 0
            : (0xFFFFFFFF << (32 - prefixLength));
        if ((ipValue & mask) == (networkValue & mask)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _queueUsesPcq(String? queueValue, Map<String, String> queueTypeKinds) {
    final rawQueue = queueValue?.trim() ?? '';
    if (rawQueue.isEmpty) {
      return false;
    }

    for (final item in rawQueue.split('/')) {
      final normalized = item.trim();
      if (normalized.isEmpty) {
        continue;
      }

      if (normalized.toLowerCase().contains('pcq')) {
        return true;
      }

      final kind = queueTypeKinds[normalized]?.toLowerCase() ?? '';
      if (kind.contains('pcq')) {
        return true;
      }
    }

    return false;
  }

  bool _isDhcpAutoQueueName(String? queueName) {
    final normalized = queueName?.trim().toLowerCase() ?? '';
    return normalized.startsWith('dhcp-ds<');
  }

  int _queueTargetSpecificity(String? target, String ipAddress) {
    final rawTarget = target?.trim() ?? '';
    if (rawTarget.isEmpty) {
      return 0;
    }

    final ipValue = _ipv4ToInt(ipAddress);
    if (ipValue == null) {
      return 0;
    }

    var best = 0;
    for (final item in rawTarget.split(',')) {
      final normalized = item.trim();
      if (normalized.isEmpty) {
        continue;
      }

      final parts = normalized.split('/');
      final baseAddress = parts.first.trim();
      if (baseAddress == ipAddress) {
        if (best < 32) {
          best = 32;
        }
        continue;
      }

      if (parts.length != 2) {
        continue;
      }

      final networkValue = _ipv4ToInt(baseAddress);
      final prefixLength = int.tryParse(parts[1].trim());
      if (networkValue == null ||
          prefixLength == null ||
          prefixLength < 0 ||
          prefixLength > 32) {
        continue;
      }

      final mask = prefixLength == 0 ? 0 : (0xFFFFFFFF << (32 - prefixLength));
      if ((ipValue & mask) == (networkValue & mask) && prefixLength > best) {
        best = prefixLength;
      }
    }

    return best;
  }

  String? _normalizeQueueGroupLabel(String? value) {
    final rawValue = value?.trim() ?? '';
    if (rawValue.isEmpty) {
      return null;
    }

    const ignoredValues = {
      'none',
      'global',
      'global-in',
      'global-out',
      'global-total',
    };
    if (ignoredValues.contains(rawValue.toLowerCase())) {
      return null;
    }

    return rawValue.split(RegExp(r'\s+')).first.trim();
  }

  Future<Map<String, String>?> _getSimpleQueueSpeed(String ipAddress) async {
    List<Map<String, String>> queueTypes = const [];
    try {
      queueTypes = await _talk([
        '/queue/type/print',
        _proplist([
          'name',
          'kind',
          'pcq-rate',
          'pcq-limit',
          'pcq-total-limit',
          'pcq-classifier',
        ]),
      ], timeout: const Duration(seconds: 4));
    } catch (_) {
      queueTypes = const [];
    }

    final queueTypeKinds = <String, String>{};
    final queueTypesByName = <String, Map<String, String>>{};
    for (final type in queueTypes) {
      final name = type['name']?.trim();
      if (name == null || name.isEmpty) {
        continue;
      }
      queueTypeKinds[name] = type['kind']?.trim() ?? '';
      queueTypesByName[name] = type;
    }

    final queues = await _talk([
      '/queue/simple/print',
      _proplist([
        '.id',
        'name',
        'target',
        'max-limit',
        'limit-at',
        'queue',
        'parent',
        'disabled',
      ]),
    ], timeout: const Duration(seconds: 4));

    final queuesByName = <String, Map<String, String>>{};
    for (final queue in queues) {
      final name = queue['name']?.trim();
      if (name != null && name.isNotEmpty) {
        queuesByName[name] = queue;
      }
    }

    final matches = queues.where((queue) {
      if (_isDisabledFlag(queue['disabled'])) {
        return false;
      }
      return _queueTargetContainsIp(queue['target'], ipAddress);
    }).toList();

    if (matches.isEmpty) {
      return null;
    }

    String resolveRate(Map<String, String> queue) {
      final queueValue = queue['queue']?.trim() ?? '';
      final usesPcq = _queueUsesPcq(queueValue, queueTypeKinds);
      if (usesPcq) {
        final queueParts = queueValue.split('/');
        final uploadType = queueParts.isNotEmpty ? queueParts.first.trim() : '';
        final downloadType = queueParts.length > 1 ? queueParts[1].trim() : '';
        final uploadRate = _formatSingleRateValue(
          queueTypesByName[uploadType]?['pcq-rate'],
        );
        final downloadRate = _formatSingleRateValue(
          queueTypesByName[downloadType]?['pcq-rate'],
        );

        if (uploadRate.isNotEmpty || downloadRate.isNotEmpty) {
          final fallbackRate = _firstUsableRateValue(
            queue['max-limit'],
            queue['limit-at'],
          );
          final fallbackParts = _splitFormattedRatePair(fallbackRate);
          return _mergeRatePair(
            uploadRate.isNotEmpty ? uploadRate : fallbackParts['upload'],
            downloadRate.isNotEmpty ? downloadRate : fallbackParts['download'],
          );
        }
      }

      final directRate = _firstUsableRateValue(
        queue['max-limit'],
        queue['limit-at'],
      );
      if (directRate.isNotEmpty) {
        return directRate;
      }

      final parentName = queue['parent']?.trim();
      if (parentName == null || parentName.isEmpty) {
        return '';
      }

      final parentQueue = queuesByName[parentName];
      if (parentQueue == null) {
        return '';
      }

      return _firstUsableRateValue(
        parentQueue['max-limit'],
        parentQueue['limit-at'],
      );
    }

    matches.sort((a, b) {
      final aIsDhcpAutoQueue = _isDhcpAutoQueueName(a['name']) ? 1 : 0;
      final bIsDhcpAutoQueue = _isDhcpAutoQueueName(b['name']) ? 1 : 0;
      if (aIsDhcpAutoQueue != bIsDhcpAutoQueue) {
        return bIsDhcpAutoQueue.compareTo(aIsDhcpAutoQueue);
      }

      final aSpecificity = _queueTargetSpecificity(a['target'], ipAddress);
      final bSpecificity = _queueTargetSpecificity(b['target'], ipAddress);
      if (aSpecificity != bSpecificity) {
        return bSpecificity.compareTo(aSpecificity);
      }

      final aPcq = _queueUsesPcq(a['queue'], queueTypeKinds) ? 1 : 0;
      final bPcq = _queueUsesPcq(b['queue'], queueTypeKinds) ? 1 : 0;
      if (aPcq != bPcq) {
        return bPcq.compareTo(aPcq);
      }

      final aRate = resolveRate(a).isNotEmpty ? 1 : 0;
      final bRate = resolveRate(b).isNotEmpty ? 1 : 0;
      if (aRate != bRate) {
        return bRate.compareTo(aRate);
      }

      return 0;
    });

    final selectedQueue = matches.first;
    final speedLimit = resolveRate(selectedQueue);
    final usesPcq = _queueUsesPcq(selectedQueue['queue'], queueTypeKinds);
    final groupLabel = _normalizeQueueGroupLabel(selectedQueue['parent']);
    final queueName = selectedQueue['name']?.trim() ?? '';
    final isDhcpAutoQueue = _isDhcpAutoQueueName(queueName);
    final policyLabel = usesPcq
        ? 'PCQ'
        : isDhcpAutoQueue
        ? 'DHCP'
        : (groupLabel ??
              (queueName.isNotEmpty
                  ? queueName.split(RegExp(r'\s+')).first
                  : 'Queue'));

    return {
      'max_limit': speedLimit,
      'rate_limit': speedLimit,
      'source': isDhcpAutoQueue ? 'dhcp_lease' : 'simple_queue',
      'policy_label': policyLabel,
      'policy_kind': usesPcq
          ? 'pcq'
          : isDhcpAutoQueue
          ? 'dhcp'
          : (groupLabel != null ? 'group' : 'queue'),
      'queue_name': queueName,
      'queue_parent': selectedQueue['parent']?.trim() ?? '',
    };
  }

  Future<String?> _findIpForMac(String macAddress) async {
    final mac = _normalizeMac(macAddress);
    if (mac == null) {
      return null;
    }

    try {
      final leases = await _talk([
        '/ip/dhcp-server/lease/print',
        '?=mac-address=$mac',
        _proplist(['.id', 'address', 'mac-address', 'status']),
      ]);
      for (final lease in leases) {
        final address = lease['address'];
        if (address != null && address.isNotEmpty) {
          return address;
        }
      }
    } catch (_) {}

    try {
      final arps = await _talk([
        '/ip/arp/print',
        '?=mac-address=$mac',
        _proplist(['.id', 'address', 'mac-address']),
      ]);
      for (final arp in arps) {
        final address = arp['address'];
        if (address != null && address.isNotEmpty) {
          return address;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _resolveTargetIp(String target) async {
    final trimmed = target.trim();
    final isMacAddress =
        trimmed.contains(':') && trimmed.split(':').length == 6;
    if (isMacAddress) {
      return _findIpForMac(trimmed);
    }

    final ipAddress = trimmed.split('/').first.trim();
    return _ipv4ToInt(ipAddress) == null ? null : ipAddress;
  }

  Future<Map<String, String>?> _findDhcpLease({
    String? ipAddress,
    String? macAddress,
  }) async {
    final proplist = _proplist([
      '.id',
      'address',
      'mac-address',
      'host-name',
      'comment',
      'dynamic',
      'status',
      'server',
      'rate-limit',
      'block-access',
    ]);

    if (ipAddress != null && ipAddress.isNotEmpty) {
      try {
        final leases = await _talk([
          '/ip/dhcp-server/lease/print',
          '?=address=$ipAddress',
          proplist,
        ], timeout: const Duration(seconds: 4));
        if (leases.isNotEmpty) {
          return leases.first;
        }
      } catch (_) {}
    }

    final mac = _normalizeMac(macAddress);
    if (mac != null) {
      try {
        final leases = await _talk([
          '/ip/dhcp-server/lease/print',
          '?=mac-address=$mac',
          proplist,
        ], timeout: const Duration(seconds: 4));
        if (leases.isNotEmpty) {
          return leases.first;
        }
      } catch (_) {}
    }

    return null;
  }

  Future<bool> makeClientStatic({String? ipAddress, String? macAddress}) async {
    if (_client == null || !isConnected) {
      throw Exception('Connection is not established');
    }

    final ip = ipAddress?.trim();
    final mac = _normalizeMac(macAddress);
    if ((ip == null || ip.isEmpty) && mac == null) {
      throw Exception('IP or MAC is required to make a client static.');
    }

    final lease = await _findDhcpLease(ipAddress: ip, macAddress: mac);
    final leaseId = lease?['.id'];
    if (leaseId != null && leaseId.isNotEmpty) {
      final dynamic = lease?['dynamic']?.toLowerCase();
      if (dynamic == 'false' || dynamic == 'no') {
        return true;
      }

      await _talk([
        '/ip/dhcp-server/lease/make-static',
        '=numbers=$leaseId',
      ], timeout: const Duration(seconds: 4));
      return true;
    }

    if (ip != null && ip.isNotEmpty && mac != null) {
      await _talk([
        '/ip/dhcp-server/lease/add',
        '=address=$ip',
        '=mac-address=$mac',
        '=comment=$_staticMarker',
      ], timeout: const Duration(seconds: 4));
      return true;
    }

    throw Exception('DHCP lease was not found for this client.');
  }

  Future<List<Map<String, String>>> _getDhcpServers() {
    return _talk([
      '/ip/dhcp-server/print',
      _proplist(['.id', 'name', 'address-pool', 'disabled']),
    ], timeout: const Duration(seconds: 4));
  }

  Future<Map<String, String>> _getPrimaryDhcpServer() async {
    final servers = await _getDhcpServers();
    if (servers.isEmpty) {
      throw Exception('No DHCP server was found.');
    }
    return servers.first;
  }

  Future<String> _firstNonStaticAddressPool() async {
    try {
      final servers = await _getDhcpServers();
      for (final server in servers) {
        final poolName = server['address-pool']?.trim();
        if (poolName != null &&
            poolName.isNotEmpty &&
            poolName != _staticOnlyPool) {
          return poolName;
        }
      }
    } catch (_) {}

    final pools = await _talk([
      '/ip/pool/print',
      _proplist(['.id', 'name']),
    ], timeout: const Duration(seconds: 4));

    for (final pool in pools) {
      final name = pool['name']?.trim();
      if (name != null && name.isNotEmpty && name != _staticOnlyPool) {
        return name;
      }
    }

    throw Exception('No DHCP address pool except $_staticOnlyPool was found.');
  }

  Future<bool> lockNewConnections() async {
    if (_client == null || !isConnected) {
      throw Exception('Connection is not established');
    }

    final server = await _getPrimaryDhcpServer();
    final id = server['.id'];
    if (id == null || id.isEmpty) {
      throw Exception('DHCP server id was not found.');
    }

    await _talk([
      '/ip/dhcp-server/set',
      '=.id=$id',
      '=address-pool=$_staticOnlyPool',
    ], timeout: const Duration(seconds: 4));
    return true;
  }

  Future<bool> unlockNewConnections() async {
    if (_client == null || !isConnected) {
      throw Exception('Connection is not established');
    }

    final server = await _getPrimaryDhcpServer();
    final id = server['.id'];
    if (id == null || id.isEmpty) {
      throw Exception('DHCP server id was not found.');
    }

    final pool = await _firstNonStaticAddressPool();
    await _talk([
      '/ip/dhcp-server/set',
      '=.id=$id',
      '=address-pool=$pool',
    ], timeout: const Duration(seconds: 4));
    return true;
  }

  Future<bool> isNewConnectionsLocked() async {
    if (_client == null || !isConnected) {
      return false;
    }

    try {
      final server = await _getPrimaryDhcpServer();
      return server['address-pool'] == _staticOnlyPool &&
          !_isDisabledFlag(server['disabled']);
    } catch (_) {
      return false;
    }
  }

  Future<String> setDhcpLeaseDisplayName({
    String? ipAddress,
    String? macAddress,
    required String displayName,
  }) async {
    if (_client == null || !isConnected) {
      throw Exception('Connection is not established');
    }

    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      throw Exception('Display name is required.');
    }

    try {
      if (ipAddress != null && ipAddress.trim().isNotEmpty) {
        await _talk([
          '/ip/dhcp-server/lease/set',
          '=numbers=[find where address=${ipAddress.trim()}]',
          '=comment=$normalizedName',
        ], timeout: const Duration(seconds: 4));
        return normalizedName;
      }
    } catch (_) {}

    final lease = await _findDhcpLease(
      ipAddress: ipAddress?.trim(),
      macAddress: macAddress,
    );
    final leaseId = lease?['.id'];
    if (leaseId == null || leaseId.isEmpty) {
      throw Exception('DHCP lease was not found for this client.');
    }

    await _talk([
      '/ip/dhcp-server/lease/set',
      '=.id=$leaseId',
      '=comment=$normalizedName',
    ], timeout: const Duration(seconds: 4));
    return normalizedName;
  }

  Future<bool> connect(MikroTikConnection connection) async {
    try {
      _routerInfoCache = null;
      _wirelessFeaturesEnabled = null;
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
        _routerInfoCache = null;
        _wirelessFeaturesEnabled = null;
      }
      return success;
    } catch (e) {
      _client = null;
      _connection = null;
      _routerInfoCache = null;
      _wirelessFeaturesEnabled = null;
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
    _routerInfoCache = null;
    _wirelessFeaturesEnabled = null;
  }

  /// دریافت همه کاربران و دستگاه‌های متصل
  /// مشابه POST /api/clients/all
  Future<Map<String, dynamic>> getAllClients() async {
    if (_client == null || !isConnected) {
      throw Exception('اتصال برقرار نشده');
    }

    try {
      final allClients = <ClientInfo>[];
      final wirelessFeaturesEnabled = await _supportsWirelessFeatures();

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
      if (wirelessFeaturesEnabled) {
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
                hostName: _displayNameFromLease(lease),
                status: lease['status'],
                server: lease['server'],
                expiresAfter: lease['expires-after'],
                id: lease['.id'],
                isStaticLease: isStaticLease,
                rawData: Map<String, String>.from(lease),
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
        final arpEntries = await _talk([
          '/ip/arp/print',
          _proplist(['.id', 'address', 'mac-address', 'interface']),
        ]);
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

      // دریافت همه کلاینت‌ها (مشابه getAllClients)
      final allClientsResult = await getAllClients();
      final clients = (allClientsResult['clients'] as List)
          .map((c) => ClientInfo.fromMap(c as Map<String, dynamic>))
          .toList();

      // افزودن اطلاعات ARP
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
      final wirelessFeaturesEnabled = await _supportsWirelessFeatures();

      // دریافت DHCP leases برای hostname
      final dhcpLeasesDict = <String, Map<String, String>>{};
      var dhcpLeasesSnapshot = <Map<String, String>>[];
      try {
        final dhcpLeases = await _talk([
          '/ip/dhcp-server/lease/print',
          _proplist([
            '.id',
            'address',
            'mac-address',
            'host-name',
            'comment',
            'status',
            'server',
            'expires-after',
            'dynamic',
          ]),
        ]);
        dhcpLeasesSnapshot = dhcpLeases;
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
      if (wirelessFeaturesEnabled) {
        try {
          final wirelessClients = await _talk([
            '/interface/wireless/registration-table/print',
            _proplist([
              '.id',
              'mac-address',
              'interface',
              'ssid',
              'signal-strength',
              'uptime',
              'last-ip',
            ]),
          ]);
          for (var client in wirelessClients) {
            final mac = client['mac-address']?.toUpperCase();
            final dhcpInfo = mac != null ? dhcpLeasesDict[mac] : null;
            final arpInfo = mac != null ? arpTable[mac] : null;

            // اولویت: DHCP > ARP
            final ipAddress = dhcpInfo?['address'] ?? arpInfo?['address'];
            final hostName = _displayNameFromLease(dhcpInfo);

            // تشخیص Static/Dynamic از DHCP lease
            bool? isStaticLease;
            if (dhcpInfo != null && dhcpInfo.containsKey('dynamic')) {
              final dynamicValue = dhcpInfo['dynamic']
                  ?.toString()
                  .toLowerCase();
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
                rawData: Map<String, String>.from(client)
                  ..['host-name'] = hostName ?? ''
                  ..['comment'] = dhcpInfo?['comment'] ?? '',
              ),
            );
          }
        } catch (e) {
          // Wireless ممکن است فعال نباشد
        }

        // 2. DHCP Leases (Bound) که wireless نیستند
      }

      try {
        final dhcpLeases = dhcpLeasesSnapshot;
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
                  hostName: _displayNameFromLease(lease),
                  status: lease['status'],
                  id: lease['.id'],
                  isStaticLease: isStaticLease,
                  rawData: Map<String, String>.from(lease),
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
        final hotspotActive = await _talk([
          '/ip/hotspot/active/print',
          _proplist([
            '.id',
            'user',
            'address',
            'mac-address',
            'uptime',
            'bytes-in',
            'bytes-out',
            'login-by',
            'server',
          ]),
        ]);
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
    if (_client == null || !isConnected) {
      throw Exception('Connection is not established');
    }

    final fingerprint = DeviceFingerprint.fromClientInfo(
      ipAddress,
      macAddress,
      hostname,
      ssid,
    );
    final fingerprintService = DeviceFingerprintService();
    await fingerprintService.saveBannedFingerprint(fingerprint);

    return banClient(
      ipAddress,
      macAddress: macAddress,
      comment: 'Banned: ${fingerprint.fingerprintId}',
    );
  }

  /// 4. Wireless Access List
  Future<bool> banClient(
    String ipAddress, {
    String? macAddress,
    String? comment,
  }) async {
    if (_client == null || !isConnected) {
      throw Exception('Connection is not established');
    }

    try {
      final macToUse =
          _normalizeMac(macAddress) ?? await _findMacForIp(ipAddress);
      final reason = (comment == null || comment.trim().isEmpty)
          ? 'Manual ban'
          : comment.trim();
      final banComment = '$_banMarker $reason';

      await _ensureRawDropRule(
        ipAddress: ipAddress,
        comment: '$banComment - IP',
      );

      if (macToUse != null) {
        await _ensureRawDropRule(
          macAddress: macToUse,
          comment: '$banComment - MAC',
        );

        try {
          await _setDhcpBlockForMac(macToUse, block: true);
        } catch (_) {}

        try {
          await _ensureWirelessAccessRule(
            macToUse,
            allow: false,
            comment: '$banComment - Wireless',
          );
        } catch (_) {}
      }

      return true;
    } catch (e) {
      throw Exception('Ban failed: $e');
    }
  }

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
      throw Exception('Connection is not established');
    }

    try {
      final macToUse =
          _normalizeMac(macAddress) ?? await _findMacForIp(ipAddress);
      final rawRules = await _rawRulesFor(
        ipAddress: ipAddress,
        macAddress: macToUse,
      );
      var removedManagedRawRule = false;

      for (final rule in rawRules) {
        final id = rule['.id'];
        if (id == null || !_isManagedBanComment(rule['comment'])) {
          continue;
        }
        try {
          await _talk(['/ip/firewall/raw/remove', '=.id=$id']);
          removedManagedRawRule = true;
        } catch (_) {}
      }

      if (macToUse != null) {
        try {
          await _setDhcpBlockForMac(
            macToUse,
            block: false,
            allowLegacyUnblock: removedManagedRawRule,
          );
        } catch (_) {}

        try {
          await _removeManagedAccessRules(
            macToUse,
            includeLegacyEmptyDeny: removedManagedRawRule,
          );
        } catch (_) {}
      }

      return removedManagedRawRule || macToUse != null || ipAddress.isNotEmpty;
    } catch (e) {
      throw Exception('Unban failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getBannedClients() async {
    if (_client == null || !isConnected) {
      throw Exception('Connection is not established');
    }

    try {
      final wirelessFeaturesEnabled = await _supportsWirelessFeatures();
      final rawRules = await _talk([
        '/ip/firewall/raw/print',
        _proplist([
          '.id',
          'chain',
          'action',
          'src-address',
          'src-mac-address',
          'comment',
        ]),
      ]);

      final dhcpByIp = <String, Map<String, String>>{};
      final dhcpByMac = <String, Map<String, String>>{};
      try {
        final leases = await _talk([
          '/ip/dhcp-server/lease/print',
          _proplist([
            '.id',
            'address',
            'mac-address',
            'host-name',
            'status',
            'block-access',
            'comment',
          ]),
        ]);
        for (final lease in leases) {
          final ip = lease['address'];
          final mac = _normalizeMac(lease['mac-address']);
          if (ip != null && ip.isNotEmpty) {
            dhcpByIp[ip] = lease;
          }
          if (mac != null) {
            dhcpByMac[mac] = lease;
          }
        }
      } catch (_) {}

      final arpByIp = <String, Map<String, String>>{};
      final arpByMac = <String, Map<String, String>>{};
      try {
        final arps = await _talk([
          '/ip/arp/print',
          _proplist(['.id', 'address', 'mac-address', 'interface']),
        ]);
        for (final arp in arps) {
          final ip = arp['address'];
          final mac = _normalizeMac(arp['mac-address']);
          if (ip != null && ip.isNotEmpty) {
            arpByIp[ip] = arp;
          }
          if (mac != null) {
            arpByMac[mac] = arp;
          }
        }
      } catch (_) {}

      final accessByMac = <String, Map<String, String>>{};
      if (wirelessFeaturesEnabled) {
        try {
          final accessList = await _talk([
            '/interface/wireless/access-list/print',
            _proplist([
              '.id',
              'mac-address',
              'authentication',
              'forwarding',
              'action',
              'comment',
            ]),
          ]);
          for (final rule in accessList) {
            final mac = _normalizeMac(rule['mac-address']);
            if (mac != null) {
              accessByMac[mac] = rule;
            }
          }
        } catch (_) {}
      }

      final grouped = <String, Map<String, dynamic>>{};
      for (final rule in rawRules) {
        if (rule['chain'] != 'prerouting' ||
            rule['action'] != 'drop' ||
            !_isManagedBanComment(rule['comment'])) {
          continue;
        }

        var ip = rule['src-address'];
        var mac = _normalizeMac(rule['src-mac-address']);
        if (mac == null && ip != null) {
          mac =
              _normalizeMac(dhcpByIp[ip]?['mac-address']) ??
              _normalizeMac(arpByIp[ip]?['mac-address']);
        }
        if ((ip == null || ip.isEmpty) && mac != null) {
          ip = dhcpByMac[mac]?['address'] ?? arpByMac[mac]?['address'];
        }

        final key = mac != null ? 'mac:$mac' : 'ip:${ip ?? rule['.id']}';
        final item = grouped.putIfAbsent(key, () {
          return {
            'address': ip,
            'mac_address': mac,
            'chains': <String>[],
            'rule_ids': <String>[],
            'comment': rule['comment'] ?? '',
          };
        });

        if ((item['address'] == null || item['address'] == '') && ip != null) {
          item['address'] = ip;
        }
        if ((item['mac_address'] == null || item['mac_address'] == '') &&
            mac != null) {
          item['mac_address'] = mac;
        }

        final chain = rule['chain'];
        if (chain != null && !(item['chains'] as List).contains(chain)) {
          (item['chains'] as List).add(chain);
        }
        final id = rule['.id'];
        if (id != null && !(item['rule_ids'] as List).contains(id)) {
          (item['rule_ids'] as List).add(id);
        }
      }

      for (final client in grouped.values) {
        final mac = _normalizeMac(client['mac_address']?.toString());
        final ip = client['address']?.toString();
        final lease = mac != null
            ? dhcpByMac[mac]
            : (ip != null ? dhcpByIp[ip] : null);
        if (lease != null) {
          client['host_name'] = _displayNameFromLease(lease);
          client['dhcp_status'] = lease['status'];
          client['dhcp_blocked'] = _isTruthy(lease['block-access']);
        }
        if (mac != null && accessByMac.containsKey(mac)) {
          client['wireless_blocked'] = _isDenyLikeAccessRule(accessByMac[mac]!);
        }
      }

      return grouped.values.toList();
    } catch (e) {
      throw Exception('Failed to get banned clients: $e');
    }
  }

  Future<bool> _setDhcpLeaseRateLimit(
    String ipAddress,
    String rateLimit,
  ) async {
    final normalizedIp = ipAddress.trim();
    final lease = await _findDhcpLease(ipAddress: normalizedIp);
    if (lease == null) {
      throw Exception('DHCP lease for $normalizedIp was not found.');
    }

    final leaseId = lease['.id'];
    if (leaseId == null || leaseId.isEmpty) {
      throw Exception('DHCP lease id for $normalizedIp was not found.');
    }

    final normalizedRateLimit = rateLimit.trim();
    final isDynamicLease = _isTruthy(lease['dynamic']);
    final currentRateLimit = lease['rate-limit']?.trim() ?? '';

    if (isDynamicLease) {
      if (normalizedRateLimit.isEmpty && currentRateLimit.isEmpty) {
        return true;
      }

      await _talk([
        '/ip/dhcp-server/lease/make-static',
        '=numbers=$leaseId',
      ], timeout: const Duration(seconds: 4));
    }

    await _talk([
      '/ip/dhcp-server/lease/set',
      '=.id=$leaseId',
      '=rate-limit=$normalizedRateLimit',
    ], timeout: const Duration(seconds: 4));
    return true;
  }

  Future<bool> setClientSpeed(String target, String maxLimit) async {
    if (_client == null || !isConnected) {
      throw Exception('????? ?????? ????');
    }

    final targetIp = await _resolveTargetIp(target);
    if (targetIp == null) {
      throw Exception('??????? IP ?? ???? target ???? ???: $target');
    }

    return _setDhcpLeaseRateLimit(targetIp, _formatRatePair(maxLimit));
  }

  Future<bool> removeClientSpeed(String target) async {
    if (_client == null || !isConnected) {
      throw Exception('????? ?????? ????');
    }

    final targetIp = await _resolveTargetIp(target);
    if (targetIp == null) {
      throw Exception('??????? IP ?? ???? target ???? ???: $target');
    }

    return _setDhcpLeaseRateLimit(targetIp, '');
  }

  Future<Map<String, String>?> getClientSpeed(String target) async {
    if (_client == null || !isConnected) {
      throw Exception('????? ?????? ????');
    }

    final targetIp = await _resolveTargetIp(target);
    if (targetIp == null) {
      return null;
    }

    final queueInfo = await _getSimpleQueueSpeed(targetIp);
    if (queueInfo != null) {
      return queueInfo;
    }

    final leases = await _talk([
      '/ip/dhcp-server/lease/print',
      '?=address=$targetIp',
      _proplist(['.id', 'address', 'mac-address', 'rate-limit']),
    ], timeout: const Duration(seconds: 4));
    if (leases.isEmpty) {
      return null;
    }

    final rateLimit = leases.first['rate-limit']?.trim() ?? '';
    if (!_hasUsableMaxLimit(rateLimit)) {
      return null;
    }

    return {
      'max_limit': _formatRatePair(rateLimit),
      'rate_limit': _formatRatePair(rateLimit),
      'lease_id': leases.first['.id'] ?? '',
      'source': 'dhcp_lease',
      'policy_label': 'DHCP',
      'policy_kind': 'dhcp',
    };
  }

  Future<bool> legacySetClientSpeed(String target, String maxLimit) {
    return setClientSpeed(target, maxLimit);
  }

  Future<bool> legacyRemoveClientSpeed(String target) {
    return removeClientSpeed(target);
  }

  Future<Map<String, String>?> legacyGetClientSpeed(String target) {
    return getClientSpeed(target);
  }

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

      // دریافت board-name و model از /system/routerboard/print (اگر موجود باشد)
      String? boardName;
      String? model;
      try {
        final routerboard = await _client!.talk(['/system/routerboard/print']);
        if (routerboard.isNotEmpty) {
          boardName = routerboard[0]['board-name']?.toString();
          model = routerboard[0]['model']?.toString();
        }
      } catch (e) {
        // ignore - routerboard data optional است
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
        'model': model ?? 'Unknown',
        'platform': resourceData['platform']?.toString() ?? 'Unknown',
        'identity': identity ?? 'Unknown',
      };

      final wirelessFeaturesEnabled = !_isWirelessUnsupportedRouter(routerInfo);
      routerInfo['wireless-features-enabled'] = wirelessFeaturesEnabled;
      _routerInfoCache = routerInfo;
      _wirelessFeaturesEnabled = wirelessFeaturesEnabled;

      return routerInfo;
    } catch (e) {
      throw Exception('خطا در دریافت اطلاعات روتر: $e');
    }
  }

  /// قفل کردن اتصال دستگاه‌های جدید
  /// این تابع از ابتدا مانع اتصال دستگاه‌های جدید می‌شود اما دستگاه‌های قبلاً متصل شده کار می‌کنند
  ///
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
            result['host_name'] = _displayNameFromLease(lease);
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
