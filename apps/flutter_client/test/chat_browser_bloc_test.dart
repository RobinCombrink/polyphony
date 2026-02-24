import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polyphony_flutter_client/features/chat_browser/application/chat_browser_bloc.dart';
import 'package:polyphony_flutter_client/features/chat_browser/application/chat_browser_event.dart';
import 'package:polyphony_flutter_client/features/chat_browser/application/chat_browser_state.dart';
import 'package:polyphony_flutter_client/shared/models/chat_models.dart';

void main() {
  test('emits failure when selecting server before loading servers', () async {
    final bloc = ChatBrowserBloc(httpClient: _successfulClient());

    bloc.add(const ServerSelected(
        Server(id: 'srv-1', name: 'Test', ownerSubject: 'auth0|u1')));
    await _waitForBloc();

    expect(bloc.state, isA<ChatBrowserFailureState>());
    expect(
      bloc.state.statusMessage,
      'Select server is only valid from ready state.',
    );

    await bloc.close();
  });

  test(
      'transitions from loading servers to ready and then loading channels to ready',
      () async {
    final bloc = ChatBrowserBloc(httpClient: _successfulClient());

    bloc.add(
      const LoadServersRequested(
        bearerToken: 'token-value',
        baseUrl: 'http://127.0.0.1:5067',
      ),
    );
    await _waitForBloc();

    expect(bloc.state, isA<ChatBrowserReadyState>());
    expect(bloc.state.servers.length, 1);

    final selectedServer = bloc.state.servers.first;
    bloc.add(ServerSelected(selectedServer));
    await _waitForBloc();

    expect(bloc.state, isA<ChatBrowserReadyState>());
    expect(bloc.state.channels.length, 1);

    await bloc.close();
  });

  test('transitions from ready to create-server loading and back to ready',
      () async {
    final bloc = ChatBrowserBloc(httpClient: _successfulClient());

    bloc.add(
      const LoadServersRequested(
        bearerToken: 'token-value',
        baseUrl: 'http://127.0.0.1:5067',
      ),
    );
    await _waitForBloc();

    expect(bloc.state, isA<ChatBrowserReadyState>());

    bloc.add(const CreateServerRequested('New Server'));
    await _waitForBloc();

    expect(bloc.state, isA<ChatBrowserReadyState>());
    expect(bloc.state.statusMessage, contains('Loaded'));

    await bloc.close();
  });
}

Future<void> _waitForBloc() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

http.Client _successfulClient() {
  return MockClient((http.Request request) async {
    if (request.method == 'POST' && request.url.path == '/api/v1/servers') {
      return http.Response(
        jsonEncode(
          <String, dynamic>{
            'id': 'srv-2',
            'name': 'New Server',
            'owner_subject': 'auth0|u1',
          },
        ),
        201,
      );
    }

    if (request.method == 'POST' &&
        request.url.path == '/api/v1/servers/srv-1/channels') {
      return http.Response(
        jsonEncode(
          <String, dynamic>{
            'id': 'chn-2',
            'server_id': 'srv-1',
            'name': 'new-channel',
          },
        ),
        201,
      );
    }

    if (request.method == 'POST' &&
        request.url.path == '/api/v1/channels/chn-1/messages') {
      return http.Response(
        jsonEncode(
          <String, dynamic>{
            'id': 'msg-2',
            'channel_id': 'chn-1',
            'author_subject': 'auth0|u1',
            'content': 'new message',
          },
        ),
        201,
      );
    }

    if (request.url.path == '/api/v1/servers') {
      return http.Response(
        jsonEncode(
          <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'srv-1',
              'name': 'Server One',
              'owner_subject': 'auth0|u1',
            },
          ],
        ),
        200,
      );
    }

    if (request.url.path == '/api/v1/servers/srv-1/channels') {
      return http.Response(
        jsonEncode(
          <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'chn-1',
              'server_id': 'srv-1',
              'name': 'general',
            },
          ],
        ),
        200,
      );
    }

    if (request.url.path == '/api/v1/channels/chn-1/messages') {
      return http.Response(
        jsonEncode(
          <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'msg-1',
              'channel_id': 'chn-1',
              'author_subject': 'auth0|u1',
              'content': 'hello',
            },
          ],
        ),
        200,
      );
    }

    return http.Response('Not found', 404);
  });
}
