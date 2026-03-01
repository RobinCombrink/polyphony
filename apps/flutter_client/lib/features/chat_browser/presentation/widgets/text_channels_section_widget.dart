import "dart:async";

import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/section_status.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

enum ChannelInteractionType {
  text,
  voice,
}

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
      ChannelsValidationIssue.channelSelectionRequired => const SectionStatus(
          message: "Select a channel first.",
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

class TextChannelsSectionWidget extends StatefulWidget {
  const TextChannelsSectionWidget({
    required this.channels,
    required this.selectedChannelId,
    required this.voiceParticipantCount,
    this.voiceParticipantsByChannelId =
        const <String, List<VoiceParticipant>>{},
    this.connectedVoiceChannelId,
    this.selfParticipantUserId,
    this.isSelfDeafened = false,
    required this.isLoading,
    required this.createController,
    required this.onTap,
    this.onDeleteChannel,
    required this.onCreate,
    this.title = "Text channels",
    this.createLabel = "Create channel",
    this.createActionLabel = "Create channel",
    this.showCreateControls = true,
    this.interactionType = ChannelInteractionType.text,
    super.key,
  });

  final List<Channel> channels;
  final String? selectedChannelId;
  final int voiceParticipantCount;
  final Map<String, List<VoiceParticipant>> voiceParticipantsByChannelId;
  final String? connectedVoiceChannelId;
  final String? selfParticipantUserId;
  final bool isSelfDeafened;
  final bool isLoading;
  final TextEditingController createController;
  final void Function(Channel channel) onTap;
  final void Function(Channel channel)? onDeleteChannel;
  final VoidCallback onCreate;
  final String title;
  final String createLabel;
  final String createActionLabel;
  final bool showCreateControls;
  final ChannelInteractionType interactionType;

  @override
  State<TextChannelsSectionWidget> createState() =>
      _TextChannelsSectionWidgetState();
}

class _TextChannelsSectionWidgetState extends State<TextChannelsSectionWidget> {
  var _isCreatingChannel = false;

  Future<void> _showChannelContextMenu({
    required BuildContext context,
    required Channel channel,
    required Offset globalPosition,
  }) async {
    final onDeleteChannel = widget.onDeleteChannel;
    if (onDeleteChannel == null) {
      return;
    }

    final errorColor = Theme.of(context).colorScheme.error;
    await showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: <PopupMenuEntry<void>>[
        PopupMenuItem<void>(
          onTap: () => Future<void>.delayed(
            Duration.zero,
            () => onDeleteChannel(channel),
          ),
          child: Text(
            "Delete channel",
            style: TextStyle(color: errorColor),
          ),
        ),
      ],
    );
  }

  void _openCreateChannelInput() {
    setState(() {
      _isCreatingChannel = true;
    });
  }

  void _cancelCreateChannelInput() {
    widget.createController.clear();

    setState(() {
      _isCreatingChannel = false;
    });
  }

  void _submitCreateChannelInput() {
    widget.onCreate();
    widget.createController.clear();

    setState(() {
      _isCreatingChannel = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          if (widget.showCreateControls)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: _isCreatingChannel
                  ? TextField(
                      controller: widget.createController,
                      autofocus: true,
                      enabled: !widget.isLoading,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitCreateChannelInput(),
                      decoration: InputDecoration(
                        hintText: widget.createLabel,
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: "Cancel",
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: _cancelCreateChannelInput,
                        ),
                      ),
                    )
                  : InkWell(
                      onTap: widget.isLoading ? null : _openCreateChannelInput,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.add, size: 18),
                            const SizedBox(width: 8),
                            Text(widget.createActionLabel),
                          ],
                        ),
                      ),
                    ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.channels.length,
              itemBuilder: (context, index) {
                final channel = widget.channels[index];
                final isSelected = widget.selectedChannelId == channel.id;
                final isConnectedVoiceChannel =
                    widget.interactionType == ChannelInteractionType.voice &&
                        widget.connectedVoiceChannelId == channel.id;
                final showParticipantCount =
                    isSelected && widget.voiceParticipantCount > 0;
                final voiceParticipants =
                    widget.voiceParticipantsByChannelId[channel.id] ??
                        const <VoiceParticipant>[];

                return GestureDetector(
                  onSecondaryTapDown:
                      widget.isLoading || widget.onDeleteChannel == null
                          ? null
                          : (details) => unawaited(
                                _showChannelContextMenu(
                                  context: context,
                                  channel: channel,
                                  globalPosition: details.globalPosition,
                                ),
                              ),
                  child: ListTile(
                    dense: true,
                    selected: isSelected,
                    leading: Icon(
                      widget.interactionType == ChannelInteractionType.voice
                          ? Icons.volume_up
                          : Icons.tag,
                      size: 18,
                    ),
                    title: Text(channel.name),
                    subtitle: widget.interactionType ==
                                ChannelInteractionType.voice &&
                            voiceParticipants.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: voiceParticipants
                                  .map(
                                    (participant) {
                                      final isSelfParticipant =
                                          participant.userId ==
                                              widget.selfParticipantUserId;
                                      final showSelfDeafened =
                                          isSelfParticipant &&
                                              widget.isSelfDeafened;

                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          children: <Widget>[
                                            const Icon(
                                              Icons.account_circle,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                participant.displayName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (participant.isMuted)
                                              const Icon(
                                                Icons.mic_off,
                                                size: 14,
                                              ),
                                            if (showSelfDeafened)
                                              const Padding(
                                                padding:
                                                    EdgeInsets.only(left: 4),
                                                child: Icon(
                                                  Icons.headset_off,
                                                  size: 14,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  )
                                  .toList(),
                            ),
                          )
                        : null,
                    trailing: isConnectedVoiceChannel || showParticipantCount
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (isConnectedVoiceChannel)
                                const Icon(Icons.headset, size: 16),
                              if (isConnectedVoiceChannel &&
                                  showParticipantCount)
                                const SizedBox(width: 4),
                              if (showParticipantCount)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      widget.interactionType ==
                                              ChannelInteractionType.voice
                                          ? Icons.headset
                                          : Icons.mic,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(widget.voiceParticipantCount
                                        .toString()),
                                  ],
                                ),
                            ],
                          )
                        : null,
                    onTap:
                        widget.isLoading ? null : () => widget.onTap(channel),
                    onLongPress:
                        widget.isLoading || widget.onDeleteChannel == null
                            ? null
                            : () {
                                final renderBox =
                                    context.findRenderObject() as RenderBox?;
                                final globalPosition = renderBox == null
                                    ? Offset.zero
                                    : renderBox.localToGlobal(
                                        renderBox.size.center(Offset.zero),
                                      );

                                unawaited(
                                  _showChannelContextMenu(
                                    context: context,
                                    channel: channel,
                                    globalPosition: globalPosition,
                                  ),
                                );
                              },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
