import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:polyphony_flutter_client/app/app_route.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/home/presentation/widgets/home_workspace_widget.dart";
import "package:polyphony_flutter_client/features/home/presentation/widgets/workspace_destination.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/identity/presentation/widgets/display_name_banner_widget.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_center_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/servers/presentation/widgets/servers_pane_widget.dart";
import "package:polyphony_flutter_client/features/voice_sessions/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/voice_sessions/presentation/widgets/voice_keybindings_focus_widget.dart";
import "package:polyphony_flutter_client/features/voice_sessions/presentation/widgets/voice_quick_actions_overlay_widget.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/top_right_error_toast.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/notification_service.dart";

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  final createServerController = TextEditingController();
  final createChannelController = TextEditingController();
  final createMessageController = TextEditingController();
  _NotificationChannelTarget? _pendingNotificationChannelTarget;
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

  void _refreshUnreadCount(BuildContext context) {
    context.read<NotificationCenterBloc>().add(
          const NotificationCenterUnreadCountRefreshRequested(),
        );
  }

  void _showDirectMessagesWorkspace() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }

    router.goNamed(AppRouteId.directMessages.name);
  }

  void _showWorkspaceDestination(WorkspaceDestination destination) {
    switch (destination) {
      case DirectMessageWorkspaceDestination():
        _showDirectMessagesWorkspace();
      case NoServerSelectedWorkspaceDestination():
        _showServerWorkspace();
      case ServerSelectedWorkspaceDestination():
        _showServerWorkspace();
    }
  }

  void _showServerWorkspace() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }

    router.goNamed(AppRouteId.appHome.name);
  }

  bool _isDirectMessageNotification(NotificationCenterEntry entry) {
    final normalizedServerId = entry.event.serverId.trim().toLowerCase();
    final normalizedServerName = entry.event.serverName.trim().toLowerCase();
    final normalizedChannelName = entry.event.channelName.trim().toLowerCase();

    return normalizedServerId == "direct-messages" ||
        normalizedServerId == "direct_messages" ||
        normalizedServerId == "dms" ||
        normalizedServerName == "direct messages" ||
        normalizedServerName == "dms" ||
        normalizedChannelName.contains("direct message");
  }

  int _directMessagesUnreadCount(NotificationCenterState state) {
    return state.entries.where(_isDirectMessageNotification).length;
  }

  Future<void> _markChannelNotificationsRead(ChannelId channelId) async {
    final markReadResult = await context
        .read<NotificationService>()
        .markChannelNotificationsRead(channelId: channelId.value);

    if (!mounted) {
      return;
    }

    if (markReadResult case Error<void>()) {
      showTopRightErrorToast(
        context,
        "Unable to mark notifications as read.",
      );
      return;
    }

    _refreshUnreadCount(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Polyphony"),
        actions: <Widget>[
          BlocBuilder<NotificationCenterBloc, NotificationCenterState>(
            builder: (context, notificationState) {
              return _UnreadNotificationCountIconButton(
                totalUnreadCount: notificationState.totalUnreadCount,
                onPressed: () => _refreshUnreadCount(context),
              );
            },
          ),
          BlocBuilder<NotificationCenterBloc, NotificationCenterState>(
            builder: (context, notificationFeedState) {
              return _NotificationFeedIconButton(
                feedEntryCount: notificationFeedState.entries.length,
                onPressed: () => _showNotificationFeedSheet(context),
              );
            },
          ),
          IconButton(
            onPressed: () async {
              await context.pushNamed(AppRouteId.settings.name);

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
              listenWhen: (_, current) => current is ServersLoadedState,
              listener: (context, state) {
                if (state is! ServersLoadedState) {
                  return;
                }

                switch (state) {
                  case NoServerSelected():
                    context.read<ServerMembersBloc>().add(
                          const ResetServerMembersRequested(),
                        );
                  case ServerSelected(:final selectedServer):
                    context.read<ServerMembersBloc>().add(
                          LoadServerMembersRequested(
                            serverId: selectedServer.id,
                          ),
                        );
                  case ServersValidationFailedState():
                    return;
                }
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
            BlocListener<ChannelsBloc, ChannelsState>(
              listenWhen: (_, current) => current is ChannelsLoadedDataState,
              listener: (context, state) {
                final pendingTarget = _pendingNotificationChannelTarget;
                if (pendingTarget == null ||
                    state is! ChannelsLoadedDataState) {
                  return;
                }

                if (state.serverId != pendingTarget.serverId) {
                  return;
                }

                final hasTargetChannel = state.textChannels.any(
                  (channel) => channel.id == pendingTarget.channelId,
                );

                _pendingNotificationChannelTarget = null;

                if (!hasTargetChannel) {
                  showTopRightErrorToast(
                    context,
                    "Unable to open notification channel.",
                  );
                  return;
                }

                context.read<ChannelsBloc>().add(
                      SelectTextChannelRequested(
                        channelId: pendingTarget.channelId,
                      ),
                    );
              },
            ),
            BlocListener<ChannelsBloc, ChannelsState>(
              listenWhen: (previous, current) {
                final currentSelectedTextChannelId = switch (current) {
                  TextChannelSelected(:final selectedTextChannel) =>
                    selectedTextChannel.id,
                  TextChannelSelectedValidationFailedState(
                    :final selectedTextChannel,
                  ) =>
                    selectedTextChannel.id,
                  _ => null,
                };

                if (currentSelectedTextChannelId == null) {
                  return false;
                }

                final previousSelection = switch (previous) {
                  TextChannelSelected(
                    :final selectedTextChannel,
                    :final serverId,
                  ) =>
                    (
                      serverId: serverId,
                      channelId: selectedTextChannel.id,
                    ),
                  TextChannelSelectedValidationFailedState(
                    :final selectedTextChannel,
                    :final serverId,
                  ) =>
                    (
                      serverId: serverId,
                      channelId: selectedTextChannel.id,
                    ),
                  _ => null,
                };

                final currentSelection = switch (current) {
                  TextChannelSelected(
                    :final selectedTextChannel,
                    :final serverId,
                  ) =>
                    (
                      serverId: serverId,
                      channelId: selectedTextChannel.id,
                    ),
                  TextChannelSelectedValidationFailedState(
                    :final selectedTextChannel,
                    :final serverId,
                  ) =>
                    (
                      serverId: serverId,
                      channelId: selectedTextChannel.id,
                    ),
                  _ => null,
                };

                return previousSelection != currentSelection;
              },
              listener: (context, state) {
                final selectedTextChannelId = switch (state) {
                  TextChannelSelected(:final selectedTextChannel) =>
                    selectedTextChannel.id,
                  TextChannelSelectedValidationFailedState(
                    :final selectedTextChannel,
                  ) =>
                    selectedTextChannel.id,
                  _ => null,
                };

                if (selectedTextChannelId == null) {
                  return;
                }

                unawaited(
                  _markChannelNotificationsRead(selectedTextChannelId),
                );
              },
            ),
            BlocListener<MessagesBloc, MessagesState>(
              listenWhen: (_, current) {
                return current is MessagesExceptionState ||
                    current is MessagesLoadedDataState;
              },
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
            BlocListener<NotificationCenterBloc, NotificationCenterState>(
              listenWhen: (_, current) =>
                  current is NotificationCenterExceptionState,
              listener: (context, state) {
                if (state is! NotificationCenterExceptionState) {
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
                            child: BlocBuilder<ServersBloc, ServersState>(
                              builder: (context, serversState) => BlocBuilder<
                                  NotificationCenterBloc,
                                  NotificationCenterState>(
                                builder: (context, notificationState) =>
                                    switch (serversState) {
                                  ServerSelected(:final selectedServer) =>
                                    ServersPaneWidget(
                                      createController: createServerController,
                                      selectedDestination:
                                          ServerSelectedWorkspaceDestination(
                                        serverId: selectedServer.id.value,
                                      ),
                                      directMessagesUnreadCount:
                                          _directMessagesUnreadCount(
                                        notificationState,
                                      ),
                                      onSelectDestination:
                                          _showWorkspaceDestination,
                                    ),
                                  NoServerSelected() ||
                                  ServersValidationFailedState() =>
                                    ServersPaneWidget(
                                      createController: createServerController,
                                      selectedDestination:
                                          const NoServerSelectedWorkspaceDestination(),
                                      directMessagesUnreadCount:
                                          _directMessagesUnreadCount(
                                        notificationState,
                                      ),
                                      onSelectDestination:
                                          _showWorkspaceDestination,
                                    ),
                                  ServersInitialState() ||
                                  ServersLoadingState() ||
                                  ServersExceptionState() =>
                                    ServersPaneWidget(
                                      createController: createServerController,
                                      selectedDestination:
                                          const NoServerSelectedWorkspaceDestination(),
                                      directMessagesUnreadCount:
                                          _directMessagesUnreadCount(
                                        notificationState,
                                      ),
                                      onSelectDestination:
                                          _showWorkspaceDestination,
                                    ),
                                },
                              ),
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

  Future<void> _showNotificationFeedSheet(BuildContext context) async {
    final notificationCenterBloc = context.read<NotificationCenterBloc>();
    final serversBloc = context.read<ServersBloc>();
    final channelsBloc = context.read<ChannelsBloc>();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return MultiBlocProvider(
            providers: [
              BlocProvider<NotificationCenterBloc>.value(
                value: notificationCenterBloc,
              ),
              BlocProvider<ServersBloc>.value(
                value: serversBloc,
              ),
              BlocProvider<ChannelsBloc>.value(
                value: channelsBloc,
              ),
            ],
            child: SafeArea(
              child:
                  BlocBuilder<NotificationCenterBloc, NotificationCenterState>(
                builder: (context, state) {
                  final entries = state.entries;

                  if (entries.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text("No recent notifications."),
                      ),
                    );
                  }

                  return Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: <Widget>[
                            const Text(
                              "Recent notifications",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context
                                  .read<NotificationCenterBloc>()
                                  .add(
                                      const NotificationCenterFeedClearedRequested()),
                              child: const Text("Clear"),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];

                            return ListTile(
                              title: Text(_notificationEntryTitle(entry)),
                              onTap: () => _openNotificationFeedEntry(
                                context,
                                entry,
                              ),
                              subtitle: Text(
                                _notificationEntrySubtitle(entry),
                              ),
                              trailing: Text(_notificationEntryTime(entry)),
                              dense: true,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ));
      },
    );
  }

  String _notificationEntryTitle(NotificationCenterEntry entry) {
    return switch (entry.event) {
      UnreadMessageRuntimeNotificationEvent() => "New unread message",
      MentionedRuntimeNotificationEvent() => "You were mentioned",
      FriendJoinedVoiceRuntimeNotificationEvent(:final joinedUserDisplayName) =>
        "$joinedUserDisplayName joined voice",
    };
  }

  String _notificationEntrySubtitle(NotificationCenterEntry entry) {
    return "${entry.event.channelName} / ${entry.event.serverName}";
  }

  void _openNotificationFeedEntry(
    BuildContext context,
    NotificationCenterEntry entry,
  ) {
    final serverId = ServerId(entry.event.serverId.trim());
    final serversBloc = context.read<ServersBloc>();
    final channelsBloc = context.read<ChannelsBloc>();

    Navigator.of(context).pop();

    _showServerWorkspace();

    serversBloc.add(
      SelectServerRequested(serverId: serverId),
    );

    final channelsState = channelsBloc.state;

    final hasTargetLoaded = channelsState is ChannelsLoadedDataState &&
        channelsState.serverId == serverId &&
        channelsState.textChannels.any(
          (channel) => channel.id.value == entry.event.channelId,
        );

    if (hasTargetLoaded) {
      channelsBloc.add(
        SelectTextChannelRequested(channelId: ChannelId(entry.event.channelId)),
      );
      return;
    }

    _pendingNotificationChannelTarget = _NotificationChannelTarget(
      serverId: serverId,
      channelId: ChannelId(entry.event.channelId),
    );

    channelsBloc.add(LoadChannelsRequested(serverId: serverId));
  }

  String _notificationEntryTime(NotificationCenterEntry entry) {
    final localTime = entry.receivedAt.toLocal();
    final hour = localTime.hour.toString().padLeft(2, "0");
    final minute = localTime.minute.toString().padLeft(2, "0");

    return "$hour:$minute";
  }
}

final class _NotificationChannelTarget {
  const _NotificationChannelTarget({
    required this.serverId,
    required this.channelId,
  });

  final ServerId serverId;
  final ChannelId channelId;
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

class _NotificationFeedIconButton extends StatelessWidget {
  const _NotificationFeedIconButton({
    required this.feedEntryCount,
    required this.onPressed,
  });

  final int feedEntryCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final semanticCount = switch (feedEntryCount) {
      < 0 => 0,
      > 99 => 99,
      _ => feedEntryCount,
    };

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        IconButton(
          onPressed: onPressed,
          tooltip: "Notification feed",
          icon: const Icon(Icons.notifications),
        ),
        if (feedEntryCount > 0)
          Positioned(
            top: 8,
            right: 6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                semanticCount > 99 ? "99+" : "$semanticCount",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
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
