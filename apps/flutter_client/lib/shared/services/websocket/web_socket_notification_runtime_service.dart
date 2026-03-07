import "dart:async";
import "dart:convert";
import "dart:io";

import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";

class WebSocketNotificationRuntimeService
    implements NotificationRuntimeService {
  WebSocketNotificationRuntimeService({
    this.reconnectDelay = const Duration(seconds: 2),
  });

  final Duration reconnectDelay;
  final _notificationEventsController =
      StreamController<RuntimeNotificationEvent>.broadcast();

  WebSocket? _socket;
  Timer? _reconnectTimer;
  String? _notificationsWebSocketUrl;
  String? _bearerToken;
  var _isConnecting = false;
  var _isConnected = false;
  var _manualDisconnectRequested = false;

  @override
  Future<Result<void>> connect({
    required String notificationsWebSocketUrl,
    required String bearerToken,
  }) {
    _notificationsWebSocketUrl = notificationsWebSocketUrl;
    _bearerToken = bearerToken;
    _manualDisconnectRequested = false;

    return _connectInternal();
  }

  @override
  Future<Result<void>> disconnect() async {
    _manualDisconnectRequested = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnected = false;

    final activeSocket = _socket;
    _socket = null;

    if (activeSocket == null) {
      return const Ok<void>(null);
    }

    try {
      await activeSocket.close();
      return const Ok<void>(null);
    } on Exception catch (exception) {
      return Error<void>(
        RuntimeConnectionException(
          operation: "disconnect notifications websocket",
          cause: exception,
        ),
      );
    }
  }

  @override
  Stream<RuntimeNotificationEvent> notificationEvents() {
    return _notificationEventsController.stream;
  }

  Future<Result<void>> _connectInternal() async {
    if (_isConnecting || _isConnected) {
      return const Ok<void>(null);
    }

    final resolvedNotificationsWebSocketUrl = _notificationsWebSocketUrl;
    final resolvedBearerToken = _bearerToken;

    if (resolvedNotificationsWebSocketUrl == null ||
        resolvedBearerToken == null) {
      return Error<void>(
        RuntimeConnectionException(
          operation: "connect notifications websocket",
          cause: Exception("Notifications runtime configuration missing."),
        ),
      );
    }

    _isConnecting = true;

    try {
      final socket = await WebSocket.connect(
        resolvedNotificationsWebSocketUrl,
        headers: <String, String>{
          HttpHeaders.authorizationHeader: "Bearer $resolvedBearerToken",
        },
      );

      _socket = socket;
      _isConnected = true;

      socket.listen(
        _onSocketData,
        onDone: _onSocketDone,
        onError: (_) => _onSocketDone(),
        cancelOnError: true,
      );

      return const Ok<void>(null);
    } on Exception catch (exception) {
      _scheduleReconnect();
      return Error<void>(
        RuntimeConnectionException(
          operation: "connect notifications websocket",
          cause: exception,
        ),
      );
    } finally {
      _isConnecting = false;
    }
  }

  void _onSocketData(Object? payload) {
    if (payload is! String) {
      return;
    }

    try {
      final decodedPayload = jsonDecode(payload);

      if (decodedPayload is! Map<String, dynamic>) {
        return;
      }

      final event = _parseNotificationEvent(decodedPayload);
      if (event == null) {
        return;
      }

      _notificationEventsController.add(event);
    } on FormatException {
      return;
    }
  }

  RuntimeNotificationEvent? _parseNotificationEvent(
    Map<String, dynamic> payload,
  ) {
    final eventTypeRaw = payload["event_type"];
    final channelIdRaw = payload["channel_id"];
    final messageIdRaw = payload["message_id"];

    if (eventTypeRaw is! String ||
        channelIdRaw is! String ||
        messageIdRaw is! String) {
      return null;
    }

    final eventType = switch (eventTypeRaw) {
      "unread_message" => RuntimeNotificationEventType.unreadMessage,
      "mentioned" => RuntimeNotificationEventType.mentioned,
      _ => null,
    };

    if (eventType == null) {
      return null;
    }

    return RuntimeNotificationEvent(
      eventType: eventType,
      channelId: channelIdRaw,
      messageId: messageIdRaw,
    );
  }

  void _onSocketDone() {
    _isConnected = false;
    _socket = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manualDisconnectRequested || _reconnectTimer != null) {
      return;
    }

    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectTimer = null;
      unawaited(_connectInternal());
    });
  }
}
