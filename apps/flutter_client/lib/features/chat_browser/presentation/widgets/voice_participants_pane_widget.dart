import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
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
    required this.participantVideoTracks,
  });

  final List<VoiceParticipant> participants;
  final String? selfParticipantUserId;
  final bool isSelfDeafened;
  final Map<String, Object> participantVideoTracks;

  @override
  State<_VoiceFocusedStreamWidget> createState() =>
      _VoiceFocusedStreamWidgetState();
}

class _VoiceFocusedStreamWidgetState extends State<_VoiceFocusedStreamWidget> {
  String? _focusedParticipantUserId;

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
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: streamItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = streamItems[index];
              final isFocused =
                  item.participantUserId == focusedStream.participantUserId;

              return SizedBox(
                width: 220,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _focusedParticipantUserId = item.participantUserId;
                    });
                  },
                  icon: Icon(
                    isFocused ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                  label: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.statusText,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
