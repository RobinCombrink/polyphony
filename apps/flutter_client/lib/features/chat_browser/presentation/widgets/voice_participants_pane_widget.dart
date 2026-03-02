import "dart:async";
import "dart:convert";

import "package:collection/collection.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:desktop_multi_window/desktop_multi_window.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/something_went_wrong_widget.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:livekit_client/livekit_client.dart";
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
        isSpeaking: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChannelsBloc, ChannelsState>(
      builder: (context, channelsState) {
        final channelData =
            channelsState is ChannelsLoadedDataState ? channelsState : null;

        return BlocBuilder<VoiceSessionsBloc, VoiceSessionsState>(
          builder: (context, voiceState) {
            final isInitialLoading = voiceState is VoiceSessionsInitialState;
            final loadedData =
                voiceState is VoiceSessionsLoadedDataState ? voiceState : null;
            final errorMessage = voiceState is VoiceSessionsExceptionState
                ? voiceState.error.toString()
                : null;

            if (errorMessage != null) {
              return SomethingWentWrongWidget(message: errorMessage);
            }

            final selectedVoiceChannel =
                channelData?.voiceChannels.firstWhereOrNull(
              (channel) => channel.id == channelData.selectedVoiceChannelId,
            );

            if (selectedVoiceChannel == null) {
              return const Card(
                child: Center(
                  child: Text("Select a voice channel to see participants"),
                ),
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
  final _popoutWindowIdByParticipantUserId =
      <String, String>{};

  @override
  void initState() {
    super.initState();

    if (_isDesktopRuntime()) {
      _windowsChangedSubscription = onWindowsChanged.listen((_) {
        unawaited(_handleWindowsChanged());
      });
    }
  }

  @override
  void dispose() {
    unawaited(_windowsChangedSubscription?.cancel());
    super.dispose();
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
          child: _VoiceVideoTileWidget(
            displayName: focusedStream.displayName,
            videoTrack: focusedStream.videoTrack,
            isFocused: true,
          ),
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
                      ? (item.isSelfParticipant
                          ? null
                          : () => unawaited(_openPopoutWindow(item)))
                      : null,
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
    if (streamItem.isSelfParticipant) {
      return;
    }

    final activeConnection = widget.activeConnection;
    if (activeConnection == null) {
      return;
    }

    final payload = jsonEncode(<String, String>{
      "type": "voice_stream_popout",
      "livekitUrl": activeConnection.livekitUrl,
      "accessToken": activeConnection.accessToken,
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
    await windowController.show();
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

    final voiceSessionsBloc = context.read<VoiceSessionsBloc>();
    voiceSessionsBloc.add(
      DisconnectVoiceSessionRequested(channelId: channelId),
    );
    voiceSessionsBloc.add(
      ConnectVoiceSessionRequested(channelId: channelId),
    );
  }

  List<_VoiceStreamItemData> _streamItems() {
    final participantByUserId = <String, VoiceParticipant>{
      for (final participant in widget.participants)
        participant.userId: participant,
    };
    final selfUserId = widget.selfParticipantUserId;

    return widget.participantVideoTracks.entries
        .map((entry) {
          final participantUserId = entry.key;

          if (entry.value case final VideoTrack videoTrack) {
            final participant = participantByUserId[participantUserId];
            final isSelfParticipant =
                selfUserId != null && participantUserId == selfUserId;
            final displayName = participant?.displayName ??
                (isSelfParticipant ? "You" : "Member");
            final isMuted = participant?.isMuted ?? false;
            final isSpeaking = participant?.isSpeaking ?? false;
            final statusText = _statusText(
              isMuted: isMuted,
              isSpeaking: isSpeaking,
              isSelfParticipant: isSelfParticipant,
              isSelfDeafened: widget.isSelfDeafened,
            );

            return _VoiceStreamItemData(
              participantUserId: participantUserId,
              displayName: displayName,
              isSelfParticipant: isSelfParticipant,
              statusText: statusText,
              videoTrack: videoTrack,
            );
          }

          return null;
        })
        .whereType<_VoiceStreamItemData>()
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
    required bool isSpeaking,
    required bool isSelfParticipant,
    required bool isSelfDeafened,
  }) {
    if (isSelfParticipant && isSelfDeafened) {
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
    required this.videoTrack,
  });

  final String participantUserId;
  final String displayName;
  final bool isSelfParticipant;
  final String statusText;
  final VideoTrack videoTrack;
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
  });

  final _VoiceStreamItemData streamItem;
  final bool isFocused;
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
                  child: _VoiceVideoTileWidget(
                    displayName: streamItem.displayName,
                    videoTrack: streamItem.videoTrack,
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
                  tooltip: "Pop out",
                  onPressed: onPopout,
                  icon: const Icon(
                    Icons.open_in_new,
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
