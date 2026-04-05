import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/emote_catalog_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/message_reactions_bloc.dart";
import "package:polyphony_flutter_client/features/messages/presentation/widgets/emote_picker_widget.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/services/emote_service.dart";
import "package:polyphony_flutter_client/shared/services/reaction_service.dart";

class MessageReactionsWidget extends StatelessWidget {
  const MessageReactionsWidget({
    required this.channelId,
    required this.messageId,
    super.key,
  });

  final ChannelId channelId;
  final MessageId messageId;

  void _showEmotePicker(BuildContext context) {
    final emoteService = context.read<EmoteService>();
    final reactionsBloc = context.read<MessageReactionsBloc>();
    unawaited(showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider(
        create: (_) => EmoteCatalogBloc(emoteService: emoteService)
          ..add(const EmoteCatalogLoadRequested()),
        child: AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: EmotePickerWidget(
            onEmoteSelected: (emote) {
              Navigator.of(dialogContext).pop();
              reactionsBloc.add(
                MessageReactionsToggleRequested(emoteId: emote.id),
              );
            },
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MessageReactionsBloc, MessageReactionsState>(
      builder: (context, state) {
        final reactions = switch (state) {
          MessageReactionsLoadedState(:final reactions) => reactions,
          _ => const <ReactionSummary>[],
        };

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (final reaction in reactions)
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
                onPressed: () => context.read<MessageReactionsBloc>().add(
                      MessageReactionsToggleRequested(
                        emoteId: reaction.emoteId,
                      ),
                    ),
              ),
            ActionChip(
              avatar: const Icon(Icons.add_reaction_outlined, size: 16),
              label: const Text("+"),
              onPressed: () => _showEmotePicker(context),
            ),
          ],
        );
      },
    );
  }
}
