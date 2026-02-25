import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:polyphony_flutter_client/features/chat_browser/application/chat_browser_bloc.dart';
import 'package:polyphony_flutter_client/features/chat_browser/application/chat_browser_event.dart';
import 'package:polyphony_flutter_client/features/chat_browser/application/chat_browser_state.dart';
import 'package:polyphony_flutter_client/shared/models/chat_models.dart';

import 'entity_seeder.dart';

void main() {
  final entitySeeder = EntitySeeder();
  final fixture = entitySeeder.chatApiFixture();

  test('emits failure when selecting server before loading servers', () async {
    final bloc =
        ChatBrowserBloc(httpClient: _successfulClient(entitySeeder, fixture));

    bloc.add(ServerSelected(fixture.listedServer));
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
    final bloc =
        ChatBrowserBloc(httpClient: _successfulClient(entitySeeder, fixture));

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
    final bloc =
        ChatBrowserBloc(httpClient: _successfulClient(entitySeeder, fixture));

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

  test('updates message and remains in ready state with refreshed list',
      () async {
    final bloc =
        ChatBrowserBloc(httpClient: _successfulClient(entitySeeder, fixture));

    bloc.add(
      const LoadServersRequested(
        bearerToken: 'token-value',
        baseUrl: 'http://127.0.0.1:5067',
      ),
    );
    await _waitForBloc();

    bloc.add(ServerSelected(bloc.state.servers.first));
    await _waitForBloc();

    bloc.add(ChannelSelected(bloc.state.channels.first));
    await _waitForBloc();

    final messageToUpdate = bloc.state.messages.first;

    bloc.add(UpdateMessageRequested(
      messageId: messageToUpdate.id,
      messageContent: 'edited',
    ));
    await _waitForBloc();

    expect(bloc.state, isA<ChatBrowserReadyState>());
    expect(bloc.state.messages.first.content, 'edited');

    await bloc.close();
  });

  test('deletes message and remains in ready state', () async {
    final bloc =
        ChatBrowserBloc(httpClient: _successfulClient(entitySeeder, fixture));

    bloc.add(
      const LoadServersRequested(
        bearerToken: 'token-value',
        baseUrl: 'http://127.0.0.1:5067',
      ),
    );
    await _waitForBloc();

    bloc.add(ServerSelected(bloc.state.servers.first));
    await _waitForBloc();

    bloc.add(ChannelSelected(bloc.state.channels.first));
    await _waitForBloc();

    final messageToDelete = bloc.state.messages.first;

    bloc.add(DeleteMessageRequested(messageId: messageToDelete.id));
    await _waitForBloc();

    expect(bloc.state, isA<ChatBrowserReadyState>());
    expect(bloc.state.messages, isEmpty);

    await bloc.close();
  });
}

Future<void> _waitForBloc() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

http.Client _successfulClient(
    EntitySeeder entitySeeder, ChatApiFixture fixture) {
  final messages = <Map<String, dynamic>>[
    entitySeeder.messageJson(fixture.listedMessage),
  ];

  return MockClient((http.Request request) async {
    if (request.method == 'POST' && request.url.path == '/api/v1/servers') {
      return http.Response(
        jsonEncode(entitySeeder.serverJson(fixture.createdServer)),
        201,
      );
    }

    if (request.method == 'POST' &&
        request.url.path ==
            '/api/v1/servers/${fixture.listedServer.id}/channels') {
      return http.Response(
        jsonEncode(entitySeeder.channelJson(fixture.createdChannel)),
        201,
      );
    }

    if (request.method == 'POST' &&
        request.url.path ==
            '/api/v1/channels/${fixture.listedChannel.id}/messages') {
      final newMessage = entitySeeder.messageJson(fixture.createdMessage);
      messages.add(<String, dynamic>{...newMessage});

      return http.Response(
        jsonEncode(newMessage),
        201,
      );
    }

    if (request.method == 'PATCH' &&
        request.url.path.startsWith(
            '/api/v1/channels/${fixture.listedChannel.id}/messages/')) {
      final messageId = request.url.pathSegments.last;
      final messageIndex = messages
          .indexWhere((message) => message['id'] as String == messageId);

      if (messageIndex == -1) {
        return http.Response('Not found', 404);
      }

      messages[messageIndex] = <String, dynamic>{
        ...messages[messageIndex],
        'content': 'edited',
      };

      return http.Response(
        jsonEncode(messages[messageIndex]),
        200,
      );
    }

    if (request.method == 'DELETE' &&
        request.url.path.startsWith(
            '/api/v1/channels/${fixture.listedChannel.id}/messages/')) {
      final messageId = request.url.pathSegments.last;
      messages.removeWhere((message) => message['id'] == messageId);
      return http.Response('', 204);
    }

    if (request.url.path == '/api/v1/servers') {
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          entitySeeder.serverJson(fixture.listedServer),
        ]),
        200,
      );
    }

    if (request.url.path ==
        '/api/v1/servers/${fixture.listedServer.id}/channels') {
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          entitySeeder.channelJson(fixture.listedChannel),
        ]),
        200,
      );
    }

    if (request.url.path ==
        '/api/v1/channels/${fixture.listedChannel.id}/messages') {
      return http.Response(
        jsonEncode(messages),
        200,
      );
    }

    return http.Response('Not found', 404);
  });
}
