import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

class ChatBrowserPageWidget extends StatefulWidget {
  const ChatBrowserPageWidget({super.key});

  @override
  State<ChatBrowserPageWidget> createState() => _ChatBrowserPageWidgetState();
}

class _ChatBrowserPageWidgetState extends State<ChatBrowserPageWidget> {
  final baseUrlController =
      TextEditingController(text: PolyphonyConfig.backendBaseUrl);
  final createServerController = TextEditingController();
  final createChannelController = TextEditingController();
  final createMessageController = TextEditingController();

  Server? selectedServer;
  Channel? selectedChannel;

  String _statusText({
    required ServersState serversState,
    required ChannelsState channelsState,
    required MessagesState messagesState,
    required VoiceSessionsState voiceSessionsState,
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

    if (voiceSessionsState is VoiceSessionsValidationFailedState) {
      return switch (voiceSessionsState.issue) {
        VoiceSessionsValidationIssue.channelSelectionRequired =>
          "Select a channel first.",
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

    if (voiceSessionsState is VoiceSessionsExceptionState) {
      return "Voice operation failed: ${voiceSessionsState.error}";
    }

    if (serversState.isLoading ||
        channelsState.isLoading ||
        messagesState.isLoading ||
        voiceSessionsState.isLoading) {
      return "Working...";
    }

    if (serversState.servers.isEmpty) {
      return "No servers found for this user.";
    }

    return "Loaded ${serversState.servers.length} server(s), ${channelsState.channels.length} channel(s), ${messagesState.messages.length} message(s), ${voiceSessionsState.voiceSessions.length} voice participant(s).";
  }

  bool _hasErrorOrException({
    required ServersState serversState,
    required ChannelsState channelsState,
    required MessagesState messagesState,
    required VoiceSessionsState voiceSessionsState,
  }) {
    return serversState is ServersValidationFailedState ||
        channelsState is ChannelsValidationFailedState ||
        messagesState is MessagesValidationFailedState ||
        voiceSessionsState is VoiceSessionsValidationFailedState ||
        serversState is ServersExceptionState ||
        channelsState is ChannelsExceptionState ||
        messagesState is MessagesExceptionState ||
        voiceSessionsState is VoiceSessionsExceptionState;
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
    final authenticationState = context.read<AuthenticationBloc>().state;
    final bearerToken = authenticationState is AuthenticationAuthenticatedState
        ? authenticationState.bearerToken
        : "";

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(text: "Chat"),
              Tab(text: "Token"),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _buildChatTab(context),
            _buildTokenTab(context, bearerToken),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Builder(
        builder: (context) {
          final serversState = context.watch<ServersBloc>().state;
          final channelsState = context.watch<ChannelsBloc>().state;
          final messagesState = context.watch<MessagesBloc>().state;
          final voiceSessionsState = context.watch<VoiceSessionsBloc>().state;
          final isLoading = serversState.isLoading ||
              channelsState.isLoading ||
              messagesState.isLoading ||
              voiceSessionsState.isLoading;

          final servers = serversState.servers;
          final channels = channelsState.channels;
          final messages = messagesState.messages;
          final voiceSessions = voiceSessionsState.voiceSessions;

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
                        context
                            .read<VoiceSessionsBloc>()
                            .add(const ResetVoiceSessionsRequested());
                        context.read<ServersBloc>().add(
                              LoadServersRequested(
                                baseUrl: baseUrlController.text,
                              ),
                            );
                      },
                child: const Text("Load Servers"),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final statusText = _statusText(
                    serversState: serversState,
                    channelsState: channelsState,
                    messagesState: messagesState,
                    voiceSessionsState: voiceSessionsState,
                  );
                  final hasErrorOrException = _hasErrorOrException(
                    serversState: serversState,
                    channelsState: channelsState,
                    messagesState: messagesState,
                    voiceSessionsState: voiceSessionsState,
                  );

                  if (hasErrorOrException) {
                    return SelectableText(statusText);
                  }

                  return Text(statusText);
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _buildListSection<Server>(
                        title: "Servers",
                        items: servers,
                        isSelected: (server) => selectedServer?.id == server.id,
                        label: (server) => server.name,
                        onTap: (server) {
                          setState(() {
                            selectedServer = server;
                            selectedChannel = null;
                          });
                          context
                              .read<MessagesBloc>()
                              .add(const ResetMessagesRequested());
                          context
                              .read<VoiceSessionsBloc>()
                              .add(const ResetVoiceSessionsRequested());
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
                        subtitle: (channel) {
                          final isSelectedChannel =
                              selectedChannel?.id == channel.id;
                          if (!isSelectedChannel || voiceSessions.isEmpty) {
                            return null;
                          }

                          return "In voice";
                        },
                        trailing: (channel) {
                          final isSelectedChannel =
                              selectedChannel?.id == channel.id;
                          if (!isSelectedChannel || voiceSessions.isEmpty) {
                            return null;
                          }

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.mic, size: 18),
                              const SizedBox(width: 4),
                              Text(voiceSessions.length.toString()),
                            ],
                          );
                        },
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
                          context.read<VoiceSessionsBloc>().add(
                                LoadVoiceSessionsRequested(
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildVoiceSection(
                        voiceSessions: voiceSessions,
                        isLoading: isLoading,
                        onJoin: () => context.read<VoiceSessionsBloc>().add(
                              JoinVoiceSessionRequested(
                                baseUrl: baseUrlController.text,
                                channelId: selectedChannel?.id ?? "",
                              ),
                            ),
                        onLeave: () => context.read<VoiceSessionsBloc>().add(
                              LeaveVoiceSessionRequested(
                                baseUrl: baseUrlController.text,
                                channelId: selectedChannel?.id ?? "",
                              ),
                            ),
                        onRefresh: () => context.read<VoiceSessionsBloc>().add(
                              LoadVoiceSessionsRequested(
                                baseUrl: baseUrlController.text,
                                channelId: selectedChannel?.id ?? "",
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
    );
  }

  Widget _buildTokenTab(BuildContext context, String bearerToken) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton(
            onPressed: bearerToken.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: bearerToken));

                    if (!context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Token copied")),
                    );
                  },
            child: const Text("Copy Token"),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(bearerToken),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection<T>({
    required String title,
    required List<T> items,
    required bool Function(T item) isSelected,
    required String Function(T item) label,
    String? Function(T item)? subtitle,
    Widget? Function(T item)? trailing,
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
                final itemSubtitle = subtitle?.call(item);
                return ListTile(
                  selected: isSelected(item),
                  title: Text(label(item)),
                  subtitle: itemSubtitle != null ? Text(itemSubtitle) : null,
                  trailing: trailing?.call(item),
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

  Widget _buildVoiceSection({
    required List<VoiceSession> voiceSessions,
    required bool isLoading,
    required VoidCallback onJoin,
    required VoidCallback onLeave,
    required VoidCallback onRefresh,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              "Voice",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: isLoading ? null : onJoin,
                  child: const Text("Join"),
                ),
                FilledButton.tonal(
                  onPressed: isLoading ? null : onLeave,
                  child: const Text("Leave"),
                ),
                OutlinedButton(
                  onPressed: isLoading ? null : onRefresh,
                  child: const Text("Refresh"),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: voiceSessions.length,
              itemBuilder: (context, index) {
                final voiceSession = voiceSessions[index];

                return ListTile(
                  leading: const Icon(Icons.mic),
                  title: Text(voiceSession.participantSubject),
                  subtitle: Text("Channel ${voiceSession.channelId}"),
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
