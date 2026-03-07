import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/section_status.dart";

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
    required this.mentionCandidates,
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
  final List<UserProfile> mentionCandidates;
  final bool isLoading;
  final void Function(String? mentionedUserId) onCreate;
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
            child: _MessageComposerWidget(
              createController: createController,
              mentionCandidates: mentionCandidates,
              isLoading: isLoading,
              onCreate: onCreate,
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

class _MessageComposerWidget extends StatefulWidget {
  const _MessageComposerWidget({
    required this.createController,
    required this.mentionCandidates,
    required this.isLoading,
    required this.onCreate,
  });

  final TextEditingController createController;
  final List<UserProfile> mentionCandidates;
  final bool isLoading;
  final void Function(String? mentionedUserId) onCreate;

  @override
  State<_MessageComposerWidget> createState() => _MessageComposerWidgetState();
}

class _MessageComposerWidgetState extends State<_MessageComposerWidget> {
  String? _mentionQuery;
  String? _selectedMentionedUserId;

  String _displayLabel(UserProfile profile) {
    final displayName = profile.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return profile.userId;
  }

  Iterable<UserProfile> _filteredCandidates() {
    final query = _mentionQuery?.trim().toLowerCase();
    if (query == null) {
      return const <UserProfile>[];
    }

    if (query.isEmpty) {
      return widget.mentionCandidates;
    }

    return widget.mentionCandidates.where((candidate) {
      final displayLabel = _displayLabel(candidate).toLowerCase();
      return displayLabel.contains(query) ||
          candidate.userId.toLowerCase().contains(query);
    });
  }

  void _refreshMentionQuery() {
    final text = widget.createController.text;
    final mentionMatch = RegExp(r"(?:^|\s)@([^\s@]*)$").firstMatch(text);
    final nextMentionQuery = mentionMatch?.group(1);

    if (nextMentionQuery == _mentionQuery) {
      return;
    }

    setState(() {
      _mentionQuery = nextMentionQuery;
    });
  }

  void _selectMentionCandidate(UserProfile candidate) {
    final label = _displayLabel(candidate);
    final text = widget.createController.text;
    final mentionMatch = RegExp(r"(?:^|\s)@([^\s@]*)$").firstMatch(text);
    if (mentionMatch == null) {
      return;
    }

    final replacementStart = mentionMatch.start;
    final replacementPrefix = text.substring(0, replacementStart);
    final leadingWhitespace = text[replacementStart] == " " ? " " : "";
    final replacedText = "$replacementPrefix$leadingWhitespace@$label ";

    widget.createController.value = TextEditingValue(
      text: replacedText,
      selection: TextSelection.collapsed(offset: replacedText.length),
    );

    setState(() {
      _selectedMentionedUserId = candidate.userId;
      _mentionQuery = null;
    });
  }

  void _submitMessage() {
    widget.onCreate(_selectedMentionedUserId);
    setState(() {
      _selectedMentionedUserId = null;
      _mentionQuery = null;
    });
  }

  @override
  void initState() {
    super.initState();
    widget.createController.addListener(_refreshMentionQuery);
    _refreshMentionQuery();
  }

  @override
  void didUpdateWidget(covariant _MessageComposerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.createController == widget.createController) {
      return;
    }

    oldWidget.createController.removeListener(_refreshMentionQuery);
    widget.createController.addListener(_refreshMentionQuery);
    _refreshMentionQuery();
  }

  @override
  void dispose() {
    widget.createController.removeListener(_refreshMentionQuery);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCandidates = _filteredCandidates().take(6).toList();
    final showMentionSuggestions = _mentionQuery != null && filteredCandidates.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: widget.createController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitMessage(),
                decoration: const InputDecoration(
                  labelText: "Send message",
                  hintText: "Type @ to mention a member",
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.isLoading ? null : _submitMessage,
              child: const Text("Send"),
            ),
          ],
        ),
        if (_selectedMentionedUserId != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              "Mention target selected",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (showMentionSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filteredCandidates.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final candidate = filteredCandidates[index];
                return ListTile(
                  dense: true,
                  title: Text(_displayLabel(candidate)),
                  subtitle: Text(candidate.userId),
                  onTap: () => _selectMentionCandidate(candidate),
                );
              },
            ),
          ),
      ],
    );
  }
}
