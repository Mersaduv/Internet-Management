import '../models/client_info.dart';

/// Resolves human-readable device labels consistently across list and detail UI.
abstract final class ClientDisplayName {
  static const String banMarker = '[Ariyabod BAN]';
  static const String staticMarker = '[Ariyabod STATIC]';

  /// Best known friendly name, or null when only IP/MAC fallbacks remain.
  static String? resolveHostName(ClientInfo client) {
    final hostName = _trimmed(client.hostName);
    if (hostName != null) {
      return hostName;
    }

    final user = _trimmed(client.user);
    if (user != null) {
      return user;
    }

    final name = _trimmed(client.name);
    if (name != null) {
      return name;
    }

    final neighborIdentity = _trimmed(client.rawData['identity']?.toString());
    if (neighborIdentity != null) {
      return neighborIdentity;
    }

    final rawHostName = _trimmed(client.rawData['host-name']?.toString());
    if (rawHostName != null) {
      return rawHostName;
    }

    final comment = displayNameFromLeaseComment(
      client.rawData['comment']?.toString(),
    );
    if (comment != null) {
      return comment;
    }

    return null;
  }

  /// Full label for UI: friendly name, then IP, then MAC, then [unknownLabel].
  static String displayLabel(
    ClientInfo client, {
    String devicePrefix = 'Device',
    String unknownLabel = 'Unknown Device',
  }) {
    final resolved = resolveHostName(client);
    if (resolved != null) {
      return resolved;
    }

    final ip = _trimmed(client.ipAddress);
    if (ip != null) {
      return '$devicePrefix $ip';
    }

    final mac = _trimmed(client.macAddress);
    if (mac != null) {
      return '$devicePrefix $mac';
    }

    return unknownLabel;
  }

  /// Parses DHCP lease comment / host-name the same way in provider and service.
  static String? displayNameFromLease(Map<String, String> lease) {
    final fromComment = displayNameFromLeaseComment(lease['comment']);
    if (fromComment != null) {
      return fromComment;
    }

    return _trimmed(lease['host-name']);
  }

  static String? displayNameFromLeaseComment(String? comment) {
    var value = comment?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }

    if (_isBannedComment(value)) {
      return null;
    }

    value = value
        .replaceAll(banMarker, '')
        .replaceAll(staticMarker, '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    if (value.isEmpty ||
        value.startsWith('Auto-banned:') ||
        value == 'Banned via Flutter App') {
      return null;
    }

    return value;
  }

  static bool _isBannedComment(String value) {
    return value.contains(banMarker) ||
        value.contains('Banned via Flutter App') ||
        value.startsWith('Auto-banned:') ||
        value.startsWith('Banned:');
  }

  static String? _trimmed(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
