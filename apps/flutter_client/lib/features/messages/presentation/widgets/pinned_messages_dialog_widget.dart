import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/pinned_messages_bloc.dart";
import "package:polyphony_flutter_client/shared/services/pinned_message_service.dart";

class PinnedMessagesDialogWidget extends StatelessWidget {
  const PinnedMessagesDialogWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PinnedMessagesBloc, PinnedMessagesState>(
      builder: (context, state) {
        return switch (state) {
          PinnedMessagesInitialState() => const _EmptyPinsView(),
          PinnedMessagesLoadingState() => const Center(
              child: CircularProgressIndicator(),
            ),
          PinnedMessagesLoadedState(:final pinnedMessages, :final serverId) =>
            pinnedMessages.isEmpty
                ? const _EmptyPinsView()
                : _PinnedMessagesListView(
                    pinnedMessages: pinnedMessages,
                    onUnpin: (pinnedMessage) {
                      context.read<PinnedMessagesBloc>().add(
                            UnpinMessageRequested(
                              serverId: serverId,
                              messageId: pinnedMessage.messageId,
                            ),
                          );
                    },
                  ),
          PinnedMessagesExceptionState(:final error) => Center(
              child: Text("Failed to load pins: $error"),
            ),
        };
      },
    );
  }
}

class _EmptyPinsView extends StatelessWidget {
  const _EmptyPinsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.push_pin_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            "No pinned messages",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _PinnedMessagesListView extends StatelessWidget {
  const _PinnedMessagesListView({
    required this.pinnedMessages,
    required this.onUnpin,
  });

  final List<PinnedMessage> pinnedMessages;
  final ValueChanged<PinnedMessage> onUnpin;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: pinnedMessages.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final pin = pinnedMessages[index];
        return _PinnedMessageTile(
          pinnedMessage: pin,
          onUnpin: () => onUnpin(pin),
        );
      },
    );
  }
}

class _PinnedMessageTile extends StatelessWidget {
  const _PinnedMessageTile({
    required this.pinnedMessage,
    required this.onUnpin,
  });

  final PinnedMessage pinnedMessage;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.push_pin, size: 20),
      title: Text(
        pinnedMessage.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: "Unpin",
        onPressed: onUnpin,
      ),
    );
  }
}
