import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

class ChatBrowserPageWidget extends StatefulWidget {
  const ChatBrowserPageWidget({super.key});

  @override
  State<ChatBrowserPageWidget> createState() => _ChatBrowserPageWidgetState();
}

class _ChatBrowserPageWidgetState extends State<ChatBrowserPageWidget> {
  final baseUrlController =
      TextEditingController(text: "http://127.0.0.1:5067");
  final createServerController = TextEditingController();
  final createChannelController = TextEditingController();
  final createMessageController = TextEditingController();

  Server? selectedServer;
  Channel? selectedChannel;

  String _statusText({
    required ServersState serversState,
    required ChannelsState channelsState,
    required MessagesState messagesState,
  }) {
    if (serversState is ServersValidationFailedState) {
      return switch (serversState.issue) {
        ServersValidationIssue.serverNameRequired => "Server name is required.",
      };
    }

    if (channelsState is ChannelsValidationFailedState) {
      return switch (channelsState.issue) {
        ChannelsValidationIssue.serverSelectionRequired =>
          "Select a server first.",
        ChannelsValidationIssue.channelNameRequired =>
          "Channel name is required.",
      };
    }

    if (messagesState is MessagesValidationFailedState) {
      return switch (messagesState.issue) {
        MessagesValidationIssue.channelSelectionRequired =>
          "Select a channel first.",
        MessagesValidationIssue.messageContentRequired =>
          "Message content is required.",
        MessagesValidationIssue.updatedContentRequired =>
          "Updated content is required.",
      };
    }

    if (serversState is ServersExceptionState) {
      return "Server operation failed: ${serversState.error}";
    }

    if (channelsState is ChannelsExceptionState) {
      return "Channel operation failed: ${channelsState.error}";
    }

    if (messagesState is MessagesExceptionState) {
      return "Message operation failed: ${messagesState.error}";
    }

    if (serversState.isLoading ||
        channelsState.isLoading ||
        messagesState.isLoading) {
      return "Working...";
    }

    if (serversState.servers.isEmpty) {
      return "No servers found for this user.";
    }

    return "Loaded ${serversState.servers.length} server(s), ${channelsState.channels.length} channel(s), ${messagesState.messages.length} message(s).";
  }

