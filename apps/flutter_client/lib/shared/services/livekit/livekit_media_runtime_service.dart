import "dart:async";

import "package:livekit_client/livekit_client.dart";
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/livekit/livekit_runtime_projection.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";

class LivekitMediaRuntimeService implements MediaRuntimeService {
  static const _deafenedAttributeKey = "polyphony_deafened";

  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  final _participantUserIdsController =
      StreamController<Set<String>>.broadcast();
  final _participantStatusUpdatesController =
      StreamController<ParticipantStatusUpdate>.broadcast();
  final _participantVideoTracksController =
      StreamController<Map<String, Object>>.broadcast();

  var _isSelfMuted = false;
  var _isSelfDeafened = false;
  var _isSelfScreenShareEnabled = false;

  final _participantAudioChannelByUserId =
      <ParticipantUserId, RuntimeAudioChannel>{};
  final _audioChannelEnabled = <RuntimeAudioChannel, bool>{
    RuntimeAudioChannel.voice: true,
    RuntimeAudioChannel.livestream: true,
  };

  Set<ParticipantUserId>? _lastParticipantUserIds;
  Set<ParticipantUserId>? _lastSpeakingParticipantUserIds;
  Set<ParticipantUserId>? _lastMutedParticipantUserIds;
  Set<ParticipantUserId>? _lastDeafenedParticipantUserIds;
  Map<String, Object>? _lastParticipantVideoTracks;

  @override
  Future<Result<void>> connect({
    required String livekitUrl,
    required String accessToken,
  }) async {
    try {
      await _disconnectCurrentRoom();

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      await room.prepareConnection(livekitUrl, accessToken);
      await room.connect(livekitUrl, accessToken);
      await room.localParticipant?.setMicrophoneEnabled(true);
      await room.localParticipant?.setScreenShareEnabled(false);
      _setLocalParticipantDeafenedAttribute(
        localParticipant: room.localParticipant,
        deafenState: const NotDeafenedState(),
      );

      _isSelfMuted = false;
      _isSelfDeafened = false;
      _isSelfScreenShareEnabled = false;
      _participantAudioChannelByUserId.clear();
      _audioChannelEnabled
        ..clear()
        ..addAll(<RuntimeAudioChannel, bool>{
          RuntimeAudioChannel.voice: true,
          RuntimeAudioChannel.livestream: true,
        });

      _room = room;
      _roomListener = room.createListener()
        ..on<RoomEvent>((_) {
          _emitRoomSnapshot(room);
        })
        ..on<TrackMutedEvent>((_) {
          _emitMutedParticipantUserIds(_mutedParticipantUserIdsFromRoom(room));
        })
        ..on<TrackUnmutedEvent>((_) {
          _emitMutedParticipantUserIds(_mutedParticipantUserIdsFromRoom(room));
        })
        ..on<ParticipantMetadataUpdatedEvent>((_) {
          _emitDeafenedParticipantUserIds(
            _deafenedParticipantUserIdsFromRoom(room),
          );
        })
        ..on<ActiveSpeakersChangedEvent>((event) {
          _emitSpeakingParticipantUserIds(event.speakers);
        })
        ..on<TrackSubscribedEvent>((event) {
          if (!_isSelfDeafened || event.track is! RemoteAudioTrack) {
            return;
          }

          unawaited(event.publication.unsubscribe());
        });

      _emitRoomSnapshot(room);
      _emitSpeakingParticipantUserIds(room.activeSpeakers);
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(
        RuntimeConnectionException(operation: "connect", cause: error),
      );
    }
  }

