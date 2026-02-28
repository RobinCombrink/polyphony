import "dart:async";

import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/message_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/voice_runtime_service.dart";

import "../../entity_seeder.dart";

class FakeServerRepository implements ServerRepo {
  FakeServerRepository({
    required ChatApiFixture fixture,
    this.forceAddMemberError = false,
    this.forceDeleteError = false,
  })  : _servers = <Server>[fixture.listedServer],
        _createdServer = fixture.createdServer;

  final bool forceAddMemberError;
  final bool forceDeleteError;
  final List<Server> _servers;
  final Server _createdServer;

  @override
  Future<Result<Server>> createOne({
    required CreateServerCommand command,
  }) async {
    _servers.add(_createdServer);
    return Ok<Server>(_createdServer);
  }

  @override
  Future<Result<Iterable<Server>>> getMany({
    required GetServersQuery query,
  }) async {
    return Ok<Iterable<Server>>(List<Server>.unmodifiable(_servers));
  }

  @override
  Future<Result<void>> deleteOne({
    required DeleteServerCommand command,
  }) async {
    if (forceDeleteError) {
      return Error<void>(Exception("Failed to delete server"));
    }

    _servers.removeWhere((server) => server.id == command.serverId);
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> updateOne({
    required AddServerMemberCommand command,
  }) async {
    if (forceAddMemberError) {
      return Error<void>(Exception("Failed to add server member"));
    }

    return const Ok<void>(null);
  }
}

class FakeChannelRepository implements ChannelRepo {
  FakeChannelRepository({
    required ChatApiFixture fixture,
    this.forceDeleteError = false,
  })  : _channelsByServer = <String, List<Channel>>{
          fixture.listedServer.id: <Channel>[fixture.listedChannel],
        },
        _createdChannel = fixture.createdChannel;

  final bool forceDeleteError;
  final Map<String, List<Channel>> _channelsByServer;
  final Channel _createdChannel;

  @override
  Future<Result<Channel>> createOne({
    required CreateChannelCommand command,
  }) async {
    final channels = _channelsByServer.putIfAbsent(
      command.serverId,
      () => <Channel>[],
    );
    channels.add(_createdChannel);
    return Ok<Channel>(_createdChannel);
  }

  @override
  Future<Result<Iterable<Channel>>> getMany({
    required GetChannelsQuery query,
  }) async {
    final channels = _channelsByServer[query.serverId] ?? <Channel>[];
    return Ok<Iterable<Channel>>(List<Channel>.unmodifiable(channels));
  }

