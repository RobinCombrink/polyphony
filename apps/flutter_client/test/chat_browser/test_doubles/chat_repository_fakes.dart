import "dart:async";

import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/text_session_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/message_runtime_service.dart";

import "../../entity_seeder.dart";

class FakeServerRepository implements ServerRepo {
  FakeServerRepository({
    required ChatApiFixture fixture,
    this.forceAddMemberError = false,
    this.forceDeleteError = false,
  })  : _servers = <Server>[fixture.listedServer],
        _membersByServerId = <String, Set<String>>{
          fixture.listedServer.id: <String>{fixture.ownerUserId},
          fixture.createdServer.id: <String>{fixture.ownerUserId},
        },
        _createdServer = fixture.createdServer;

  final bool forceAddMemberError;
  final bool forceDeleteError;
  final List<Server> _servers;
  final Map<String, Set<String>> _membersByServerId;
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
    _membersByServerId.remove(command.serverId);
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> updateOne({
    required AddServerMemberCommand command,
  }) async {
    if (forceAddMemberError) {
      return Error<void>(Exception("Failed to add server member"));
    }

    final members = _membersByServerId.putIfAbsent(
      command.serverId,
      () => <String>{},
    );
    members.add(command.userId);

    return const Ok<void>(null);
  }

  @override
  Future<Result<Iterable<ServerMember>>> getServerMembers({
    required GetServerMembersQuery query,
  }) async {
    final members = _membersByServerId[query.serverId];
    if (members == null) {
      return Error<Iterable<ServerMember>>(
        Exception("Failed to list server members"),
      );
    }

    return Ok<Iterable<ServerMember>>(
      members
          .map(
            (userId) => ServerMember(serverId: query.serverId, userId: userId),
          )
          .toList(),
    );
  }
}

class FakeChannelRepository implements ChannelRepo {
  FakeChannelRepository({
    required ChatApiFixture fixture,
    this.forceDeleteError = false,
  })  : _channelsByServer = <String, List<Channel>>{
          fixture.listedServer.id: <Channel>[
            fixture.listedChannel,
            fixture.listedVoiceChannel,
          ],
        },
        _createdTextChannel = fixture.createdChannel;

  final bool forceDeleteError;
  final Map<String, List<Channel>> _channelsByServer;
  final Channel _createdTextChannel;

  @override
  Future<Result<Channel>> createOne({
    required CreateChannelCommand command,
  }) async {
    final channels = _channelsByServer.putIfAbsent(
      command.serverId,
      () => <Channel>[],
    );

    final createdChannel = _createdTextChannel;

    channels.add(createdChannel);
    return Ok<Channel>(createdChannel);
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
  }) : _connectedVoiceSession = fixture.connectedVoiceSession;

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
}

class FakeTextSessionRepository implements TextSessionRepo {
  FakeTextSessionRepository({
    required ChatApiFixture fixture,
  }) : _connectedTextSession = TextConnectSession(
          livekitUrl: fixture.connectedVoiceSession.livekitUrl,
          accessToken: fixture.connectedVoiceSession.accessToken,
          channelId: fixture.connectedVoiceSession.channelId,
          participantUserId: fixture.connectedVoiceSession.participantUserId,
        );

  final TextConnectSession _connectedTextSession;

  @override
  Future<Result<TextConnectSession>> createOne({
    required ConnectTextSessionCommand command,
  }) async {
    return Ok<TextConnectSession>(
      TextConnectSession(
        livekitUrl: _connectedTextSession.livekitUrl,
        accessToken: _connectedTextSession.accessToken,
        channelId: command.channelId,
        participantUserId: _connectedTextSession.participantUserId,
      ),
    );
  }
}

class FakeVoiceRuntimeService implements MediaRuntimeService {
  FakeVoiceRuntimeService({
    this.forceConnectError = false,
    this.forceDisconnectError = false,
    this.forceSetSelfMutedError = false,
    this.forceSetSelfDeafenedError = false,
    this.forceSetSelfScreenShareEnabledError = false,
    this.initialParticipantUserIds = const <String>{"auth0|u1"},
  });

  final bool forceConnectError;
  final bool forceDisconnectError;
  final bool forceSetSelfMutedError;
  final bool forceSetSelfDeafenedError;
  final bool forceSetSelfScreenShareEnabledError;
  final Set<String> initialParticipantUserIds;
  final _participantUserIdsController =
      StreamController<Set<String>>.broadcast();
  final _speakingParticipantUserIdsController =
      StreamController<Set<String>>.broadcast();
  final _participantVideoTracksController =
      StreamController<Map<String, Object>>.broadcast();
  late Set<String> _currentParticipantUserIds =
      Set<String>.from(initialParticipantUserIds);
  final Map<String, Object> _currentParticipantVideoTracks = <String, Object>{};
  final Map<String, RuntimeAudioChannel> _audioChannelByParticipantUserId =
      <String, RuntimeAudioChannel>{};
  final Map<RuntimeAudioChannel, bool> _audioChannelEnabled =
      <RuntimeAudioChannel, bool>{
    RuntimeAudioChannel.voice: true,
    RuntimeAudioChannel.livestream: true,
  };
  var _isSelfMuted = false;
  var _isSelfDeafened = false;
  var _isSelfScreenShareEnabled = false;

