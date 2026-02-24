import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_models.dart';
import '../result/result.dart';

class PolyphonyApiClient {
  PolyphonyApiClient({required this.baseUrl, required this.httpClient});

  final String baseUrl;
  final http.Client httpClient;

  Future<Result<List<Server>>> listServers(
      {required String bearerToken}) async {
    return _performListRequest<Server>(
      endpoint: '/api/v1/servers',
      bearerToken: bearerToken,
      operation: 'list servers',
      decodeItem: Server.fromJson,
    );
  }

  Future<Result<List<Channel>>> listChannels({
    required String bearerToken,
    required String serverId,
  }) async {
    return _performListRequest<Channel>(
      endpoint: '/api/v1/servers/$serverId/channels',
      bearerToken: bearerToken,
      operation: 'list channels',
      decodeItem: Channel.fromJson,
    );
  }

  Future<Result<List<Message>>> listMessages({
    required String bearerToken,
    required String channelId,
  }) async {
    return _performListRequest<Message>(
      endpoint: '/api/v1/channels/$channelId/messages',
      bearerToken: bearerToken,
      operation: 'list messages',
      decodeItem: Message.fromJson,
    );
  }

  Future<Result<Server>> createServer({
    required String bearerToken,
    required String name,
  }) async {
    return _performPostRequest<Server>(
      endpoint: '/api/v1/servers',
      bearerToken: bearerToken,
      operation: 'create server',
      body: <String, dynamic>{'name': name},
      expectedStatusCode: 201,
      decodeItem: Server.fromJson,
    );
  }

  Future<Result<Channel>> createChannel({
    required String bearerToken,
    required String serverId,
    required String name,
  }) async {
    return _performPostRequest<Channel>(
      endpoint: '/api/v1/servers/$serverId/channels',
      bearerToken: bearerToken,
      operation: 'create channel',
      body: <String, dynamic>{'name': name},
      expectedStatusCode: 201,
      decodeItem: Channel.fromJson,
    );
  }

  Future<Result<Message>> createMessage({
    required String bearerToken,
    required String channelId,
    required String content,
  }) async {
    return _performPostRequest<Message>(
      endpoint: '/api/v1/channels/$channelId/messages',
      bearerToken: bearerToken,
      operation: 'create message',
      body: <String, dynamic>{'content': content},
      expectedStatusCode: 201,
      decodeItem: Message.fromJson,
    );
  }

  Map<String, String> _headers(String bearerToken) {
    return <String, String>{
      'Authorization': 'Bearer $bearerToken',
      'Content-Type': 'application/json',
    };
  }

  List<Map<String, dynamic>> _decodeList(String body) {
    final decoded = jsonDecode(body) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<Result<List<T>>> _performListRequest<T>({
    required String endpoint,
    required String bearerToken,
    required String operation,
    required T Function(Map<String, dynamic>) decodeItem,
  }) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers(bearerToken),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Error<List<T>>(
          Exception(
              'Failed to $operation: ${response.statusCode} ${response.body}'),
        );
      }

      final items = _decodeList(response.body).map(decodeItem).toList();
      return Ok<List<T>>(items);
    } on Exception catch (error) {
      return Error<List<T>>(error);
    } catch (error) {
      return Error<List<T>>(
          Exception('Unexpected error while trying to $operation: $error'));
    }
  }

  Future<Result<T>> _performPostRequest<T>({
    required String endpoint,
    required String bearerToken,
    required String operation,
    required Map<String, dynamic> body,
    required int expectedStatusCode,
    required T Function(Map<String, dynamic>) decodeItem,
  }) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers(bearerToken),
        body: jsonEncode(body),
      );

      if (response.statusCode != expectedStatusCode) {
        return Error<T>(
          Exception(
            'Failed to $operation: ${response.statusCode} ${response.body}',
          ),
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return Ok<T>(decodeItem(decoded));
    } on Exception catch (error) {
      return Error<T>(error);
    } catch (error) {
      return Error<T>(
        Exception('Unexpected error while trying to $operation: $error'),
      );
    }
  }
}
