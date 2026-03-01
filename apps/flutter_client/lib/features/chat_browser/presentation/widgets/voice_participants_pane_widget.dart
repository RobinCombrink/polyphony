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
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _VoiceVideoGridWidget(
                        participants: visibleParticipants,
                        selfParticipantUserId: selfParticipantUserId,
                        participantVideoTracks: participantVideoTracks,
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: <Widget>[
                          if (visibleParticipants.isEmpty)
                            const ListTile(
                              leading: Icon(Icons.mic_off),
                              title: Text("No participants"),
                            )
                          else
                            ...visibleParticipants.map(
                              (participant) {
                                final isSelfParticipant =
                                    participant.userId == selfParticipantUserId;
                                final showDeafenedIcon =
                                    isSelfParticipant && isSelfDeafened;

                                return ListTile(
                                  leading: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: participant.isSpeaking
                                          ? Border.all(
                                              color: Colors.green,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: const Icon(Icons.account_circle),
                                  ),
                                  title: Text(participant.displayName),
                                  trailing:
                                      participant.isMuted || showDeafenedIcon
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                if (participant.isMuted)
                                                  const Icon(Icons.mic_off),
                                                if (showDeafenedIcon)
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      left: 6,
                                                    ),
                                                    child: Icon(
                                                      Icons.headset_off,
                                                    ),
                                                  ),
                                              ],
                                            )
                                          : null,
                                );
                              },
                            ),
                        ],
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

class _VoiceVideoGridWidget extends StatelessWidget {
  const _VoiceVideoGridWidget({
    required this.participants,
    required this.selfParticipantUserId,
    required this.participantVideoTracks,
  });

  final List<VoiceParticipant> participants;
  final String? selfParticipantUserId;
  final Map<String, Object> participantVideoTracks;

  @override
  Widget build(BuildContext context) {
    final displayNameByUserId = <String, String>{
      for (final participant in participants)
        participant.userId: participant.displayName,
    };
    final selfUserId = selfParticipantUserId;

    final videoTiles = participantVideoTracks.entries
        .map((entry) {
          final participantUserId = entry.key;

          if (entry.value case final VideoTrack videoTrack) {
            final isSelfParticipant =
                selfUserId != null && participantUserId == selfUserId;

            final displayName = displayNameByUserId[participantUserId] ??
                (isSelfParticipant ? "You" : "Member");

            return _VoiceVideoTileData(
              displayName: displayName,
              isSelfParticipant: isSelfParticipant,
              videoTrack: videoTrack,
            );
          }

          return null;
        })
        .whereType<_VoiceVideoTileData>()
        .toList()
        .sorted((left, right) {
          if (left.isSelfParticipant != right.isSelfParticipant) {
            return left.isSelfParticipant ? -1 : 1;
          }

          return left.displayName.compareTo(right.displayName);
        });

    if (videoTiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 180,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 16 / 9,
        ),
        itemCount: videoTiles.length,
        itemBuilder: (context, index) {
          final tileData = videoTiles[index];

          return _VoiceVideoTileWidget(
            displayName: tileData.displayName,
            videoTrack: tileData.videoTrack,
          );
        },
      ),
    );
  }
}

class _VoiceVideoTileData {
  const _VoiceVideoTileData({
    required this.displayName,
    required this.isSelfParticipant,
    required this.videoTrack,
  });

  final String displayName;
  final bool isSelfParticipant;
  final VideoTrack videoTrack;
}

class _VoiceVideoTileWidget extends StatelessWidget {
  const _VoiceVideoTileWidget({
    required this.displayName,
    required this.videoTrack,
  });

  final String displayName;
  final VideoTrack videoTrack;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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
