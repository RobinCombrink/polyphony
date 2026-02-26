import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/voice_runtime_service.dart";

import "../../entity_seeder.dart";

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
    this.forceDisconnectError = false,
  }) : _connectedVoiceSession = fixture.connectedVoiceSession;

  final bool forceDisconnectError;
  final VoiceConnectSession _connectedVoiceSession;

  @override
  Future<Result<VoiceConnectSession>> connectVoiceSession({
    required String baseUrl,
    required String channelId,
  }) async {
    return Ok<VoiceConnectSession>(
      VoiceConnectSession(
        livekitUrl: _connectedVoiceSession.livekitUrl,
        accessToken: _connectedVoiceSession.accessToken,
        channelId: channelId,
        participantSubject: _connectedVoiceSession.participantSubject,
      ),
    );
  }

  @override
  Future<Result<void>> disconnectVoiceSession({
    required String baseUrl,
    required String channelId,
  }) async {
    final _ = channelId;

    if (forceDisconnectError) {
      return Error<void>(Exception("Failed to disconnect voice session"));
    }

    return const Ok<void>(null);
  }
}

class FakeVoiceRuntimeService implements VoiceRuntimeService {
  FakeVoiceRuntimeService({
    this.forceConnectError = false,
    this.forceDisconnectError = false,
  });

  final bool forceConnectError;
  final bool forceDisconnectError;

  @override
  Future<Result<void>> connect({
    required String livekitUrl,
    required String accessToken,
  }) async {
    if (forceConnectError) {
      return Error<void>(Exception("Failed to connect to livekit"));
    }

    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> disconnect() async {
    if (forceDisconnectError) {
      return Error<void>(Exception("Failed to disconnect from livekit"));
    }

    return const Ok<void>(null);
  }
}
