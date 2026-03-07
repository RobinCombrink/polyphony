import "dart:async";

import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/channels/presentation/widgets/channel_widget.dart";
import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/section_status.dart";

enum _PaneMenuAction { createChannel }

enum _ChannelMenuAction { notificationPreferences, deleteChannel }

SectionStatus? buildChannelPaneStatus(ChannelsState state) {
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

class ChannelPaneWidget extends StatefulWidget {
  const ChannelPaneWidget({
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
    this.onNotificationPreferences,
    required this.onCreateChannel,
    this.title = "Channels",
    this.createActionLabel = "Create channel",
    this.showCreateControls = true,
    this.bottomSection,
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
  final void Function(Channel channel)? onNotificationPreferences;
  final void Function({
    required String channelName,
    required ChannelType channelType,
  }) onCreateChannel;
  final String title;
  final String createActionLabel;
  final bool showCreateControls;
  final Widget? bottomSection;

  @override
  State<ChannelPaneWidget> createState() => _ChannelPaneWidgetState();
}

class _ChannelPaneWidgetState extends State<ChannelPaneWidget> {
  Future<void> _showCreateChannelDialog(BuildContext context) async {
    if (widget.isLoading) {
      return;
    }

    widget.createController.clear();
    var selectedChannelType = ChannelType.text;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canCreateChannel =
                widget.createController.text.trim().isNotEmpty;

            return AlertDialog(
              title: const Text("Create channel"),
              content: RadioGroup<ChannelType>(
                groupValue: selectedChannelType,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setDialogState(() {
                    selectedChannelType = value;
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const RadioListTile<ChannelType>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: ChannelType.text,
                      title: Row(
                        children: <Widget>[
                          Icon(Icons.tag, size: 18),
                          SizedBox(width: 8),
                          Text("Text channel"),
                        ],
                      ),
                    ),
                    const RadioListTile<ChannelType>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: ChannelType.voice,
                      title: Row(
                        children: <Widget>[
                          Icon(Icons.volume_up, size: 18),
                          SizedBox(width: 8),
                          Text("Voice channel"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: widget.createController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setDialogState(() {}),
                      onSubmitted: (_) {
                        if (!canCreateChannel) {
                          return;
                        }

                        Navigator.of(dialogContext).pop(true);
                      },
                      decoration: const InputDecoration(
                        labelText: "Channel name",
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: canCreateChannel
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text("Create"),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || shouldCreate != true) {
      widget.createController.clear();
      return;
    }

    final channelName = widget.createController.text;
    widget.onCreateChannel(
      channelName: channelName,
      channelType: selectedChannelType,
    );
    widget.createController.clear();
  }

  Future<void> _showPaneContextMenu({
    required BuildContext context,
    required Offset globalPosition,
  }) async {
    if (widget.isLoading) {
      return;
    }

    final selectedAction = await showMenu<_PaneMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: <PopupMenuEntry<_PaneMenuAction>>[
        const PopupMenuItem<_PaneMenuAction>(
          value: _PaneMenuAction.createChannel,
          child: Text("Create channel"),
        ),
      ],
    );

    if (!context.mounted || selectedAction != _PaneMenuAction.createChannel) {
      return;
    }

    await _showCreateChannelDialog(context);
  }

  Future<void> _showChannelContextMenu({
    required BuildContext context,
    required Channel channel,
    required Offset globalPosition,
  }) async {
    final onDeleteChannel = widget.onDeleteChannel;
    final onNotificationPreferences = widget.onNotificationPreferences;
    if (onDeleteChannel == null && onNotificationPreferences == null) {
      return;
    }

    final errorColor = Theme.of(context).colorScheme.error;
    final selectedAction = await showMenu<_ChannelMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: <PopupMenuEntry<_ChannelMenuAction>>[
        if (onNotificationPreferences != null)
          const PopupMenuItem<_ChannelMenuAction>(
            value: _ChannelMenuAction.notificationPreferences,
            child: Text("Notification preferences"),
          ),
        PopupMenuItem<_ChannelMenuAction>(
          value: _ChannelMenuAction.deleteChannel,
          child: Text(
            "Delete channel",
            style: TextStyle(color: errorColor),
          ),
        ),
      ],
    );

    if (!mounted || selectedAction == null) {
      return;
    }

    switch (selectedAction) {
      case _ChannelMenuAction.notificationPreferences:
        onNotificationPreferences?.call(channel);
      case _ChannelMenuAction.deleteChannel:
        onDeleteChannel?.call(channel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: widget.isLoading
          ? null
          : (details) => unawaited(
                _showPaneContextMenu(
                  context: context,
                  globalPosition: details.globalPosition,
                ),
              ),
      onLongPress: widget.isLoading
          ? null
          : () {
              final renderBox = context.findRenderObject() as RenderBox?;
              final globalPosition = renderBox == null
                  ? Offset.zero
                  : renderBox.localToGlobal(
                      renderBox.size.center(Offset.zero),
                    );

              unawaited(
                _showPaneContextMenu(
                  context: context,
                  globalPosition: globalPosition,
                ),
              );
            },
      child: Card(
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
                child: InkWell(
                  onTap: widget.isLoading
                      ? null
                      : () => unawaited(_showCreateChannelDialog(context)),
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
                  final isConnectedVoiceChannel = switch (channel) {
                    VoiceChannel() =>
                      widget.connectedVoiceChannelId == channel.id,
                    TextChannel() => false,
                  };
                  final showParticipantCount =
                      isSelected && widget.voiceParticipantCount > 0;
                  final voiceParticipants =
                      widget.voiceParticipantsByChannelId[channel.id] ??
                          const <VoiceParticipant>[];

                  return GestureDetector(
                    onSecondaryTapDown: widget.isLoading ||
                            (widget.onDeleteChannel == null &&
                                widget.onNotificationPreferences == null)
                        ? null
                        : (details) => unawaited(
                              _showChannelContextMenu(
                                context: context,
                                channel: channel,
                                globalPosition: details.globalPosition,
                              ),
                            ),
                    onLongPress: widget.isLoading ||
                            (widget.onDeleteChannel == null &&
                                widget.onNotificationPreferences == null)
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
                    child: ChannelWidget.fromChannel(
                      channel: channel,
                      isSelected: isSelected,
                      showParticipantCount: showParticipantCount,
                      voiceParticipantCount: widget.voiceParticipantCount,
                      isConnectedVoiceChannel: isConnectedVoiceChannel,
                      voiceParticipants: voiceParticipants,
                      selfParticipantUserId: widget.selfParticipantUserId,
                      isSelfDeafened: widget.isSelfDeafened,
                      onTap:
                          widget.isLoading ? null : () => widget.onTap(channel),
                    ),
                  );
                },
              ),
            ),
            if (widget.bottomSection != null) ...<Widget>[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: widget.bottomSection,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
