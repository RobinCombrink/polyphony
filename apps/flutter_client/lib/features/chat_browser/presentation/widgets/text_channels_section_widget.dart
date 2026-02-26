import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/list_section_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/section_status.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

SectionStatus? buildTextChannelsSectionStatus(ChannelsState state) {
  if (state is ChannelsValidationFailedState) {
    return switch (state.issue) {
      ChannelsValidationIssue.serverSelectionRequired => const SectionStatus(
          message: "Select a server first.",
          isError: true,
        ),
      ChannelsValidationIssue.channelNameRequired => const SectionStatus(
          message: "Channel name is required.",
          isError: true,
        ),
    };
  }

  if (state is ChannelsExceptionState) {
    return SectionStatus(
      message: "Channel operation failed: ${state.error}",
      isError: true,
    );
  }

  return null;
}

class TextChannelsSectionWidget extends StatelessWidget {
  const TextChannelsSectionWidget({
    required this.channels,
    required this.selectedChannelId,
    required this.voiceParticipantCount,
    required this.isLoading,
    required this.createController,
    required this.onTap,
    required this.onCreate,
    super.key,
  });

  final List<Channel> channels;
  final String? selectedChannelId;
  final int voiceParticipantCount;
  final bool isLoading;
  final TextEditingController createController;
  final void Function(Channel channel) onTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListSectionWidget<Channel>(
      title: "Text channels",
      items: channels,
      isSelected: (channel) => selectedChannelId == channel.id,
      label: (channel) => channel.name,
      subtitle: (channel) {
        final isSelectedChannel = selectedChannelId == channel.id;
        if (!isSelectedChannel || voiceParticipantCount == 0) {
          return null;
        }

        return "In voice";
      },
      trailing: (channel) {
        final isSelectedChannel = selectedChannelId == channel.id;
        if (!isSelectedChannel || voiceParticipantCount == 0) {
          return null;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.mic, size: 18),
            const SizedBox(width: 4),
            Text(voiceParticipantCount.toString()),
          ],
        );
      },
      onTap: onTap,
      isLoading: isLoading,
      createController: createController,
      createLabel: "Create text channel",
      createActionLabel: "Add",
      onCreate: onCreate,
    );
  }
}
