import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/channels/presentation/widgets/channels_pane_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/messages_pane_widget.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/servers/presentation/widgets/server_users_pane_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/voice_participants_pane_widget.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

class ServerWorkspaceWidget extends StatelessWidget {
  const ServerWorkspaceWidget({
    required this.createChannelController,
    required this.createMessageController,
    super.key,
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
