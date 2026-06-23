import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

enum NotificationPermissionStatus {
  granted,
  denied,
  provisional,
  notDetermined,
}

enum NotificationSource {
  foreground,
  openedApp,
  background,
  initialMessage,
}

class PushMessage {
  final String? id;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final NotificationSource source;
  final DateTime receivedAt;

  PushMessage({
    this.id,
    this.title,
    this.body,
    this.data = const {},
    required this.source,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  PushMessage copyWith({
    String? id,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    NotificationSource? source,
    DateTime? receivedAt,
  }) {
    return PushMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      source: source ?? this.source,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }
}

abstract class PushNotificationProvider {
  Future<void> initialize();
  Future<NotificationPermissionStatus> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<PushMessage> get onMessage;
  Stream<PushMessage> get onMessageOpenedApp;
  Future<PushMessage?> getInitialMessage();
  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);
  Future<void> deleteToken();
}

class PushNotificationConfig {
  final bool requestPermissionOnInit;
  final bool storeTokenLocally;
  final String localTokenStorageKey;

  const PushNotificationConfig({
    this.requestPermissionOnInit = true,
    this.storeTokenLocally = true,
    this.localTokenStorageKey = 'gems_push_token',
  });
}

class PushNotificationService {
  final PushNotificationProvider _provider;
  final SharedPreferences _prefs;
  final PushNotificationConfig _config;

  final StreamController<PushMessage> _messagesController =
      StreamController<PushMessage>.broadcast();
  final StreamController<String> _tokenController =
      StreamController<String>.broadcast();

  StreamSubscription<PushMessage>? _foregroundSub;
  StreamSubscription<PushMessage>? _openedSub;
  StreamSubscription<String>? _tokenSub;

  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notDetermined;

  PushNotificationService(
    this._provider,
    this._prefs, {
    PushNotificationConfig config = const PushNotificationConfig(),
  }) : _config = config;

  Stream<PushMessage> get messages => _messagesController.stream;
  Stream<String> get tokenChanges => _tokenController.stream;
  NotificationPermissionStatus get permissionStatus => _permissionStatus;

  Future<void> initialize() async {
    await _provider.initialize();

    if (_config.requestPermissionOnInit) {
      _permissionStatus = await _provider.requestPermission();
    }

    _foregroundSub = _provider.onMessage.listen(_messagesController.add);
    _openedSub = _provider.onMessageOpenedApp.listen(_messagesController.add);

    _tokenSub = _provider.onTokenRefresh.listen((token) async {
      await _persistTokenIfNeeded(token);
      _tokenController.add(token);
    });

    final currentToken = await _provider.getToken();
    if (currentToken != null && currentToken.isNotEmpty) {
      await _persistTokenIfNeeded(currentToken);
      _tokenController.add(currentToken);
    }

    final initialMessage = await _provider.getInitialMessage();
    if (initialMessage != null) {
      _messagesController.add(initialMessage);
    }
  }

  Future<String?> getToken() async {
    final token = await _provider.getToken();
    if (token != null && token.isNotEmpty) {
      await _persistTokenIfNeeded(token);
      return token;
    }
    return _readStoredToken();
  }

  Future<String?> getStoredToken() async => _readStoredToken();

  Future<void> subscribeToTopic(String topic) async {
    await _provider.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _provider.unsubscribeFromTopic(topic);
  }

  Future<void> clearToken() async {
    await _provider.deleteToken();
    await _prefs.remove(_config.localTokenStorageKey);
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _tokenSub?.cancel();
    await _messagesController.close();
    await _tokenController.close();
  }

  Future<void> _persistTokenIfNeeded(String token) async {
    if (_config.storeTokenLocally) {
      await _prefs.setString(_config.localTokenStorageKey, token);
    }
  }

  String? _readStoredToken() {
    if (!_config.storeTokenLocally) return null;
    return _prefs.getString(_config.localTokenStorageKey);
  }
}

class FirebasePushNotificationProvider extends CustomPushNotificationProvider {
  FirebasePushNotificationProvider({
    super.initializeHandler,
    super.permissionHandler,
    super.tokenHandler,
    super.subscribeHandler,
    super.unsubscribeHandler,
    super.deleteTokenHandler,
    super.initialMessageHandler,
    required Stream<String> tokenRefreshStream,
    required Stream<PushMessage> messageStream,
    required Stream<PushMessage> messageOpenedStream,
  }) : super(
          tokenRefreshStream: tokenRefreshStream,
          messageStream: messageStream,
          messageOpenedStream: messageOpenedStream,
        );
}

class CustomPushNotificationProvider implements PushNotificationProvider {
  final Future<void> Function()? initializeHandler;
  final Future<NotificationPermissionStatus> Function()? permissionHandler;
  final Future<String?> Function()? tokenHandler;
  final Future<void> Function(String topic)? subscribeHandler;
  final Future<void> Function(String topic)? unsubscribeHandler;
  final Future<void> Function()? deleteTokenHandler;
  final Future<PushMessage?> Function()? initialMessageHandler;
  final Stream<String> tokenRefreshStream;
  final Stream<PushMessage> messageStream;
  final Stream<PushMessage> messageOpenedStream;

  CustomPushNotificationProvider({
    this.initializeHandler,
    this.permissionHandler,
    this.tokenHandler,
    this.subscribeHandler,
    this.unsubscribeHandler,
    this.deleteTokenHandler,
    this.initialMessageHandler,
    Stream<String>? tokenRefreshStream,
    Stream<PushMessage>? messageStream,
    Stream<PushMessage>? messageOpenedStream,
  })  : tokenRefreshStream = tokenRefreshStream ?? const Stream.empty(),
        messageStream = messageStream ?? const Stream.empty(),
        messageOpenedStream = messageOpenedStream ?? const Stream.empty();

  @override
  Future<void> initialize() async {
    await initializeHandler?.call();
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    if (permissionHandler == null) {
      return NotificationPermissionStatus.granted;
    }
    return permissionHandler!.call();
  }

  @override
  Future<String?> getToken() async {
    if (tokenHandler == null) return null;
    return tokenHandler!.call();
  }

  @override
  Stream<String> get onTokenRefresh => tokenRefreshStream;

  @override
  Stream<PushMessage> get onMessage => messageStream;

  @override
  Stream<PushMessage> get onMessageOpenedApp => messageOpenedStream;

  @override
  Future<PushMessage?> getInitialMessage() async {
    if (initialMessageHandler == null) return null;
    return initialMessageHandler!.call();
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    await subscribeHandler?.call(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    await unsubscribeHandler?.call(topic);
  }

  @override
  Future<void> deleteToken() async {
    await deleteTokenHandler?.call();
  }
}
