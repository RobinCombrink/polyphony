import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/messages_section_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/servers_section_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/text_channels_section_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/token_tab_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/voice_channels_section_widget.dart";
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
            TokenTabWidget(bearerToken: bearerToken),
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
                  final sectionStatus =
                      buildServersSectionStatus(serversState) ??
                          buildTextChannelsSectionStatus(channelsState) ??
                          buildMessagesSectionStatus(messagesState) ??
                          buildVoiceChannelsSectionStatus(voiceSessionsState);

                  if (sectionStatus != null) {
                    if (sectionStatus.isError) {
                      return SelectableText(sectionStatus.message);
                    }

                    return Text(sectionStatus.message);
                  }

                  if (isLoading) {
                    return const Text("Working...");
                  }

                  return Text(
                    "Loaded ${servers.length} server(s), ${channels.length} channel(s), ${messages.length} message(s), ${voiceSessions.length} voice participant(s).",
                  );
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: ServersSectionWidget(
                        servers: servers,
                        selectedServerId: selectedServer?.id,
                        isLoading: isLoading,
                        createController: createServerController,
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
                      child: TextChannelsSectionWidget(
                        channels: channels,
                        selectedChannelId: selectedChannel?.id,
                        voiceParticipantCount: voiceSessions.length,
                        isLoading: isLoading,
                        createController: createChannelController,
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
                      child: MessagesSectionWidget(
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
                        onEdit: (message) => _showEditMessageDialog(
                          context,
                          message,
                        ),
                        onDelete: (message) => context.read<MessagesBloc>().add(
                              DeleteMessageRequested(
                                baseUrl: baseUrlController.text,
                                channelId: selectedChannel?.id ?? "",
                                messageId: message.id,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: VoiceChannelsSectionWidget(
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
