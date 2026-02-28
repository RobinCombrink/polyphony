import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/something_went_wrong_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/voice_channels_section_widget.dart";
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

            final selectedVoiceChannel = channelData?.channels.firstWhere(
              (channel) => channel.id == channelData.selectedVoiceChannelId,
              orElse: () => const Channel(id: "", serverId: "", name: ""),
            );

            if (selectedVoiceChannel == null ||
                selectedVoiceChannel.id.isEmpty) {
              return const Card(
                child: Center(
                  child: Text("Select a voice channel to see participants"),
                ),
              );
            }

            final participants =
                loadedData?.participants ?? const <VoiceParticipant>[];
            final isSelfMuted = loadedData?.isSelfMuted ?? false;
            final isConnected = loadedData?.connectedChannelId != null;
            final visibleParticipants = isLoading && participants.isEmpty
                ? _skeletonParticipants()
                : participants;

            return Skeletonizer(
              enabled: isLoading,
              child: VoiceChannelsSectionWidget(
                channelName: selectedVoiceChannel.name,
                participants: visibleParticipants,
                isLoading: isLoading,
                isConnected: isConnected,
                isSelfMuted: isSelfMuted,
                onToggleSelfMute: () => context.read<VoiceSessionsBloc>().add(
                      SetSelfMutedRequested(muted: !isSelfMuted),
                    ),
                onLeave: () => context.read<VoiceSessionsBloc>().add(
                      DisconnectVoiceSessionRequested(
                        channelId: selectedVoiceChannel.id,
                      ),
                    ),
              ),
            );
          },
        );
      },
    );
  }
}
