import "dart:async";

import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/messages/presentation/widgets/emote_picker_widget.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/reaction_service.dart";
import "package:provider/provider.dart";

class MessageReactionsWidget extends StatefulWidget {
  const MessageReactionsWidget({
    required this.channelId,
    required this.messageId,
    super.key,
  });

  final ChannelId channelId;
  final MessageId messageId;

  @override
  State<MessageReactionsWidget> createState() => _MessageReactionsWidgetState();
}

class _MessageReactionsWidgetState extends State<MessageReactionsWidget> {
  List<ReactionSummary> _reactions = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadReactions());
  }

  Future<void> _loadReactions() async {
    final service = context.read<ReactionService>();
    final result = await service.listReactions(
      channelId: widget.channelId,
      messageId: widget.messageId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      if (result case Ok<List<ReactionSummary>>(:final value)) {
        _reactions = value;
      }
    });
  }

  Future<void> _toggleReaction(String emoteId) async {
    final service = context.read<ReactionService>();
    await service.toggleReaction(
      channelId: widget.channelId,
      messageId: widget.messageId,
      emoteId: emoteId,
    );
    await _loadReactions();
  }

  void _showEmotePicker() {
    unawaited(showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: EmotePickerWidget(
          onEmoteSelected: (emote) {
            Navigator.of(dialogContext).pop();
            unawaited(_toggleReaction(emote.id));
          },
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final reaction in _reactions)
          ActionChip(
            label: Text(
              "${reaction.emoteId} ${reaction.count}",
              style: TextStyle(
                fontWeight: reaction.reactedByCurrentUser
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            backgroundColor: reaction.reactedByCurrentUser
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            onPressed: () => unawaited(_toggleReaction(reaction.emoteId)),
          ),
        ActionChip(
          avatar: const Icon(Icons.add_reaction_outlined, size: 16),
          label: const Text("+"),
          onPressed: _showEmotePicker,
        ),
      ],
    );
  }
}
