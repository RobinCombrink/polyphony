import "package:polyphony_flutter_client/shared/result/result.dart";

sealed class RuntimeNotificationEvent {
  const RuntimeNotificationEvent({
    required this.serverId,
    required this.serverName,
    required this.channelId,
    required this.channelName,
    required this.messageId,
  });

  final String serverId;
  final String serverName;
  final String channelId;
  final String channelName;
  final String messageId;
}

final class UnreadMessageRuntimeNotificationEvent
    extends RuntimeNotificationEvent {
  const UnreadMessageRuntimeNotificationEvent({
    required super.serverId,
    required super.serverName,
    required super.channelId,
    required super.channelName,
    required super.messageId,
  });
}

final class MentionedRuntimeNotificationEvent extends RuntimeNotificationEvent {
  const MentionedRuntimeNotificationEvent({
    required super.serverId,
    required super.serverName,
    required super.channelId,
    required super.channelName,
    required super.messageId,
  });
}

abstract interface class NotificationRuntimeService {
  Future<Result<void>> connect({
    required String notificationsWebSocketUrl,
    required String bearerToken,
  });

  Future<Result<void>> disconnect();

  Stream<RuntimeNotificationEvent> notificationEvents();
}
