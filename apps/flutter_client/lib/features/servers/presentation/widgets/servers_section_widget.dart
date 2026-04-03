import "dart:async";

import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/home/presentation/widgets/workspace_destination.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/section_status.dart";

SectionStatus? buildServersSectionStatus(ServersState state) {
  if (state is ServersValidationFailedState) {
    return switch (state.issue) {
      ServersValidationIssue.serverNameRequired =>
        const SectionStatus(message: "Server name is required.", isError: true),
      ServersValidationIssue.serverSelectionRequired =>
        const SectionStatus(message: "Select a server first.", isError: true),
    };
  }

  if (state is ServersExceptionState) {
    return SectionStatus(
      message: "Server operation failed: ${state.error}",
      isError: true,
    );
  }

  if (state is ServersLoadedState && state.servers.isEmpty) {
    return const SectionStatus(
      message: "No servers found for this user.",
      isError: false,
    );
  }

  return null;
}

class ServersSectionWidget extends StatefulWidget {
  const ServersSectionWidget({
    required this.servers,
    required this.selectedDestination,
    required this.directMessagesUnreadCount,
    required this.currentUserId,
    required this.isLoading,
    required this.createController,
    required this.onSelectDirectMessages,
    required this.onTap,
    required this.onAddUser,
    required this.onInviteFriend,
    required this.onNotificationPreferences,
    required this.onRenameServer,
    required this.onDeleteServer,
    required this.onCreate,
    super.key,
  });

  final List<Server> servers;
  final WorkspaceDestination selectedDestination;
  final int directMessagesUnreadCount;
  final UserId? currentUserId;
  final bool isLoading;
  final TextEditingController createController;
  final VoidCallback onSelectDirectMessages;
  final void Function(Server server) onTap;
  final void Function(Server server) onAddUser;
  final void Function(Server server) onInviteFriend;
  final void Function(Server server) onNotificationPreferences;
  final void Function(Server server) onRenameServer;
  final void Function(Server server) onDeleteServer;
  final VoidCallback onCreate;

  @override
  State<ServersSectionWidget> createState() => _ServersSectionWidgetState();
}

class _ServersSectionWidgetState extends State<ServersSectionWidget> {
  var _isCreatingServer = false;
  var _isDirectMessagesHovered = false;
  ServerId? _hoveredServerId;

  void _openCreateServerInput() {
    setState(() {
      _isCreatingServer = true;
    });
  }

  void _submitCreateServer() {
    widget.onCreate();
    widget.createController.clear();

    setState(() {
      _isCreatingServer = false;
    });
  }

  void _cancelCreateServer() {
    widget.createController.clear();
    setState(() {
      _isCreatingServer = false;
    });
  }

