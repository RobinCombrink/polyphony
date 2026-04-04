import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:markdown/markdown.dart" as md;
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/messages/presentation/widgets/emote_picker_widget.dart";
import "package:polyphony_flutter_client/features/messages/presentation/widgets/link_preview_card_widget.dart";
import "package:polyphony_flutter_client/features/messages/presentation/widgets/message_reactions_widget.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/section_status.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/link_preview_service.dart";
import "package:url_launcher/url_launcher.dart";

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
    this.onPin,
    this.onViewPins,
    this.channelName,
    super.key,
  });

  final List<Message> messages;
  final UserProfile currentUser;
  final Map<UserId, String?> authorDisplayNamesByUserId;
  final String? channelName;
  final TextEditingController createController;
  final List<UserProfile> mentionCandidates;
  final bool isLoading;
  final void Function(UserId? mentionedUserId) onCreate;
  final Future<void> Function(Message message) onEdit;
  final void Function(Message message) onDelete;
  final void Function(Message message)? onPin;
  final VoidCallback? onViewPins;

  String _authorLabel(UserId authorUserId, bool isOwnMessage) {
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

  bool _isMentioningCurrentUser(Message message) {
    final normalizedContent = message.content.toLowerCase();
    final mentionTargets = <String>{
      currentUser.userId.value.trim().toLowerCase(),
    };

    final displayName = currentUser.displayName?.trim().toLowerCase();
    if (displayName != null && displayName.isNotEmpty) {
      mentionTargets.add(displayName);
    }

    return mentionTargets.any((target) {
      if (target.isEmpty) {
        return false;
      }

      return normalizedContent.contains("@$target");
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
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Messages",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (onViewPins != null)
                  IconButton(
                    icon: const Icon(Icons.push_pin_outlined, size: 20),
                    tooltip: "View pinned messages",
                    onPressed: onViewPins,
                  ),
              ],
            ),
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
            child: BlocSelector<SettingsBloc, SettingsState, bool>(
              selector: (state) => switch (state) {
                SettingsLoadedState(:final isDeveloperModeEnabled) =>
                  isDeveloperModeEnabled,
                SettingsExceptionState(:final isDeveloperModeEnabled) =>
                  isDeveloperModeEnabled,
                SettingsInitialState() => false,
              },
              builder: (context, isDeveloperModeEnabled) {
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isOwnMessage =
                        message.authorUserId == currentUser.userId;
                    final isMentioningCurrentUser =
                        !isOwnMessage && _isMentioningCurrentUser(message);
                    final mentionBackgroundColor = isMentioningCurrentUser
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : null;

                    return Align(
                      alignment: isOwnMessage
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: GestureDetector(
                          onSecondaryTapDown: (details) async {
                            final menuItems = <PopupMenuEntry<String>>[
                              if (onPin != null)
                                const PopupMenuItem<String>(
                                  value: "pinMessage",
                                  child: Text("Pin message"),
                                ),
                              if (isDeveloperModeEnabled)
                                const PopupMenuItem<String>(
                                  value: "copyMessageId",
                                  child: Text("Copy message ID"),
                                ),
                            ];

                            if (menuItems.isEmpty) {
                              return;
                            }

                            final action = await showMenu<String>(
                              context: context,
                              position: RelativeRect.fromLTRB(
                                details.globalPosition.dx,
                                details.globalPosition.dy,
                                details.globalPosition.dx,
                                details.globalPosition.dy,
                              ),
                              items: menuItems,
                            );

                            if (!context.mounted) {
                              return;
                            }

                            if (action == "pinMessage") {
                              onPin?.call(message);
                            } else if (action == "copyMessageId") {
                              await Clipboard.setData(
                                ClipboardData(text: message.id.value),
                              );
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Message ID copied"),
                                ),
                              );
                            }
                          },
                          child: Card(
                            color: mentionBackgroundColor,
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
                                    _authorLabel(
                                      message.authorUserId,
                                      isOwnMessage,
                                    ),
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  MarkdownBody(
                                    data: message.content,
                                    selectable: true,
                                    extensionSet: md.ExtensionSet.gitHubWeb,
                                    onTapLink: (text, href, title) async {
                                      if (href == null) {
                                        return;
                                      }
                                      final uri = Uri.tryParse(href);
                                      if (uri == null) {
                                        return;
                                      }
                                      if (uri.scheme != "http" &&
                                          uri.scheme != "https") {
                                        return;
                                      }
                                      await launchUrl(uri);
                                    },
                                    imageBuilder: (uri, title, alt) =>
                                        Text(alt ?? uri.toString()),
                                  ),
                                  _MessageLinkPreviewWidget(
                                    content: message.content,
                                  ),
                                  MessageReactionsWidget(
                                    channelId: message.channelId,
                                    messageId: message.id,
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      IconButton(
                                        onPressed: isLoading
                                            ? null
                                            : () => onEdit(message),
                                        icon: const Icon(Icons.edit),
                                        tooltip: "Edit message",
                                      ),
                                      if (isOwnMessage)
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final _urlPattern = RegExp(
  r"https?://[^\s<>\)\]]+",
  caseSensitive: false,
);

class _MessageLinkPreviewWidget extends StatefulWidget {
  const _MessageLinkPreviewWidget({required this.content});

  final String content;

  @override
  State<_MessageLinkPreviewWidget> createState() =>
      _MessageLinkPreviewWidgetState();
}

class _MessageLinkPreviewWidgetState extends State<_MessageLinkPreviewWidget> {
  LinkPreview? _preview;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchPreview());
  }

  @override
  void didUpdateWidget(covariant _MessageLinkPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      unawaited(_fetchPreview());
    }
  }

  Future<void> _fetchPreview() async {
    final match = _urlPattern.firstMatch(widget.content);
    if (match == null) {
      setState(() {
        _preview = null;
        _loading = false;
      });
      return;
    }

    final url = match.group(0)!;
    final service = context.read<LinkPreviewService>();

    setState(() {
      _loading = true;
    });

    final result = await service.fetchPreview(url: url);
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _preview = switch (result) {
        Ok<LinkPreview>(:final value) when value.hasContent => value,
        _ => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _preview == null) {
      return const SizedBox.shrink();
    }

    return LinkPreviewCardWidget(
      title: _preview!.title ?? "",
      description: _preview!.description,
      url: _preview!.url,
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
  final void Function(UserId? mentionedUserId) onCreate;

  @override
  State<_MessageComposerWidget> createState() => _MessageComposerWidgetState();
}

class _MessageComposerWidgetState extends State<_MessageComposerWidget> {
  String? _mentionQuery;
  UserId? _selectedMentionedUserId;

  String _displayLabel(UserProfile profile) {
    final displayName = profile.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return profile.userId.value;
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
          candidate.userId.value.toLowerCase().contains(query);
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

  void _showEmotePicker(BuildContext context) {
    unawaited(showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: EmotePickerWidget(
          onEmoteSelected: (emote) {
            final controller = widget.createController;
            final text = controller.text;
            final selection = controller.selection;
            final insertOffset =
                selection.isValid ? selection.baseOffset : text.length;
            final newText =
                "${text.substring(0, insertOffset)}${emote.shortcode}${text.substring(insertOffset)}";
            controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(
                offset: insertOffset + emote.shortcode.length,
              ),
            );
            Navigator.of(dialogContext).pop();
          },
        ),
      ),
    ));
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
    final showMentionSuggestions =
        _mentionQuery != null && filteredCandidates.isNotEmpty;

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
            IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined),
              tooltip: "Emotes",
              onPressed: () => _showEmotePicker(context),
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
                  subtitle: Text(candidate.userId.value),
                  onTap: () => _selectMentionCandidate(candidate),
                );
              },
            ),
          ),
      ],
    );
  }
}
