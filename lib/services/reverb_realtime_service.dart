import 'dart:async';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/datasources/realtime_remote_datasource.dart';
import '../data/models/realtime/pos_bootstrap_config.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/session_repository.dart';
import '../utils/app_navigation.dart';
import '../utils/app_snackbar.dart';

/// Laravel Reverb (Pusher protocol) client for table locks + force logout.
///
/// Clients never publish business data — REST only; this service only listens.
class ReverbRealtimeService extends GetxService {
  ReverbRealtimeService({
    required RealtimeRemoteDataSource remote,
    required AuthRepository authRepository,
    required SessionRepository sessionRepository,
    required ApiClient apiClient,
  })  : _remote = remote,
        _authRepository = authRepository,
        _sessionRepository = sessionRepository,
        _apiClient = apiClient;

  final RealtimeRemoteDataSource _remote;
  final AuthRepository _authRepository;
  final SessionRepository _sessionRepository;
  final ApiClient _apiClient;

  static const eventTableSessionStarted = 'TableSessionStarted';
  static const eventTableSessionEnded = 'TableSessionEnded';
  static const eventForceLogout = 'force.logout';

  PusherChannelsClient? _client;
  StreamSubscription<void>? _connectionSub;
  final List<StreamSubscription<ChannelReadEvent>> _eventSubs = [];

  final Set<int> _subscribedFloorIds = {};
  bool _starting = false;
  bool _stopping = false;
  bool _forceLogoutHandling = false;
  bool _restartQueued = false;
  int _reconnectAttempts = 0;

  static const _maxReconnectAttempts = 5;
  static const _disconnectTimeout = Duration(seconds: 2);

  final isConnected = false.obs;
  final tablesLockRevision = 0.obs;

  /// Start (or restart) after login / cold-start restore.
  ///
  /// Safe to call concurrently (e.g. login + force_login verify): a second
  /// call while connecting queues one restart with the latest token.
  Future<void> start() async {
    if (_stopping) {
      _restartQueued = true;
      return;
    }
    if (_starting) {
      _restartQueued = true;
      return;
    }
    if (!_authRepository.isAuthenticated) {
      await stop();
      return;
    }
    final token = _apiClient.authToken;
    if (token == null || token.isEmpty) {
      await stop();
      return;
    }
    if (ApiConfig.deviceId == null ||
        ApiConfig.deviceId!.isEmpty ||
        ApiConfig.deviceToken == null ||
        ApiConfig.deviceToken!.isEmpty) {
      _log('skip start — missing device credentials');
      return;
    }

    _starting = true;
    _restartQueued = false;
    _reconnectAttempts = 0;
    try {
      final bootstrap = await _loadBootstrap();
      if (!bootstrap.shouldConnect) {
        _log(
          'realtime disabled (enabled=${bootstrap.realtimeEnabled}, '
          'reverb=${bootstrap.reverb != null}) — app continues on HTTP only',
        );
        await stop();
        return;
      }

      await _connect(bootstrap.reverb!);
    } catch (e, st) {
      _log('start failed: $e — continuing without realtime');
      debugPrintStack(stackTrace: st);
      await stop();
    } finally {
      _starting = false;
      if (_restartQueued && _authRepository.isAuthenticated) {
        _restartQueued = false;
        unawaited(start());
      }
    }
  }

  /// Tear down WS (logout / force logout / disable).
  ///
  /// Must not hang — HTTP force-logout navigates to login even when Reverb
  /// cannot connect (demo server often advertises WS but does not upgrade).
  ///
  /// [resetReconnectBudget] false when tearing down before an intentional
  /// reconnect so the first failure is not treated as "already maxed out".
  Future<void> stop({bool resetReconnectBudget = true}) async {
    if (_stopping) return;
    _stopping = true;
    isConnected.value = false;
    if (resetReconnectBudget) {
      _reconnectAttempts = _maxReconnectAttempts; // block further refresh()
    }
    try {
      _clearEventSubsOnlySync();
      await _connectionSub?.cancel();
      _connectionSub = null;
      final client = _client;
      _client = null;
      _subscribedFloorIds.clear();
      if (client != null) {
        try {
          await client.disconnect().timeout(_disconnectTimeout);
        } catch (_) {}
        try {
          client.dispose();
        } catch (_) {}
      }
    } finally {
      _stopping = false;
    }
  }

  /// Subscribe to `private-tables.floor.{id}` while viewing that floor.
  Future<void> subscribeFloor(int floorId) async {
    if (floorId <= 0) return;
    if (_subscribedFloorIds.contains(floorId)) return;
    final client = _client;
    if (client == null || !isConnected.value) return;
    _subscribedFloorIds.add(floorId);
    _subscribePrivateChannel(
      client,
      'private-tables.floor.$floorId',
      bindTableEvents: true,
    );
  }

