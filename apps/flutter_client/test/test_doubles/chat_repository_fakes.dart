import "dart:async";

import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/friend_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_member_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/text_session_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/audio_device_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/message_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";

import "../entity_seeder.dart";

class FakeServerRepository implements ServerRepo {
  FakeServerRepository({
    required ChatApiFixture fixture,
    this.forceAddMemberError = false,
    this.addMemberError,
    this.forceInviteFriendError = false,
    this.inviteFriendError,
    this.forceDeleteError = false,
  })  : _servers = <Server>[fixture.listedServer],
        _membersByServerId = <ServerId, Set<UserId>>{
          fixture.listedServer.id: <UserId>{fixture.ownerUserId},
          fixture.createdServer.id: <UserId>{fixture.ownerUserId},
        },
        _createdServer = fixture.createdServer;

  final bool forceAddMemberError;
  final Exception? addMemberError;
  final bool forceInviteFriendError;
  final Exception? inviteFriendError;
  final bool forceDeleteError;
  final List<Server> _servers;
  final Map<ServerId, Set<UserId>> _membersByServerId;
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
    required ServerUpdateCommand command,
  }) async {
    return switch (command) {
      UpdateServerNameCommand(:final serverId, :final name) =>
        _updateServerName(serverId: serverId, name: name),
      AddServerMemberUpdateCommand(:final serverId, :final userId) =>
        _addServerMember(serverId: serverId, userId: userId),
      InviteFriendToServerCommand() => _inviteFriendToServer(),
    };
  }

  Result<void> _updateServerName({
    required ServerId serverId,
    required String name,
  }) {
    final serverIndex = _servers.indexWhere((server) => server.id == serverId);
    if (serverIndex == -1) {
      return Error<void>(Exception("Server not found"));
    }

    final existingServer = _servers[serverIndex];
    _servers[serverIndex] = Server(
      id: existingServer.id,
      name: name,
      ownerUserId: existingServer.ownerUserId,
    );

    return const Ok<void>(null);
  }

  Result<void> _inviteFriendToServer() {
    if (forceInviteFriendError) {
      return Error<void>(
        inviteFriendError ?? Exception("Failed to invite friend to server"),
      );
    }

    return const Ok<void>(null);
  }

  Result<void> _addServerMember({
    required ServerId serverId,
    required UserId userId,
  }) {
    if (forceAddMemberError) {
      return Error<void>(
          addMemberError ?? Exception("Failed to add server member"));
    }

    _membersByServerId.putIfAbsent(serverId, () => <UserId>{}).add(userId);

    return const Ok<void>(null);
  }
}

class FakeServerMemberRepository implements ServerMemberRepo {
  FakeServerMemberRepository({
    required ChatApiFixture fixture,
  }) : _membersByServerId = <ServerId, Set<UserId>>{
          fixture.listedServer.id: <UserId>{fixture.ownerUserId},
          fixture.createdServer.id: <UserId>{fixture.ownerUserId},
        };

  final Map<ServerId, Set<UserId>> _membersByServerId;

