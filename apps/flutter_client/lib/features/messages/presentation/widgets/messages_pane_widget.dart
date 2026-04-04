import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/pinned_messages_bloc.dart";
import "package:polyphony_flutter_client/features/messages/presentation/widgets/messages_section_widget.dart";
import "package:polyphony_flutter_client/features/messages/presentation/widgets/pinned_messages_dialog_widget.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_center_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/pane_placeholder_widget.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/something_went_wrong_widget.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_service.dart";
import "package:skeletonizer/skeletonizer.dart";

class MessagesPaneWidget extends StatefulWidget {
  const MessagesPaneWidget({
    required this.createController,
    super.key,
  });

  final TextEditingController createController;

  @override
  State<MessagesPaneWidget> createState() => _MessagesPaneWidgetState();
}

class _MessagesPaneWidgetState extends State<MessagesPaneWidget> {
  ServerId? _selectedServerId(BuildContext context) {
    final serversState = context.read<ServersBloc>().state;
    return switch (serversState) {
      ServerSelected(:final selectedServer) => selectedServer.id,
      _ => null,
    };
  }

  void _showPinnedMessagesDialog(BuildContext context) {
    final serverId = _selectedServerId(context);
    if (serverId == null) {
      return;
    }
    context.read<PinnedMessagesBloc>().add(
          LoadPinnedMessagesRequested(serverId: serverId),
        );
    unawaited(showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<PinnedMessagesBloc>(),
        child: AlertDialog(
          title: const Text("Pinned Messages"),
          content: const SizedBox(
            width: 400,
            height: 300,
            child: PinnedMessagesDialogWidget(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    ));
  }

  Future<void> _markMessageAsUnread(
    BuildContext context,
    ChannelId channelId,
    Message message,
  ) async {
    final notificationService = context.read<NotificationService>();
    final result = await notificationService.markMessageAsUnread(
      channelId: channelId.value,
      messageId: message.id.value,
    );

    if (!context.mounted) {
      return;
    }

    switch (result) {
      case Ok<void>():
        context
            .read<NotificationCenterBloc>()
            .add(const NotificationCenterUnreadCountRefreshRequested());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Marked as unread")),
        );
      case Error<void>(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to mark as unread: $error")),
        );
    }
  }

  List<Message> _skeletonMessages(ChannelId channelId) {
    return List<Message>.generate(
      5,
      (index) => Message(
        id: MessageId("msg-skeleton-$index"),
        channelId: channelId,
        authorUserId: const UserId("author-skeleton"),
        content: "Loading message $index",
      ),
    );
  }

  Future<void> _showEditMessageDialog(Message message) async {
    final controller = TextEditingController(text: message.content);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Edit message"),
          content: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            decoration: const InputDecoration(labelText: "Message content"),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    final selectedTextChannelId = switch (context.read<ChannelsBloc>().state) {
      TextChannelSelected(:final selectedTextChannel) => selectedTextChannel.id,
      TextChannelSelectedValidationFailedState(
        :final selectedTextChannel,
      ) =>
        selectedTextChannel.id,
      _ => null,
    };

    if (selectedTextChannelId == null) {
      return;
    }

    context.read<MessagesBloc>().add(
          UpdateMessageRequested(
            channelId: selectedTextChannelId,
            messageId: message.id,
            messageContent: result,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChannelsBloc, ChannelsState>(
      builder: (context, channelsState) {
        final selectedTextChannel = switch (channelsState) {
          TextChannelSelected(:final selectedTextChannel) =>
            selectedTextChannel,
          TextChannelSelectedValidationFailedState(
            :final selectedTextChannel,
          ) =>
            selectedTextChannel,
          _ => null,
        };

        if (selectedTextChannel == null) {
          return const PanePlaceholderWidget(
            icon: Icons.chat_bubble_outline,
            message: "Select a text channel to view and send messages.",
            subtitle: "Pick a channel from the middle pane.",
          );
        }

        return BlocBuilder<MessagesBloc, MessagesState>(
          builder: (context, messagesState) {
            final isLoading = messagesState is MessagesInitialState ||
                messagesState is MessagesLoadingState;
            final loadedData =
                messagesState is MessagesLoadedDataState ? messagesState : null;
            final errorMessage = messagesState is MessagesExceptionState
                ? messagesState.error.toString()
                : null;

            if (errorMessage != null) {
              return SomethingWentWrongWidget(message: errorMessage);
            }

            return BlocBuilder<ProfileBloc, ProfileState>(
              builder: (context, profileState) {
                if (profileState is! ProfileLoadedDataState) {
                  return const PanePlaceholderWidget(
                    icon: Icons.account_circle_outlined,
                    message: "Loading your profile...",
                  );
                }

                final currentUser = UserProfile(
                  userId: profileState.userId,
                  displayName: profileState.displayName,
                );

                final messages = loadedData?.messages ?? const <Message>[];
                final visibleMessages = isLoading && messages.isEmpty
                    ? _skeletonMessages(selectedTextChannel.id)
                    : messages;
                final mentionCandidates =
                    switch (context.watch<ServerMembersBloc>().state) {
                  ServerMembersLoadedDataState(:final members) => members
                      .where((member) => member.userId != profileState.userId)
                      .toList(),
                  _ => const <UserProfile>[],
                };

                return Skeletonizer(
                  enabled: isLoading,
                  child: MessagesSectionWidget(
                    messages: visibleMessages,
                    currentUser: currentUser,
                    authorDisplayNamesByUserId:
                        loadedData?.authorDisplayNamesByUserId ??
                            const <UserId, String?>{},
                    channelName: selectedTextChannel.name,
                    createController: widget.createController,
                    mentionCandidates: mentionCandidates,
                    isLoading: isLoading,
                    onCreate: (mentionedUserId) =>
                        context.read<MessagesBloc>().add(
                              CreateMessageRequested(
                                channelId: selectedTextChannel.id,
                                messageContent: widget.createController.text,
                                mentionedUserId: mentionedUserId,
                              ),
                            ),
                    onEdit: _showEditMessageDialog,
                    onDelete: (message) => context.read<MessagesBloc>().add(
                          DeleteMessageRequested(
                            channelId: selectedTextChannel.id,
                            messageId: message.id,
                          ),
                        ),
                    onPin: _selectedServerId(context) != null
                        ? (message) {
                            final serverId = _selectedServerId(context);
                            if (serverId != null) {
                              context.read<PinnedMessagesBloc>().add(
                                    PinMessageRequested(
                                      serverId: serverId,
                                      messageId: message.id,
                                    ),
                                  );
                            }
                          }
                        : null,
                    onViewPins: _selectedServerId(context) != null
                        ? () => _showPinnedMessagesDialog(context)
                        : null,
                    onMarkUnread: (message) => _markMessageAsUnread(
                      context,
                      selectedTextChannel.id,
                      message,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
