import "dart:convert";

import "package:http/http.dart" as http;

import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class PolyphonyApiClient implements ChatApi {
  PolyphonyApiClient({
    required http.Client httpClient,
    required AuthenticationStateSource authenticationStateSource,
  })  : _httpClient = httpClient,
        _authenticationStateSource = authenticationStateSource;

  final http.Client _httpClient;
  final AuthenticationStateSource _authenticationStateSource;

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
  Future<Result<ApiChannel>> createChannel({
    required String baseUrl,
    required String serverId,
    required String name,
  }) {
    return _performPostRequest<ApiChannel>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/servers/$serverId/channels",
      operation: "create channel",
      body: <String, dynamic>{"name": name},
      expectedStatusCode: 201,
      decodeItem: ApiChannel.fromJson,
    );
  }

  @override
  Future<Result<ApiMessage>> createMessage({
    required String baseUrl,
    required String channelId,
    required String content,
  }) {
    return _performPostRequest<ApiMessage>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/channels/$channelId/messages",
      operation: "create message",
      body: <String, dynamic>{"content": content},
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
  Future<Result<ApiVoiceConnectSession>> connectVoiceSession({
    required String baseUrl,
    required String channelId,
  }) {
    return _performPostRequest<ApiVoiceConnectSession>(
      baseUrl: baseUrl,
      endpoint: "/api/v1/channels/$channelId/voice/connect",
      operation: "connect voice session",
      body: const <String, dynamic>{},
      expectedStatusCode: 200,
      decodeItem: ApiVoiceConnectSession.fromJson,
    );
  }

  @override
  Future<Result<void>> disconnectVoiceSession({
    required String baseUrl,
    required String channelId,
  }) {
    final _ = channelId;
    return Future<Result<void>>.value(const Ok<void>(null));
  }

  Map<String, String> _headers() {
    final currentAuthState = _authenticationStateSource.currentAuthState;

    if (currentAuthState is! AuthenticationAuthenticatedState) {
      throw StateError("Auth token is required.");
    }

    final bearerToken = currentAuthState.bearerToken;

    return <String, String>{
      "Authorization": "Bearer $bearerToken",
      "Content-Type": "application/json",
    };
  }

  List<Map<String, dynamic>> _decodeList(String body) {
    final decoded = jsonDecode(body) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
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
          Exception(
              "Failed to $operation: ${response.statusCode} ${response.body}"),
        );
      }

      final items = _decodeList(response.body).map(decodeItem).toList();
      return Ok<List<T>>(items);
    } on Exception catch (error) {
      return Error<List<T>>(error);
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
          Exception(
            "Failed to $operation: ${response.statusCode} ${response.body}",
          ),
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return Ok<T>(decodeItem(decoded));
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
          Exception(
            "Failed to $operation: ${response.statusCode} ${response.body}",
          ),
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return Ok<T>(decodeItem(decoded));
    } on Exception catch (error) {
      return Error<T>(error);
    } on Object catch (error) {
      return Error<T>(
        Exception("Unexpected error while trying to $operation: $error"),
      );
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
          Exception(
            "Failed to $operation: ${response.statusCode} ${response.body}",
          ),
        );
      }

      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    } on Object catch (error) {
      return Error<void>(
        Exception("Unexpected error while trying to $operation: $error"),
      );
    }
  }
}
