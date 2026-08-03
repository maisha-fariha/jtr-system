/// Parsed `GET /api/pos/bootstrap` (and optional activation `bootstrap` map).
class PosBootstrapConfig {
  const PosBootstrapConfig({
    required this.realtimeEnabled,
    this.reverb,
  });

  final bool realtimeEnabled;
  final ReverbConnectionConfig? reverb;

  bool get shouldConnect =>
      realtimeEnabled && reverb != null && reverb!.appKey.isNotEmpty;

  factory PosBootstrapConfig.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    final enabled = data['realtime_enabled'] == true;
    final reverbRaw = data['reverb'];
    ReverbConnectionConfig? reverb;
    if (reverbRaw is Map) {
      reverb = ReverbConnectionConfig.fromJson(
        Map<String, dynamic>.from(reverbRaw),
      );
    }

    return PosBootstrapConfig(
      realtimeEnabled: enabled,
      reverb: reverb,
    );
  }
}

class ReverbConnectionConfig {
  const ReverbConnectionConfig({
    required this.appKey,
    required this.port,
    required this.useTls,
    this.host,
  });

  final String appKey;
  final int port;
  final bool useTls;

  /// Optional override; defaults to API hostname when null/empty.
  final String? host;

  factory ReverbConnectionConfig.fromJson(Map<String, dynamic> json) {
    final key = json['app_key']?.toString().trim() ??
        json['key']?.toString().trim() ??
        '';
    final portRaw = json['port'];
    final port = portRaw is num
        ? portRaw.toInt()
        : int.tryParse(portRaw?.toString() ?? '') ?? 6001;
    final useTls = json['use_tls'] == true ||
        json['useTLS'] == true ||
        json['forceTLS'] == true;
    final host = json['host']?.toString().trim() ??
        json['wsHost']?.toString().trim() ??
        json['hostname']?.toString().trim();

    return ReverbConnectionConfig(
      appKey: key,
      port: port,
      useTls: useTls,
      host: (host == null || host.isEmpty) ? null : host,
    );
  }
}

/// Parsed table lock payload from `TableSessionStarted` / `TableSessionEnded`.
class TableSessionWireEvent {
  const TableSessionWireEvent({
    required this.tableId,
    required this.isLocked,
    this.floorId,
    this.lockedBy,
    this.lockedAt,
    this.status,
    this.sessionWaiterName,
  });

  final int tableId;
  final int? floorId;
  final int? lockedBy;
  final String? lockedAt;
  final bool isLocked;
  final String? status;
  final String? sessionWaiterName;

  factory TableSessionWireEvent.fromJson(Map<String, dynamic> json) {
    final nested = json['table'] is Map
        ? Map<String, dynamic>.from(json['table'] as Map)
        : null;

    int? asInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '');
    }

    final id = asInt(json['id']) ?? asInt(nested?['id']) ?? 0;
    final floorId = asInt(json['floor_id']) ?? asInt(nested?['floor_id']);
    final lockedBy = asInt(json['locked_by']) ?? asInt(nested?['locked_by']);
    final lockedAt =
        json['locked_at']?.toString() ?? nested?['locked_at']?.toString();
    final explicitLocked = json.containsKey('is_locked')
        ? json['is_locked'] == true
        : (nested != null && nested.containsKey('is_locked')
            ? nested['is_locked'] == true
            : null);
    final status =
        json['status']?.toString() ?? nested?['status']?.toString();
    final isLocked = explicitLocked ??
        (status?.toLowerCase() == 'open');
    final waiter = json['session_waiter_name']?.toString() ??
        nested?['session_waiter_name']?.toString();

    return TableSessionWireEvent(
      tableId: id,
      floorId: floorId,
      lockedBy: lockedBy,
      lockedAt: lockedAt,
      isLocked: isLocked,
      status: status,
      sessionWaiterName: waiter,
    );
  }

  /// Patch fields applied onto a cached tables-list row.
  Map<String, dynamic> toTablePatch() {
    return {
      'id': tableId,
      if (floorId != null) 'floor_id': floorId,
      'locked_by': lockedBy,
      'locked_at': lockedAt,
      'is_locked': isLocked,
      if (status != null) 'status': status,
      // Always write — null clears prior owner on TableSessionEnded.
      'session_waiter_name': sessionWaiterName,
      'session_owner_id': lockedBy,
    };
  }
}

class ForceLogoutWireEvent {
  const ForceLogoutWireEvent({
    required this.userId,
    required this.message,
    this.timestamp,
  });

  final int userId;
  final String message;
  final String? timestamp;

  factory ForceLogoutWireEvent.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'] is num
        ? (json['user_id'] as num).toInt()
        : int.tryParse(json['user_id']?.toString() ?? '') ?? 0;
    final message = json['message']?.toString().trim().isNotEmpty == true
        ? json['message'].toString().trim()
        : 'Vous avez été déconnecté car une autre session a été ouverte.';
    return ForceLogoutWireEvent(
      userId: userId,
      message: message,
      timestamp: json['timestamp']?.toString(),
    );
  }
}