  @override
  Future<Result<void>> connect({
    required String livekitUrl,
    required String accessToken,
  }) async {
    if (forceConnectError) {
      return Error<void>(Exception("Failed to connect to livekit"));
    }

    _isSelfMuted = false;
    _isSelfDeafened = false;
    _isSelfScreenShareEnabled = false;
    _currentParticipantVideoTracks.clear();
    _audioChannelByParticipantUserId.clear();
    _audioChannelEnabled
      ..clear()
      ..addAll(<RuntimeAudioChannel, bool>{
        RuntimeAudioChannel.voice: true,
        RuntimeAudioChannel.livestream: true,
      });
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> disconnect() async {
    if (forceDisconnectError) {
      return Error<void>(Exception("Failed to disconnect from livekit"));
    }

    _isSelfMuted = false;
    _isSelfDeafened = false;
    _isSelfScreenShareEnabled = false;
    _currentParticipantVideoTracks.clear();
    _audioChannelByParticipantUserId.clear();
    _audioChannelEnabled
      ..clear()
      ..addAll(<RuntimeAudioChannel, bool>{
        RuntimeAudioChannel.voice: true,
        RuntimeAudioChannel.livestream: true,
      });
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> setSelfMuted({required bool muted}) async {
    if (forceSetSelfMutedError) {
      return Error<void>(Exception("Failed to update microphone state"));
    }

    _isSelfMuted = muted;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> setSelfDeafened({required bool deafened}) async {
    if (forceSetSelfDeafenedError) {
      return Error<void>(Exception("Failed to update deafen state"));
    }

    _isSelfDeafened = deafened;
    if (deafened) {
      _isSelfMuted = true;
    } else {
      _isSelfMuted = false;
    }

    return const Ok<void>(null);
  }

  @override
  bool isSelfMuted() {
    return _isSelfMuted;
  }

  @override
  bool isSelfDeafened() {
    return _isSelfDeafened;
  }

  @override
  Future<Result<void>> setSelfScreenShareEnabled(
      {required bool enabled, String? sourceId}) async {
    if (forceSetSelfScreenShareEnabledError) {
      return Error<void>(Exception("Failed to update camera state"));
    }

    _isSelfScreenShareEnabled = enabled;
    return const Ok<void>(null);
  }

  @override
  bool isSelfScreenShareEnabled() {
    return _isSelfScreenShareEnabled;
  }

  @override
  Future<Result<void>> setAudioChannelEnabled({
    required RuntimeAudioChannel channel,
    required bool enabled,
  }) async {
    _audioChannelEnabled[channel] = enabled;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> setParticipantAudioChannel({
    required String participantUserId,
    required RuntimeAudioChannel channel,
  }) async {
    _audioChannelByParticipantUserId[participantUserId] = channel;
    return const Ok<void>(null);
  }

  @override
  bool isAudioChannelEnabled(RuntimeAudioChannel channel) {
    return _audioChannelEnabled[channel] ?? true;
  }

  @override
  RuntimeAudioChannel participantAudioChannel(String participantUserId) {
    return _audioChannelByParticipantUserId[participantUserId] ??
        RuntimeAudioChannel.voice;
  }

  @override
  Iterable<String> currentParticipantUserIds() {
    return _currentParticipantUserIds;
  }

  @override
  Stream<Set<String>> participantUserIds() {
    return _participantUserIdsController.stream;
  }

  @override
  Stream<Set<String>> speakingParticipantUserIds() {
    return _speakingParticipantUserIdsController.stream;
  }

  @override
  Map<String, Object> currentParticipantVideoTracks() {
    return Map<String, Object>.from(_currentParticipantVideoTracks);
  }

  @override
  Stream<Map<String, Object>> participantVideoTracks() {
    return _participantVideoTracksController.stream;
  }

  void emitSpeakingParticipantUserIds(Set<String> userIds) {
    _speakingParticipantUserIdsController.add(userIds);
  }

  void emitParticipantUserIds(Set<String> userIds) {
    _currentParticipantUserIds = Set<String>.from(userIds);
    _participantUserIdsController.add(userIds);
  }

  void emitParticipantVideoTracks(Map<String, Object> videoTracks) {
    _currentParticipantVideoTracks
      ..clear()
      ..addAll(videoTracks);
    _participantVideoTracksController
        .add(Map<String, Object>.from(videoTracks));
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
