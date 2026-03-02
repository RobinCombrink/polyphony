import "dart:async";

import "package:livekit_client/livekit_client.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";

class LivekitMediaRuntimeService implements MediaRuntimeService {
  static const _deafenedAttributeKey = "polyphony_deafened";

  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  final _participantUserIdsController =
      StreamController<Set<String>>.broadcast();
  final _speakingParticipantUserIdsController =
      StreamController<Set<String>>.broadcast();
  final _mutedParticipantUserIdsController =
      StreamController<Set<String>>.broadcast();
  final _deafenedParticipantUserIdsController =
      StreamController<Set<String>>.broadcast();
  final _participantVideoTracksController =
      StreamController<Map<String, Object>>.broadcast();
  var _isSelfMuted = false;
  var _isSelfDeafened = false;
  var _isSelfScreenShareEnabled = false;
  final _participantAudioChannelByUserId = <String, RuntimeAudioChannel>{};
  final _audioChannelEnabled = <RuntimeAudioChannel, bool>{
    RuntimeAudioChannel.voice: true,
    RuntimeAudioChannel.livestream: true,
  };

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
        deafened: false,
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
      _roomListener = room.createListener()
        ..on<RoomEvent>((_) {
          _emitParticipantUserIds(room);
          _emitMutedParticipantUserIds(room);
          _emitDeafenedParticipantUserIds(room);
          _emitParticipantVideoTracks(room);
        })
        ..on<TrackMutedEvent>((_) {
          _emitMutedParticipantUserIds(room);
        })
        ..on<TrackUnmutedEvent>((_) {
          _emitMutedParticipantUserIds(room);
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
      _emitParticipantUserIds(room);
      _emitSpeakingParticipantUserIds(room.activeSpeakers);
      _emitMutedParticipantUserIds(room);
      _emitDeafenedParticipantUserIds(room);
      _emitParticipantVideoTracks(room);
      _room = room;
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
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
      _participantUserIdsController.add(const <String>{});
      _speakingParticipantUserIdsController.add(const <String>{});
      _mutedParticipantUserIdsController.add(const <String>{});
      _deafenedParticipantUserIdsController.add(const <String>{});
      _participantVideoTracksController.add(const <String, Object>{});
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
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
      _emitMutedParticipantUserIds(activeRoom);
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
        deafened: deafened,
      );
      _emitMutedParticipantUserIds(activeRoom);
      _emitDeafenedParticipantUserIds(activeRoom);
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
      _emitParticipantVideoTracks(activeRoom);
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
      final trimmedParticipantUserId = participantUserId.trim();
      if (trimmedParticipantUserId.isEmpty) {
        return Error<void>(Exception("Participant user id cannot be empty."));
      }

      _participantAudioChannelByUserId[trimmedParticipantUserId] = channel;
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
    return _participantAudioChannelByUserId[participantUserId] ??
        RuntimeAudioChannel.voice;
  }

  @override
  Iterable<String> currentParticipantUserIds() {
    final activeRoom = _room;
    if (activeRoom == null) {
      return const <String>[];
    }

    return _participantUserIdsFromRoom(activeRoom);
  }

  @override
  Set<String> currentMutedParticipantUserIds() {
    final activeRoom = _room;
    if (activeRoom == null) {
      return const <String>{};
    }

    return _mutedParticipantUserIdsFromRoom(activeRoom);
  }

  @override
  Set<String> currentDeafenedParticipantUserIds() {
    final activeRoom = _room;
    if (activeRoom == null) {
      return const <String>{};
    }

    return _deafenedParticipantUserIdsFromRoom(activeRoom);
  }

  @override
  Stream<Set<String>> participantUserIds() {
    return _participantUserIdsController.stream;
  }

  Set<String> _participantUserIdsFromRoom(Room room) {
    final localIdentity = _normalizedParticipantUserId(
      room.localParticipant?.identity,
    );
    final remoteIdentities = room.remoteParticipants.values.map(
        (participant) => _normalizedParticipantUserId(participant.identity));

    return <String>{
      if (localIdentity.isNotEmpty) localIdentity,
      ...remoteIdentities.where((identity) => identity.isNotEmpty),
    };
  }

  @override
  Stream<Set<String>> speakingParticipantUserIds() {
    return _speakingParticipantUserIdsController.stream;
  }

  @override
  Stream<Set<String>> mutedParticipantUserIds() {
    return _mutedParticipantUserIdsController.stream;
  }

