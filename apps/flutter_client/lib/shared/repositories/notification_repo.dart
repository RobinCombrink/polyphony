import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class GetNotificationUnreadCountQuery {
  const GetNotificationUnreadCountQuery();
}

abstract interface class NotificationRepo
    with RepositoryGetOne<int, GetNotificationUnreadCountQuery> {
  Future<Result<ApiNotificationGlobalPreference>>
      getGlobalNotificationPreference();

  Future<Result<void>> updateGlobalNotificationPreference({
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
    ApiNotificationCategoryPreference? channelDefaultCategory,
  });

  Future<Result<ApiNotificationServerPreference>>
      getServerNotificationPreference({
    required String serverId,
  });

  Future<Result<void>> updateServerNotificationPreference({
    required String serverId,
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
  });

  Future<Result<ApiNotificationChannelPreference>>
      getChannelNotificationPreference({
    required String channelId,
  });

  Future<Result<void>> updateChannelNotificationPreference({
    required String channelId,
    required ApiNotificationCategoryPreference notificationCategory,
  });

  Future<Result<void>> muteChannelNotifications({
    required String channelId,
    required int durationMinutes,
  });

  Future<Result<void>> unmuteChannelNotifications({
    required String channelId,
  });
}
