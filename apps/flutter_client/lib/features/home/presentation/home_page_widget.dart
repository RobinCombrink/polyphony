import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/home/presentation/widgets/home_workspace_widget.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/identity/presentation/widgets/display_name_banner_widget.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_unread_count_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_unread_count_event.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_unread_count_state.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/servers/presentation/widgets/servers_pane_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/chat_browser_settings_page_widget.dart";
import "package:polyphony_flutter_client/features/voice_sessions/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/voice_sessions/presentation/widgets/voice_keybindings_focus_widget.dart";
import "package:polyphony_flutter_client/features/voice_sessions/presentation/widgets/voice_quick_actions_overlay_widget.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/top_right_error_toast.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  final createServerController = TextEditingController();
  final createChannelController = TextEditingController();
  final createMessageController = TextEditingController();
  late final NotificationRuntimeService _notificationRuntimeService;
  StreamSubscription<RuntimeNotificationEvent>? _notificationSubscription;
  var _keybindingsRefreshToken = 0;
  var _isDisplayNamePromptOpen = false;

  void _signOut(BuildContext context) {
    context
        .read<AuthenticationBloc>()
        .add(const AuthenticationLogoutRequested());
  }

  @override
  void initState() {
    super.initState();

    _notificationRuntimeService = context.read<NotificationRuntimeService>();

    _notificationSubscription =
        _notificationRuntimeService.notificationEvents().listen((_) {
      if (!mounted) {
        return;
      }

      context.read<NotificationUnreadCountBloc>().add(
            const LoadNotificationUnreadCountRequested(),
          );
    });

    unawaited(_connectNotificationRuntime(context));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _loadInitialData(context);
    });
  }

  @override
  void dispose() {
    final notificationSubscription = _notificationSubscription;
    if (notificationSubscription != null) {
      unawaited(notificationSubscription.cancel());
    }

    unawaited(_notificationRuntimeService.disconnect());
    createServerController.dispose();
    createChannelController.dispose();
    createMessageController.dispose();
    super.dispose();
  }

  Future<void> _connectNotificationRuntime(BuildContext context) async {
    final authenticationState = context.read<AuthenticationBloc>().state;
    if (authenticationState is! AuthenticationAuthenticatedState) {
      return;
    }

    final notificationsWebSocketUrl = _notificationWebSocketUrlFromBaseUrl(
      PolyphonyConfig.backendBaseUrl,
    );

    await _notificationRuntimeService.connect(
      notificationsWebSocketUrl: notificationsWebSocketUrl,
      bearerToken: authenticationState.metadata.bearerToken,
    );
  }

  String _notificationWebSocketUrlFromBaseUrl(String baseUrl) {
    final baseUri = Uri.parse(baseUrl);
    final notificationsPath =
        "${baseUri.path.endsWith("/") ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path}/api/v1/notifications/ws";

    final websocketScheme = switch (baseUri.scheme) {
      "https" => "wss",
      _ => "ws",
    };

    return baseUri
        .replace(
          scheme: websocketScheme,
          path: notificationsPath,
        )
        .toString();
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
    context.read<NotificationUnreadCountBloc>().add(
          const LoadNotificationUnreadCountRequested(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authenticationState = context.read<AuthenticationBloc>().state;
    final bearerToken = authenticationState is AuthenticationAuthenticatedState
        ? authenticationState.metadata.bearerToken
        : "";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Polyphony"),
        actions: <Widget>[
          BlocBuilder<NotificationUnreadCountBloc,
              NotificationUnreadCountState>(
            builder: (context, notificationState) {
              return _UnreadNotificationCountIconButton(
                totalUnreadCount: notificationState.totalUnreadCountOrZero(),
                onPressed: () => _loadInitialData(context),
              );
            },
          ),
          IconButton(
            onPressed: () async {
              final currentProfileState = context.read<ProfileBloc>().state;
              final currentDisplayName = switch (currentProfileState) {
                ProfileLoadedDataState(:final displayName) => displayName,
                _ => null,
              };

              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (settingsContext) => ChatBrowserSettingsPageWidget(
                    bearerToken: bearerToken,
                    initialDisplayName: currentDisplayName,
                    onSaveDisplayName: (displayName) =>
                        _requestUpdateDisplayName(context, displayName),
                  ),
                ),
              );

              if (!mounted) {
                return;
              }

              setState(() {
                _keybindingsRefreshToken = _keybindingsRefreshToken + 1;
              });
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
            onPressed: () => _signOut(context),
            tooltip: "Sign out",
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _buildChatTab(context),
    );
  }

  Widget _buildChatTab(BuildContext context) {
    return VoiceKeybindingsFocusWidget(
        refreshToken: _keybindingsRefreshToken,
        child: MultiBlocListener(
          listeners: [
            BlocListener<ProfileBloc, ProfileState>(
              listenWhen: (_, current) {
                return current is ProfileLoadedDataState &&
                    current.displayName == null;
              },
              listener: (context, state) {
                if (_isDisplayNamePromptOpen ||
                    state is! ProfileLoadedDataState) {
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
              listenWhen: (_, current) {
                return current is MessagesExceptionState ||
                    current is MessagesLoadedDataState;
              },
              listener: (context, state) {
                context.read<NotificationUnreadCountBloc>().add(
                      const LoadNotificationUnreadCountRequested(),
                    );

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
              listenWhen: (_, current) =>
                  current is VoiceSessionsExceptionState,
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
            BlocListener<NotificationUnreadCountBloc,
                NotificationUnreadCountState>(
              listenWhen: (_, current) =>
                  current is NotificationUnreadCountExceptionState,
              listener: (context, state) {
                if (state is! NotificationUnreadCountExceptionState) {
                  return;
                }

                showTopRightErrorToast(
                  context,
                  "Unable to refresh notifications.",
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
                    const DisplayNameBannerWidget(),
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
                            child: HomeWorkspaceWidget(
                              createChannelController: createChannelController,
                              createMessageController: createMessageController,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const VoiceQuickActionsOverlayWidget(),
              ],
            ),
          ),
        ));
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

class _UnreadNotificationCountIconButton extends StatelessWidget {
  const _UnreadNotificationCountIconButton({
    required this.totalUnreadCount,
    required this.onPressed,
  });

  final int totalUnreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final semanticCount = switch (totalUnreadCount) {
      < 0 => 0,
      > 999 => 999,
      _ => totalUnreadCount,
    };

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        IconButton(
          onPressed: onPressed,
          tooltip: "Refresh notifications",
          icon: const Icon(Icons.notifications_outlined),
        ),
        if (totalUnreadCount > 0)
          Positioned(
            top: 8,
            right: 6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                semanticCount > 99 ? "99+" : "$semanticCount",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