  @override
  Stream<Set<String>> deafenedParticipantUserIds() {
    return _deafenedParticipantUserIdsController.stream;
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

  Future<void> _setRemoteAudioSubscriptionsEnabled({
    required bool enabled,
  }) async {
    final activeRoom = _room;
    if (activeRoom == null) {
      return;
    }

    for (final remoteParticipant in activeRoom.remoteParticipants.values) {
      for (final publication in remoteParticipant.audioTrackPublications) {
        final participantIdentity = _normalizedParticipantUserId(
          remoteParticipant.identity,
        );
        if (participantIdentity.isEmpty) {
          continue;
        }

        final participantChannel = participantAudioChannel(participantIdentity);
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

  void _emitSpeakingParticipantUserIds(Iterable<Participant> speakers) {
    final speakingUserIds = speakers
        .map(
            (participant) => _normalizedParticipantUserId(participant.identity))
        .where((identity) => identity.isNotEmpty)
        .toSet();

    _speakingParticipantUserIdsController.add(speakingUserIds);
  }

  void _emitParticipantUserIds(Room room) {
    final participantUserIds = _participantUserIdsFromRoom(room);

    for (final participantUserId in participantUserIds) {
      _participantAudioChannelByUserId.putIfAbsent(
        participantUserId,
        () => RuntimeAudioChannel.voice,
      );
    }

    _participantAudioChannelByUserId.keys
        .where((participantUserId) =>
            !participantUserIds.contains(participantUserId))
        .toList()
        .forEach(_participantAudioChannelByUserId.remove);

    _participantUserIdsController.add(participantUserIds);

    unawaited(_applyRemoteAudioSubscriptions());
  }

  void _emitMutedParticipantUserIds(Room room) {
    _mutedParticipantUserIdsController
        .add(_mutedParticipantUserIdsFromRoom(room));
  }

  void _emitDeafenedParticipantUserIds(Room room) {
    _deafenedParticipantUserIdsController
        .add(_deafenedParticipantUserIdsFromRoom(room));
  }

  Future<void> _applyRemoteAudioSubscriptions() async {
    await _setRemoteAudioSubscriptionsEnabled(enabled: !_isSelfDeafened);
  }

  Map<String, Object> _participantVideoTracksFromRoom(Room room) {
    final tracksByUserId = <String, Object>{};

    final localParticipant = room.localParticipant;
    final localIdentity = _normalizedParticipantUserId(
      localParticipant?.identity,
    );
    final localTrack = _firstVideoTrackFromPublications(
      localParticipant?.trackPublications.values,
    );

    if (localIdentity.isNotEmpty && localTrack != null) {
      tracksByUserId[localIdentity] = localTrack;
    }

    for (final remoteParticipant in room.remoteParticipants.values) {
      final remoteIdentity = _normalizedParticipantUserId(
        remoteParticipant.identity,
      );
      if (remoteIdentity.isEmpty) {
        continue;
      }

      final remoteTrack = _firstVideoTrackFromPublications(
        remoteParticipant.trackPublications.values,
      );

      if (remoteTrack != null) {
        tracksByUserId[remoteIdentity] = remoteTrack;
      }
    }

    return tracksByUserId;
  }

  Set<String> _mutedParticipantUserIdsFromRoom(Room room) {
    final mutedParticipantUserIds = <String>{};

    final localIdentity = _normalizedParticipantUserId(
      room.localParticipant?.identity,
    );
    final localAudioPublications =
        room.localParticipant?.audioTrackPublications;
    final isLocalMutedByTrack =
        localAudioPublications?.any((publication) => publication.muted) ??
            false;

    if (localIdentity.isNotEmpty && (_isSelfMuted || isLocalMutedByTrack)) {
      mutedParticipantUserIds.add(localIdentity);
    }

    for (final remoteParticipant in room.remoteParticipants.values) {
      final remoteIdentity = _normalizedParticipantUserId(
        remoteParticipant.identity,
      );

      if (remoteIdentity.isEmpty) {
        continue;
      }

      final isRemoteMuted = remoteParticipant.audioTrackPublications
          .any((publication) => publication.muted);

      if (isRemoteMuted) {
        mutedParticipantUserIds.add(remoteIdentity);
      }
    }

    return mutedParticipantUserIds;
  }

  Set<String> _deafenedParticipantUserIdsFromRoom(Room room) {
    final deafenedParticipantUserIds = <String>{};

    final localIdentity = _normalizedParticipantUserId(
      room.localParticipant?.identity,
    );
    final localDeafenedFromAttributes =
        _isParticipantMarkedAsDeafened(room.localParticipant);
    if (localIdentity.isNotEmpty &&
        (_isSelfDeafened || localDeafenedFromAttributes)) {
      deafenedParticipantUserIds.add(localIdentity);
    }

    for (final remoteParticipant in room.remoteParticipants.values) {
      final remoteIdentity = _normalizedParticipantUserId(
        remoteParticipant.identity,
      );
      if (remoteIdentity.isEmpty) {
        continue;
      }

      if (_isParticipantMarkedAsDeafened(remoteParticipant)) {
        deafenedParticipantUserIds.add(remoteIdentity);
      }
    }

    return deafenedParticipantUserIds;
  }

  bool _isParticipantMarkedAsDeafened(Participant? participant) {
    if (participant == null) {
      return false;
    }

    final deafenedAttribute = participant.attributes[_deafenedAttributeKey];
    return deafenedAttribute?.toLowerCase() == "true";
  }

  void _setLocalParticipantDeafenedAttribute({
    required LocalParticipant? localParticipant,
    required bool deafened,
  }) {
    if (localParticipant == null) {
      return;
    }

    final attributes = Map<String, String>.from(localParticipant.attributes)
      ..[_deafenedAttributeKey] = deafened ? "true" : "false";
    localParticipant.setAttributes(attributes);
  }

  String _normalizedParticipantUserId(String? identity) {
    final trimmedIdentity = identity?.trim() ?? "";
    if (trimmedIdentity.isEmpty) {
      return "";
    }

    final separatorIndex = trimmedIdentity.indexOf(":");
    if (separatorIndex <= 0) {
      return trimmedIdentity;
    }

    return trimmedIdentity.substring(0, separatorIndex);
  }

  void _emitParticipantVideoTracks(Room room) {
    _participantVideoTracksController
        .add(_participantVideoTracksFromRoom(room));
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
}
