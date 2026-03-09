import "package:polyphony_flutter_client/shared/result/result.dart";

sealed class RuntimeNotificationEvent {
  const RuntimeNotificationEvent({
    required this.serverId,
    required this.serverName,
    required this.channelId,
    required this.channelName,
  });

  final String serverId;
  final String serverName;
  final String channelId;
  final String channelName;
}

final class UnreadMessageRuntimeNotificationEvent
    extends RuntimeNotificationEvent {
  const UnreadMessageRuntimeNotificationEvent({
    required super.serverId,
    required super.serverName,
    required super.channelId,
    required super.channelName,
    required this.messageId,
  });

  final String messageId;
}

final class MentionedRuntimeNotificationEvent extends RuntimeNotificationEvent {
  const MentionedRuntimeNotificationEvent({
    required super.serverId,
    required super.serverName,
    required super.channelId,
    required super.channelName,
    required this.messageId,
  });

  final String messageId;
}

final class FriendJoinedVoiceRuntimeNotificationEvent
    extends RuntimeNotificationEvent {
  const FriendJoinedVoiceRuntimeNotificationEvent({
    required super.serverId,
    required super.serverName,
    required super.channelId,
    required super.channelName,
    required this.joinedUserId,
    required this.joinedUserDisplayName,
  });

  final String joinedUserId;
  final String joinedUserDisplayName;
}

abstract interface class NotificationRuntimeService {
  Future<Result<void>> connect({
    required String bearerToken,
  });

  Future<Result<void>> disconnect();

  Stream<RuntimeNotificationEvent> notificationEvents();
}