  @override
  Future<Result<Iterable<ServerMember>>> getMany({
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

class FakeFriendRepository implements FriendRepo {
  FakeFriendRepository({
    required this.friendUserIds,
    this.initialPendingOutgoingRequests = const <PendingFriendRequest>[],
    this.forceCreateError = false,
    this.createError,
    this.forceCancelError = false,
    this.cancelError,
  });

  final Set<UserId> friendUserIds;
  final List<PendingFriendRequest> initialPendingOutgoingRequests;
  final bool forceCreateError;
  final Exception? createError;
  final bool forceCancelError;
  final Exception? cancelError;

  List<PendingFriendRequest>? _pendingOutgoingRequests;

  List<PendingFriendRequest> get _pendingRequests {
    return _pendingOutgoingRequests ??=
        List<PendingFriendRequest>.from(initialPendingOutgoingRequests);
  }

  @override
  Future<Result<PendingFriendRequest>> createOne({
    required SendFriendRequestFromServerContextCommand command,
  }) async {
    if (forceCreateError) {
      return Error<PendingFriendRequest>(
          createError ?? Exception("Failed to send friend request"));
    }

    final pendingRequest = PendingFriendRequest(
      id: FriendRequestId("pending-${command.targetUserId.value}"),
      requesterUserId: const UserId("requester-user"),
      addresseeUserId: command.targetUserId,
    );
    _pendingRequests.add(pendingRequest);

    return Ok<PendingFriendRequest>(pendingRequest);
  }

  @override
  Future<Result<void>> deleteOne({
    required CancelOutgoingFriendRequestCommand command,
  }) async {
    if (forceCancelError) {
      return Error<void>(
        cancelError ?? Exception("Failed to cancel friend request"),
      );
    }

    _pendingRequests.removeWhere(
      (request) => request.id == command.friendRequestId,
    );

    return const Ok<void>(null);
  }

  @override
  Future<Result<Iterable<Friend>>> getMany({
    required GetFriendsQuery query,
  }) async {
    final friends = friendUserIds
        .map((userId) => Friend(userId: userId))
        .toList(growable: false);
    return Ok<Iterable<Friend>>(friends);
  }

  @override
  Future<Result<Iterable<PendingFriendRequest>>> getOne({
    required GetOutgoingPendingFriendRequestsQuery query,
  }) async {
    return Ok<Iterable<PendingFriendRequest>>(
      List<PendingFriendRequest>.from(_pendingRequests),
    );
  }
}

class FakeChannelRepository implements ChannelRepo {
  FakeChannelRepository({
    required ChatApiFixture fixture,
    this.forceDeleteError = false,
  })  : _channelsByServer = <ServerId, List<Channel>>{
          fixture.listedServer.id: <Channel>[
            fixture.listedChannel,
            fixture.listedVoiceChannel,
          ],
        },
        _createdTextChannel = fixture.createdChannel;

  final bool forceDeleteError;
  final Map<ServerId, List<Channel>> _channelsByServer;
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

  @override
  Future<Result<void>> updateOne({
    required UpdateChannelNameCommand command,
  }) async {
    for (final channels in _channelsByServer.values) {
      final index =
          channels.indexWhere((channel) => channel.id == command.channelId);
      if (index == -1) {
        continue;
      }

      final existing = channels[index];
      channels[index] = switch (existing) {
        TextChannel(:final id, :final serverId) =>
          TextChannel(id: id, serverId: serverId, name: command.name),
        VoiceChannel(:final id, :final serverId) =>
          VoiceChannel(id: id, serverId: serverId, name: command.name),
      };
      return const Ok<void>(null);
    }

    return Error<void>(Exception("Channel not found"));
  }
}

class FakeMessageRepository implements MessageRepo {
  FakeMessageRepository({
    required ChatApiFixture fixture,
    this.forceUpdateNotFound = false,
    this.forceDeleteNotFound = false,
  })  : _messagesByChannel = <ChannelId, List<Message>>{
          fixture.listedChannel.id: <Message>[fixture.listedMessage],
        },
        _createdMessage = fixture.createdMessage;

  final bool forceUpdateNotFound;
  final bool forceDeleteNotFound;
  final Map<ChannelId, List<Message>> _messagesByChannel;
  final Message _createdMessage;

  @override
  Future<Result<Message>> createOne({
    required CreateMessageCommand command,
  }) async {
    _messagesByChannel
        .putIfAbsent(command.channelId, () => <Message>[])
        .add(_createdMessage);
    return Ok<Message>(_createdMessage);
  }

  @override
  Future<Result<void>> deleteOne({
    required DeleteMessageCommand command,
  }) async {
    if (forceDeleteNotFound) {
      return Error<void>(Exception("Failed to delete message: 404 Not found"));
    }

    (_messagesByChannel[command.channelId] ?? <Message>[])
        .removeWhere((message) => message.id == command.messageId);
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
    this.connectError,
  }) : _connectedVoiceSession = fixture.connectedVoiceSession;

  final VoiceConnectSession _connectedVoiceSession;
  final Exception? connectError;

  @override
  Future<Result<VoiceConnectSession>> createOne({
    required ConnectVoiceSessionCommand command,
  }) async {
    final resolvedConnectError = connectError;
    if (resolvedConnectError != null) {
      return Error<VoiceConnectSession>(resolvedConnectError);
    }

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
    this.selfParticipantUserId = "auth0|u1",
    this.initialMutedParticipantUserIds = const <String>{},
    this.initialDeafenedParticipantUserIds = const <String>{},
  });

  final bool forceConnectError;
  final bool forceDisconnectError;
  final bool forceSetSelfMutedError;
  final bool forceSetSelfDeafenedError;
  final bool forceSetSelfScreenShareEnabledError;
  final Set<String> initialParticipantUserIds;
  final String selfParticipantUserId;
  final Set<String> initialMutedParticipantUserIds;
  final Set<String> initialDeafenedParticipantUserIds;
  final _participantUserIdsController =
      StreamController<Set<String>>.broadcast();
  final _participantStatusUpdatesController =
      StreamController<ParticipantStatusUpdate>.broadcast();
  final _participantVideoTracksController =
      StreamController<Map<String, Object>>.broadcast();
  final _audioDeviceChangesController = StreamController<void>.broadcast();
  late var _currentParticipantUserIds =
      Set<String>.from(initialParticipantUserIds);
  final _currentParticipantVideoTracks = <String, Object>{};
  var _audioInputDevices = const <RuntimeAudioDevice>[
    RuntimeAudioDevice(
      id: "mic-default",
      label: "Default microphone",
      isSystemDefault: true,
    ),
    RuntimeAudioDevice(id: "mic-usb", label: "USB microphone"),
  ];
  var _audioOutputDevices = const <RuntimeAudioDevice>[
    RuntimeAudioDevice(
      id: "spk-default",
      label: "Default speakers",
      isSystemDefault: true,
    ),
    RuntimeAudioDevice(id: "spk-usb", label: "USB headphones"),
  ];
  String? _selectedAudioInputDeviceId;
  String? _selectedAudioOutputDeviceId;
  final _audioChannelByParticipantUserId = <String, RuntimeAudioChannel>{};
  final _audioChannelEnabled = <RuntimeAudioChannel, bool>{
    RuntimeAudioChannel.voice: true,
    RuntimeAudioChannel.livestream: true,
  };
  late final _currentMutedParticipantUserIds =
      Set<String>.from(initialMutedParticipantUserIds);
  late final _currentDeafenedParticipantUserIds =
      Set<String>.from(initialDeafenedParticipantUserIds);
  var _isSelfMuted = false;
  var _isSelfDeafened = false;
  var _isSelfScreenShareEnabled = false;
  VoiceAudioProcessingOptions? lastAudioProcessingOptions;
  VoiceAudioProcessingOptions? lastAppliedAudioProcessingOptions;
  var applyVoiceAudioProcessingOptionsCalls = 0;

  @override
  Future<void> close() async {
    await _participantUserIdsController.close();
    await _participantStatusUpdatesController.close();
    await _participantVideoTracksController.close();
    await _audioDeviceChangesController.close();
  }

  @override
  Future<Result<void>> connect({
    required String livekitUrl,
    required String accessToken,
    required VoiceAudioProcessingOptions audioProcessingOptions,
  }) async {
    lastAudioProcessingOptions = audioProcessingOptions;

    if (forceConnectError) {
      return Error<void>(
        RuntimeConnectionException(
          operation: "connect",
          cause: Exception("Failed to connect to livekit"),
        ),
      );
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
    _currentDeafenedParticipantUserIds.clear();
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> applyVoiceAudioProcessingOptions({
    required VoiceAudioProcessingOptions audioProcessingOptions,
  }) async {
    applyVoiceAudioProcessingOptionsCalls += 1;
    lastAppliedAudioProcessingOptions = audioProcessingOptions;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> disconnect() async {
    if (forceDisconnectError) {
      return Error<void>(
        RuntimeConnectionException(
          operation: "disconnect",
          cause: Exception("Failed to disconnect from livekit"),
        ),
      );
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
    _currentDeafenedParticipantUserIds.clear();
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
      _currentDeafenedParticipantUserIds.add(selfParticipantUserId);
    } else {
      _isSelfMuted = false;
      _currentDeafenedParticipantUserIds.remove(selfParticipantUserId);
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
  Future<Result<List<RuntimeAudioDevice>>> listAudioInputDevices() async {
    return Ok<List<RuntimeAudioDevice>>(
      List<RuntimeAudioDevice>.from(_audioInputDevices),
    );
  }

  @override
  Future<Result<List<RuntimeAudioDevice>>> listAudioOutputDevices() async {
    return Ok<List<RuntimeAudioDevice>>(
      List<RuntimeAudioDevice>.from(_audioOutputDevices),
    );
  }

  @override
  Future<Result<void>> setSelectedAudioInputDeviceId(String? deviceId) async {
    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    if (normalizedDeviceId == null) {
      _selectedAudioInputDeviceId = null;
      return const Ok<void>(null);
    }

    final hasMatch =
        _audioInputDevices.any((device) => device.id == normalizedDeviceId);
    if (!hasMatch) {
      return Error<void>(Exception("Unknown audio input device id"));
    }

    _selectedAudioInputDeviceId = normalizedDeviceId;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> setSelectedAudioOutputDeviceId(String? deviceId) async {
    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    if (normalizedDeviceId == null) {
      _selectedAudioOutputDeviceId = null;
      return const Ok<void>(null);
    }

    final hasMatch =
        _audioOutputDevices.any((device) => device.id == normalizedDeviceId);
    if (!hasMatch) {
      return Error<void>(Exception("Unknown audio output device id"));
    }

    _selectedAudioOutputDeviceId = normalizedDeviceId;
    return const Ok<void>(null);
  }

  @override
  String? selectedAudioInputDeviceId() {
    return _selectedAudioInputDeviceId;
  }

  @override
  String? selectedAudioOutputDeviceId() {
    return _selectedAudioOutputDeviceId;
  }

  @override
  Stream<void> audioDeviceChanges() {
    return _audioDeviceChangesController.stream;
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
  Set<String> currentMutedParticipantUserIds() {
    final mutedParticipantUserIds =
        Set<String>.from(_currentMutedParticipantUserIds);

    if (_isSelfMuted) {
      mutedParticipantUserIds.add(selfParticipantUserId);
    } else {
      mutedParticipantUserIds.remove(selfParticipantUserId);
    }

    return mutedParticipantUserIds;
  }

  @override
  Set<String> currentDeafenedParticipantUserIds() {
    final deafenedParticipantUserIds =
        Set<String>.from(_currentDeafenedParticipantUserIds);

    if (_isSelfDeafened) {
      deafenedParticipantUserIds.add(selfParticipantUserId);
    } else {
      deafenedParticipantUserIds.remove(selfParticipantUserId);
    }

    return deafenedParticipantUserIds;
  }

  @override
  Stream<Set<String>> participantUserIds() {
    return _participantUserIdsController.stream;
  }

  @override
  Stream<ParticipantStatusUpdate> participantStatusUpdates() {
    return _participantStatusUpdatesController.stream;
  }

  @override
  Map<String, Object> currentParticipantVideoTracks() {
    return Map<String, Object>.from(_currentParticipantVideoTracks);
  }

  @override
  Stream<Map<String, Object>> participantVideoTracks() {
    return _participantVideoTracksController.stream;
  }

  void emitParticipantStatusUpdate(ParticipantStatusUpdate update) {
    _participantStatusUpdatesController.add(update);
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

  void emitAudioDevicesChanged({
    List<RuntimeAudioDevice>? audioInputDevices,
    List<RuntimeAudioDevice>? audioOutputDevices,
  }) {
    _audioInputDevices =
        List<RuntimeAudioDevice>.from(audioInputDevices ?? _audioInputDevices);
    _audioOutputDevices = List<RuntimeAudioDevice>.from(
      audioOutputDevices ?? _audioOutputDevices,
    );
    _audioDeviceChangesController.add(null);
  }

  String? _normalizeDeviceId(String? deviceId) {
    final trimmedDeviceId = deviceId?.trim();
    if (trimmedDeviceId == null || trimmedDeviceId.isEmpty) {
      return null;
    }

    return trimmedDeviceId;
  }
}

class FakeAudioDeviceRuntimeService implements AudioDeviceRuntimeService {
  final _audioDeviceChangesController = StreamController<void>.broadcast();
  var _audioInputDevices = const <RuntimeAudioDevice>[
    RuntimeAudioDevice(
      id: "mic-default",
      label: "Default microphone",
      isSystemDefault: true,
    ),
    RuntimeAudioDevice(id: "mic-usb", label: "USB microphone"),
  ];
  var _audioOutputDevices = const <RuntimeAudioDevice>[
    RuntimeAudioDevice(
      id: "spk-default",
      label: "Default speakers",
      isSystemDefault: true,
    ),
    RuntimeAudioDevice(id: "spk-usb", label: "USB headphones"),
  ];
  String? _selectedAudioInputDeviceId;
  String? _selectedAudioOutputDeviceId;

  @override
  Future<Result<List<RuntimeAudioDevice>>> listAudioInputDevices() async {
    return Ok<List<RuntimeAudioDevice>>(
      List<RuntimeAudioDevice>.from(_audioInputDevices),
    );
  }

  @override
  Future<Result<List<RuntimeAudioDevice>>> listAudioOutputDevices() async {
    return Ok<List<RuntimeAudioDevice>>(
      List<RuntimeAudioDevice>.from(_audioOutputDevices),
    );
  }

  @override
  Future<Result<void>> setSelectedAudioInputDeviceId(String? deviceId) async {
    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    if (normalizedDeviceId == null) {
      _selectedAudioInputDeviceId = null;
      return const Ok<void>(null);
    }

    final hasMatch =
        _audioInputDevices.any((device) => device.id == normalizedDeviceId);
    if (!hasMatch) {
      return Error<void>(Exception("Unknown audio input device id"));
    }

    _selectedAudioInputDeviceId = normalizedDeviceId;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> setSelectedAudioOutputDeviceId(String? deviceId) async {
    final normalizedDeviceId = _normalizeDeviceId(deviceId);
    if (normalizedDeviceId == null) {
      _selectedAudioOutputDeviceId = null;
      return const Ok<void>(null);
    }

    final hasMatch =
        _audioOutputDevices.any((device) => device.id == normalizedDeviceId);
    if (!hasMatch) {
      return Error<void>(Exception("Unknown audio output device id"));
    }

    _selectedAudioOutputDeviceId = normalizedDeviceId;
    return const Ok<void>(null);
  }

  @override
  String? selectedAudioInputDeviceId() {
    return _selectedAudioInputDeviceId;
  }

  @override
  String? selectedAudioOutputDeviceId() {
    return _selectedAudioOutputDeviceId;
  }

  @override
  Stream<void> audioDeviceChanges() {
    return _audioDeviceChangesController.stream;
  }

  @override
  Future<Result<void>> applySelectedAudioDevicesToActiveRoom() async {
    return const Ok<void>(null);
  }

  @override
  Future<void> close() async {
    await _audioDeviceChangesController.close();
  }

  void emitAudioDevicesChanged({
    List<RuntimeAudioDevice>? audioInputDevices,
    List<RuntimeAudioDevice>? audioOutputDevices,
  }) {
    _audioInputDevices =
        List<RuntimeAudioDevice>.from(audioInputDevices ?? _audioInputDevices);
    _audioOutputDevices = List<RuntimeAudioDevice>.from(
      audioOutputDevices ?? _audioOutputDevices,
    );
    _audioDeviceChangesController.add(null);
  }

  String? _normalizeDeviceId(String? deviceId) {
    final trimmedDeviceId = deviceId?.trim();
    if (trimmedDeviceId == null || trimmedDeviceId.isEmpty) {
      return null;
    }

    return trimmedDeviceId;
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

class FakeNotificationRuntimeService implements NotificationRuntimeService {
  FakeNotificationRuntimeService({
    this.forceConnectError = false,
    this.forceDisconnectError = false,
  });

  final bool forceConnectError;
  final bool forceDisconnectError;
  final _notificationEventsController =
      StreamController<RuntimeNotificationEvent>.broadcast();

  @override
  Future<Result<void>> connect({
    required String bearerToken,
  }) async {
    if (forceConnectError) {
      return Error<void>(
        RuntimeConnectionException(
          operation: "connect notifications websocket",
          cause: Exception("Failed to connect to notifications websocket"),
        ),
      );
    }

    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> disconnect() async {
    if (forceDisconnectError) {
      return Error<void>(
        RuntimeConnectionException(
          operation: "disconnect notifications websocket",
          cause: Exception("Failed to disconnect from notifications websocket"),
        ),
      );
    }

    return const Ok<void>(null);
  }

  @override
  Stream<RuntimeNotificationEvent> notificationEvents() {
    return _notificationEventsController.stream;
  }

  void emit(RuntimeNotificationEvent event) {
    _notificationEventsController.add(event);
  }
}

class FakeProfileRepository implements ProfileRepo {
  FakeProfileRepository({
    required this.userId,
    this.initialDisplayName,
    this.forceGetError = false,
    this.forceUpdateError = false,
    this.displayNamesByUserId = const <UserId, String?>{},
  }) : _displayName = initialDisplayName;

  final UserId userId;
  final String? initialDisplayName;
  final bool forceGetError;
  final bool forceUpdateError;
  final Map<UserId, String?> displayNamesByUserId;
  String? _displayName;

  @override
  Future<Result<UserProfile>> getOne({required GetUserQuery query}) async {
    if (forceGetError) {
      return Error<UserProfile>(Exception("Failed to get profile"));
    }

    final resolvedUserId = UserId(query.userId.value.trim());
    final displayName = displayNamesByUserId.containsKey(resolvedUserId)
        ? displayNamesByUserId[resolvedUserId]
        : (resolvedUserId == userId ? _displayName : null);

    return Ok<UserProfile>(
      UserProfile(
        userId: resolvedUserId,
        displayName: displayName,
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
}
