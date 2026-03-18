import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/channels/presentation/widgets/channels_pane_widget.dart";
import "package:polyphony_flutter_client/features/direct_messages/bloc/direct_messages_bloc.dart";
import "package:polyphony_flutter_client/features/direct_messages/presentation/widgets/direct_messages_pane_widget.dart";
import "package:polyphony_flutter_client/features/friends/presentation/widgets/friends_pane_widget.dart";
import "package:polyphony_flutter_client/features/messages/presentation/widgets/messages_pane_widget.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/servers/presentation/widgets/server_users_pane_widget.dart";
import "package:polyphony_flutter_client/features/voice_sessions/presentation/widgets/voice_participants_pane_widget.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/pane_placeholder_widget.dart";

enum HomeWorkspaceMode {
  server,
  directMessages,
}

class HomeWorkspaceWidget extends StatelessWidget {
  const HomeWorkspaceWidget({
    required this.createChannelController,
    required this.createMessageController,
    required this.workspaceMode,
    super.key,
  });

  final TextEditingController createChannelController;
  final TextEditingController createMessageController;
  final HomeWorkspaceMode workspaceMode;

  Widget _buildPrimaryPane() {
    return BlocBuilder<ChannelsBloc, ChannelsState>(
      builder: (context, channelsState) {
        final selectionMode = switch (channelsState) {
          ChannelsLoadedDataState(:final selectionMode) => selectionMode,
          _ => ChannelSelectionMode.text,
        };

        return switch (selectionMode) {
          ChannelSelectionMode.voice => const VoiceParticipantsPaneWidget(),
          ChannelSelectionMode.text => MessagesPaneWidget(
              createController: createMessageController,
            ),
        };
      },
    );
  }

  Widget _buildDirectMessagesWorkspace(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 320,
          child: FriendsPaneWidget(
            onStartDirectMessage: (userId) {
              context.read<DirectMessagesBloc>().add(
                    OpenDirectMessageThreadRequested(userId: userId),
                  );
            },
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: DirectMessagesPaneWidget(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (workspaceMode == HomeWorkspaceMode.directMessages) {
      return _buildDirectMessagesWorkspace(context);
    }

    return BlocBuilder<ServersBloc, ServersState>(
      builder: (context, serversState) {
        final loadedData =
            serversState is ServersLoadedDataState ? serversState : null;
        final selectedServerId = loadedData?.selectedServerId;
        final selectedServerName = loadedData?.servers
            .firstWhereOrNull((server) => server.id == selectedServerId)
            ?.name;

        if (selectedServerId == null) {
          return const PanePlaceholderWidget(
            icon: Icons.dns_outlined,
            message: "Select a server to view channels and messages.",
            subtitle: "Choose a server from the left to get started.",
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 1100;

            if (isCompact) {
              return Column(
                children: <Widget>[
                  Flexible(
                    flex: 3,
                    child: ChannelsPaneWidget(
                      createController: createChannelController,
                      serverName: selectedServerName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    flex: 5,
                    child: _buildPrimaryPane(),
                  ),
                  const SizedBox(height: 12),
                  const Flexible(
                    flex: 2,
                    child: ServerUsersPaneWidget(),
                  ),
                ],
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
                  child: _buildPrimaryPane(),
                ),
                const SizedBox(width: 12),
                const SizedBox(
                  width: 320,
                  child: ServerUsersPaneWidget(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
