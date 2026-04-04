import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestNotificationService extends RestRequestServiceBase
    implements NotificationService {
  RestNotificationService({
    required super.dio,
  });

  @override
  Future<Result<ApiNotificationUnreadCount>> getUnreadNotificationCount() {
    return performGetRequest<ApiNotificationUnreadCount>(
      endpoint: "/api/v1/notifications/unread-count",
      operation: "get unread notification count",
      decodeItem: ApiNotificationUnreadCount.fromJson,
    );
  }

  @override
  Future<Result<void>> markChannelNotificationsRead({
    required String channelId,
  }) {
    return performPostRequestWithoutResponseBody(
      endpoint: "/api/v1/channels/$channelId/notifications/read",
      operation: "mark channel notifications read",
      body: const <String, dynamic>{},
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<void>> markMessageAsUnread({
    required String channelId,
    required String messageId,
  }) {
    return performPostRequestWithoutResponseBody(
      endpoint: "/api/v1/channels/$channelId/notifications/unread-from",
      operation: "mark message as unread",
      body: <String, dynamic>{"message_id": messageId},
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<ApiNotificationGlobalPreference>>
      getGlobalNotificationPreference() {
    return performGetRequest<ApiNotificationGlobalPreference>(
      endpoint: "/api/v1/notifications/preferences/global",
      operation: "get global notification preference",
      decodeItem: ApiNotificationGlobalPreference.fromJson,
    );
  }

  @override
  Future<Result<void>> updateGlobalNotificationPreference({
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
    ApiNotificationCategoryPreference? channelDefaultCategory,
  }) {
    return performPatchRequestWithoutResponseBody(
      endpoint: "/api/v1/notifications/preferences/global",
      operation: "update global notification preference",
      body: <String, dynamic>{
        if (muteState != null) "mute_state": muteState.apiValue,
        if (notificationCategory != null)
          "notification_category": notificationCategory.apiValue,
        if (channelDefaultCategory != null)
          "channel_default_category": channelDefaultCategory.apiValue,
      },
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<ApiNotificationServerPreference>>
      getServerNotificationPreference({
    required String serverId,
  }) {
    return performGetRequest<ApiNotificationServerPreference>(
      endpoint: "/api/v1/servers/$serverId/notifications/preferences",
      operation: "get server notification preference",
      decodeItem: ApiNotificationServerPreference.fromJson,
    );
  }

  @override
  Future<Result<void>> updateServerNotificationPreference({
    required String serverId,
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
  }) {
    return performPatchRequestWithoutResponseBody(
      endpoint: "/api/v1/servers/$serverId/notifications/preferences",
      operation: "update server notification preference",
      body: <String, dynamic>{
        if (muteState != null) "mute_state": muteState.apiValue,
        if (notificationCategory != null)
          "notification_category": notificationCategory.apiValue,
      },
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<ApiNotificationChannelPreference>>
      getChannelNotificationPreference({
    required String channelId,
  }) {
    return performGetRequest<ApiNotificationChannelPreference>(
      endpoint: "/api/v1/channels/$channelId/notifications/preferences",
      operation: "get channel notification preference",
      decodeItem: ApiNotificationChannelPreference.fromJson,
    );
  }

  @override
  Future<Result<void>> updateChannelNotificationPreference({
    required String channelId,
    required ApiNotificationCategoryPreference notificationCategory,
  }) {
    return performPatchRequestWithoutResponseBody(
      endpoint: "/api/v1/channels/$channelId/notifications/preferences",
      operation: "update channel notification preference",
      body: <String, dynamic>{
        "notification_category": notificationCategory.apiValue,
      },
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<void>> muteChannelNotifications({
    required String channelId,
    required int durationMinutes,
  }) {
    return performPostRequestWithoutResponseBody(
      endpoint: "/api/v1/channels/$channelId/notifications/preferences/mute",
      operation: "mute channel notifications",
      body: <String, dynamic>{"duration_minutes": durationMinutes},
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<void>> unmuteChannelNotifications({
    required String channelId,
  }) {
    return performPostRequestWithoutResponseBody(
      endpoint: "/api/v1/channels/$channelId/notifications/preferences/unmute",
      operation: "unmute channel notifications",
      body: const <String, dynamic>{},
      expectedStatusCode: 204,
    );
  }
}
