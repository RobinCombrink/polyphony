import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/section_status.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

SectionStatus? buildMessagesSectionStatus(MessagesState state) {
  if (state is MessagesValidationFailedState) {
    return switch (state.issue) {
      MessagesValidationIssue.channelSelectionRequired => const SectionStatus(
          message: "Select a channel first.",
          isError: true,
        ),
      MessagesValidationIssue.messageContentRequired => const SectionStatus(
          message: "Message content is required.",
          isError: true,
        ),
      MessagesValidationIssue.updatedContentRequired => const SectionStatus(
          message: "Updated content is required.",
          isError: true,
        ),
    };
  }

  if (state is MessagesExceptionState) {
    return SectionStatus(
      message: "Message operation failed: ${state.error}",
      isError: true,
    );
  }

  return null;
}

class MessagesSectionWidget extends StatelessWidget {
  const MessagesSectionWidget({
    required this.messages,
    required this.currentUser,
    required this.authorDisplayNamesByUserId,
    required this.createController,
    required this.isLoading,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    this.channelName,
    super.key,
  });

  final List<Message> messages;
  final UserProfile currentUser;
  final Map<String, String?> authorDisplayNamesByUserId;
  final String? channelName;
  final TextEditingController createController;
  final bool isLoading;
  final VoidCallback onCreate;
  final Future<void> Function(Message message) onEdit;
  final void Function(Message message) onDelete;

  String _authorLabel(String authorUserId, bool isOwnMessage) {
    final resolvedDisplayName =
        authorDisplayNamesByUserId[authorUserId]?.trim();
    final currentUserDisplayName = currentUser.displayName?.trim();

    if (isOwnMessage) {
      return currentUserDisplayName?.isNotEmpty == true
          ? currentUserDisplayName!
          : (resolvedDisplayName?.isNotEmpty == true
              ? resolvedDisplayName!
              : "You");
    }

    return resolvedDisplayName?.isNotEmpty == true
        ? resolvedDisplayName!
        : "Member";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(12),
            child:
                Text("Messages", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (channelName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "# ${channelName!}",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: createController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onCreate(),
                    decoration:
                        const InputDecoration(labelText: "Send message"),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isLoading ? null : onCreate,
                  child: const Text("Send"),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isOwnMessage = message.authorUserId == currentUser.userId;

                return Align(
                  alignment: isOwnMessage
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: isOwnMessage
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _authorLabel(message.authorUserId, isOwnMessage),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 4),
                            SelectableText(message.content),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  onPressed:
                                      isLoading ? null : () => onEdit(message),
                                  icon: const Icon(Icons.edit),
                                  tooltip: "Edit message",
                                ),
                                IconButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => onDelete(message),
                                  icon: const Icon(Icons.delete),
                                  tooltip: "Delete message",
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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
