import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/something_went_wrong_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/text_channels_section_widget.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:skeletonizer/skeletonizer.dart";

class TextChannelsPaneWidget extends StatelessWidget {
  const TextChannelsPaneWidget({
    required this.createController,
    super.key,
  });

  final TextEditingController createController;

  List<Channel> _skeletonChannels() {
    return List<Channel>.generate(
      6,
      (index) => Channel(
        id: "txt-skeleton-$index",
        serverId: "srv-skeleton",
        name: "channel-${index + 1}",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

        return Skeletonizer(
          enabled: isLoading,
          child: TextChannelsSectionWidget(
            channels: visibleChannels,
            selectedChannelId: loadedData?.selectedTextChannelId,
            voiceParticipantCount: 0,
            isLoading: isLoading,
            createController: createController,
            onTap: (textChannel) {
              context.read<ChannelsBloc>().add(
                    SelectTextChannelRequested(
                      channelId: textChannel.id,
                    ),
                  );
              context.read<MessagesBloc>().add(
                    LoadMessagesRequested(channelId: textChannel.id),
                  );
            },
            onCreate: () => context.read<ChannelsBloc>().add(
                  CreateChannelRequested(
                    serverId: loadedData?.serverId ?? "",
                    channelName: createController.text,
                  ),
                ),
          ),
        );
      },
    );
  }
}
