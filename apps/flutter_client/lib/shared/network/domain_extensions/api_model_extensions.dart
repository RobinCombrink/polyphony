import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/models/notification_preference.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";

extension ApiServerToDomainExtension on ApiServer {
  Server toDomainModel() {
    return Server(
      id: ServerId(id),
      name: name,
      ownerUserId: UserId(ownerUserId),
    );
  }
}

extension DomainServerToApiExtension on Server {
  ApiServer toApiModel() {
    return ApiServer(
      id: id.value,
      name: name,
      ownerUserId: ownerUserId.value,
    );
  }
}

extension ApiServerMemberToDomainExtension on ApiServerMember {
  ServerMember toDomainModel() {
    return ServerMember(
      serverId: ServerId(serverId),
      userId: UserId(userId),
    );
  }
}

extension ApiFriendToDomainExtension on ApiFriend {
  Friend toDomainModel() {
    return Friend(
      userId: UserId(userId),
    );
  }
}

extension ApiFriendRequestToDomainExtension on ApiFriendRequest {
  PendingFriendRequest toDomainModel() {
    return PendingFriendRequest(
      id: FriendRequestId(id),
      requesterUserId: UserId(requesterUserId),
      addresseeUserId: UserId(addresseeUserId),
    );
  }
}

extension ApiBlockedUserToDomainExtension on ApiBlockedUser {
  BlockedUser toDomainModel() {
    return BlockedUser(userId: UserId(blockedUserId));
  }
}

extension ApiDirectMessageThreadToDomainExtension on ApiDirectMessageThread {
  DirectMessageThread toDomainModel() {
    return DirectMessageThread(
      id: DirectMessageThreadId(id),
      participantAUserId: UserId(participantAUserId),
      participantBUserId: UserId(participantBUserId),
    );
  }
}

extension ApiDirectMessageToDomainExtension on ApiDirectMessage {
  DirectMessage toDomainModel() {
    return DirectMessage(
      id: DirectMessageId(id),
      threadId: DirectMessageThreadId(threadId),
      authorUserId: UserId(authorUserId),
      content: content,
    );
  }
}

extension DomainFriendToApiExtension on Friend {
  ApiFriend toApiModel() {
    return ApiFriend(
      userId: userId.value,
    );
  }
}

extension DomainServerMemberToApiExtension on ServerMember {
  ApiServerMember toApiModel() {
    return ApiServerMember(
      serverId: serverId.value,
      userId: userId.value,
    );
  }
}

extension ApiChannelToDomainExtension on ApiChannel {
  Channel toDomainModel() {
    return switch (channelType) {
      ChannelType.voice => VoiceChannel(
          id: ChannelId(id),
          serverId: ServerId(serverId),
          name: name,
        ),
      ChannelType.text => TextChannel(
          id: ChannelId(id),
          serverId: ServerId(serverId),
          name: name,
        ),
    };
  }
}

extension DomainChannelToApiExtension on Channel {
  ApiChannel toApiModel() {
    return ApiChannel(
      id: id.value,
      serverId: serverId.value,
      name: name,
      channelType: channelType,
    );
  }
}

extension ApiMessageToDomainExtension on ApiMessage {
  Message toDomainModel() {
    return Message(
      id: MessageId(id),
      channelId: ChannelId(channelId),
      authorUserId: UserId(authorUserId),
      content: content,
    );
  }
}

extension DomainMessageToApiExtension on Message {
  ApiMessage toApiModel() {
    return ApiMessage(
      id: id.value,
      channelId: channelId.value,
      authorUserId: authorUserId.value,
      content: content,
    );
  }
}

extension ApiVoiceConnectSessionToDomainExtension on ApiVoiceConnectSession {
  VoiceConnectSession toDomainModel() {
    return VoiceConnectSession(
      livekitUrl: livekitUrl,
      accessToken: accessToken,
      channelId: ChannelId(channelId),
      participantUserId: UserId(participantUserId),
    );
  }
}

