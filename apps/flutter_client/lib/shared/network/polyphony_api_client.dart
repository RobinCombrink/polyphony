import "dart:convert";

import "package:http/http.dart" as http;
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";
import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class PolyphonyApiClient implements ChatApi {
  PolyphonyApiClient({
    required http.Client httpClient,
  }) : _httpClient = httpClient;

  final http.Client _httpClient;

  @override
  Future<Result<List<ApiServer>>> listServers({required String baseUrl}) {
    return _performListRequest<ApiServer>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/servers",
      operation: "list servers",
      decodeItem: ApiServer.fromJson,
    );
  }

  @override
  Future<Result<List<ApiChannel>>> listChannels({
    required String baseUrl,
    required String serverId,
  }) {
    return _performListRequest<ApiChannel>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/servers/$serverId/channels",
      operation: "list channels",
      decodeItem: ApiChannel.fromJson,
    );
  }

  @override
  Future<Result<List<ApiMessage>>> listMessages({
    required String baseUrl,
    required String channelId,
  }) {
    return _performListRequest<ApiMessage>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/channels/$channelId/messages",
      operation: "list messages",
      decodeItem: ApiMessage.fromJson,
    );
  }

  @override
  Future<Result<ApiServer>> createServer({
    required String baseUrl,
    required String name,
  }) {
    return _performPostRequest<ApiServer>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/servers",
      operation: "create server",
      body: <String, dynamic>{"name": name},
      expectedStatusCode: 201,
      decodeItem: ApiServer.fromJson,
    );
  }

  @override
  Future<Result<void>> deleteServer({
    required String baseUrl,
    required String serverId,
  }) {
    return _performDeleteRequest(
      baseUrl: baseUrl,
      endpoint: "/api/v1/servers/$serverId",
      operation: "delete server",
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<void>> addServerMember({
    required String baseUrl,
    required String serverId,
    required String userId,
  }) {
    return _performPostRequestWithoutResponseBody(
      baseUrl: baseUrl,
      endpoint: "/api/v1/servers/$serverId/members",
      operation: "add server member",
      body: <String, dynamic>{"user_id": userId},
      expectedStatusCode: 201,
    );
  }

  @override
  Future<Result<List<ApiServerMember>>> listServerMembers({
    required String baseUrl,
    required String serverId,
  }) {
    return _performListRequest<ApiServerMember>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/servers/$serverId/members",
      operation: "list server members",
      decodeItem: ApiServerMember.fromJson,
    );
  }

  @override
  Future<Result<ApiChannel>> createChannel({
    required String baseUrl,
    required String serverId,
    required String name,
    required ChannelType channelType,
  }) {
    return _performPostRequest<ApiChannel>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/servers/$serverId/channels",
      operation: "create channel",
      body: <String, dynamic>{
        "name": name,
        "channel_type": channelType.apiValue,
      },
      expectedStatusCode: 201,
      decodeItem: ApiChannel.fromJson,
    );
  }

  @override
  Future<Result<void>> deleteChannel({
    required String baseUrl,
    required String channelId,
  }) {
    return _performDeleteRequest(
      baseUrl: baseUrl,
      endpoint: "/api/v1/channels/$channelId",
      operation: "delete channel",
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<ApiMessage>> createMessage({
    required String baseUrl,
    required String channelId,
    required String content,
    String? mentionedUserId,
  }) {
    final trimmedMentionedUserId = mentionedUserId?.trim();

    return _performPostRequest<ApiMessage>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/channels/$channelId/messages",
      operation: "create message",
      body: <String, dynamic>{
        "content": content,
        if (trimmedMentionedUserId != null && trimmedMentionedUserId.isNotEmpty)
          "mentioned_user_id": trimmedMentionedUserId,
      },
      expectedStatusCode: 201,
      decodeItem: ApiMessage.fromJson,
    );
  }

  @override
  Future<Result<ApiMessage>> updateMessage({
    required String baseUrl,
    required String channelId,
    required String messageId,
    required String content,
  }) {
    return _performPatchRequest<ApiMessage>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/channels/$channelId/messages/$messageId",
      operation: "update message",
      body: <String, dynamic>{"content": content},
      expectedStatusCode: 200,
      decodeItem: ApiMessage.fromJson,
    );
  }

  @override
  Future<Result<void>> deleteMessage({
    required String baseUrl,
    required String channelId,
    required String messageId,
  }) {
    return _performDeleteRequest(
      baseUrl: baseUrl,
      endpoint: "/api/v1/channels/$channelId/messages/$messageId",
      operation: "delete message",
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<ApiTextConnectSession>> connectTextSession({
    required String baseUrl,
    required String channelId,
  }) {
    return _performPostRequest<ApiTextConnectSession>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/channels/$channelId/session",
      operation: "connect text session",
      body: const <String, dynamic>{"session_type": "text"},
      expectedStatusCode: 200,
      decodeItem: ApiTextConnectSession.fromJson,
    );
  }

  @override
  Future<Result<ApiVoiceConnectSession>> connectVoiceSession({
    required String baseUrl,
    required String channelId,
    String? participantInstanceId,
  }) {
    final trimmedParticipantInstanceId = participantInstanceId?.trim();

    return _performPostRequest<ApiVoiceConnectSession>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/channels/$channelId/session",
      operation: "connect voice session",
      body: <String, dynamic>{
        "session_type": "voice",
        if (trimmedParticipantInstanceId != null &&
            trimmedParticipantInstanceId.isNotEmpty)
          "participant_instance_id": trimmedParticipantInstanceId,
      },
      expectedStatusCode: 200,
      decodeItem: ApiVoiceConnectSession.fromJson,
    );
  }

  @override
  Future<Result<ApiMe>> getMe({required String baseUrl}) {
    return _performGetRequest<ApiMe>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/me",
      operation: "get me",
      decodeItem: ApiMe.fromJson,
    );
  }

  @override
  Future<Result<ApiMe>> updateDisplayName({
    required String baseUrl,
    required String displayName,
  }) {
    return _performPatchRequest<ApiMe>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/me",
      operation: "update display name",
      body: <String, dynamic>{"display_name": displayName},
      expectedStatusCode: 200,
      decodeItem: ApiMe.fromJson,
    );
  }

  @override
  Future<Result<ApiUserLookup>> getUserById({
    required String baseUrl,
    required String userId,
  }) {
    return _performGetRequest<ApiUserLookup>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/users/$userId",
      operation: "get user by id",
      decodeItem: ApiUserLookup.fromJson,
    );
  }

  @override
  Future<Result<ApiNotificationUnreadCount>> getUnreadNotificationCount({
    required String baseUrl,
  }) {
    return _performGetRequest<ApiNotificationUnreadCount>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/notifications/unread-count",
      operation: "get unread notification count",
      decodeItem: ApiNotificationUnreadCount.fromJson,
    );
  }

  @override
  Future<Result<ApiNotificationGlobalPreference>>
      getGlobalNotificationPreference({
    required String baseUrl,
  }) {
    return _performGetRequest<ApiNotificationGlobalPreference>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/notifications/preferences/global",
      operation: "get global notification preference",
      decodeItem: ApiNotificationGlobalPreference.fromJson,
    );
  }

  @override
  Future<Result<void>> updateGlobalNotificationPreference({
    required String baseUrl,
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
    ApiNotificationCategoryPreference? channelDefaultCategory,
  }) {
    return _performPatchRequestWithoutResponseBody(
      baseUrl: baseUrl,
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
    required String baseUrl,
    required String serverId,
  }) {
    return _performGetRequest<ApiNotificationServerPreference>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/servers/$serverId/notifications/preferences",
      operation: "get server notification preference",
      decodeItem: ApiNotificationServerPreference.fromJson,
    );
  }

  @override
  Future<Result<void>> updateServerNotificationPreference({
    required String baseUrl,
    required String serverId,
    ApiNotificationMuteState? muteState,
    ApiNotificationCategoryPreference? notificationCategory,
  }) {
    return _performPatchRequestWithoutResponseBody(
      baseUrl: baseUrl,
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
    required String baseUrl,
    required String channelId,
  }) {
    return _performGetRequest<ApiNotificationChannelPreference>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/channels/$channelId/notifications/preferences",
      operation: "get channel notification preference",
      decodeItem: ApiNotificationChannelPreference.fromJson,
    );
  }

  @override
  Future<Result<void>> updateChannelNotificationPreference({
    required String baseUrl,
    required String channelId,
    required ApiNotificationCategoryPreference notificationCategory,
  }) {
    return _performPatchRequestWithoutResponseBody(
      baseUrl: baseUrl,
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
    required String baseUrl,
    required String channelId,
    required int durationMinutes,
  }) {
    return _performPostRequestWithoutResponseBody(
      baseUrl: baseUrl,
      endpoint: "/api/v1/channels/$channelId/notifications/preferences/mute",
      operation: "mute channel notifications",
      body: <String, dynamic>{"duration_minutes": durationMinutes},
      expectedStatusCode: 204,
    );
  }

  @override
  Future<Result<void>> unmuteChannelNotifications({
    required String baseUrl,
    required String channelId,
  }) {
    return _performPostRequestWithoutResponseBody(
      baseUrl: baseUrl,
      endpoint: "/api/v1/channels/$channelId/notifications/preferences/unmute",
      operation: "unmute channel notifications",
      body: const <String, dynamic>{},
      expectedStatusCode: 204,
    );
  }

  Map<String, String> _headers() {
    return <String, String>{
      "Content-Type": "application/json",
    };
  }

  List<Map<String, dynamic>> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      return const <Map<String, dynamic>>[];
    }

    return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<Result<List<T>>> _performListRequest<T>({
    required String baseUrl,
    required String endpoint,
    required String operation,
    required T Function(Map<String, dynamic>) decodeItem,
  }) async {
    try {
      final response = await _httpClient.get(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Error<List<T>>(
          _apiRequestException(
            operation: operation,
            statusCode: response.statusCode,
            responseBody: response.body,
          ),
        );
      }

      final items = _decodeList(response.body).map(decodeItem).toList();
      return Ok<List<T>>(items);
    } on Exception catch (error) {
      return Error<List<T>>(error);
    }
  }

  Future<Result<T>> _performGetRequest<T>({
    required String baseUrl,
    required String endpoint,
    required String operation,
    required T Function(Map<String, dynamic>) decodeItem,
  }) async {
    try {
      final response = await _httpClient.get(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Error<T>(
          _apiRequestException(
            operation: operation,
            statusCode: response.statusCode,
            responseBody: response.body,
          ),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return Error<T>(
          Exception("Failed to $operation: invalid response payload"),
        );
      }

      return Ok<T>(decodeItem(Map<String, dynamic>.from(decoded)));
    } on Exception catch (error) {
      return Error<T>(error);
    }
  }

  Future<Result<T>> _performPostRequest<T>({
    required String baseUrl,
    required String endpoint,
    required String operation,
    required Map<String, dynamic> body,
    required int expectedStatusCode,
    required T Function(Map<String, dynamic>) decodeItem,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(),
        body: jsonEncode(body),
      );

      if (response.statusCode != expectedStatusCode) {
        return Error<T>(
          _apiRequestException(
            operation: operation,
            statusCode: response.statusCode,
            responseBody: response.body,
          ),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return Error<T>(
          Exception("Failed to $operation: invalid response payload"),
        );
      }

      return Ok<T>(decodeItem(Map<String, dynamic>.from(decoded)));
    } on Exception catch (error) {
      return Error<T>(error);
    }
  }

  Future<Result<T>> _performPatchRequest<T>({
    required String baseUrl,
    required String endpoint,
    required String operation,
    required Map<String, dynamic> body,
    required int expectedStatusCode,
    required T Function(Map<String, dynamic>) decodeItem,
  }) async {
    try {
      final response = await _httpClient.patch(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(),
        body: jsonEncode(body),
      );

      if (response.statusCode != expectedStatusCode) {
        return Error<T>(
          _apiRequestException(
            operation: operation,
            statusCode: response.statusCode,
            responseBody: response.body,
          ),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return Error<T>(
          Exception("Failed to $operation: invalid response payload"),
        );
      }

      return Ok<T>(decodeItem(Map<String, dynamic>.from(decoded)));
    } on Exception catch (error) {
      return Error<T>(error);
    }
  }

  Future<Result<void>> _performPatchRequestWithoutResponseBody({
    required String baseUrl,
    required String endpoint,
    required String operation,
    required Map<String, dynamic> body,
    required int expectedStatusCode,
  }) async {
    try {
      final response = await _httpClient.patch(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(),
        body: jsonEncode(body),
      );

      if (response.statusCode != expectedStatusCode) {
        return Error<void>(
          _apiRequestException(
            operation: operation,
            statusCode: response.statusCode,
            responseBody: response.body,
          ),
        );
      }

      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  Future<Result<void>> _performDeleteRequest({
    required String baseUrl,
    required String endpoint,
    required String operation,
    required int expectedStatusCode,
  }) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(),
      );

      if (response.statusCode != expectedStatusCode) {
        return Error<void>(
          _apiRequestException(
            operation: operation,
            statusCode: response.statusCode,
            responseBody: response.body,
          ),
        );
      }

      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  Future<Result<void>> _performPostRequestWithoutResponseBody({
    required String baseUrl,
    required String endpoint,
    required String operation,
    required Map<String, dynamic> body,
    required int expectedStatusCode,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(),
        body: jsonEncode(body),
      );

      if (response.statusCode != expectedStatusCode) {
        return Error<void>(
          _apiRequestException(
            operation: operation,
            statusCode: response.statusCode,
            responseBody: response.body,
          ),
        );
      }

      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  ApiRequestException _apiRequestException({
    required String operation,
    required int statusCode,
    required String responseBody,
  }) {
    return ApiRequestException(
      operation: operation,
      statusCode: statusCode,
      responseBody: responseBody,
    );
  }
}
