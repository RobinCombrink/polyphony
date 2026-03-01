import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/something_went_wrong_widget.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
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
            final isLoading = voiceState is VoiceSessionsInitialState ||
                voiceState is VoiceSessionsLoadingState;
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
            final visibleParticipants = isLoading && participants.isEmpty
                ? _skeletonParticipants()
                : participants;

            return Skeletonizer(
              enabled: isLoading,
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
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox.shrink(),
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