  Future<void> _showServerContextMenu({
    required BuildContext context,
    required Server server,
    required Offset globalPosition,
  }) async {
    final errorColor = Theme.of(context).colorScheme.error;
    final canDeleteServer = widget.currentUserId == server.ownerUserId;

    await showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: <PopupMenuEntry<void>>[
        PopupMenuItem<void>(
          onTap: () => widget.onAddUser(server),
          child: const Text("Add user to server"),
        ),
        PopupMenuItem<void>(
          onTap: () => widget.onInviteFriend(server),
          child: const Text("Invite friend to server"),
        ),
        PopupMenuItem<void>(
          onTap: () => widget.onNotificationPreferences(server),
          child: const Text("Notification preferences"),
        ),
        if (canDeleteServer)
          PopupMenuItem<void>(
            onTap: () => widget.onRenameServer(server),
            child: const Text("Rename server"),
          ),
        if (canDeleteServer)
          PopupMenuItem<void>(
            onTap: () => widget.onDeleteServer(server),
            child: Text(
              "Delete server",
              style: TextStyle(color: errorColor),
            ),
          ),
      ],
    );
  }

  Widget _buildRailBadge(BuildContext context, int count) {
    final semanticCount = switch (count) {
      < 0 => 0,
      > 99 => 99,
      _ => count,
    };

    return Positioned(
      top: -2,
      right: -2,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 4),
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
    );
  }

  Widget _buildRailAvatar({
    required BuildContext context,
    required bool isSelected,
    required bool isHovered,
    required VoidCallback? onTap,
    required Widget child,
    String? tooltip,
    GestureLongPressCallback? onLongPress,
    GestureTapDownCallback? onSecondaryTapDown,
    int unreadCount = 0,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = switch ((isSelected, isHovered)) {
      (true, _) => colorScheme.primary,
      (false, true) => colorScheme.primary.withAlpha(170),
      _ => Colors.transparent,
    };
    final backgroundColor = switch ((isSelected, isHovered)) {
      (true, _) => colorScheme.primaryContainer,
      (false, true) => colorScheme.surfaceContainerHighest,
      _ => null,
    };
    final foregroundColor = switch ((isSelected, isHovered)) {
      (true, _) => colorScheme.onPrimaryContainer,
      (false, true) => colorScheme.onSurface,
      _ => null,
    };

    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        child: child,
      ),
    );

    final body = unreadCount > 0
        ? Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              avatar,
              _buildRailBadge(context, unreadCount),
            ],
          )
        : avatar;

    final interactive = InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapDown: onSecondaryTapDown,
      child: body,
    );

    if (tooltip == null) {
      return interactive;
    }

    return Tooltip(
      message: tooltip,
      child: interactive,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          if (_isCreatingServer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: widget.createController,
                autofocus: true,
                enabled: !widget.isLoading,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitCreateServer(),
                decoration: InputDecoration(
                  hintText: "Server",
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: "Cancel",
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: _cancelCreateServer,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: "Create server",
              onPressed: widget.isLoading ? null : _openCreateServerInput,
              icon: const Icon(Icons.add),
            ),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            child: MouseRegion(
              onEnter: (_) {
                setState(() {
                  _isDirectMessagesHovered = true;
                });
              },
              onExit: (_) {
                setState(() {
                  _isDirectMessagesHovered = false;
                });
              },
              child: _buildRailAvatar(
                context: context,
                tooltip: "Direct messages",
                isSelected: widget.selectedDestination
                    is DirectMessageWorkspaceDestination,
                isHovered: _isDirectMessagesHovered,
                unreadCount: widget.directMessagesUnreadCount,
                onTap: widget.isLoading ? null : widget.onSelectDirectMessages,
                child: const Icon(Icons.forum_outlined),
              ),
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: widget.servers.length,
              itemBuilder: (context, index) {
                final server = widget.servers[index];
                final isSelected = switch (widget.selectedDestination) {
                  ServerSelectedWorkspaceDestination(:final serverId) =>
                    serverId == server.id.value,
                  _ => false,
                };

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: MouseRegion(
                    onEnter: (_) {
                      setState(() {
                        _hoveredServerId = server.id;
                      });
                    },
                    onExit: (_) {
                      setState(() {
                        if (_hoveredServerId == server.id) {
                          _hoveredServerId = null;
                        }
                      });
                    },
                    child: _buildRailAvatar(
                      context: context,
                      tooltip: server.name,
                      isSelected: isSelected,
                      isHovered: _hoveredServerId == server.id,
                      onTap:
                          widget.isLoading ? null : () => widget.onTap(server),
                      onSecondaryTapDown: widget.isLoading
                          ? null
                          : (details) => _showServerContextMenu(
                                context: context,
                                server: server,
                                globalPosition: details.globalPosition,
                              ),
                      onLongPress: widget.isLoading
                          ? null
                          : () {
                              final renderObject = context.findRenderObject();
                              final globalPosition = switch (renderObject) {
                                final RenderBox box => box.localToGlobal(
                                    box.size.center(Offset.zero)),
                                _ => Offset.zero,
                              };

                              unawaited(
                                _showServerContextMenu(
                                  context: context,
                                  server: server,
                                  globalPosition: globalPosition,
                                ),
                              );
                            },
                      child: Text(
                        server.name.isEmpty
                            ? "S"
                            : server.name.substring(0, 1).toUpperCase(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
