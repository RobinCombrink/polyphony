import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/messages/presentation/widgets/messages_section_widget.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/pane_placeholder_widget.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/something_went_wrong_widget.dart";
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
  List<Message> _skeletonMessages(String channelId) {
    return List<Message>.generate(
      5,
      (index) => Message(
        id: "msg-skeleton-$index",
        channelId: channelId,
        authorUserId: "author-skeleton",
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
      ChannelsLoadedDataState(:final selectedTextChannelId) =>
        selectedTextChannelId,
      _ => null,
    };

    context.read<MessagesBloc>().add(
          UpdateMessageRequested(
            channelId: selectedTextChannelId ?? "",
            messageId: message.id,
            messageContent: result,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChannelsBloc, ChannelsState>(
      builder: (context, channelsState) {
        final channelsData =
            channelsState is ChannelsLoadedDataState ? channelsState : null;
        final selectedTextChannel = channelsData?.textChannels.firstWhereOrNull(
          (channel) => channel.id == channelsData.selectedTextChannelId,
        );

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
                            const <String, String?>{},
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
