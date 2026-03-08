import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract interface class ChatApi {
  Future<Result<List<ApiServer>>> listServers({
    required String baseUrl,
  });

  Future<Result<ApiServer>> createServer({
    required String baseUrl,
    required String name,
  });

  Future<Result<void>> deleteServer({
    required String baseUrl,
    required String serverId,
  });

  Future<Result<void>> addServerMember({
    required String baseUrl,
    required String serverId,
    required String userId,
  });

  Future<Result<List<ApiServerMember>>> listServerMembers({
    required String baseUrl,
    required String serverId,
  });

  Future<Result<List<ApiChannel>>> listChannels({
    required String baseUrl,
    required String serverId,
  });

  Future<Result<ApiChannel>> createChannel({
    required String baseUrl,
    required String serverId,
    required String name,
    required ChannelType channelType,
  });

  Future<Result<void>> deleteChannel({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<List<ApiMessage>>> listMessages({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<ApiMessage>> createMessage({
    required String baseUrl,
    required String channelId,
    required String content,
    String? mentionedUserId,
  });

  Future<Result<ApiMessage>> updateMessage({
    required String baseUrl,
    required String channelId,
    required String messageId,
    required String content,
  });

  Future<Result<void>> deleteMessage({
    required String baseUrl,
    required String channelId,
    required String messageId,
  });

  Future<Result<ApiTextConnectSession>> connectTextSession({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<ApiVoiceConnectSession>> connectVoiceSession({
    required String baseUrl,
    required String channelId,
    String? participantInstanceId,
  });

  Future<Result<ApiMe>> getMe({
    required String baseUrl,
  });

  Future<Result<ApiMe>> updateDisplayName({
    required String baseUrl,
    required String displayName,
  });

  Future<Result<ApiUserLookup>> getUserById({
    required String baseUrl,
    required String userId,
  });

  Future<Result<ApiNotificationUnreadCount>> getUnreadNotificationCount({
    required String baseUrl,
  });

  Future<Result<void>> markChannelNotificationsRead({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<ApiNotificationGlobalPreference>>
      getGlobalNotificationPreference({
    required String baseUrl,
  });

  Future<Result<void>> updateGlobalNotificationPreference({
    required String baseUrl,
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
    ApiNotificationCategoryPreference? channelDefaultCategory,
  });

  Future<Result<ApiNotificationServerPreference>>
      getServerNotificationPreference({
    required String baseUrl,
    required String serverId,
  });

  Future<Result<void>> updateServerNotificationPreference({
    required String baseUrl,
    required String serverId,
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
  });

  Future<Result<ApiNotificationChannelPreference>>
      getChannelNotificationPreference({
    required String baseUrl,
    required String channelId,
  });

  Future<Result<void>> updateChannelNotificationPreference({
    required String baseUrl,
    required String channelId,
    required ApiNotificationCategoryPreference notificationCategory,
  });

  Future<Result<void>> muteChannelNotifications({
    required String baseUrl,
    required String channelId,
    required int durationMinutes,
  });

  Future<Result<void>> unmuteChannelNotifications({
    required String baseUrl,
    required String channelId,
  });
}
