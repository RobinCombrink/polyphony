import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/servers/presentation/widgets/servers_section_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/something_went_wrong_widget.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:skeletonizer/skeletonizer.dart";

class ServersPaneWidget extends StatefulWidget {
  const ServersPaneWidget({
    required this.createController,
    super.key,
  });

  final TextEditingController createController;

  @override
  State<ServersPaneWidget> createState() => _ServersPaneWidgetState();
}

class _ServersPaneWidgetState extends State<ServersPaneWidget> {
  Future<void> _showAddUserToServerDialog(String serverId) async {
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

    context.read<ServersBloc>().add(
          AddServerMemberRequested(
            serverId: serverId,
            userId: result,
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

  List<Server> _skeletonServers() {
    return List<Server>.generate(
      6,
      (index) => Server(
        id: "srv-skeleton-$index",
        name: "Server ${index + 1}",
        ownerUserId: "owner-skeleton",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ServersBloc, ServersState>(
      listenWhen: (previous, current) {
        final previousSelectedServerId = switch (previous) {
          ServersLoadedDataState(:final selectedServerId) => selectedServerId,
          _ => null,
        };
        final currentSelectedServerId = switch (current) {
          ServersLoadedDataState(:final selectedServerId) => selectedServerId,
          _ => null,
        };

        return previousSelectedServerId != currentSelectedServerId;
      },
      listener: (context, state) {
        final selectedServerId = switch (state) {
          ServersLoadedDataState(:final selectedServerId) => selectedServerId,
          _ => null,
        };

        if (selectedServerId == null) {
          return;
        }

        context.read<MessagesBloc>().add(const ResetMessagesRequested());
        context.read<ChannelsBloc>().add(const ResetChannelsRequested());
        context
            .read<ChannelsBloc>()
            .add(LoadChannelsRequested(serverId: selectedServerId));
      },
      child: BlocBuilder<ServersBloc, ServersState>(
        builder: (context, serversState) {
          final isLoading = serversState is ServersInitialState ||
              serversState is ServersLoadingState;
          final loadedData =
              serversState is ServersLoadedDataState ? serversState : null;
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
              selectedServerId: loadedData?.selectedServerId,
              isLoading: isLoading,
              createController: widget.createController,
              onTap: (server) {
                context
                    .read<ServersBloc>()
                    .add(SelectServerRequested(serverId: server.id));
              },
              onAddUser: (server) => _showAddUserToServerDialog(server.id),
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