  @override
  void dispose() {
    baseUrlController.dispose();
    createServerController.dispose();
    createChannelController.dispose();
    createMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Polyphony MVP Client"),
        actions: <Widget>[
          IconButton(
            onPressed: () => context
                .read<AuthenticationBloc>()
                .add(const AuthenticationLogoutRequested()),
            tooltip: "Sign out",
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Builder(
          builder: (context) {
            final serversState = context.watch<ServersBloc>().state;
            final channelsState = context.watch<ChannelsBloc>().state;
            final messagesState = context.watch<MessagesBloc>().state;
            final isLoading = serversState.isLoading ||
                channelsState.isLoading ||
                messagesState.isLoading;

            final servers = serversState.servers;
            final channels = channelsState.channels;
            final messages = messagesState.messages;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: baseUrlController,
                  decoration:
                      const InputDecoration(labelText: "Backend base URL"),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          setState(() {
                            selectedServer = null;
                            selectedChannel = null;
                          });
                          context
                              .read<ChannelsBloc>()
                              .add(const ResetChannelsRequested());
                          context
                              .read<MessagesBloc>()
                              .add(const ResetMessagesRequested());
                          context.read<ServersBloc>().add(
                                LoadServersRequested(
                                  baseUrl: baseUrlController.text,
                                ),
                              );
                        },
                  child: const Text("Load Servers"),
                ),
                const SizedBox(height: 12),
                Text(
                  _statusText(
                    serversState: serversState,
                    channelsState: channelsState,
                    messagesState: messagesState,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildListSection<Server>(
                          title: "Servers",
                          items: servers,
                          isSelected: (server) =>
                              selectedServer?.id == server.id,
                          label: (server) => server.name,
                          onTap: (server) {
                            setState(() {
                              selectedServer = server;
                              selectedChannel = null;
                            });
                            context
                                .read<MessagesBloc>()
                                .add(const ResetMessagesRequested());
                            context.read<ChannelsBloc>().add(
                                  LoadChannelsRequested(
                                    baseUrl: baseUrlController.text,
                                    serverId: server.id,
                                  ),
                                );
                          },
                          isLoading: isLoading,
                          createController: createServerController,
                          createLabel: "Create server",
                          createActionLabel: "Add",
                          onCreate: () => context.read<ServersBloc>().add(
                                CreateServerRequested(
                                  baseUrl: baseUrlController.text,
                                  serverName: createServerController.text,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildListSection<Channel>(
                          title: "Channels",
                          items: channels,
                          isSelected: (channel) =>
                              selectedChannel?.id == channel.id,
                          label: (channel) => channel.name,
                          onTap: (channel) {
                            setState(() {
                              selectedChannel = channel;
                            });
                            context.read<MessagesBloc>().add(
                                  LoadMessagesRequested(
                                    baseUrl: baseUrlController.text,
                                    channelId: channel.id,
                                  ),
                                );
                          },
                          isLoading: isLoading,
                          createController: createChannelController,
                          createLabel: "Create channel",
                          createActionLabel: "Add",
                          onCreate: () => context.read<ChannelsBloc>().add(
                                CreateChannelRequested(
                                  baseUrl: baseUrlController.text,
                                  serverId: selectedServer?.id ?? "",
                                  channelName: createChannelController.text,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMessagesSection(
                          messages: messages,
                          createController: createMessageController,
                          isLoading: isLoading,
                          onCreate: () => context.read<MessagesBloc>().add(
                                CreateMessageRequested(
                                  baseUrl: baseUrlController.text,
                                  channelId: selectedChannel?.id ?? "",
                                  messageContent: createMessageController.text,
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildListSection<T>({
    required String title,
    required List<T> items,
    required bool Function(T item) isSelected,
    required String Function(T item) label,
    required void Function(T item) onTap,
    required bool isLoading,
    required TextEditingController createController,
    required String createLabel,
    required String createActionLabel,
    required VoidCallback onCreate,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: createController,
                    decoration: InputDecoration(labelText: createLabel),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isLoading ? null : onCreate,
                  child: Text(createActionLabel),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  selected: isSelected(item),
                  title: Text(label(item)),
                  onTap: isLoading ? null : () => onTap(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesSection({
    required List<Message> messages,
    required TextEditingController createController,
    required bool isLoading,
    required VoidCallback onCreate,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(12),
            child:
                Text("Messages", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: createController,
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
                return ListTile(
                  title: Text(message.content),
                  subtitle: Text(message.authorSubject),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        onPressed: isLoading
                            ? null
                            : () => _showEditMessageDialog(
                                  context,
                                  message,
                                ),
                        icon: const Icon(Icons.edit),
                        tooltip: "Edit message",
                      ),
                      IconButton(
                        onPressed: isLoading
                            ? null
                            : () => context.read<MessagesBloc>().add(
                                  DeleteMessageRequested(
                                    baseUrl: baseUrlController.text,
                                    channelId: selectedChannel?.id ?? "",
                                    messageId: message.id,
                                  ),
                                ),
                        icon: const Icon(Icons.delete),
                        tooltip: "Delete message",
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditMessageDialog(
    BuildContext context,
    Message message,
  ) async {
    final controller = TextEditingController(text: message.content);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Edit message"),
          content: TextField(
            controller: controller,
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

    if (!context.mounted || result == null) {
      return;
    }

    context.read<MessagesBloc>().add(
          UpdateMessageRequested(
            baseUrl: baseUrlController.text,
            channelId: selectedChannel?.id ?? "",
            messageId: message.id,
            messageContent: result,
          ),
        );
  }
}
