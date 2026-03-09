import "package:polyphony_flutter_client/shared/config/backend_base_url_resolver.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

class RestNotificationService implements NotificationService {
  RestNotificationService({
    required ChatApi chatApi,
    required PreferencesStore preferencesStore,
  })  : _chatApi = chatApi,
        _preferencesStore = preferencesStore;

  final ChatApi _chatApi;
  final PreferencesStore _preferencesStore;

  Future<String> _baseUrl() {
    return resolveBackendBaseUrl(preferencesStore: _preferencesStore);
  }

  @override
  Future<Result<ApiNotificationUnreadCount>>
      getUnreadNotificationCount() async {
    return _chatApi.getUnreadNotificationCount(baseUrl: await _baseUrl());
  }

  @override
  Future<Result<void>> markChannelNotificationsRead({
    required String channelId,
  }) async {
    return _chatApi.markChannelNotificationsRead(
      baseUrl: await _baseUrl(),
      channelId: channelId,
    );
  }

  @override
  Future<Result<ApiNotificationGlobalPreference>>
      getGlobalNotificationPreference() async {
    return _chatApi.getGlobalNotificationPreference(
      baseUrl: await _baseUrl(),
    );
  }

  @override
  Future<Result<void>> updateGlobalNotificationPreference({
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
    ApiNotificationCategoryPreference? channelDefaultCategory,
  }) async {
    return _chatApi.updateGlobalNotificationPreference(
      baseUrl: await _baseUrl(),
      muteState: muteState,
      notificationCategory: notificationCategory,
      channelDefaultCategory: channelDefaultCategory,
    );
  }

  @override
  Future<Result<ApiNotificationServerPreference>>
      getServerNotificationPreference({
    required String serverId,
  }) async {
    return _chatApi.getServerNotificationPreference(
      baseUrl: await _baseUrl(),
      serverId: serverId,
    );
  }

  @override
  Future<Result<void>> updateServerNotificationPreference({
    required String serverId,
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
  }) async {
    return _chatApi.updateServerNotificationPreference(
      baseUrl: await _baseUrl(),
      serverId: serverId,
      muteState: muteState,
      notificationCategory: notificationCategory,
    );
  }

  @override
  Future<Result<ApiNotificationChannelPreference>>
      getChannelNotificationPreference({
    required String channelId,
  }) async {
    return _chatApi.getChannelNotificationPreference(
      baseUrl: await _baseUrl(),
      channelId: channelId,
    );
  }

  @override
  Future<Result<void>> updateChannelNotificationPreference({
    required String channelId,
    required ApiNotificationCategoryPreference notificationCategory,
  }) async {
    return _chatApi.updateChannelNotificationPreference(
      baseUrl: await _baseUrl(),
      channelId: channelId,
      notificationCategory: notificationCategory,
    );
  }

  @override
  Future<Result<void>> muteChannelNotifications({
    required String channelId,
    required int durationMinutes,
  }) async {
    return _chatApi.muteChannelNotifications(
      baseUrl: await _baseUrl(),
      channelId: channelId,
      durationMinutes: durationMinutes,
    );
  }

  @override
  Future<Result<void>> unmuteChannelNotifications({
    required String channelId,
  }) async {
    return _chatApi.unmuteChannelNotifications(
      baseUrl: await _baseUrl(),
      channelId: channelId,
    );
  }
}
