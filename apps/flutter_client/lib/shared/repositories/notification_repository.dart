import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_service.dart";

class NotificationRepository implements NotificationRepo {
  const NotificationRepository({
    required NotificationService notificationService,
  }) : _notificationService = notificationService;

  final NotificationService _notificationService;

  @override
  Future<Result<int>> getOne({
    required GetNotificationUnreadCountQuery query,
  }) async {
    final serviceResult =
        await _notificationService.getUnreadNotificationCount();

    return switch (serviceResult) {
      Ok<ApiNotificationUnreadCount>(:final value) =>
        Ok<int>(value.totalUnreadCount),
      Error<ApiNotificationUnreadCount>(:final error) => Error<int>(error),
    };
  }

  @override
  Future<Result<ApiNotificationGlobalPreference>>
      getGlobalNotificationPreference() {
    return _notificationService.getGlobalNotificationPreference();
  }

  @override
  Future<Result<void>> updateGlobalNotificationPreference({
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
    ApiNotificationCategoryPreference? channelDefaultCategory,
  }) {
    return _notificationService.updateGlobalNotificationPreference(
      muteState: muteState,
      notificationCategory: notificationCategory,
      channelDefaultCategory: channelDefaultCategory,
    );
  }

  @override
  Future<Result<ApiNotificationServerPreference>>
      getServerNotificationPreference({
    required String serverId,
  }) {
    return _notificationService.getServerNotificationPreference(
      serverId: serverId,
    );
  }

  @override
  Future<Result<void>> updateServerNotificationPreference({
    required String serverId,
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
  }) {
    return _notificationService.updateServerNotificationPreference(
      serverId: serverId,
      muteState: muteState,
      notificationCategory: notificationCategory,
    );
  }

  @override
  Future<Result<ApiNotificationChannelPreference>>
      getChannelNotificationPreference({
    required String channelId,
  }) {
    return _notificationService.getChannelNotificationPreference(
      channelId: channelId,
    );
  }

  @override
  Future<Result<void>> updateChannelNotificationPreference({
    required String channelId,
    required ApiNotificationCategoryPreference notificationCategory,
  }) {
    return _notificationService.updateChannelNotificationPreference(
      channelId: channelId,
      notificationCategory: notificationCategory,
    );
  }

  @override
  Future<Result<void>> muteChannelNotifications({
    required String channelId,
    required int durationMinutes,
  }) {
    return _notificationService.muteChannelNotifications(
      channelId: channelId,
      durationMinutes: durationMinutes,
    );
  }

  @override
  Future<Result<void>> unmuteChannelNotifications({
    required String channelId,
  }) {
    return _notificationService.unmuteChannelNotifications(
      channelId: channelId,
    );
  }
}