extension DomainVoiceConnectSessionToApiExtension on VoiceConnectSession {
  ApiVoiceConnectSession toApiModel() {
    return ApiVoiceConnectSession(
      livekitUrl: livekitUrl,
      accessToken: accessToken,
      channelId: channelId.value,
      participantUserId: participantUserId.value,
    );
  }
}

extension ApiTextConnectSessionToDomainExtension on ApiTextConnectSession {
  TextConnectSession toDomainModel() {
    return TextConnectSession(
      livekitUrl: livekitUrl,
      accessToken: accessToken,
      channelId: ChannelId(channelId),
      participantUserId: UserId(participantUserId),
    );
  }
}

extension DomainTextConnectSessionToApiExtension on TextConnectSession {
  ApiTextConnectSession toApiModel() {
    return ApiTextConnectSession(
      livekitUrl: livekitUrl,
      accessToken: accessToken,
      channelId: channelId.value,
      participantUserId: participantUserId.value,
    );
  }
}

extension ApiMeToDomainExtension on ApiMe {
  UserProfile toDomainModel() {
    return UserProfile(
      userId: UserId(userId),
      displayName: displayName,
    );
  }
}

extension ApiUserLookupToDomainExtension on ApiUserLookup {
  UserProfile toDomainModel() {
    return UserProfile(
      userId: UserId(id),
      displayName: displayName,
    );
  }
}

extension ApiNotificationMuteStateToDomainExtension
    on ApiNotificationMuteState {
  NotificationMuteState toDomain() => switch (this) {
        ApiNotificationMuteState.unmuted => NotificationMuteState.unmuted,
        ApiNotificationMuteState.muted => NotificationMuteState.muted,
      };
}

extension NotificationMuteStateToApiExtension on NotificationMuteState {
  ApiNotificationMuteState toApi() => switch (this) {
        NotificationMuteState.unmuted => ApiNotificationMuteState.unmuted,
        NotificationMuteState.muted => ApiNotificationMuteState.muted,
      };
}

extension ApiNotificationCategoryPreferenceToDomainExtension
    on ApiNotificationCategoryPreference {
  NotificationCategoryPreference toDomain() => switch (this) {
        ApiNotificationCategoryPreference.allMessages =>
          NotificationCategoryPreference.allMessages,
        ApiNotificationCategoryPreference.onlyMentions =>
          NotificationCategoryPreference.onlyMentions,
        ApiNotificationCategoryPreference.none =>
          NotificationCategoryPreference.none,
      };
}

extension NotificationCategoryPreferenceToApiExtension
    on NotificationCategoryPreference {
  ApiNotificationCategoryPreference toApi() => switch (this) {
        NotificationCategoryPreference.allMessages =>
          ApiNotificationCategoryPreference.allMessages,
        NotificationCategoryPreference.onlyMentions =>
          ApiNotificationCategoryPreference.onlyMentions,
        NotificationCategoryPreference.none =>
          ApiNotificationCategoryPreference.none,
      };
}

extension ApiNotificationGlobalPreferenceToDomainExtension
    on ApiNotificationGlobalPreference {
  NotificationGlobalPreference toDomain() => NotificationGlobalPreference(
        muteState: muteState.toDomain(),
        notificationCategory: notificationCategory.toDomain(),
        channelDefaultCategory: channelDefaultCategory.toDomain(),
      );
}

extension ApiNotificationServerPreferenceToDomainExtension
    on ApiNotificationServerPreference {
  NotificationServerPreference toDomain() => NotificationServerPreference(
        muteState: muteState.toDomain(),
        notificationCategory: notificationCategory.toDomain(),
      );
}

extension ApiNotificationChannelPreferenceToDomainExtension
    on ApiNotificationChannelPreference {
  NotificationChannelPreference toDomain() => NotificationChannelPreference(
        muteState: muteState.toDomain(),
        notificationCategory: notificationCategory.toDomain(),
        mutedUntilEpochSeconds: mutedUntilEpochSeconds,
        inheritedFromGlobalDefault: inheritedFromGlobalDefault,
      );
}
