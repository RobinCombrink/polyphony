import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/home/presentation/widgets/workspace_destination.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_preferences_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/servers/presentation/widgets/servers_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_notification_preferences_section_widget.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/something_went_wrong_widget.dart";
import "package:skeletonizer/skeletonizer.dart";

class ServersPaneWidget extends StatefulWidget {
  const ServersPaneWidget({
    required this.createController,
    required this.selectedDestination,
    required this.directMessagesUnreadCount,
    required this.onSelectDestination,
    super.key,
  });

  final TextEditingController createController;
  final WorkspaceDestination selectedDestination;
  final int directMessagesUnreadCount;
  final ValueChanged<WorkspaceDestination> onSelectDestination;

  @override
  State<ServersPaneWidget> createState() => _ServersPaneWidgetState();
}

class _ServersPaneWidgetState extends State<ServersPaneWidget> {
  Future<void> _showAddUserToServerDialog(ServerId serverId) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Add user to server"),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            decoration: const InputDecoration(labelText: "User id"),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text("Add user"),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    context.read<ServerMembersBloc>().add(
          AddServerMemberRequested(
            serverId: serverId,
            userId: UserId(result),
          ),
        );
  }

  Future<void> _showDeleteServerConfirmationDialog(Server server) async {
    final controller = TextEditingController();
    var matchesName = false;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text("Delete server"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Type ${server.name} to confirm deletion.",
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) {
                      setDialogState(() {
                        matchesName = value.trim() == server.name;
                      });
                    },
                    onSubmitted: (_) {
                      if (matchesName) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: "Server name",
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: matchesName
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text("Delete"),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    context.read<ServersBloc>().add(
          DeleteServerRequested(serverId: server.id),
        );
  }

  Future<void> _showInviteFriendToServerDialog(ServerId serverId) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Invite friend to server"),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            decoration: const InputDecoration(labelText: "Friend user id"),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text("Invite"),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    context.read<ServerMembersBloc>().add(
          InviteFriendToServerRequested(
            serverId: serverId,
            friendUserId: UserId(result),
          ),
        );
  }

  Future<void> _showRenameServerDialog(Server server) async {
    final controller = TextEditingController(text: server.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final canRename = controller.text.trim().isNotEmpty &&
                controller.text.trim() != server.name;

            return AlertDialog(
              title: const Text("Rename server"),
              content: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setDialogState(() {}),
                onSubmitted: (_) {
                  if (canRename) {
                    Navigator.of(dialogContext).pop(controller.text);
                  }
                },
                decoration: const InputDecoration(labelText: "Server name"),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: canRename
                      ? () => Navigator.of(dialogContext).pop(controller.text)
                      : null,
                  child: const Text("Rename"),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || newName == null) {
      return;
    }

    context.read<ServersBloc>().add(
          UpdateServerNameRequested(
            serverId: server.id,
            name: newName,
          ),
        );
  }

  Future<void> _showServerNotificationPreferencesDialog(Server server) async {
    final notificationPreferencesBloc =
        context.read<NotificationPreferencesBloc>()
          ..add(
            LoadNotificationPreferencesRequested(
              serverId: server.id,
              channelId: null,
            ),
          );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return BlocProvider<NotificationPreferencesBloc>.value(
          value: notificationPreferencesBloc,
          child: Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SettingsNotificationPreferencesSectionWidget(
                  selectedServerId: server.id,
                  showGlobal: false,
                  showChannel: false,
                  title: "Server notification preferences",
                  description: "Control notifications for this server.",
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Server> _skeletonServers() {
    return List<Server>.generate(
      6,
      (index) => Server(
        id: ServerId("srv-skeleton-$index"),
        name: "Server ${index + 1}",
        ownerUserId: const UserId("owner-skeleton"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = switch (context.watch<ProfileBloc>().state) {
      ProfileLoadedDataState(:final userId) => userId,
      _ => null,
    };

    return BlocListener<ServersBloc, ServersState>(
      listenWhen: (previous, current) {
        return switch ((previous, current)) {
          (
            ServerSelected(:final selectedServer),
            ServerSelected(selectedServer: final currentSelectedServer),
          ) =>
            selectedServer.id != currentSelectedServer.id,
          (
            NoServerSelected(),
            NoServerSelected(),
          ) =>
            false,
          (
            ServersLoadedState(),
            ServersLoadedState(),
          ) =>
            true,
          _ => false,
        };
      },
      listener: (context, state) {
        switch (state) {
          case ServerSelected(:final selectedServer):
            context.read<MessagesBloc>().add(const ResetMessagesRequested());
            context.read<ChannelsBloc>().add(const ResetChannelsRequested());
            context
                .read<ChannelsBloc>()
                .add(LoadChannelsRequested(serverId: selectedServer.id));
          case NoServerSelected() || ServersValidationFailedState():
            return;
          default:
            return;
        }
      },
      child: BlocBuilder<ServersBloc, ServersState>(
        builder: (context, serversState) {
          final isLoading = serversState is ServersInitialState ||
              serversState is ServersLoadingState;
          final loadedData =
              serversState is ServersLoadedState ? serversState : null;
          final errorMessage = serversState is ServersExceptionState
              ? serversState.error.toString()
              : null;

          if (errorMessage != null) {
            return SomethingWentWrongWidget(message: errorMessage);
          }

          final servers = loadedData?.servers ?? const <Server>[];
          final visibleServers =
              isLoading && servers.isEmpty ? _skeletonServers() : servers;

          return Skeletonizer(
            enabled: isLoading,
            child: ServersSectionWidget(
              servers: visibleServers,
              selectedDestination: widget.selectedDestination,
              directMessagesUnreadCount: widget.directMessagesUnreadCount,
              currentUserId: currentUserId,
              isLoading: isLoading,
              createController: widget.createController,
              onSelectDirectMessages: () => widget.onSelectDestination(
                const DirectMessageWorkspaceDestination(),
              ),
              onTap: (server) {
                context
                    .read<ServersBloc>()
                    .add(SelectServerRequested(serverId: server.id));
                widget.onSelectDestination(
                  ServerSelectedWorkspaceDestination(serverId: server.id.value),
                );
              },
              onAddUser: (server) => _showAddUserToServerDialog(server.id),
              onInviteFriend: (server) =>
                  _showInviteFriendToServerDialog(server.id),
              onNotificationPreferences: (server) =>
                  unawaited(_showServerNotificationPreferencesDialog(server)),
              onRenameServer: (server) =>
                  unawaited(_showRenameServerDialog(server)),
              onDeleteServer: (server) =>
                  unawaited(_showDeleteServerConfirmationDialog(server)),
              onCreate: () => context.read<ServersBloc>().add(
                    CreateServerRequested(
                      serverName: widget.createController.text,
                    ),
                  ),
            ),
          );
        },
      ),
    );
  }
}