  @override
  Future<Result<void>> disconnect() async {
    try {
      await _disconnectCurrentRoom();
      _isSelfMuted = false;
      _isSelfDeafened = false;
      _isSelfScreenShareEnabled = false;
      _participantAudioChannelByUserId.clear();
      _audioChannelEnabled
        ..clear()
        ..addAll(<RuntimeAudioChannel, bool>{
          RuntimeAudioChannel.voice: true,
          RuntimeAudioChannel.livestream: true,
        });

      _emitParticipantUserIds(const <ParticipantUserId>{});
      _emitSpeakingParticipantUserIdsFromSet(const <ParticipantUserId>{});
      _emitMutedParticipantUserIds(const <ParticipantUserId>{});
      _emitDeafenedParticipantUserIds(const <ParticipantUserId>{});
      _emitParticipantVideoTracks(const <String, Object>{});

      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(
        RuntimeConnectionException(operation: "disconnect", cause: error),
      );
    }
  }

  @override
  Future<Result<void>> setSelfMuted({required bool muted}) async {
    try {
      final activeRoom = _room;
      if (activeRoom == null) {
        return Error<void>(Exception("Not connected to a voice session."));
      }

      await activeRoom.localParticipant?.setMicrophoneEnabled(!muted);
      _isSelfMuted = muted;
      _emitMutedParticipantUserIds(
          _mutedParticipantUserIdsFromRoom(activeRoom));
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  @override
  bool isSelfMuted() {
    return _isSelfMuted;
  }

  @override
  Future<Result<void>> setSelfDeafened({required bool deafened}) async {
    try {
      final activeRoom = _room;
      if (activeRoom == null) {
        return Error<void>(Exception("Not connected to a voice session."));
      }

      if (deafened) {
        await activeRoom.localParticipant?.setMicrophoneEnabled(false);
        _isSelfMuted = true;
        await _setRemoteAudioSubscriptionsEnabled(enabled: false);
      } else {
        await activeRoom.localParticipant?.setMicrophoneEnabled(true);
        _isSelfMuted = false;
        await _setRemoteAudioSubscriptionsEnabled(enabled: true);
      }

      _isSelfDeafened = deafened;
      _setLocalParticipantDeafenedAttribute(
        localParticipant: activeRoom.localParticipant,
        deafenState: ParticipantDeafenState.fromBool(deafened),
      );
      _emitMutedParticipantUserIds(
          _mutedParticipantUserIdsFromRoom(activeRoom));
      _emitDeafenedParticipantUserIds(
        _deafenedParticipantUserIdsFromRoom(activeRoom),
      );

      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  @override
  bool isSelfDeafened() {
    return _isSelfDeafened;
  }

  @override
  Future<Result<void>> setSelfScreenShareEnabled(
      {required bool enabled, String? sourceId}) async {
    try {
      final activeRoom = _room;
      if (activeRoom == null) {
        return Error<void>(Exception("Not connected to a voice session."));
      }

      final localParticipant = activeRoom.localParticipant;
      if (localParticipant == null) {
        return Error<void>(
          Exception("Local participant is unavailable for screen sharing."),
        );
      }

      if (enabled && !localParticipant.permissions.canPublish) {
        return Error<void>(
          Exception("Not allowed to publish screen share."),
        );
      }

      if (enabled) {
        final trimmedSourceId = sourceId?.trim();

        if (trimmedSourceId != null && trimmedSourceId.isNotEmpty) {
          final existingScreenSharePublication =
              localParticipant.getTrackPublicationBySource(
            TrackSource.screenShareVideo,
          );

          if (existingScreenSharePublication != null) {
            await localParticipant
                .removePublishedTrack(existingScreenSharePublication.sid);
          }

          final track = await LocalVideoTrack.createScreenShareTrack(
            ScreenShareCaptureOptions(
              sourceId: trimmedSourceId,
              maxFrameRate: 15.0,
              params: activeRoom
                  .roomOptions.defaultScreenShareCaptureOptions.params,
            ),
          );

          await localParticipant.publishVideoTrack(track);
        } else {
          await localParticipant.setScreenShareEnabled(true);
        }
      } else {
        await localParticipant.setScreenShareEnabled(false);
      }

      final isScreenShareEnabled = localParticipant.isScreenShareEnabled();

      if (enabled && !isScreenShareEnabled) {
        return Error<void>(
          Exception("Screen sharing did not start."),
        );
      }

      if (!enabled && isScreenShareEnabled) {
        return Error<void>(Exception("Screen sharing did not stop."));
      }

      _isSelfScreenShareEnabled = isScreenShareEnabled;
      _emitParticipantVideoTracks(_participantVideoTracksFromRoom(activeRoom));
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
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
    try {
      _audioChannelEnabled[channel] = enabled;
      await _applyRemoteAudioSubscriptions();
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  @override
  Future<Result<void>> setParticipantAudioChannel({
    required String participantUserId,
    required RuntimeAudioChannel channel,
  }) async {
    try {
      final normalizedParticipantUserId =
          ParticipantUserId.fromRaw(participantUserId);
      if (normalizedParticipantUserId == null) {
        return Error<void>(Exception("Participant user id cannot be empty."));
      }

      _participantAudioChannelByUserId[normalizedParticipantUserId] = channel;
      await _applyRemoteAudioSubscriptions();
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  @override
  bool isAudioChannelEnabled(RuntimeAudioChannel channel) {
    return _audioChannelEnabled[channel] ?? true;
  }

  @override
  RuntimeAudioChannel participantAudioChannel(String participantUserId) {
    final normalizedParticipantUserId =
        ParticipantUserId.fromRaw(participantUserId);
    if (normalizedParticipantUserId == null) {
      return RuntimeAudioChannel.voice;
    }

    return _participantAudioChannelByUserId[normalizedParticipantUserId] ??
        RuntimeAudioChannel.voice;
  }

  @override
  Iterable<String> currentParticipantUserIds() {
    final activeRoom = _room;
    if (activeRoom == null) {
      return const <String>[];
    }

    return LivekitRuntimeProjection.rawParticipantUserIds(
      _participantUserIdsFromRoom(activeRoom),
    );
  }

  @override
  Set<String> currentMutedParticipantUserIds() {
    final activeRoom = _room;
    if (activeRoom == null) {
      return const <String>{};
    }

    return LivekitRuntimeProjection.rawParticipantUserIds(
      _mutedParticipantUserIdsFromRoom(activeRoom),
    );
  }

  @override
  Set<String> currentDeafenedParticipantUserIds() {
    final activeRoom = _room;
    if (activeRoom == null) {
      return const <String>{};
    }

    return LivekitRuntimeProjection.rawParticipantUserIds(
      _deafenedParticipantUserIdsFromRoom(activeRoom),
    );
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
    final activeRoom = _room;
    if (activeRoom == null) {
      return const <String, Object>{};
    }

    return _participantVideoTracksFromRoom(activeRoom);
  }

  @override
  Stream<Map<String, Object>> participantVideoTracks() {
    return _participantVideoTracksController.stream;
  }

  Future<void> _disconnectCurrentRoom() async {
    final activeListener = _roomListener;
    _roomListener = null;
    if (activeListener != null) {
      await activeListener.dispose();
    }

    final activeRoom = _room;
    _room = null;

    if (activeRoom == null) {
      return;
    }

    await activeRoom.disconnect();
  }

  void _emitRoomSnapshot(Room room) {
    final participantUserIds = _participantUserIdsFromRoom(room);
    final didParticipantSetChange =
        !_setEquals(participantUserIds, _lastParticipantUserIds);

    if (_synchronizeParticipantAudioChannels(participantUserIds) ||
        didParticipantSetChange) {
      unawaited(_applyRemoteAudioSubscriptions());
    }

    _emitParticipantUserIds(participantUserIds);
    _emitMutedParticipantUserIds(_mutedParticipantUserIdsFromRoom(room));
    _emitDeafenedParticipantUserIds(_deafenedParticipantUserIdsFromRoom(room));
    _emitParticipantVideoTracks(_participantVideoTracksFromRoom(room));
  }

  bool _synchronizeParticipantAudioChannels(
    Set<ParticipantUserId> participantUserIds,
  ) {
    final previousChannels = Map<ParticipantUserId, RuntimeAudioChannel>.from(
      _participantAudioChannelByUserId,
    );

    final synchronizedChannels =
        LivekitRuntimeProjection.synchronizedAudioChannels(
      existingChannels: previousChannels,
      participantUserIds: participantUserIds,
    );

    if (_runtimeAudioChannelMapEquals(previousChannels, synchronizedChannels)) {
      return false;
    }

    _participantAudioChannelByUserId
      ..clear()
      ..addAll(synchronizedChannels);
    return true;
  }

  Set<ParticipantUserId> _participantUserIdsFromRoom(Room room) {
    return LivekitRuntimeProjection.participantUserIds(
      localIdentity:
          ParticipantIdentity.fromRaw(room.localParticipant?.identity),
      remoteIdentities: room.remoteParticipants.values
          .map((participant) =>
              ParticipantIdentity.fromRaw(participant.identity))
          .whereType<ParticipantIdentity>(),
    );
  }

  Future<void> _setRemoteAudioSubscriptionsEnabled({
    required bool enabled,
  }) async {
    final activeRoom = _room;
    if (activeRoom == null) {
      return;
    }

    for (final remoteParticipant in activeRoom.remoteParticipants.values) {
      for (final publication in remoteParticipant.audioTrackPublications) {
        final participantIdentity =
            ParticipantIdentity.fromRaw(remoteParticipant.identity);
        if (participantIdentity == null) {
          continue;
        }

        final participantChannel =
            _participantAudioChannelByUserId[participantIdentity.toUserId()] ??
                RuntimeAudioChannel.voice;
        final channelEnabled = isAudioChannelEnabled(participantChannel);
        final shouldBeEnabled = enabled && channelEnabled;

        if (shouldBeEnabled) {
          await publication.subscribe();
          continue;
        }

        await publication.unsubscribe();
      }
    }
  }

  Future<void> _applyRemoteAudioSubscriptions() async {
    await _setRemoteAudioSubscriptionsEnabled(enabled: !_isSelfDeafened);
  }

  void _emitParticipantUserIds(Set<ParticipantUserId> participantUserIds) {
    if (_setEquals(participantUserIds, _lastParticipantUserIds)) {
      return;
    }

    _lastParticipantUserIds = Set<ParticipantUserId>.from(participantUserIds);
    _participantUserIdsController.add(
      LivekitRuntimeProjection.rawParticipantUserIds(participantUserIds),
    );
  }

  void _emitSpeakingParticipantUserIds(Iterable<Participant> speakers) {
    final speakingUserIds = speakers
        .map((participant) => ParticipantIdentity.fromRaw(participant.identity))
        .whereType<ParticipantIdentity>()
        .map((participantIdentity) => participantIdentity.toUserId())
        .toSet();

    _emitSpeakingParticipantUserIdsFromSet(speakingUserIds);
  }

  void _emitSpeakingParticipantUserIdsFromSet(
    Set<ParticipantUserId> speakingUserIds,
  ) {
    final previousSpeakingUserIds = _lastSpeakingParticipantUserIds;
    if (_setEquals(speakingUserIds, _lastSpeakingParticipantUserIds)) {
      return;
    }

    _emitParticipantStatusUpdatesFromSetDiff(
      previousValues: previousSpeakingUserIds,
      currentValues: speakingUserIds,
      updateForValue: (participantUserId, isEnabled) =>
          ParticipantSpeakingStatusUpdated(
        participantUserId: participantUserId.rawValue,
        isSpeaking: isEnabled,
      ),
    );

    _lastSpeakingParticipantUserIds =
        Set<ParticipantUserId>.from(speakingUserIds);
  }

  void _emitMutedParticipantUserIds(
      Set<ParticipantUserId> mutedParticipantUserIds) {
    final previousMutedParticipantUserIds = _lastMutedParticipantUserIds;
    if (_setEquals(mutedParticipantUserIds, _lastMutedParticipantUserIds)) {
      return;
    }

    _emitParticipantStatusUpdatesFromSetDiff(
      previousValues: previousMutedParticipantUserIds,
      currentValues: mutedParticipantUserIds,
      updateForValue: (participantUserId, isEnabled) =>
          ParticipantMutedStatusUpdated(
        participantUserId: participantUserId.rawValue,
        isMuted: isEnabled,
      ),
    );

    _lastMutedParticipantUserIds =
        Set<ParticipantUserId>.from(mutedParticipantUserIds);
  }

  void _emitDeafenedParticipantUserIds(
    Set<ParticipantUserId> deafenedParticipantUserIds,
  ) {
    final previousDeafenedParticipantUserIds = _lastDeafenedParticipantUserIds;
    if (_setEquals(
      deafenedParticipantUserIds,
      _lastDeafenedParticipantUserIds,
    )) {
      return;
    }

    _emitParticipantStatusUpdatesFromSetDiff(
      previousValues: previousDeafenedParticipantUserIds,
      currentValues: deafenedParticipantUserIds,
      updateForValue: (participantUserId, isEnabled) =>
          ParticipantDeafenedStatusUpdated(
        participantUserId: participantUserId.rawValue,
        isDeafened: isEnabled,
      ),
    );

    _lastDeafenedParticipantUserIds =
        Set<ParticipantUserId>.from(deafenedParticipantUserIds);
  }

  void _emitParticipantVideoTracks(Map<String, Object> participantVideoTracks) {
    if (_mapEquals(participantVideoTracks, _lastParticipantVideoTracks)) {
      return;
    }

    _lastParticipantVideoTracks =
        Map<String, Object>.from(participantVideoTracks);
    _participantVideoTracksController.add(participantVideoTracks);
  }

  Set<ParticipantUserId> _mutedParticipantUserIdsFromRoom(Room room) {
    final localAudioPublications =
        room.localParticipant?.audioTrackPublications;
    final localAudioState = ParticipantAudioState.fromMutedFlag(
      _isSelfMuted ||
          (localAudioPublications?.any((publication) => publication.muted) ??
              false),
    );

    final remoteParticipantAudioSnapshots = room.remoteParticipants.values
        .map(
          (remoteParticipant) => ParticipantAudioSnapshot(
            identity: ParticipantIdentity.fromRaw(remoteParticipant.identity),
            audioState: ParticipantAudioState.fromMutedFlag(
              remoteParticipant.audioTrackPublications
                  .any((publication) => publication.muted),
            ),
          ),
        )
        .toList(growable: false);

    return LivekitRuntimeProjection.mutedParticipantUserIds(
      localIdentity:
          ParticipantIdentity.fromRaw(room.localParticipant?.identity),
      localAudioState: localAudioState,
      remoteParticipantAudio: remoteParticipantAudioSnapshots,
    );
  }

  Set<ParticipantUserId> _deafenedParticipantUserIdsFromRoom(Room room) {
    final localDeafenState = _isSelfDeafened
        ? const DeafenedState()
        : _participantDeafenState(room.localParticipant);

    final remoteParticipantDeafenSnapshots = room.remoteParticipants.values
        .map(
          (remoteParticipant) => ParticipantDeafenSnapshot(
            identity: ParticipantIdentity.fromRaw(remoteParticipant.identity),
            deafenState: _participantDeafenState(remoteParticipant),
          ),
        )
        .toList(growable: false);

    return LivekitRuntimeProjection.deafenedParticipantUserIds(
      localIdentity:
          ParticipantIdentity.fromRaw(room.localParticipant?.identity),
      localDeafenState: localDeafenState,
      remoteParticipantDeafen: remoteParticipantDeafenSnapshots,
    );
  }

  ParticipantDeafenState _participantDeafenState(Participant? participant) {
    if (participant == null) {
      return const NotDeafenedState();
    }

    final deafenedAttribute = participant.attributes[_deafenedAttributeKey];
    return ParticipantDeafenState.fromAttribute(deafenedAttribute);
  }

  Map<String, Object> _participantVideoTracksFromRoom(Room room) {
    final tracksByUserId = <String, Object>{};

    final localParticipant = room.localParticipant;
    final localIdentity =
        ParticipantIdentity.fromRaw(localParticipant?.identity);
    final localTrack = _firstVideoTrackFromPublications(
      localParticipant?.trackPublications.values,
    );

    if (localIdentity != null && localTrack != null) {
      tracksByUserId[localIdentity.toUserId().rawValue] = localTrack;
    }

    for (final remoteParticipant in room.remoteParticipants.values) {
      final remoteIdentity =
          ParticipantIdentity.fromRaw(remoteParticipant.identity);
      if (remoteIdentity == null) {
        continue;
      }

      final remoteTrack = _firstVideoTrackFromPublications(
        remoteParticipant.trackPublications.values,
      );

      if (remoteTrack != null) {
        tracksByUserId[remoteIdentity.toUserId().rawValue] = remoteTrack;
      }
    }

    return tracksByUserId;
  }

  void _setLocalParticipantDeafenedAttribute({
    required LocalParticipant? localParticipant,
    required ParticipantDeafenState deafenState,
  }) {
    if (localParticipant == null) {
      return;
    }

    final deafenedAttributeValue = switch (deafenState) {
      DeafenedState() => "true",
      NotDeafenedState() => "false",
    };

    final attributes = Map<String, String>.from(localParticipant.attributes)
      ..[_deafenedAttributeKey] = deafenedAttributeValue;
    unawaited(localParticipant.setAttributes(attributes));
  }

  VideoTrack? _firstVideoTrackFromPublications(
    Iterable<TrackPublication>? publications,
  ) {
    if (publications == null) {
      return null;
    }

    for (final publication in publications) {
      if (publication.kind != TrackType.VIDEO) {
        continue;
      }

      final track = publication.track;
      if (track case final VideoTrack videoTrack) {
        return videoTrack;
      }
    }

    return null;
  }

  bool _setEquals<T>(Set<T> left, Set<T>? right) {
    if (right == null) {
      return false;
    }

    if (left.length != right.length) {
      return false;
    }

    for (final value in left) {
      if (!right.contains(value)) {
        return false;
      }
    }

    return true;
  }

  bool _mapEquals(Map<String, Object> left, Map<String, Object>? right) {
    if (right == null) {
      return false;
    }

    if (left.length != right.length) {
      return false;
    }

    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !identical(right[entry.key], entry.value)) {
        return false;
      }
    }

    return true;
  }

  bool _runtimeAudioChannelMapEquals(
    Map<ParticipantUserId, RuntimeAudioChannel> left,
    Map<ParticipantUserId, RuntimeAudioChannel> right,
  ) {
    if (left.length != right.length) {
      return false;
    }

    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }

  void _emitParticipantStatusUpdatesFromSetDiff({
    required Set<ParticipantUserId>? previousValues,
    required Set<ParticipantUserId> currentValues,
    required ParticipantStatusUpdate Function(
      ParticipantUserId participantUserId,
      bool isEnabled,
    ) updateForValue,
  }) {
    final previousSet = previousValues ?? const <ParticipantUserId>{};

    final changedParticipantUserIds = <ParticipantUserId>{
      ...previousSet,
      ...currentValues,
    };

    for (final participantUserId in changedParticipantUserIds) {
      final wasEnabled = previousSet.contains(participantUserId);
      final isEnabled = currentValues.contains(participantUserId);

      if (wasEnabled == isEnabled) {
        continue;
      }

      _participantStatusUpdatesController.add(
        updateForValue(participantUserId, isEnabled),
      );
    }
  }
}