  /// Re-bind core + floor channels after tables cache is refreshed.
  void resyncSubscriptions() {
    final client = _client;
    if (client == null || !isConnected.value) return;
    _subscribeCoreChannels(client);
  }

  Future<PosBootstrapConfig> _loadBootstrap() async {
    try {
      return await _remote.fetchBootstrap();
    } catch (e) {
      // Soft-fail: do not block login/session. HTTP flows keep working.
      _log('bootstrap GET failed: $e — realtime off, HTTP-only mode');
      return const PosBootstrapConfig(realtimeEnabled: false);
    }
  }

  Future<void> _connect(ReverbConnectionConfig reverb) async {
    // Tear down previous client without burning the reconnect budget.
    await stop(resetReconnectBudget: false);
    _reconnectAttempts = 0;

    final host = (reverb.host != null && reverb.host!.isNotEmpty)
        ? reverb.host!
        : (Uri.tryParse(ApiConfig.baseUrl)?.host ?? '');
    if (host.isEmpty) {
      _log('cannot connect — empty WS host');
      return;
    }

    final scheme = reverb.useTls ? 'wss' : 'ws';
    _log(
      'connecting $scheme://$host:${reverb.port}/app/${reverb.appKey}',
    );

    final options = PusherChannelsOptions.fromHost(
      scheme: scheme,
      host: host,
      key: reverb.appKey,
      port: reverb.port,
      shouldSupplyMetadataQueries: true,
      metadata: PusherChannelsOptionsMetadata.byDefault(),
    );

    late final PusherChannelsClient client;
    client = PusherChannelsClient.websocket(
      options: options,
      connectionErrorHandler: (exception, trace, refresh) {
        if (_stopping || _client == null || !identical(_client, client)) {
          _log('connection error ignored (stopping): $exception');
          return;
        }
        _reconnectAttempts++;
        if (_reconnectAttempts > _maxReconnectAttempts) {
          _log(
            'connection error: $exception — giving up after '
            '$_maxReconnectAttempts attempts (HTTP auth logout still works)',
          );
          unawaited(stop());
          return;
        }
        _log(
          'connection error: $exception — retry '
          '$_reconnectAttempts/$_maxReconnectAttempts',
        );
        refresh();
      },
      minimumReconnectDelayDuration: const Duration(seconds: 2),
    );
    _client = client;

    _connectionSub = client.onConnectionEstablished.listen((_) {
      if (_stopping || !identical(_client, client)) return;
      _reconnectAttempts = 0;
      isConnected.value = true;
      _log('connection established — subscribing channels');
      _subscribeCoreChannels(client);
    });

    try {
      await client.connect().timeout(const Duration(seconds: 8));
    } catch (e) {
      _log('initial connect failed: $e — continuing without realtime');
      // Do not block the app; HTTP Unauthenticated → login still works.
      await stop();
    }
  }

  void _subscribeCoreChannels(PusherChannelsClient client) {
    // Cancel previous listeners first (sync clear) so we never race-cancel
    // newly attached subscriptions.
    _clearEventSubsOnlySync();

    final userId = _authRepository.cachedSession?.user.id;
    if (userId != null && userId > 0) {
      _subscribePrivateChannel(
        client,
        'private-user.$userId',
        bindForceLogout: true,
      );
    }

    _subscribePrivateChannel(
      client,
      'private-tables',
      bindTableEvents: true,
    );

    // Floor channels for known floors in tables cache + active day zone.
    final floorIds = <int>{};
    for (final table in _sessionRepository.cachedTables) {
      final floor = table['floor_id'];
      if (floor is num && floor.toInt() > 0) {
        floorIds.add(floor.toInt());
      } else {
        final parsed = int.tryParse(floor?.toString() ?? '');
        if (parsed != null && parsed > 0) floorIds.add(parsed);
      }
    }
    final zoneId = _sessionRepository.cachedActiveDay?.salesZoneId;
    if (zoneId != null && zoneId > 0) floorIds.add(zoneId);

    _subscribedFloorIds
      ..clear()
      ..addAll(floorIds);
    for (final floorId in floorIds) {
      _subscribePrivateChannel(
        client,
        'private-tables.floor.$floorId',
        bindTableEvents: true,
      );
    }
  }

