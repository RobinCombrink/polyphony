import "package:polyphony_flutter_client/shared/result/result.dart";

enum RuntimeNotificationEventType {
  unreadMessage,
  mentioned,
}

final class RuntimeNotificationEvent {
  const RuntimeNotificationEvent({
    required this.eventType,
    required this.channelId,
    required this.messageId,
  });

  final RuntimeNotificationEventType eventType;
  final String channelId;
  final String messageId;
}

abstract interface class NotificationRuntimeService {
  Future<Result<void>> connect({
    required String notificationsWebSocketUrl,
    required String bearerToken,
  });

  Future<Result<void>> disconnect();

  Stream<RuntimeNotificationEvent> notificationEvents();
}
