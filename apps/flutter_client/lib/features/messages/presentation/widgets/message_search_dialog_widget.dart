import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/message_search_bloc.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";

class MessageSearchDialogWidget extends StatefulWidget {
  const MessageSearchDialogWidget({
    required this.channelId,
    super.key,
  });

  final ChannelId channelId;

  @override
  State<MessageSearchDialogWidget> createState() =>
      _MessageSearchDialogWidgetState();
}

class _MessageSearchDialogWidgetState extends State<MessageSearchDialogWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    context.read<MessageSearchBloc>().add(
          MessageSearchQueryChanged(
            channelId: widget.channelId,
            query: query,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: "Search messages...",
          ),
          onChanged: _onQueryChanged,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: BlocBuilder<MessageSearchBloc, MessageSearchState>(
            builder: (context, state) {
              return switch (state) {
                MessageSearchLoadingState() =>
                  const Center(child: CircularProgressIndicator()),
                MessageSearchExceptionState(:final error) =>
                  Center(child: Text("Search failed: $error")),
                MessageSearchLoadedState(:final results) when results.isEmpty =>
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.search_off, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          "No messages found",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                MessageSearchLoadedState(:final results) => ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final message = results[index];
                      return ListTile(
                        leading: const Icon(Icons.message_outlined, size: 20),
                        title: Text(
                          message.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                MessageSearchInitialState() => const Center(
                    child: Text(
                      "Enter a search term to find messages.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              };
            },
          ),
        ),
      ],
    );
  }
}
