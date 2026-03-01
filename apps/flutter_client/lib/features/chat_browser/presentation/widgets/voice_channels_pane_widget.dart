import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/something_went_wrong_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/text_channels_section_widget.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:skeletonizer/skeletonizer.dart";

class VoiceChannelsPaneWidget extends StatefulWidget {
  const VoiceChannelsPaneWidget({
    required this.createController,
    super.key,
  });

  final TextEditingController createController;

  @override
  State<VoiceChannelsPaneWidget> createState() =>
      _VoiceChannelsPaneWidgetState();
}

class _VoiceChannelsPaneWidgetState extends State<VoiceChannelsPaneWidget> {
  String _lastVisibleChannelIdsKey = "";

  List<Channel> _skeletonChannels() {
    return List<Channel>.generate(
      4,
      (index) => Channel(
        id: "voc-skeleton-$index",
        serverId: "srv-skeleton",
        name: "voice-${index + 1}",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceSessionsBloc, VoiceSessionsState>(
      builder: (context, voiceSessionsState) {
        final activeVoiceChannelId = switch (voiceSessionsState) {
          VoiceSessionsLoadedDataState(:final connectedChannelId) =>
            connectedChannelId,
          _ => null,
        };
        final voiceParticipantsByChannelId = switch (voiceSessionsState) {
          VoiceSessionsLoadedDataState(:final participantsByChannelId) =>
            participantsByChannelId,
          _ => const <String, List<VoiceParticipant>>{},
        };
        final selfParticipantUserId = switch (voiceSessionsState) {
          VoiceSessionsLoadedDataState(:final activeConnection) =>
            activeConnection?.participantUserId,
          _ => null,
        };
        final isSelfDeafened = switch (voiceSessionsState) {
          VoiceSessionsLoadedDataState(:final isSelfDeafened) => isSelfDeafened,
          _ => false,
        };

        return BlocBuilder<ChannelsBloc, ChannelsState>(
          builder: (context, channelsState) {
            final isLoading = channelsState is ChannelsInitialState ||
                channelsState is ChannelsLoadingState;
            final loadedData =
                channelsState is ChannelsLoadedDataState ? channelsState : null;
            final errorMessage = channelsState is ChannelsExceptionState
                ? channelsState.error.toString()
                : null;

            if (errorMessage != null) {
              return SomethingWentWrongWidget(message: errorMessage);
            }

            final channels = loadedData?.channels ?? const <Channel>[];
            final visibleChannels =
                isLoading && channels.isEmpty ? _skeletonChannels() : channels;
            final visibleChannelIds = visibleChannels
                .map((channel) => channel.id)
                .where((channelId) => channelId.isNotEmpty)
                .toList();
            final visibleChannelIdsKey = visibleChannelIds.join("|");

            if (!isLoading &&
                _lastVisibleChannelIdsKey != visibleChannelIdsKey) {
              _lastVisibleChannelIdsKey = visibleChannelIdsKey;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }

                context.read<VoiceSessionsBloc>().add(
                      RefreshVoiceParticipantsRequested(
                        channelIds: visibleChannelIds,
                      ),
                    );
              });
            }

            return Skeletonizer(
              enabled: isLoading,
              child: TextChannelsSectionWidget(
                channels: visibleChannels,
                selectedChannelId: loadedData?.selectedVoiceChannelId,
                voiceParticipantCount: 0,
                voiceParticipantsByChannelId: voiceParticipantsByChannelId,
                connectedVoiceChannelId: activeVoiceChannelId,
                selfParticipantUserId: selfParticipantUserId,
                isSelfDeafened: isSelfDeafened,
                isLoading: isLoading,
                createController: widget.createController,
                title: "Voice channels",
                createLabel: "",
                createActionLabel: "",
                showCreateControls: false,
                interactionType: ChannelInteractionType.voice,
                onTap: (voiceChannel) {
                  context.read<ChannelsBloc>().add(
                        SelectVoiceChannelRequested(
                          channelId: voiceChannel.id,
                        ),
                      );
                  context.read<VoiceSessionsBloc>().add(
                        LoadVoiceSessionsRequested(channelId: voiceChannel.id),
                      );
                  context.read<VoiceSessionsBloc>().add(
                        ConnectVoiceSessionRequested(
                            channelId: voiceChannel.id),
                      );
                },
                onCreate: () {},
              ),
            );
          },
        );
      },
    );
  }
}
