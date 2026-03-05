import "dart:async";
import "dart:convert";
import "dart:ui";

import "package:collection/collection.dart";
import "package:desktop_multi_window/desktop_multi_window.dart";
import "package:flutter/material.dart";
import "package:livekit_client/livekit_client.dart";
import "package:polyphony_flutter_client/features/voice_sessions/presentation/widgets/voice_stream_popout_channel.dart";
import "package:polyphony_flutter_client/shared/presentation/theme/polyphony_theme.dart";

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
      theme: PolyphonyTheme.light(),
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
  WindowController? _currentWindowController;
  late final AppLifecycleListener _appLifecycleListener;
  final _windowChannel = const WindowMethodChannel(
    voiceStreamPopoutWindowChannelName,
    mode: ChannelMode.unidirectional,
  );

  VideoTrack? _videoTrack;
  var _displayName = "Stream";
  var _targetParticipantUserId = "";
  var _isLoading = true;
  Exception? _error;

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      onExitRequested: _onExitRequested,
    );
    unawaited(_registerWindowMethodHandler());
    unawaited(_connect());
  }

  @override
  void dispose() {
    final currentWindowController = _currentWindowController;
    if (currentWindowController != null) {
      unawaited(currentWindowController.setWindowMethodHandler(null));
    }

    _appLifecycleListener.dispose();
    unawaited(_disconnect());
    super.dispose();
  }

  Future<AppExitResponse> _onExitRequested() async {
    await _popInAndHideWindow();
    return AppExitResponse.cancel;
  }

  Future<void> _popInAndHideWindow() async {
    await _disconnect();
    await _notifyPopInRequested();

    try {
      final currentWindow = _currentWindowController ??
          await WindowController.fromCurrentEngine();
      await currentWindow.hide();
    } on Exception {
      return;
    }
  }

  Future<void> _registerWindowMethodHandler() async {
    try {
      final currentWindowController =
          await WindowController.fromCurrentEngine();
      _currentWindowController = currentWindowController;

      await currentWindowController.setWindowMethodHandler((call) async {
        if (call.method != voiceStreamPopInRequestMethod) {
          return null;
        }

        await _disconnect();

        try {
          await currentWindowController.hide();
        } on Exception {
          return null;
        }

        return null;
      });
    } on Exception {
      return;
    }
  }

  Future<void> _notifyPopInRequested() async {
    if (_targetParticipantUserId.isEmpty) {
      return;
    }

    try {
      await _windowChannel.invokeMethod<void>(
        voiceStreamPopInMethod,
        <String, String>{
          participantUserIdArgumentKey: _targetParticipantUserId,
        },
      );
    } on Exception {
      return;
    }
  }

  List<Widget> _buildAppBarActions() {
    return <Widget>[
      IconButton(
        tooltip: "Pop in",
        onPressed: () => unawaited(_popInAndHideWindow()),
        icon: const Icon(Icons.call_received),
      ),
    ];
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

      if (!mounted) {
        return;
      }

      setState(() {
        _room = room;
        _displayName = displayName.isEmpty ? "Stream" : displayName;
        _targetParticipantUserId = participantUserId;
        _isLoading = false;
      });

      _updateVideoTrack();
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
    if (room == null || _targetParticipantUserId.isEmpty) {
      return;
    }

    VideoTrack? resolvedTrack;

    final localParticipant = room.localParticipant;
    if (localParticipant?.identity == _targetParticipantUserId) {
      resolvedTrack = _firstVideoTrackFromPublications(
        localParticipant?.trackPublications.values,
      );
    }

    final remoteParticipant = room.remoteParticipants.values.firstWhereOrNull(
      (participant) => participant.identity == _targetParticipantUserId,
    );

    if (remoteParticipant != null) {
      _ensureRemoteVideoSubscribed(remoteParticipant);
    }

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

  void _ensureRemoteVideoSubscribed(RemoteParticipant remoteParticipant) {
    for (final publication in remoteParticipant.videoTrackPublications) {
      if (publication.subscribed) {
        continue;
      }

      unawaited(publication.subscribe());
    }
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
          actions: _buildAppBarActions(),
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
          title: Text(_displayName),
          actions: _buildAppBarActions(),
        ),
        body: const Center(
          child: Text("Waiting for stream"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_displayName),
        actions: _buildAppBarActions(),
      ),
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
                    _displayName,
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
