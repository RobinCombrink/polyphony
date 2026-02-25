// ignore_for_file: cascade_invocations

import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

import "entity_seeder.dart";

void main() {
  final entitySeeder = EntitySeeder();
  final fixture = entitySeeder.chatApiFixture();

  test("servers bloc loads servers and emits loaded state", () async {
    final bloc = ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    );

    bloc.add(const LoadServersRequested(baseUrl: "http://127.0.0.1:5067"));
    await _waitForBloc();

    expect(bloc.state, isA<ServersLoadedState>());
    expect(bloc.state.servers.length, 1);

    await bloc.close();
  });

  test("servers bloc emits validation failed on empty server name", () async {
    final bloc = ServersBloc(
      serverRepo: FakeServerRepository(fixture: fixture),
    );

    bloc.add(const CreateServerRequested(
      baseUrl: "http://127.0.0.1:5067",
      serverName: "   ",
    ));
    await _waitForBloc();

    expect(bloc.state, isA<ServersValidationFailedState>());
    final validationState = bloc.state as ServersValidationFailedState;
    expect(validationState.issue, ServersValidationIssue.serverNameRequired);

    await bloc.close();
  });

  test("channels bloc emits validation failed when server not selected",
      () async {
    final bloc = ChannelsBloc(
      channelRepo: FakeChannelRepository(fixture: fixture),
    );

    bloc.add(const CreateChannelRequested(
      baseUrl: "http://127.0.0.1:5067",
      serverId: "",
      channelName: "channel",
    ));
    await _waitForBloc();

    expect(bloc.state, isA<ChannelsValidationFailedState>());
    final validationState = bloc.state as ChannelsValidationFailedState;
    expect(
      validationState.issue,
      ChannelsValidationIssue.serverSelectionRequired,
    );

    await bloc.close();
  });

  test("channels bloc loads channels for selected server", () async {
    final bloc = ChannelsBloc(
      channelRepo: FakeChannelRepository(fixture: fixture),
    );

    bloc.add(LoadChannelsRequested(
      baseUrl: "http://127.0.0.1:5067",
      serverId: fixture.listedServer.id,
    ));
    await _waitForBloc();

    expect(bloc.state, isA<ChannelsLoadedState>());
    expect(bloc.state.channels.length, 1);

    await bloc.close();
  });

  test("messages bloc updates message and emits loaded state", () async {
    final bloc = MessagesBloc(
      messageRepo: FakeMessageRepository(fixture: fixture),
    );

    bloc.add(LoadMessagesRequested(
      baseUrl: "http://127.0.0.1:5067",
      channelId: fixture.listedChannel.id,
    ));
    await _waitForBloc();

    bloc.add(UpdateMessageRequested(
      baseUrl: "http://127.0.0.1:5067",
      channelId: fixture.listedChannel.id,
      messageId: fixture.listedMessage.id,
      messageContent: "edited",
    ));
    await _waitForBloc();

    expect(bloc.state, isA<MessagesLoadedState>());
    expect(bloc.state.messages.first.content, "edited");

    await bloc.close();
  });

  test("messages bloc emits exception state when delete fails", () async {
    final bloc = MessagesBloc(
      messageRepo: FakeMessageRepository(
        fixture: fixture,
        forceDeleteNotFound: true,
      ),
    );

    bloc.add(DeleteMessageRequested(
      baseUrl: "http://127.0.0.1:5067",
      channelId: fixture.listedChannel.id,
      messageId: fixture.listedMessage.id,
    ));
    await _waitForBloc();

    expect(bloc.state, isA<MessagesExceptionState>());
    final exceptionState = bloc.state as MessagesExceptionState;
    expect(
      exceptionState.error.toString(),
      contains("Failed to delete message: 404"),
    );

    await bloc.close();
  });

  test("voice sessions bloc loads participants for selected channel", () async {
    final bloc = VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
    );

    bloc.add(LoadVoiceSessionsRequested(
      baseUrl: "http://127.0.0.1:5067",
      channelId: fixture.listedChannel.id,
    ));
    await _waitForBloc();

    expect(bloc.state, isA<VoiceSessionsLoadedState>());
    expect(bloc.state.voiceSessions.length, 1);

    await bloc.close();
  });

  test("voice sessions bloc emits validation failed on missing channel",
      () async {
    final bloc = VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
    );

    bloc.add(const JoinVoiceSessionRequested(
      baseUrl: "http://127.0.0.1:5067",
      channelId: "",
    ));
    await _waitForBloc();

    expect(bloc.state, isA<VoiceSessionsValidationFailedState>());
    final validationState = bloc.state as VoiceSessionsValidationFailedState;
    expect(
      validationState.issue,
      VoiceSessionsValidationIssue.channelSelectionRequired,
    );

    await bloc.close();
  });

  test("voice sessions bloc leaves voice and reloads empty list", () async {
    final bloc = VoiceSessionsBloc(
      voiceSessionRepo: FakeVoiceSessionRepository(fixture: fixture),
    );

    bloc.add(LeaveVoiceSessionRequested(
      baseUrl: "http://127.0.0.1:5067",
      channelId: fixture.listedChannel.id,
    ));
    await _waitForBloc();

    expect(bloc.state, isA<VoiceSessionsLoadedState>());
    expect(bloc.state.voiceSessions, isEmpty);

    await bloc.close();
  });
}

Future<void> _waitForBloc() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

class FakeServerRepository implements ServerRepo {
  FakeServerRepository({required ChatApiFixture fixture})
      : _servers = <Server>[fixture.listedServer],
        _createdServer = fixture.createdServer;

