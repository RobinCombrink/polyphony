import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_service.dart";

class RestNotificationService implements NotificationService {
  const RestNotificationService({
    required ChatApi chatApi,
  }) : _chatApi = chatApi;

  final ChatApi _chatApi;
  final String _baseUrl = PolyphonyConfig.backendBaseUrl;

  @override
  Future<Result<ApiNotificationUnreadCount>> getUnreadNotificationCount() {
    return _chatApi.getUnreadNotificationCount(baseUrl: _baseUrl);
  }

  @override
  Future<Result<ApiNotificationGlobalPreference>>
      getGlobalNotificationPreference() {
    return _chatApi.getGlobalNotificationPreference(baseUrl: _baseUrl);
  }

  @override
  Future<Result<void>> updateGlobalNotificationPreference({
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
    ApiNotificationCategoryPreference? channelDefaultCategory,
  }) {
    return _chatApi.updateGlobalNotificationPreference(
      baseUrl: _baseUrl,
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
    return _chatApi.getServerNotificationPreference(
      baseUrl: _baseUrl,
      serverId: serverId,
    );
  }

  @override
  Future<Result<void>> updateServerNotificationPreference({
    required String serverId,
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
  }) {
    return _chatApi.updateServerNotificationPreference(
      baseUrl: _baseUrl,
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
    return _chatApi.getChannelNotificationPreference(
      baseUrl: _baseUrl,
      channelId: channelId,
    );
  }

  @override
  Future<Result<void>> updateChannelNotificationPreference({
    required String channelId,
    required ApiNotificationCategoryPreference notificationCategory,
  }) {
    return _chatApi.updateChannelNotificationPreference(
      baseUrl: _baseUrl,
      channelId: channelId,
      notificationCategory: notificationCategory,
    );
  }

  @override
  Future<Result<void>> muteChannelNotifications({
    required String channelId,
    required int durationMinutes,
  }) {
    return _chatApi.muteChannelNotifications(
      baseUrl: _baseUrl,
      channelId: channelId,
      durationMinutes: durationMinutes,
    );
  }

  @override
  Future<Result<void>> unmuteChannelNotifications({
    required String channelId,
  }) {
    return _chatApi.unmuteChannelNotifications(
      baseUrl: _baseUrl,
      channelId: channelId,
    );
  }
}
