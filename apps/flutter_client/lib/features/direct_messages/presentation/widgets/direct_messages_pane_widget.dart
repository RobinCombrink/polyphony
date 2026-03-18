import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/direct_messages/bloc/direct_messages_bloc.dart";

class DirectMessagesPaneWidget extends StatefulWidget {
  const DirectMessagesPaneWidget({super.key});

  @override
  State<DirectMessagesPaneWidget> createState() =>
      _DirectMessagesPaneWidgetState();
}

class _DirectMessagesPaneWidgetState extends State<DirectMessagesPaneWidget> {
  final _sendMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final bloc = context.read<DirectMessagesBloc>();
      if (bloc.state is DirectMessagesInitialState) {
        bloc.add(const LoadDirectMessageThreadsRequested());
      }
    });
  }

  @override
  void dispose() {
    _sendMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DirectMessagesBloc, DirectMessagesState>(
      builder: (context, state) {
        final loadedData =
            state is DirectMessagesLoadedDataState ? state : null;
        final selectedThread = loadedData?.selectedThread;
        final blockedPeer = loadedData?.selectedThreadIsBlocked ?? false;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  "Direct messages",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 220,
                        child: ListView.separated(
                          itemCount: loadedData?.threads.length ?? 0,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final thread = loadedData!.threads[index];
                            final isSelected =
                                thread.id == loadedData.selectedThreadId;
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              title: Text(thread.id),
                              onTap: () {
                                context.read<DirectMessagesBloc>().add(
                                      SelectDirectMessageThreadRequested(
                                        threadId: thread.id,
                                      ),
                                    );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(
                              child: state is DirectMessagesExceptionState
                                  ? Center(child: Text(state.error.toString()))
                                  : selectedThread == null
                                      ? const Center(
                                          child: Text(
                                            "Choose a friend to open a direct message thread.",
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: loadedData
                                                  ?.selectedThreadMessages
                                                  .length ??
                                              0,
                                          separatorBuilder: (_, __) =>
                                              const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final message = loadedData!
                                                .selectedThreadMessages[index];
                                            return ListTile(
                                              dense: true,
                                              title: Text(message.content),
                                              subtitle:
                                                  Text(message.authorUserId),
                                            );
                                          },
                                        ),
                            ),
                            const SizedBox(height: 8),
                            if (blockedPeer)
                              Row(
                                children: <Widget>[
                                  const Expanded(
                                    child: Text(
                                      "You have blocked this user. Unblock to send messages.",
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () {
                                      context.read<DirectMessagesBloc>().add(
                                            const UnblockSelectedDirectMessageUserRequested(),
                                          );
                                    },
                                    child: const Text("Unblock"),
                                  ),
                                ],
                              )
                            else
                              TextField(
                                controller: _sendMessageController,
                                decoration: InputDecoration(
                                  labelText: "Send message",
                                  suffixIcon: IconButton(
                                    onPressed: selectedThread == null
                                        ? null
                                        : () {
                                            context
                                                .read<DirectMessagesBloc>()
                                                .add(
                                                  SendDirectMessageRequested(
                                                    content:
                                                        _sendMessageController
                                                            .text,
                                                  ),
                                                );
                                            _sendMessageController.clear();
                                          },
                                    icon: const Icon(Icons.send),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
