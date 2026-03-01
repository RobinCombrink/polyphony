import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/something_went_wrong_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/text_channels_section_widget.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/channel_type.dart";
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
      (index) => TextChannel(
        id: "txt-skeleton-$index",
        serverId: "srv-skeleton",
        name: "channel-${index + 1}",
      ),
    );
  }

  Future<void> _showDeleteChannelConfirmationDialog(
    BuildContext context,
    Channel channel,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete channel"),
          content: Text(
            "Are you sure you want to delete ${channel.name}?",
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (!context.mounted || shouldDelete != true) {
      return;
    }

    context.read<ChannelsBloc>().add(
          DeleteChannelRequested(channelId: channel.id),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChannelsBloc, ChannelsState>(
      listenWhen: (previous, current) {
        final previousSelectedTextChannelId = switch (previous) {
          ChannelsLoadedDataState(:final selectedTextChannelId) =>
            selectedTextChannelId,
          _ => null,
        };
        final currentSelectedTextChannelId = switch (current) {
          ChannelsLoadedDataState(:final selectedTextChannelId) =>
            selectedTextChannelId,
          _ => null,
        };

        return previousSelectedTextChannelId != currentSelectedTextChannelId;
      },
      listener: (context, state) {
        final selectedTextChannelId = switch (state) {
          ChannelsLoadedDataState(:final selectedTextChannelId) =>
            selectedTextChannelId,
          _ => null,
        };

        if (selectedTextChannelId == null) {
          context.read<MessagesBloc>().add(const ResetMessagesRequested());
          return;
        }

        context.read<MessagesBloc>().add(
              LoadMessagesRequested(channelId: selectedTextChannelId),
            );
      },
      child: BlocBuilder<ChannelsBloc, ChannelsState>(
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

          final channels = loadedData?.textChannels ?? const <Channel>[];
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
              },
              onCreate: () => context.read<ChannelsBloc>().add(
                    CreateChannelRequested(
                      serverId: loadedData?.serverId ?? "",
                      channelName: createController.text,
                      channelType: ChannelType.text,
                    ),
                  ),
              onDeleteChannel: (channel) => unawaited(
                _showDeleteChannelConfirmationDialog(context, channel),
              ),
            ),
          );
        },
      ),
    );
  }
}
