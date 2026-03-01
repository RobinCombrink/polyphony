import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/messages_pane_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/server_users_pane_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/servers_pane_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/text_channels_pane_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/token_tab_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/top_right_error_toast.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/voice_channels_pane_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/voice_participants_pane_widget.dart";

class ChatBrowserPageWidget extends StatefulWidget {
  const ChatBrowserPageWidget({super.key});

  @override
  State<ChatBrowserPageWidget> createState() => _ChatBrowserPageWidgetState();
}

class _ChatBrowserPageWidgetState extends State<ChatBrowserPageWidget> {
  final createServerController = TextEditingController();
  final createChannelController = TextEditingController();
  final createMessageController = TextEditingController();
  var _isDisplayNamePromptOpen = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _loadInitialData(context);
    });
  }

  @override
  void dispose() {
    createServerController.dispose();
    createChannelController.dispose();
    createMessageController.dispose();
    super.dispose();
  }

  void _requestUpdateDisplayName(BuildContext context, String displayName) {
    context.read<ProfileBloc>().add(
          UpdateDisplayNameRequested(
            displayName: displayName,
          ),
        );
  }

  void _loadInitialData(BuildContext context) {
    context.read<ChannelsBloc>().add(
          const ResetChannelsRequested(),
        );
    context.read<MessagesBloc>().add(
          const ResetMessagesRequested(),
        );
    context.read<VoiceSessionsBloc>().add(
          const ResetVoiceSessionsRequested(),
        );
    context.read<ServerMembersBloc>().add(
          const ResetServerMembersRequested(),
        );
    context.read<ProfileBloc>().add(
          const LoadProfileRequested(),
        );
    context.read<ServersBloc>().add(
          const LoadServersRequested(),
        );
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
              onPressed: () => unawaited(
                _showDisplayNameDialog(context, mandatory: false),
              ),
              tooltip: "Edit display name",
              icon: const Icon(Icons.person),
            ),
            IconButton(
              onPressed: () => _loadInitialData(context),
              tooltip: "Refresh servers",
              icon: const Icon(Icons.refresh),
            ),
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
    return MultiBlocListener(
      listeners: [
        BlocListener<ProfileBloc, ProfileState>(
          listenWhen: (_, current) {
            return current is ProfileLoadedDataState &&
                current.displayName == null;
          },
          listener: (context, state) {
            if (_isDisplayNamePromptOpen || state is! ProfileLoadedDataState) {
              return;
            }

            _isDisplayNamePromptOpen = true;
            unawaited(
              _showDisplayNameDialog(context, mandatory: true).whenComplete(
                () => _isDisplayNamePromptOpen = false,
              ),
            );
          },
        ),
        BlocListener<ServersBloc, ServersState>(
          listenWhen: (_, current) => current is ServersExceptionState,
          listener: (context, state) {
            if (state is! ServersExceptionState) {
              return;
            }

            showTopRightErrorToast(
              context,
              state.error.toString(),
            );
          },
        ),
        BlocListener<ServersBloc, ServersState>(
          listenWhen: (_, current) => current is ServersLoadedDataState,
          listener: (context, state) {
            if (state is! ServersLoadedDataState) {
              return;
            }

            final selectedServerId = state.selectedServerId;

            if (selectedServerId == null || selectedServerId.isEmpty) {
              context.read<ServerMembersBloc>().add(
                    const ResetServerMembersRequested(),
                  );
              return;
            }

            context.read<ServerMembersBloc>().add(
                  LoadServerMembersRequested(serverId: selectedServerId),
                );
          },
        ),
        BlocListener<ChannelsBloc, ChannelsState>(
          listenWhen: (_, current) => current is ChannelsExceptionState,
          listener: (context, state) {
            if (state is! ChannelsExceptionState) {
              return;
            }

            showTopRightErrorToast(
              context,
              state.error.toString(),
            );
          },
        ),
        BlocListener<MessagesBloc, MessagesState>(
          listenWhen: (_, current) => current is MessagesExceptionState,
          listener: (context, state) {
            if (state is! MessagesExceptionState) {
              return;
            }

            showTopRightErrorToast(
              context,
              state.error.toString(),
            );
          },
        ),
        BlocListener<VoiceSessionsBloc, VoiceSessionsState>(
          listenWhen: (_, current) => current is VoiceSessionsExceptionState,
          listener: (context, state) {
            if (state is! VoiceSessionsExceptionState) {
              return;
            }

            showTopRightErrorToast(
              context,
              state.error.toString(),
            );
          },
        ),
        BlocListener<ProfileBloc, ProfileState>(
          listenWhen: (_, current) => current is ProfileExceptionState,
          listener: (context, state) {
            if (state is! ProfileExceptionState) {
              return;
            }

            showTopRightErrorToast(
              context,
              state.error.toString(),
            );
          },
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _DisplayNameBanner(),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 120,
                        child: ServersPaneWidget(
                          createController: createServerController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ServerWorkspaceWidget(
                          createChannelController: createChannelController,
                          createMessageController: createMessageController,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const _VoiceQuickActionsOverlay(),
          ],
        ),
      ),
    );
  }

  Future<void> _showDisplayNameDialog(
    BuildContext context, {
    required bool mandatory,
  }) async {
    final profileState = context.read<ProfileBloc>().state;
    final initialDisplayName = switch (profileState) {
      ProfileLoadedDataState(:final displayName) => displayName,
      _ => null,
    };

    final controller = TextEditingController(text: initialDisplayName ?? "");

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: !mandatory,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Display name"),
          content: TextField(
            controller: controller,
            autofocus: mandatory,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            decoration: const InputDecoration(
              labelText: "Display name",
            ),
          ),
          actions: <Widget>[
            if (!mandatory)
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

    if (!context.mounted) {
      return;
    }

    if (result == null) {
      if (mandatory) {
        unawaited(_showDisplayNameDialog(context, mandatory: true));
      }
      return;
    }

    _requestUpdateDisplayName(context, result);
  }
}

