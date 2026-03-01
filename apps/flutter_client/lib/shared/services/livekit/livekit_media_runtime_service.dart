import "dart:async";

import "package:livekit_client/livekit_client.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";

class LivekitMediaRuntimeService implements MediaRuntimeService {
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  final _participantUserIdsController =
      StreamController<Set<String>>.broadcast();
  final _speakingParticipantUserIdsController =
      StreamController<Set<String>>.broadcast();
  final _participantVideoTracksController =
      StreamController<Map<String, Object>>.broadcast();
  var _isSelfMuted = false;
  var _isSelfDeafened = false;
  var _isSelfVideoEnabled = false;
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
      await room.localParticipant?.setCameraEnabled(false);
      _isSelfMuted = false;
      _isSelfDeafened = false;
      _isSelfVideoEnabled = false;
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
          _emitParticipantVideoTracks(room);
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
      _isSelfVideoEnabled = false;
      _participantAudioChannelByUserId.clear();
      _audioChannelEnabled
        ..clear()
        ..addAll(<RuntimeAudioChannel, bool>{
          RuntimeAudioChannel.voice: true,
          RuntimeAudioChannel.livestream: true,
        });
      _participantUserIdsController.add(const <String>{});
      _speakingParticipantUserIdsController.add(const <String>{});
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
  Future<Result<void>> setSelfVideoEnabled({required bool enabled}) async {
    try {
      final activeRoom = _room;
      if (activeRoom == null) {
        return Error<void>(Exception("Not connected to a voice session."));
      }

      await activeRoom.localParticipant?.setCameraEnabled(enabled);
      _isSelfVideoEnabled = enabled;
      _emitParticipantVideoTracks(activeRoom);
      return const Ok<void>(null);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  @override
  bool isSelfVideoEnabled() {
    return _isSelfVideoEnabled;
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
  Stream<Set<String>> participantUserIds() {
    return _participantUserIdsController.stream;
  }

  Set<String> _participantUserIdsFromRoom(Room room) {
    final localIdentity = room.localParticipant?.identity;
    final remoteIdentities = room.remoteParticipants.values
        .map((participant) => participant.identity);

    return <String>{
      if (localIdentity != null && localIdentity.isNotEmpty) localIdentity,
      ...remoteIdentities.where((identity) => identity.isNotEmpty),
    };
  }

  @override
  Stream<Set<String>> speakingParticipantUserIds() {
    return _speakingParticipantUserIdsController.stream;
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
        final participantIdentity = remoteParticipant.identity;
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
        .map((participant) => participant.identity)
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

  Future<void> _applyRemoteAudioSubscriptions() async {
    await _setRemoteAudioSubscriptionsEnabled(enabled: !_isSelfDeafened);
  }

  Map<String, Object> _participantVideoTracksFromRoom(Room room) {
    final tracksByUserId = <String, Object>{};

    final localParticipant = room.localParticipant;
    final localIdentity = localParticipant?.identity;
    final localTrack = localParticipant?.videoTrackPublications
        .map((publication) => publication.track)
        .firstWhere(
          (track) => track != null,
          orElse: () => null,
        );

    if (localIdentity != null &&
        localIdentity.isNotEmpty &&
        localTrack != null) {
      tracksByUserId[localIdentity] = localTrack;
    }

    for (final remoteParticipant in room.remoteParticipants.values) {
      final remoteIdentity = remoteParticipant.identity;
      if (remoteIdentity.isEmpty) {
        continue;
      }

      final remoteTrack = remoteParticipant.videoTrackPublications
          .map((publication) => publication.track)
          .firstWhere(
            (track) => track != null,
            orElse: () => null,
          );

      if (remoteTrack != null) {
        tracksByUserId[remoteIdentity] = remoteTrack;
      }
    }

    return tracksByUserId;
  }

  void _emitParticipantVideoTracks(Room room) {
    _participantVideoTracksController
        .add(_participantVideoTracksFromRoom(room));
  }
}
