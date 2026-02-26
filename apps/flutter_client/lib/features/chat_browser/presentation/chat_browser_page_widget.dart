import "dart:convert";

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
  final addServerMemberController = TextEditingController();
  final createChannelController = TextEditingController();
  final createMessageController = TextEditingController();

  @override
  void dispose() {
    baseUrlController.dispose();
    createServerController.dispose();
    addServerMemberController.dispose();
    createChannelController.dispose();
    createMessageController.dispose();
    super.dispose();
  }

  String? _currentUserSubject(AuthenticationState authenticationState) {
    if (authenticationState is! AuthenticationAuthenticatedState) {
      return null;
    }

    final tokenParts = authenticationState.bearerToken.split(".");
    if (tokenParts.length != 3) {
      return null;
    }

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(tokenParts[1])),
      );
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      final subject = claims["sub"];

      return subject is String ? subject : null;
    } on Exception {
      return null;
    }
  }

  void _requestCreateServer(BuildContext context) {
    context.read<ServersBloc>().add(
          CreateServerRequested(
            baseUrl: baseUrlController.text,
            serverName: createServerController.text,
          ),
        );
  }

  void _requestCreateChannel(BuildContext context) {
    final selectedServerId = switch (context.read<ServersBloc>().state) {
      ServersLoadedDataState(:final selectedServerId) => selectedServerId,
      _ => null,
    };

    context.read<ChannelsBloc>().add(
          CreateChannelRequested(
            baseUrl: baseUrlController.text,
            serverId: selectedServerId ?? "",
            channelName: createChannelController.text,
          ),
        );
  }

  void _requestAddServerMember(BuildContext context, String serverId) {
    context.read<ServersBloc>().add(
          AddServerMemberRequested(
            baseUrl: baseUrlController.text,
            serverId: serverId,
            userSubject: addServerMemberController.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authenticationState = context.read<AuthenticationBloc>().state;
    final bearerToken = authenticationState is AuthenticationAuthenticatedState
        ? authenticationState.bearerToken
        : "";
    final currentUserSubject = _currentUserSubject(authenticationState);

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
            _buildChatTab(context, currentUserSubject),
            TokenTabWidget(bearerToken: bearerToken),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab(BuildContext context, String? currentUserSubject) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: BlocBuilder<ServersBloc, ServersState>(
        builder: (context, serversState) {
          return BlocBuilder<ChannelsBloc, ChannelsState>(
            builder: (context, channelsState) {
              return BlocBuilder<MessagesBloc, MessagesState>(
                builder: (context, messagesState) {
                  return BlocBuilder<VoiceSessionsBloc, VoiceSessionsState>(
                    builder: (context, voiceSessionsState) {
                      final serversData = _serversLoadedData(serversState);
                      final channelsData = _channelsLoadedData(channelsState);
                      final messagesData = _messagesLoadedData(messagesState);
                      final voiceData =
                          _voiceSessionsLoadedData(voiceSessionsState);

                      final servers = serversData?.servers ?? const <Server>[];
                      final channels =
                          channelsData?.channels ?? const <Channel>[];
                      final messages =
                          messagesData?.messages ?? const <Message>[];
                      final activeVoiceConnection = voiceData?.activeConnection;
                      final selectedServerId = serversData?.selectedServerId;
                      final selectedTextChannelId =
                          channelsData?.selectedTextChannelId;
                      final selectedVoiceChannelId =
                          channelsData?.selectedVoiceChannelId;
                      final channelSelectionMode =
                          channelsData?.selectionMode ??
                              ChannelSelectionMode.text;

                      Channel? selectedTextChannel;
                      for (final channel in channels) {
                        if (channel.id == selectedTextChannelId) {
                          selectedTextChannel = channel;
                        }
                      }

                      Channel? selectedVoiceChannel;
                      for (final channel in channels) {
                        if (channel.id == selectedVoiceChannelId) {
                          selectedVoiceChannel = channel;
                        }
                      }

                      final isLoading = serversState is ServersLoadingState ||
                          channelsState is ChannelsLoadingState ||
                          messagesState is MessagesLoadingState ||
                          voiceSessionsState is VoiceSessionsLoadingState;

                      final sectionStatus = buildServersSectionStatus(
                              serversState) ??
                          (selectedServerId != null
                              ? buildTextChannelsSectionStatus(channelsState) ??
                                  buildMessagesSectionStatus(messagesState) ??
                                  buildVoiceChannelsSectionStatus(
                                    voiceSessionsState,
                                  )
                              : null);

                      final activeVoiceChannelId =
                          channelSelectionMode == ChannelSelectionMode.voice
                              ? selectedVoiceChannel?.id
                              : selectedTextChannel?.id;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextField(
                            controller: baseUrlController,
                            decoration: const InputDecoration(
                              labelText: "Backend base URL",
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    context.read<ChannelsBloc>().add(
                                          const ResetChannelsRequested(),
                                        );
                                    context.read<MessagesBloc>().add(
                                          const ResetMessagesRequested(),
                                        );
                                    context.read<VoiceSessionsBloc>().add(
                                          const ResetVoiceSessionsRequested(),
                                        );
                                    context.read<ServersBloc>().add(
                                          LoadServersRequested(
                                            baseUrl: baseUrlController.text,
                                          ),
                                        );
                                  },
                            child: const Text("Load Servers"),
                          ),
                          const SizedBox(height: 12),
                          if (sectionStatus != null)
                            sectionStatus.isError
                                ? SelectableText(sectionStatus.message)
                                : Text(sectionStatus.message)
                          else if (isLoading)
                            const Text("Working...")
                          else
                            Text(
                              "Loaded ${servers.length} server(s), ${channels.length} channel(s), ${messages.length} message(s), ${activeVoiceConnection == null ? 0 : 1} voice participant(s).",
                            ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 120,
                                  child: ServersSectionWidget(
                                    servers: servers,
                                    selectedServerId: selectedServerId,
                                    isLoading: isLoading,
                                    createController: createServerController,
                                    onTap: (server) {
                                      context.read<ServersBloc>().add(
                                            SelectServerRequested(
                                              serverId: server.id,
                                            ),
                                          );
                                      context.read<MessagesBloc>().add(
                                            const ResetMessagesRequested(),
                                          );
                                      context.read<VoiceSessionsBloc>().add(
                                            const ResetVoiceSessionsRequested(),
                                          );
                                      context.read<ChannelsBloc>().add(
                                            const ResetChannelsRequested(),
                                          );
                                      context.read<ChannelsBloc>().add(
                                            LoadChannelsRequested(
                                              baseUrl: baseUrlController.text,
                                              serverId: server.id,
                                            ),
                                          );
                                    },
                                    onCreate: () =>
                                        _requestCreateServer(context),
                                  ),
                                ),
                                if (selectedServerId == null) ...<Widget>[
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Card(
                                      child: Center(
                                        child: Text(
                                          "Select a server to view channels and messages.",
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...<Widget>[
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 360,
                                    child: Column(
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: TextField(
                                                controller:
                                                    addServerMemberController,
                                                enabled: !isLoading,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText:
                                                      "User subject to add",
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            FilledButton.tonal(
                                              onPressed: isLoading
                                                  ? null
                                                  : () =>
                                                      _requestAddServerMember(
                                                        context,
                                                        selectedServerId,
                                                      ),
                                              child: const Text("Add user"),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: TextChannelsSectionWidget(
                                            channels: channels,
                                            selectedChannelId:
                                                channelSelectionMode ==
                                                        ChannelSelectionMode
                                                            .text
                                                    ? selectedTextChannelId
                                                    : null,
                                            voiceParticipantCount:
                                                activeVoiceConnection == null
                                                    ? 0
                                                    : 1,
                                            isLoading: isLoading,
                                            createController:
                                                createChannelController,
                                            onTap: (channel) {
                                              context.read<ChannelsBloc>().add(
                                                    SelectTextChannelRequested(
                                                      channelId: channel.id,
                                                    ),
                                                  );
                                              context.read<MessagesBloc>().add(
                                                    LoadMessagesRequested(
                                                      baseUrl: baseUrlController
                                                          .text,
                                                      channelId: channel.id,
                                                    ),
                                                  );
                                              context
                                                  .read<VoiceSessionsBloc>()
                                                  .add(
                                                    LoadVoiceSessionsRequested(
                                                      baseUrl: baseUrlController
                                                          .text,
                                                      channelId: channel.id,
                                                    ),
                                                  );
                                            },
                                            onCreate: () =>
                                                _requestCreateChannel(context),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: TextChannelsSectionWidget(
                                            channels: channels,
                                            selectedChannelId:
                                                channelSelectionMode ==
                                                        ChannelSelectionMode
                                                            .voice
                                                    ? selectedVoiceChannelId
                                                    : null,
                                            voiceParticipantCount:
                                                activeVoiceConnection == null
                                                    ? 0
                                                    : 1,
                                            isLoading: isLoading,
                                            createController:
                                                createChannelController,
                                            title: "Voice channels",
                                            createLabel: "",
                                            createActionLabel: "",
                                            showCreateControls: false,
                                            interactionType:
                                                ChannelInteractionType.voice,
                                            onTap: (channel) {
                                              context.read<ChannelsBloc>().add(
                                                    SelectVoiceChannelRequested(
                                                      channelId: channel.id,
                                                    ),
                                                  );
                                              context
                                                  .read<VoiceSessionsBloc>()
                                                  .add(
                                                    LoadVoiceSessionsRequested(
                                                      baseUrl: baseUrlController
                                                          .text,
                                                      channelId: channel.id,
                                                    ),
                                                  );
                                            },
                                            onCreate: () {},
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          height: 180,
                                          child: VoiceChannelsSectionWidget(
                                            activeConnection:
                                                activeVoiceConnection,
                                            isLoading: isLoading,
                                            onConnect: () => context
                                                .read<VoiceSessionsBloc>()
                                                .add(
                                                  ConnectVoiceSessionRequested(
                                                    baseUrl:
                                                        baseUrlController.text,
                                                    channelId:
                                                        activeVoiceChannelId ??
                                                            "",
                                                  ),
                                                ),
                                            onDisconnect: () => context
                                                .read<VoiceSessionsBloc>()
                                                .add(
                                                  DisconnectVoiceSessionRequested(
                                                    baseUrl:
                                                        baseUrlController.text,
                                                    channelId:
                                                        activeVoiceChannelId ??
                                                            "",
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: selectedTextChannel != null &&
                                            channelSelectionMode ==
                                                ChannelSelectionMode.text
                                        ? MessagesSectionWidget(
                                            messages: messages,
                                            currentUserSubject:
                                                currentUserSubject,
                                            channelName:
                                                selectedTextChannel.name,
                                            createController:
                                                createMessageController,
                                            isLoading: isLoading,
                                            onCreate: () => context
                                                .read<MessagesBloc>()
                                                .add(
                                                  CreateMessageRequested(
                                                    baseUrl:
                                                        baseUrlController.text,
                                                    channelId:
                                                        selectedTextChannel
                                                                ?.id ??
                                                            "",
                                                    messageContent:
                                                        createMessageController
                                                            .text,
                                                  ),
                                                ),
                                            onEdit: (message) =>
                                                _showEditMessageDialog(
                                              context,
                                              message,
                                            ),
                                            onDelete: (message) => context
                                                .read<MessagesBloc>()
                                                .add(
                                                  DeleteMessageRequested(
                                                    baseUrl:
                                                        baseUrlController.text,
                                                    channelId:
                                                        selectedTextChannel
                                                                ?.id ??
                                                            "",
                                                    messageId: message.id,
                                                  ),
                                                ),
                                          )
                                        : Card(
                                            child: Center(
                                              child: Text(
                                                selectedVoiceChannel == null
                                                    ? "Select a text channel to view and send messages."
                                                    : "Selected voice channel ${selectedVoiceChannel.name}. Choose a text channel to open chat.",
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
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
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
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

    final selectedTextChannelId = switch (context.read<ChannelsBloc>().state) {
      ChannelsLoadedDataState(:final selectedTextChannelId) =>
        selectedTextChannelId,
      _ => null,
    };

    context.read<MessagesBloc>().add(
          UpdateMessageRequested(
            baseUrl: baseUrlController.text,
            channelId: selectedTextChannelId ?? "",
            messageId: message.id,
            messageContent: result,
          ),
        );
  }

  ServersLoadedDataState? _serversLoadedData(ServersState state) {
    return switch (state) {
      ServersLoadedDataState() => state,
      _ => null,
    };
  }

  ChannelsLoadedDataState? _channelsLoadedData(ChannelsState state) {
    return switch (state) {
      ChannelsLoadedDataState() => state,
      _ => null,
    };
  }

  MessagesLoadedDataState? _messagesLoadedData(MessagesState state) {
    return switch (state) {
      MessagesLoadedDataState() => state,
      _ => null,
    };
  }

  VoiceSessionsLoadedDataState? _voiceSessionsLoadedData(
    VoiceSessionsState state,
  ) {
    return switch (state) {
      VoiceSessionsLoadedDataState() => state,
      _ => null,
    };
  }
}