class _ServerWorkspaceWidget extends StatelessWidget {
  const _ServerWorkspaceWidget({
    required this.createChannelController,
    required this.createMessageController,
  });

  final TextEditingController createChannelController;
  final TextEditingController createMessageController;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServersBloc, ServersState>(
      builder: (context, serversState) {
        final selectedServerId = switch (serversState) {
          ServersLoadedDataState(:final selectedServerId) => selectedServerId,
          _ => null,
        };

        if (selectedServerId == null) {
          return const Card(
            child: Center(
              child: Text(
                "Select a server to view channels and messages.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Row(
          children: <Widget>[
            SizedBox(
              width: 360,
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: TextChannelsPaneWidget(
                      createController: createChannelController,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: VoiceChannelsPaneWidget(
                      createController: createChannelController,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BlocBuilder<ChannelsBloc, ChannelsState>(
                builder: (context, channelsState) {
                  final selectionMode = switch (channelsState) {
                    ChannelsLoadedDataState(:final selectionMode) =>
                      selectionMode,
                    _ => ChannelSelectionMode.text,
                  };

                  return switch (selectionMode) {
                    ChannelSelectionMode.voice =>
                      const VoiceParticipantsPaneWidget(),
                    ChannelSelectionMode.text => MessagesPaneWidget(
                        createController: createMessageController,
                      ),
                  };
                },
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox(
              width: 280,
              child: ServerUsersPaneWidget(),
            ),
          ],
        );
      },
    );
  }
}

class _DisplayNameBanner extends StatelessWidget {
  const _DisplayNameBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, profileState) {
        final displayName = switch (profileState) {
          ProfileLoadedDataState(:final displayName) => displayName,
          _ => null,
        };

        return Text("Display name: ${displayName ?? "Not set"}");
      },
    );
  }
}

class _VoiceQuickActionsOverlay extends StatelessWidget {
  const _VoiceQuickActionsOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceSessionsBloc, VoiceSessionsState>(
      builder: (context, voiceState) {
        final loadedData =
            voiceState is VoiceSessionsLoadedDataState ? voiceState : null;
        final activeVoiceConnection = loadedData?.activeConnection;
        final isSelfMuted = loadedData?.isSelfMuted ?? false;
        final isSelfDeafened = loadedData?.isSelfDeafened ?? false;

        if (activeVoiceConnection == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: 0,
          bottom: 0,
          child: _VoiceQuickActionsCard(
            channelId: activeVoiceConnection.channelId,
            isSelfMuted: isSelfMuted,
            isSelfDeafened: isSelfDeafened,
          ),
        );
      },
    );
  }
}

class _VoiceQuickActionsCard extends StatelessWidget {
  const _VoiceQuickActionsCard({
    required this.channelId,
    required this.isSelfMuted,
    required this.isSelfDeafened,
  });

  final String channelId;
  final bool isSelfMuted;
  final bool isSelfDeafened;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              onPressed: () => context.read<VoiceSessionsBloc>().add(
                    DisconnectVoiceSessionRequested(channelId: channelId),
                  ),
              tooltip: "Disconnect voice",
              icon: const Icon(Icons.call_end),
            ),
            IconButton(
              onPressed: () => context.read<VoiceSessionsBloc>().add(
                    SetSelfMutedRequested(muted: !isSelfMuted),
                  ),
              tooltip: isSelfMuted ? "Unmute" : "Mute",
              icon: Icon(isSelfMuted ? Icons.mic_off : Icons.mic),
            ),
            IconButton(
              onPressed: () => context.read<VoiceSessionsBloc>().add(
                    SetSelfDeafenedRequested(deafened: !isSelfDeafened),
                  ),
              tooltip: isSelfDeafened ? "Undeafen" : "Deafen",
              icon: Icon(isSelfDeafened ? Icons.headset_off : Icons.headset),
            ),
          ],
        ),
      ),
    );
  }
}