  @override
  Future<Result<void>> deleteOne({
    required DeleteChannelCommand command,
  }) async {
    if (forceDeleteError) {
      return Error<void>(Exception("Failed to delete channel"));
    }

    for (final channels in _channelsByServer.values) {
      channels.removeWhere((channel) => channel.id == command.channelId);
    }

    return const Ok<void>(null);
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
  Future<Result<Message>> createOne({
    required CreateMessageCommand command,
  }) async {
    final messages =
        _messagesByChannel.putIfAbsent(command.channelId, () => <Message>[]);
    messages.add(_createdMessage);
    return Ok<Message>(_createdMessage);
  }

  @override
  Future<Result<void>> deleteOne({
    required DeleteMessageCommand command,
  }) async {
    if (forceDeleteNotFound) {
      return Error<void>(Exception("Failed to delete message: 404 Not found"));
    }

    final messages = _messagesByChannel[command.channelId] ?? <Message>[];
    messages.removeWhere((message) => message.id == command.messageId);
    return const Ok<void>(null);
  }

  @override
  Future<Result<Iterable<Message>>> getMany({
    required GetMessagesQuery query,
  }) async {
    final messages = _messagesByChannel[query.channelId] ?? <Message>[];
    return Ok<Iterable<Message>>(List<Message>.unmodifiable(messages));
  }

  @override
  Future<Result<Message>> updateOne({
    required UpdateMessageCommand command,
  }) async {
    if (forceUpdateNotFound) {
      return Error<Message>(
          Exception("Failed to update message: 404 Not found"));
    }

    final messages = _messagesByChannel[command.channelId] ?? <Message>[];
    final messageIndex =
        messages.indexWhere((message) => message.id == command.messageId);

    if (messageIndex == -1) {
      return Error<Message>(
          Exception("Failed to update message: 404 Not found"));
    }

    final existingMessage = messages[messageIndex];
    final updatedMessage = Message(
      id: existingMessage.id,
      channelId: existingMessage.channelId,
      authorUserId: existingMessage.authorUserId,
      content: command.content,
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
  Future<Result<VoiceConnectSession>> createOne({
    required ConnectVoiceSessionCommand command,
  }) async {
    return Ok<VoiceConnectSession>(
      VoiceConnectSession(
        livekitUrl: _connectedVoiceSession.livekitUrl,
        accessToken: _connectedVoiceSession.accessToken,
        channelId: command.channelId,
        participantUserId: _connectedVoiceSession.participantUserId,
      ),
    );
  }

  @override
  Future<Result<void>> deleteOne({
    required DisconnectVoiceSessionCommand command,
  }) async {
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

  @override
  Iterable<String> currentParticipantUserIds() {
    return const <String>["auth0|local_user"];
  }
}

class FakeMessageRuntimeService implements MessageRuntimeService {
  FakeMessageRuntimeService({
    this.forceConnectError = false,
    this.forceDisconnectError = false,
  });

  final bool forceConnectError;
  final bool forceDisconnectError;
  final _textMessagesController =
      StreamController<RuntimeTextMessage>.broadcast();

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

  @override
  Stream<RuntimeTextMessage> textMessages() {
    return _textMessagesController.stream;
  }

  @override
  Future<Result<void>> sendTextMessage({
    required String channelId,
    required String content,
  }) async {
    final trimmedChannelId = channelId.trim();
    final trimmedContent = content.trim();

    if (trimmedChannelId.isEmpty || trimmedContent.isEmpty) {
      return Error<void>(Exception("Channel id and content are required."));
    }

    return const Ok<void>(null);
  }
}

class FakeProfileRepository implements ProfileRepo {
  FakeProfileRepository({
    required this.userId,
    this.initialDisplayName,
    this.forceGetError = false,
    this.forceUpdateError = false,
    this.displayNamesByUserId = const <String, String?>{},
  }) : _displayName = initialDisplayName;

  final String userId;
  final String? initialDisplayName;
  final bool forceGetError;
  final bool forceUpdateError;
  final Map<String, String?> displayNamesByUserId;
  String? _displayName;

  @override
  Future<Result<UserProfile>> getOne({required GetProfileQuery query}) async {
    if (forceGetError) {
      return Error<UserProfile>(Exception("Failed to get profile"));
    }

    return Ok<UserProfile>(
      UserProfile(
        userId: userId,
        displayName: _displayName,
      ),
    );
  }

  @override
  Future<Result<UserProfile>> updateOne({
    required UpdateDisplayNameCommand command,
  }) async {
    if (forceUpdateError) {
      return Error<UserProfile>(Exception("Failed to update display name"));
    }

    _displayName = command.displayName;
    return Ok<UserProfile>(
      UserProfile(
        userId: userId,
        displayName: _displayName,
      ),
    );
  }

  @override
  Future<Result<UserProfile>> getUserById({
    required GetUserProfileByIdQuery query,
  }) async {
    if (forceGetError) {
      return Error<UserProfile>(Exception("Failed to get profile"));
    }

    final displayName = displayNamesByUserId.containsKey(query.userId)
        ? displayNamesByUserId[query.userId]
        : (query.userId == userId ? _displayName : null);

    return Ok<UserProfile>(
      UserProfile(
        userId: query.userId,
        displayName: displayName,
      ),
    );
  }
}
