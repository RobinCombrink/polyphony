import "dart:async";
import "dart:convert";

import "package:collection/collection.dart";
import "package:desktop_multi_window/desktop_multi_window.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:livekit_client/livekit_client.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/voice_sessions/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/voice_sessions/presentation/widgets/voice_stream_popout_channel.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/something_went_wrong_widget.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:skeletonizer/skeletonizer.dart";

class VoiceParticipantsPaneWidget extends StatelessWidget {
  const VoiceParticipantsPaneWidget({super.key});

  List<VoiceParticipant> _skeletonParticipants() {
    return List<VoiceParticipant>.generate(
      6,
      (index) => VoiceParticipant(
        userId: "participant-skeleton-$index",
        displayName: "Participant ${index + 1}",
        isMuted: false,
        isDeafened: false,
        isSpeaking: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChannelsBloc, ChannelsState>(
      builder: (context, channelsState) {
        final selectedVoiceChannel = switch (channelsState) {
          VoiceChannelSelected(:final selectedVoiceChannel) =>
            selectedVoiceChannel,
          VoiceChannelSelectedValidationFailedState(
            :final selectedVoiceChannel,
          ) =>
            selectedVoiceChannel,
          _ => null,
        };

        return BlocBuilder<VoiceSessionsBloc, VoiceSessionsState>(
          builder: (context, voiceState) {
            final isInitialLoading = voiceState is VoiceSessionsInitialState;
            final loadedData =
                voiceState is VoiceSessionsLoadedDataState ? voiceState : null;
            final lifecycleIssue =
                loadedData is VoiceSessionsLifecycleIssueState
                    ? loadedData.issue
                    : null;
            final errorMessage = voiceState is VoiceSessionsExceptionState
                ? voiceState.error.toString()
                : null;

            if (errorMessage != null) {
              return SomethingWentWrongWidget(message: errorMessage);
            }

            if (selectedVoiceChannel == null) {
              return const Card(
                child: Center(
                  child: Text("Select a voice channel to see participants"),
                ),
              );
            }

            if (lifecycleIssue != null) {
              return _VoiceLifecycleIssueCard(
                issue: lifecycleIssue,
                channelId: selectedVoiceChannel.id,
              );
            }

            final participants =
                loadedData?.participants ?? const <VoiceParticipant>[];
            final selfParticipantUserId =
                loadedData?.activeConnection?.participantUserId;
            final isSelfDeafened = loadedData?.isSelfDeafened ?? false;
            final participantVideoTracks =
                loadedData?.participantVideoTracks ?? const <String, Object>{};
            final visibleParticipants = isInitialLoading && participants.isEmpty
                ? _skeletonParticipants()
                : participants;

            return Skeletonizer(
              enabled: isInitialLoading,
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        "Voice participants · ${selectedVoiceChannel.name}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _VoiceFocusedStreamWidget(
                          participants: visibleParticipants,
                          selfParticipantUserId: selfParticipantUserId,
                          isSelfDeafened: isSelfDeafened,
                          activeConnection: loadedData?.activeConnection,
                          participantVideoTracks: participantVideoTracks,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _VoiceLifecycleIssueCard extends StatelessWidget {
  const _VoiceLifecycleIssueCard({
    required this.issue,
    required this.channelId,
  });

  final VoiceSessionsLifecycleIssue issue;
  final String channelId;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (issue) {
      VoiceSessionsLifecycleIssue.reconnectRequired => (
          "Voice connection lost",
          "Reconnect to rejoin this voice channel.",
        ),
      VoiceSessionsLifecycleIssue.tokenExpired => (
          "Session expired",
          "Sign in again to continue voice participation.",
        ),
      VoiceSessionsLifecycleIssue.channelForbidden => (
          "Channel unavailable",
          "You no longer have access to this voice channel.",
        ),
    };

    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
              ),
              if (issue ==
                  VoiceSessionsLifecycleIssue.reconnectRequired) ...<Widget>[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => context.read<VoiceSessionsBloc>().add(
                        ConnectVoiceSessionRequested(channelId: channelId),
                      ),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Reconnect"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceFocusedStreamWidget extends StatefulWidget {
  const _VoiceFocusedStreamWidget({
    required this.participants,
    required this.selfParticipantUserId,
    required this.isSelfDeafened,
    required this.activeConnection,
    required this.participantVideoTracks,
  });

  final List<VoiceParticipant> participants;
  final String? selfParticipantUserId;
  final bool isSelfDeafened;
  final VoiceConnectSession? activeConnection;
  final Map<String, Object> participantVideoTracks;

  @override
  State<_VoiceFocusedStreamWidget> createState() =>
      _VoiceFocusedStreamWidgetState();
}

class _VoiceFocusedStreamWidgetState extends State<_VoiceFocusedStreamWidget> {
  String? _focusedParticipantUserId;
  StreamSubscription<void>? _windowsChangedSubscription;
  final _windowChannel = const WindowMethodChannel(
    voiceStreamPopoutWindowChannelName,
    mode: ChannelMode.unidirectional,
  );
  final _popoutWindowIdByParticipantUserId = <String, String>{};
  final _poppedOutParticipantUserIds = <String>{};

  @override
  void initState() {
    super.initState();

    if (_isDesktopRuntime()) {
      unawaited(_registerWindowMethodHandler());
      _windowsChangedSubscription = onWindowsChanged.listen((_) {
        unawaited(_handleWindowsChanged());
      });
    }
  }

  @override
  void dispose() {
    unawaited(_windowChannel.setMethodCallHandler(null));
    unawaited(_windowsChangedSubscription?.cancel());
    super.dispose();
  }

  Future<void> _registerWindowMethodHandler() {
    return _windowChannel.setMethodCallHandler((call) async {
      if (call.method != voiceStreamPopInMethod) {
        return null;
      }

      final arguments = call.arguments;
      if (arguments is! Map) {
        return null;
      }

      final participantUserId =
          (arguments[participantUserIdArgumentKey] as String? ?? "").trim();
      if (participantUserId.isEmpty || !mounted) {
        return null;
      }

      setState(() {
        _poppedOutParticipantUserIds.remove(participantUserId);
      });

      return null;
    });
  }

  @override
  void didUpdateWidget(covariant _VoiceFocusedStreamWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final streamItems = _streamItems();
    final focusedExists = streamItems.any(
      (item) => item.participantUserId == _focusedParticipantUserId,
    );

    if (!focusedExists) {
      _focusedParticipantUserId = streamItems.firstOrNull?.participantUserId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final streamItems = _streamItems();

    if (_focusedParticipantUserId == null && streamItems.isNotEmpty) {
      _focusedParticipantUserId = streamItems.first.participantUserId;
    }

    final focusedStream = streamItems.firstWhereOrNull(
      (item) => item.participantUserId == _focusedParticipantUserId,
    );

    if (focusedStream == null) {
      return const Center(
        child: Text("No shared streams"),
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: focusedStream.isPoppedOut
              ? _PoppedOutStreamPlaceholderWidget(
                  displayName: focusedStream.displayName,
                  onPopIn: () => unawaited(
                      _popInParticipant(focusedStream.participantUserId)),
                )
              : (focusedStream.videoTrack == null
                  ? _NoVideoPlaceholderWidget(
                      displayName: focusedStream.displayName,
                    )
                  : _VoiceVideoTileWidget(
                      displayName: focusedStream.displayName,
                      videoTrack: focusedStream.videoTrack!,
                      isFocused: true,
                    )),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: streamItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = streamItems[index];
              final isFocused =
                  item.participantUserId == focusedStream.participantUserId;

              return SizedBox(
                width: 240,
                child: _VoiceStreamPreviewSelectorItem(
                  streamItem: item,
                  isFocused: isFocused,
                  onFocus: () {
                    setState(() {
                      _focusedParticipantUserId = item.participantUserId;
                    });
                  },
                  onPopout: _isDesktopRuntime()
                      ? (item.isSelfParticipant || item.videoTrack == null
                          ? null
                          : (item.isPoppedOut
                              ? () => unawaited(
                                  _popInParticipant(item.participantUserId))
                              : () => unawaited(_openPopoutWindow(item))))
                      : null,
                  isPoppedOut: item.isPoppedOut,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isDesktopRuntime() {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
  }

  Future<void> _openPopoutWindow(_VoiceStreamItemData streamItem) async {
    if (streamItem.isSelfParticipant || streamItem.videoTrack == null) {
      return;
    }

    final activeConnection = widget.activeConnection;
    if (activeConnection == null) {
      return;
    }

    final participantInstanceId =
        "popout-${streamItem.participantUserId}-${DateTime.now().microsecondsSinceEpoch}";
    final popoutSessionResult =
        await context.read<VoiceSessionRepo>().createOne(
              command: ConnectVoiceSessionCommand(
                channelId: activeConnection.channelId,
                participantInstanceId: participantInstanceId,
              ),
            );

    if (popoutSessionResult case Error<VoiceConnectSession>()) {
      return;
    }

    final popoutSession =
        (popoutSessionResult as Ok<VoiceConnectSession>).value;

    final existingWindowId =
        _popoutWindowIdByParticipantUserId[streamItem.participantUserId];
    if (existingWindowId != null && existingWindowId.isNotEmpty) {
      final existingWindow = WindowController.fromWindowId(existingWindowId);
      await existingWindow.show();
      if (!mounted) {
        return;
      }

      setState(() {
        _poppedOutParticipantUserIds.add(streamItem.participantUserId);
      });
      return;
    }

    final payload = jsonEncode(<String, String>{
      "type": "voice_stream_popout",
      "livekitUrl": popoutSession.livekitUrl,
      "accessToken": popoutSession.accessToken,
      "participantUserId": streamItem.participantUserId,
      "displayName": streamItem.displayName,
    });

    final windowController = await WindowController.create(
      WindowConfiguration(
        arguments: payload,
      ),
    );
    _popoutWindowIdByParticipantUserId[streamItem.participantUserId] =
        windowController.windowId;
    if (!mounted) {
      return;
    }

    setState(() {
      _poppedOutParticipantUserIds.add(streamItem.participantUserId);
    });
    await windowController.show();
  }

  Future<void> _popInParticipant(String participantUserId) async {
    final windowId = _popoutWindowIdByParticipantUserId[participantUserId];

    if (!mounted) {
      return;
    }

    setState(() {
      _poppedOutParticipantUserIds.remove(participantUserId);
      _popoutWindowIdByParticipantUserId.remove(participantUserId);
    });

    if (windowId == null || windowId.isEmpty) {
      return;
    }

    final windowController = WindowController.fromWindowId(windowId);
    try {
      await windowController.invokeMethod<void>(voiceStreamPopInRequestMethod);
    } on Exception {
      await windowController.hide();
    }
  }

  Future<void> _handleWindowsChanged() async {
    if (_popoutWindowIdByParticipantUserId.isEmpty) {
      return;
    }

    final activeWindows = await WindowController.getAll();
    final activeWindowIds =
        activeWindows.map((controller) => controller.windowId).toSet();

    final closedParticipantUserIds = _popoutWindowIdByParticipantUserId.entries
        .where((entry) => !activeWindowIds.contains(entry.value))
        .map((entry) => entry.key)
        .toList(growable: false);

    if (closedParticipantUserIds.isEmpty) {
      return;
    }

    for (final participantUserId in closedParticipantUserIds) {
      _popoutWindowIdByParticipantUserId.remove(participantUserId);
      _poppedOutParticipantUserIds.remove(participantUserId);
    }

    final selfParticipantUserId = widget.selfParticipantUserId;
    if (selfParticipantUserId == null ||
        !closedParticipantUserIds.contains(selfParticipantUserId) ||
        !mounted) {
      return;
    }

    final activeConnection = widget.activeConnection;
    final channelId = activeConnection?.channelId;
    if (channelId == null || channelId.isEmpty) {
      return;
    }

    context.read<VoiceSessionsBloc>()
      ..add(
        DisconnectVoiceSessionRequested(channelId: channelId),
      )
      ..add(
        ConnectVoiceSessionRequested(channelId: channelId),
      );
  }

  List<_VoiceStreamItemData> _streamItems() {
    final participantByUserId = <String, VoiceParticipant>{
      for (final participant in widget.participants)
        participant.userId: participant,
    };
    final selfUserId = widget.selfParticipantUserId;

    final participantUserIds = <String>{
      ...participantByUserId.keys,
      ...widget.participantVideoTracks.keys,
    };

    return participantUserIds
        .map((participantUserId) {
          final participant = participantByUserId[participantUserId];
          final isSelfParticipant =
              selfUserId != null && participantUserId == selfUserId;
          final displayName = participant?.displayName ??
              (isSelfParticipant ? "You" : "Member");
          final isMuted = participant?.isMuted ?? false;
          final isDeafened = participant?.isDeafened ?? false;
          final isSpeaking = participant?.isSpeaking ?? false;
          final statusText = _statusText(
            isMuted: isMuted,
            isDeafened: isDeafened,
            isSpeaking: isSpeaking,
            isSelfParticipant: isSelfParticipant,
          );
          final rawVideoTrack =
              widget.participantVideoTracks[participantUserId];
          final videoTrack = rawVideoTrack is VideoTrack ? rawVideoTrack : null;

          return _VoiceStreamItemData(
            participantUserId: participantUserId,
            displayName: displayName,
            isSelfParticipant: isSelfParticipant,
            statusText: statusText,
            isSpeaking: isSpeaking,
            videoTrack: videoTrack,
            isPoppedOut:
                _poppedOutParticipantUserIds.contains(participantUserId),
          );
        })
        .toList()
        .sorted((left, right) {
          if (left.isSelfParticipant != right.isSelfParticipant) {
            return left.isSelfParticipant ? -1 : 1;
          }

          return left.displayName.compareTo(right.displayName);
        });
  }

  String _statusText({
    required bool isMuted,
    required bool isDeafened,
    required bool isSpeaking,
    required bool isSelfParticipant,
  }) {
    final showDeafened = isSelfParticipant ? widget.isSelfDeafened : isDeafened;

    if (showDeafened) {
      return "Deafened";
    }

    if (isMuted) {
      return "Muted";
    }

    if (isSpeaking) {
      return "Speaking";
    }

    return "Listening";
  }
}

class _VoiceStreamItemData {
  const _VoiceStreamItemData({
    required this.participantUserId,
    required this.displayName,
    required this.isSelfParticipant,
    required this.statusText,
    required this.isSpeaking,
    required this.videoTrack,
    required this.isPoppedOut,
  });

  final String participantUserId;
  final String displayName;
  final bool isSelfParticipant;
  final String statusText;
  final bool isSpeaking;
  final VideoTrack? videoTrack;
  final bool isPoppedOut;
}

class _NoVideoPlaceholderWidget extends StatelessWidget {
  const _NoVideoPlaceholderWidget({
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(displayName),
            const SizedBox(height: 8),
            const Text("No video"),
          ],
        ),
      ),
    );
  }
}

class _PoppedOutStreamPlaceholderWidget extends StatelessWidget {
  const _PoppedOutStreamPlaceholderWidget({
    required this.displayName,
    required this.onPopIn,
  });

  final String displayName;
  final VoidCallback onPopIn;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text("$displayName popped out"),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onPopIn,
              icon: const Icon(Icons.call_received),
              label: const Text("Pop in"),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceVideoTileWidget extends StatelessWidget {
  const _VoiceVideoTileWidget({
    required this.displayName,
    required this.videoTrack,
    this.isFocused = false,
  });

  final String displayName;
  final VideoTrack videoTrack;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isFocused ? 12 : 8),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          VideoTrackRenderer(videoTrack),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(displayName),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceStreamPreviewSelectorItem extends StatelessWidget {
  const _VoiceStreamPreviewSelectorItem({
    required this.streamItem,
    required this.isFocused,
    required this.onFocus,
    required this.onPopout,
    required this.isPoppedOut,
  });

  final _VoiceStreamItemData streamItem;
  final bool isFocused;
  final bool isPoppedOut;
  final VoidCallback onFocus;
  final VoidCallback? onPopout;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isFocused
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          width: isFocused ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onFocus,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 92,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: streamItem.isSpeaking
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: streamItem.isSpeaking
                          ? <BoxShadow>[
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : const <BoxShadow>[],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(1),
                      child: isPoppedOut
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.open_in_new_off, size: 18),
                              ),
                            )
                          : (streamItem.videoTrack == null
                              ? DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.videocam_off, size: 18),
                                  ),
                                )
                              : _VoiceVideoTileWidget(
                                  displayName: streamItem.displayName,
                                  videoTrack: streamItem.videoTrack!,
                                )),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      streamItem.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      streamItem.statusText,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFocused ? "Focused" : "Fullscreen",
                onPressed: onFocus,
                icon: Icon(
                  isFocused ? Icons.fullscreen_exit : Icons.fullscreen,
                  size: 18,
                ),
              ),
              if (onPopout != null)
                IconButton(
                  tooltip: isPoppedOut ? "Pop in" : "Pop out",
                  onPressed: onPopout,
                  icon: Icon(
                    isPoppedOut ? Icons.call_received : Icons.open_in_new,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
