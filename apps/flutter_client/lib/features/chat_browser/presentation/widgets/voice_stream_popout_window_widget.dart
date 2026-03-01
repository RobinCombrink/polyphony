import "dart:async";
import "dart:convert";

import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:livekit_client/livekit_client.dart";

class VoiceStreamPopoutWindowApp extends StatelessWidget {
  const VoiceStreamPopoutWindowApp({
    super.key,
    required this.arguments,
  });

  final String arguments;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Stream Popout",
      debugShowCheckedModeBanner: false,
      home: _VoiceStreamPopoutWindowPage(
        arguments: arguments,
      ),
    );
  }
}

class _VoiceStreamPopoutWindowPage extends StatefulWidget {
  const _VoiceStreamPopoutWindowPage({
    required this.arguments,
  });

  final String arguments;

  @override
  State<_VoiceStreamPopoutWindowPage> createState() =>
      _VoiceStreamPopoutWindowPageState();
}

class _VoiceStreamPopoutWindowPageState
    extends State<_VoiceStreamPopoutWindowPage> {
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  VideoTrack? _videoTrack;
  String? _displayName;
  String? _targetParticipantUserId;
  Exception? _error;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  @override
  void dispose() {
    unawaited(_disconnect());
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      final argumentsMap = jsonDecode(widget.arguments) as Map<String, dynamic>;
      final livekitUrl = (argumentsMap["livekitUrl"] as String? ?? "").trim();
      final accessToken = (argumentsMap["accessToken"] as String? ?? "").trim();
      final participantUserId =
          (argumentsMap["participantUserId"] as String? ?? "").trim();
      final displayName = (argumentsMap["displayName"] as String? ?? "").trim();

      if (livekitUrl.isEmpty ||
          accessToken.isEmpty ||
          participantUserId.isEmpty) {
        throw Exception("Invalid stream popout arguments.");
      }

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      await room.prepareConnection(livekitUrl, accessToken);
      await room.connect(livekitUrl, accessToken);

      _roomListener = room.createListener()
        ..on<RoomEvent>((_) {
          _updateVideoTrack();
        });

      _room = room;
      _displayName = displayName.isEmpty ? "Stream" : displayName;
      _targetParticipantUserId = participantUserId;
      _updateVideoTrack();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnect() async {
    final listener = _roomListener;
    _roomListener = null;
    if (listener != null) {
      await listener.dispose();
    }

    final room = _room;
    _room = null;
    if (room != null) {
      await room.disconnect();
    }
  }

  void _updateVideoTrack() {
    final room = _room;
    final targetParticipantUserId = _targetParticipantUserId;

    if (room == null || targetParticipantUserId == null) {
      return;
    }

    VideoTrack? resolvedTrack;

    final localParticipant = room.localParticipant;
    if (localParticipant?.identity == targetParticipantUserId) {
      resolvedTrack = _firstVideoTrackFromPublications(
        localParticipant?.trackPublications.values,
      );
    }

    final remoteParticipant = room.remoteParticipants.values.firstWhereOrNull(
      (participant) => participant.identity == targetParticipantUserId,
    );

    resolvedTrack ??= _firstVideoTrackFromPublications(
      remoteParticipant?.trackPublications.values,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _videoTrack = resolvedTrack;
    });
  }

  VideoTrack? _firstVideoTrackFromPublications(
    Iterable<TrackPublication>? publications,
  ) {
    if (publications == null) {
      return null;
    }

    for (final publication in publications) {
      final track = publication.track;
      if (track case final VideoTrack videoTrack) {
        return videoTrack;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Stream Popout"),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final track = _videoTrack;
    if (track == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_displayName ?? "Stream"),
        ),
        body: const Center(
          child: Text("Waiting for stream"),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          VideoTrackRenderer(track),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    _displayName ?? "Stream",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
