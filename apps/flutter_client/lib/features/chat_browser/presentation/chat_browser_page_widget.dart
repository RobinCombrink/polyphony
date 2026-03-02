import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_webrtc/flutter_webrtc.dart" as rtc;
import "package:livekit_client/livekit_client.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/channels_pane_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/messages_pane_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/server_users_pane_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/servers_pane_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/top_right_error_toast.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/voice_participants_pane_widget.dart";
import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

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

  Future<void> _signOut(BuildContext context) async {
    await context.read<AccessTokenProvider>().clearPersistedSession();
    if (!context.mounted) {
      return;
    }

    context
        .read<AuthenticationBloc>()
        .add(const AuthenticationLogoutRequested());
  }

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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Polyphony"),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              final currentProfileState = context.read<ProfileBloc>().state;
              final currentDisplayName = switch (currentProfileState) {
                ProfileLoadedDataState(:final displayName) => displayName,
                _ => null,
              };

              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (settingsContext) => _SettingsPageWidget(
                    bearerToken: bearerToken,
                    initialDisplayName: currentDisplayName,
                    onSaveDisplayName: (displayName) =>
                        _requestUpdateDisplayName(context, displayName),
                  ),
                ),
              );
            },
            tooltip: "Settings",
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            onPressed: () => _loadInitialData(context),
            tooltip: "Refresh servers",
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => unawaited(_signOut(context)),
            tooltip: "Sign out",
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _buildChatTab(context),
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
        final loadedData =
            serversState is ServersLoadedDataState ? serversState : null;
        final selectedServerId = loadedData?.selectedServerId;
        final selectedServerName = loadedData?.servers
            .where((server) => server.id == selectedServerId)
            .map((server) => server.name)
            .firstOrNull;

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
              child: ChannelsPaneWidget(
                createController: createChannelController,
                serverName: selectedServerName,
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
    return BlocBuilder<ServersBloc, ServersState>(
      builder: (context, serversState) {
        final selectedServerId = switch (serversState) {
          ServersLoadedDataState(:final selectedServerId) => selectedServerId,
          _ => null,
        };
        final selectedServerName = switch (serversState) {
          ServersLoadedDataState(:final servers) => servers
              .where((server) => server.id == selectedServerId)
              .map((server) => server.name)
              .firstOrNull,
          _ => null,
        };

        return BlocBuilder<ChannelsBloc, ChannelsState>(
          builder: (context, channelsState) {
            final selectedVoiceChannelId = switch (channelsState) {
              ChannelsLoadedDataState(:final selectedVoiceChannelId) =>
                selectedVoiceChannelId,
              _ => null,
            };
            final voiceChannels = switch (channelsState) {
              ChannelsLoadedDataState(:final voiceChannels) => voiceChannels,
              _ => const <VoiceChannel>[],
            };

            return BlocBuilder<VoiceSessionsBloc, VoiceSessionsState>(
              builder: (context, voiceState) {
                final loadedData = voiceState is VoiceSessionsLoadedDataState
                    ? voiceState
                    : null;
                final activeVoiceConnection = loadedData?.activeConnection;
                final isSelfMuted = loadedData?.isSelfMuted ?? false;
                final isSelfDeafened = loadedData?.isSelfDeafened ?? false;
                final isSelfScreenShareEnabled =
                    loadedData?.isSelfScreenShareEnabled ?? false;

                final connectedChannelId = activeVoiceConnection?.channelId;
                final hasConnectedChannel =
                    connectedChannelId != null && connectedChannelId.isNotEmpty;
                final isConnecting = !hasConnectedChannel &&
                    voiceState is VoiceSessionsLoadingState &&
                    selectedVoiceChannelId != null &&
                    selectedVoiceChannelId.isNotEmpty;

                if (!hasConnectedChannel && !isConnecting) {
                  return const SizedBox.shrink();
                }

                final contextualChannelId = hasConnectedChannel
                    ? connectedChannelId
                    : selectedVoiceChannelId;
                final contextualChannelName = voiceChannels
                    .where((channel) => channel.id == contextualChannelId)
                    .map((channel) => channel.name)
                    .firstOrNull;

                final connectionLocationText = contextualChannelName == null ||
                        contextualChannelName.isEmpty ||
                        selectedServerName == null ||
                        selectedServerName.isEmpty
                    ? null
                    : "$contextualChannelName / $selectedServerName";

                return Positioned(
                  left: 0,
                  bottom: 0,
                  child: _VoiceQuickActionsCard(
                    channelId: connectedChannelId,
                    connectionStatus: isConnecting
                        ? _VoiceConnectionStatus.connecting
                        : _VoiceConnectionStatus.connected,
                    connectionLocationText: connectionLocationText,
                    isSelfMuted: isSelfMuted,
                    isSelfDeafened: isSelfDeafened,
                    isSelfScreenShareEnabled: isSelfScreenShareEnabled,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

enum _VoiceConnectionStatus {
  connecting,
  connected,
}

class _VoiceQuickActionsCard extends StatelessWidget {
  const _VoiceQuickActionsCard({
    required this.channelId,
    required this.connectionStatus,
    required this.connectionLocationText,
    required this.isSelfMuted,
    required this.isSelfDeafened,
    required this.isSelfScreenShareEnabled,
  });

  final String? channelId;
  final _VoiceConnectionStatus connectionStatus;
  final String? connectionLocationText;
  final bool isSelfMuted;
  final bool isSelfDeafened;
  final bool isSelfScreenShareEnabled;

  Future<void> _onToggleScreenSharePressed(BuildContext context) async {
    try {
      final shouldEnable = !isSelfScreenShareEnabled;
      String? sourceId;

      if (shouldEnable && _isDesktopRuntime()) {
        final selectedSource = await showDialog<rtc.DesktopCapturerSource>(
          context: context,
          builder: (_) => ScreenSelectDialog(),
        );

        if (!context.mounted) {
          return;
        }

        if (selectedSource == null) {
          return;
        }

        sourceId = selectedSource.id;
      }

      context.read<VoiceSessionsBloc>().add(
            SetSelfScreenShareEnabledRequested(
              enabled: shouldEnable,
              sourceId: sourceId,
            ),
          );
    } on Exception catch (error) {
      if (context.mounted) {
        showTopRightErrorToast(
          context,
          "Failed to open screen source picker: $error",
        );
      }
    }
  }

  bool _isDesktopRuntime() {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final controlsEnabled =
        connectionStatus == _VoiceConnectionStatus.connected &&
            channelId != null &&
            channelId!.isNotEmpty;

    final (statusLabel, statusColor) = switch (connectionStatus) {
      _VoiceConnectionStatus.connecting => ("Connecting", Colors.yellow),
      _VoiceConnectionStatus.connected => ("Connected", Colors.green),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text("Voice · $statusLabel"),
              ],
            ),
            if (connectionLocationText != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                connectionLocationText!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (controlsEnabled) ...<Widget>[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    onPressed: () => context.read<VoiceSessionsBloc>().add(
                          DisconnectVoiceSessionRequested(
                              channelId: channelId!),
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
                    icon: Icon(
                      isSelfDeafened ? Icons.headset_off : Icons.headset,
                    ),
                  ),
                  IconButton(
                    onPressed: () => unawaited(
                      _onToggleScreenSharePressed(context),
                    ),
                    tooltip: isSelfScreenShareEnabled
                        ? "Stop sharing screen"
                        : "Share your screen",
                    icon: Icon(
                      isSelfScreenShareEnabled
                          ? Icons.stop_screen_share
                          : Icons.screen_share,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsPageWidget extends StatefulWidget {
  const _SettingsPageWidget({
    required this.bearerToken,
    required this.initialDisplayName,
    required this.onSaveDisplayName,
  });

  final String bearerToken;
  final String? initialDisplayName;
  final ValueChanged<String> onSaveDisplayName;

  @override
  State<_SettingsPageWidget> createState() => _SettingsPageWidgetState();
}

class _SettingsPageWidgetState extends State<_SettingsPageWidget> {
  late final TextEditingController _displayNameController;
  var _developerOptionsEnabled = false;

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.initialDisplayName ?? "");
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _copyToken() async {
    await Clipboard.setData(ClipboardData(text: widget.bearerToken));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Token copied")),
    );
  }

  void _saveDisplayName() {
    widget.onSaveDisplayName(_displayNameController.text);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Display name updated")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              "Display name",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _displayNameController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveDisplayName(),
              decoration: const InputDecoration(
                labelText: "Display name",
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _saveDisplayName,
                child: const Text("Save"),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Developer options",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Enable developer options"),
              value: _developerOptionsEnabled,
              onChanged: (value) {
                setState(() {
                  _developerOptionsEnabled = value;
                });
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed:
                    _developerOptionsEnabled && widget.bearerToken.isNotEmpty
                        ? () => unawaited(_copyToken())
                        : null,
                child: const Text("Copy token"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