  final List<Server> _servers;
  final Server _createdServer;

  @override
  Future<Result<Server>> createServer({
    required String baseUrl,
    required String name,
  }) async {
    _servers.add(_createdServer);
    return Ok<Server>(_createdServer);
  }

  @override
  Future<Result<List<Server>>> listServers({
    required String baseUrl,
  }) async {
    return Ok<List<Server>>(List<Server>.unmodifiable(_servers));
  }
}

class FakeChannelRepository implements ChannelRepo {
  FakeChannelRepository({required ChatApiFixture fixture})
      : _channelsByServer = <String, List<Channel>>{
          fixture.listedServer.id: <Channel>[fixture.listedChannel],
        },
        _createdChannel = fixture.createdChannel;

  final Map<String, List<Channel>> _channelsByServer;
  final Channel _createdChannel;

  @override
  Future<Result<Channel>> createChannel({
    required String baseUrl,
    required String serverId,
    required String name,
  }) async {
    final channels = _channelsByServer.putIfAbsent(serverId, () => <Channel>[]);
    channels.add(_createdChannel);
    return Ok<Channel>(_createdChannel);
  }

  @override
  Future<Result<List<Channel>>> listChannels({
    required String baseUrl,
    required String serverId,
  }) async {
    final channels = _channelsByServer[serverId] ?? <Channel>[];
    return Ok<List<Channel>>(List<Channel>.unmodifiable(channels));
  }
}

class FakeMessageRepository implements MessageRepo {
  FakeMessageRepository({
    required ChatApiFixture fixture,
    this.forceUpdateNotFound = false,
    this.forceDeleteNotFound = false,
  })  : _messagesByChannel = <String, List<Message>>{
          fixture.listedChannel.id: <Message>[fixture.listedMessage],
        },
        _createdMessage = fixture.createdMessage;

  final bool forceUpdateNotFound;
  final bool forceDeleteNotFound;
  final Map<String, List<Message>> _messagesByChannel;
  final Message _createdMessage;

  @override
  Future<Result<Message>> createMessage({
    required String baseUrl,
    required String channelId,
    required String content,
  }) async {
    final messages =
        _messagesByChannel.putIfAbsent(channelId, () => <Message>[]);
    messages.add(_createdMessage);
    return Ok<Message>(_createdMessage);
  }

  @override
  Future<Result<void>> deleteMessage({
    required String baseUrl,
    required String channelId,
    required String messageId,
  }) async {
    if (forceDeleteNotFound) {
      return Error<void>(Exception("Failed to delete message: 404 Not found"));
    }

    final messages = _messagesByChannel[channelId] ?? <Message>[];
    messages.removeWhere((message) => message.id == messageId);
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<Message>>> listMessages({
    required String baseUrl,
    required String channelId,
  }) async {
    final messages = _messagesByChannel[channelId] ?? <Message>[];
    return Ok<List<Message>>(List<Message>.unmodifiable(messages));
  }

  @override
  Future<Result<Message>> updateMessage({
    required String baseUrl,
    required String channelId,
    required String messageId,
    required String content,
  }) async {
    if (forceUpdateNotFound) {
      return Error<Message>(
          Exception("Failed to update message: 404 Not found"));
    }

    final messages = _messagesByChannel[channelId] ?? <Message>[];
    final messageIndex =
        messages.indexWhere((message) => message.id == messageId);

    if (messageIndex == -1) {
      return Error<Message>(
          Exception("Failed to update message: 404 Not found"));
    }

    final existingMessage = messages[messageIndex];
    final updatedMessage = Message(
      id: existingMessage.id,
      channelId: existingMessage.channelId,
      authorSubject: existingMessage.authorSubject,
      content: content,
    );

    messages[messageIndex] = updatedMessage;
    return Ok<Message>(updatedMessage);
  }
}

class FakeVoiceSessionRepository implements VoiceSessionRepo {
  FakeVoiceSessionRepository({
    required ChatApiFixture fixture,
    this.forceLeaveNotFound = false,
  })  : _sessionsByChannel = <String, List<VoiceSession>>{
          fixture.listedChannel.id: <VoiceSession>[fixture.listedVoiceSession],
        },
        _createdVoiceSession = fixture.createdVoiceSession;

  final bool forceLeaveNotFound;
  final Map<String, List<VoiceSession>> _sessionsByChannel;
  final VoiceSession _createdVoiceSession;

  @override
  Future<Result<VoiceSession>> joinVoiceSession({
    required String baseUrl,
    required String channelId,
  }) async {
    final voiceSessions =
        _sessionsByChannel.putIfAbsent(channelId, () => <VoiceSession>[]);
    voiceSessions.add(_createdVoiceSession);

    return Ok<VoiceSession>(_createdVoiceSession);
  }

  @override
  Future<Result<void>> leaveVoiceSession({
    required String baseUrl,
    required String channelId,
  }) async {
    if (forceLeaveNotFound) {
      return Error<void>(
          Exception("Failed to leave voice session: 404 Not found"));
    }

    _sessionsByChannel[channelId] = <VoiceSession>[];

    return const Ok<void>(null);
  }

  @override
  Future<Result<List<VoiceSession>>> listVoiceSessions({
    required String baseUrl,
    required String channelId,
  }) async {
    final voiceSessions = _sessionsByChannel[channelId] ?? <VoiceSession>[];

    return Ok<List<VoiceSession>>(
        List<VoiceSession>.unmodifiable(voiceSessions));
  }
}