  void _subscribePrivateChannel(
    PusherChannelsClient client,
    String channelName, {
    bool bindTableEvents = false,
    bool bindForceLogout = false,
  }) {
    final channel = client.privateChannel(
      channelName,
      authorizationDelegate:
          EndpointAuthorizableChannelTokenAuthorizationDelegate
              .forPrivateChannel(
        authorizationEndpoint: Uri.parse(
          '${ApiConfig.baseUrl}${ApiEndpoints.broadcastingAuth}',
        ),
        // Package posts form-urlencoded body; don't force JSON content-type.
        headers: _authHeaders(),
        onAuthFailed: (exception, trace) {
          _log('auth failed for $channelName → $exception');
        },
      ),
      forceCreateNewInstance: true,
    );

    channel.subscribe();

    if (bindTableEvents) {
      _eventSubs.add(
        channel.bind(eventTableSessionStarted).listen(_onTableSessionStarted),
      );
      _eventSubs.add(
        channel.bind(eventTableSessionEnded).listen(_onTableSessionEnded),
      );
    }
    if (bindForceLogout) {
      _eventSubs.add(
        channel.bind(eventForceLogout).listen(_onForceLogout),
      );
    }

    _eventSubs.add(
      channel.onAuthenticationSubscriptionFailed().listen((event) {
        _log('subscription auth error on $channelName: ${event.data}');
      }),
    );
  }

  Map<String, String> _authHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    final token = _apiClient.authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final deviceId = ApiConfig.deviceId;
    final deviceToken = ApiConfig.deviceToken;
    if (deviceId != null && deviceId.isNotEmpty) {
      headers['X-Device-Id'] = deviceId;
    }
    if (deviceToken != null && deviceToken.isNotEmpty) {
      headers['X-Device-Token'] = deviceToken;
    }
    final tenant = ApiConfig.tenantSchema.trim();
    if (tenant.isNotEmpty) {
      headers['X-Tenant-Schema'] = tenant;
    }
    return headers;
  }

  void _onTableSessionStarted(ChannelReadEvent event) {
    final payload = event.tryGetDataAsMap();
    if (payload == null) {
      _log('TableSessionStarted: unparseable data=${event.data}');
      return;
    }
    final wire = TableSessionWireEvent.fromJson(payload);
    if (wire.tableId <= 0) return;
    _log(
      'TableSessionStarted table=${wire.tableId} locked_by=${wire.lockedBy}',
    );
    unawaited(_sessionRepository.applyTableSessionWireEvent(wire));
    tablesLockRevision.value++;
    if (wire.floorId != null && wire.floorId! > 0) {
      unawaited(subscribeFloor(wire.floorId!));
    }
  }

  void _onTableSessionEnded(ChannelReadEvent event) {
    final payload = event.tryGetDataAsMap();
    if (payload == null) {
      _log('TableSessionEnded: unparseable data=${event.data}');
      return;
    }
    final wire = TableSessionWireEvent.fromJson(payload);
    if (wire.tableId <= 0) return;
    _log('TableSessionEnded table=${wire.tableId}');
    unawaited(_sessionRepository.applyTableSessionWireEvent(wire));
    tablesLockRevision.value++;
  }

  void _onForceLogout(ChannelReadEvent event) {
    if (_forceLogoutHandling) return;

    final payload = event.tryGetDataAsMap();
    final wire = payload != null
        ? ForceLogoutWireEvent.fromJson(payload)
        : const ForceLogoutWireEvent(
            userId: 0,
            message:
                'Vous avez été déconnecté car une autre session a été ouverte.',
          );

    final me = _authRepository.cachedSession?.user.id;
    if (wire.userId > 0 && me != null && me > 0 && wire.userId != me) {
      _log(
        'force.logout ignored — payload user=${wire.userId} != me=$me',
      );
      return;
    }

    _forceLogoutHandling = true;
    _log('force.logout user=${wire.userId}');
    unawaited(_handleForceLogout(wire));
  }

  Future<void> _handleForceLogout(ForceLogoutWireEvent wire) async {
    try {
      AppSnackbar.show(
        'Session terminée',
        wire.message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      );
    } catch (_) {}
    try {
      await stop();
    } catch (_) {}
    AppNavigation.forceLogoutForUnauthenticated(
      delay: const Duration(milliseconds: 200),
    );
    _forceLogoutHandling = false;
  }

  /// Drop listeners immediately so a concurrent resubscribe cannot be cancelled.
  void _clearEventSubsOnlySync() {
    final pending = List<StreamSubscription<ChannelReadEvent>>.of(_eventSubs);
    _eventSubs.clear();
    for (final sub in pending) {
      try {
        sub.cancel();
      } catch (_) {}
    }
  }

  void _log(String message) {
    final line = '[REVERB] $message';
    // ignore: avoid_print
    print(line);
    debugPrint(line);
  }

  @override
  void onClose() {
    unawaited(stop());
    super.onClose();
  }
}
