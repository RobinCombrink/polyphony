import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/channel_pane_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/something_went_wrong_widget.dart";
import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:skeletonizer/skeletonizer.dart";

class ChannelsPaneWidget extends StatefulWidget {
  const ChannelsPaneWidget({
    required this.createController,
    required this.serverName,
    super.key,
  });

  final TextEditingController createController;
  final String? serverName;

  @override
  State<ChannelsPaneWidget> createState() => _ChannelsPaneWidgetState();
}

class _ChannelsPaneWidgetState extends State<ChannelsPaneWidget> {
  String _lastVisibleVoiceChannelIdsKey = "";

  void _onTextChannelTapped(BuildContext context, TextChannel channel) {
    context.read<ChannelsBloc>().add(
          SelectTextChannelRequested(
            channelId: channel.id,
          ),
        );
  }

  void _onVoiceChannelTapped(BuildContext context, VoiceChannel channel) {
    context.read<ChannelsBloc>().add(
          SelectVoiceChannelRequested(
            channelId: channel.id,
          ),
        );
    context.read<VoiceSessionsBloc>().add(
          LoadVoiceSessionsRequested(
            channelId: channel.id,
          ),
        );
    context.read<VoiceSessionsBloc>().add(
          ConnectVoiceSessionRequested(
            channelId: channel.id,
          ),
        );
  }

  List<Channel> _skeletonChannels() {
    return List<Channel>.generate(
      6,
      (index) => TextChannel(
        id: "txt-skeleton-$index",
        serverId: "srv-skeleton",
        name: "channel-${index + 1}",
      ),
    );
  }

  void _createChannel({
    required BuildContext context,
    required String serverId,
    required String channelName,
    required ChannelType channelType,
  }) {
    context.read<ChannelsBloc>().add(
          CreateChannelRequested(
            serverId: serverId,
            channelName: channelName,
            channelType: channelType,
          ),
        );
  }

  Future<void> _showDeleteChannelConfirmationDialog(
    BuildContext context,
    Channel channel,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete channel"),
          content: Text(
            "Are you sure you want to delete ${channel.name}?",
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (!context.mounted || shouldDelete != true) {
      return;
    }

    context.read<ChannelsBloc>().add(
          DeleteChannelRequested(channelId: channel.id),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChannelsBloc, ChannelsState>(
      listenWhen: (previous, current) {
        final previousSelectedTextChannelId = switch (previous) {
          ChannelsLoadedDataState(:final selectedTextChannelId) =>
            selectedTextChannelId,
          _ => null,
        };
        final currentSelectedTextChannelId = switch (current) {
          ChannelsLoadedDataState(:final selectedTextChannelId) =>
            selectedTextChannelId,
          _ => null,
        };

        return previousSelectedTextChannelId != currentSelectedTextChannelId;
      },
      listener: (context, state) {
        final selectedTextChannelId = switch (state) {
          ChannelsLoadedDataState(:final selectedTextChannelId) =>
            selectedTextChannelId,
          _ => null,
        };

        if (selectedTextChannelId == null) {
          context.read<MessagesBloc>().add(const ResetMessagesRequested());
          return;
        }

        context.read<MessagesBloc>().add(
              LoadMessagesRequested(channelId: selectedTextChannelId),
            );
      },
      child: BlocBuilder<VoiceSessionsBloc, VoiceSessionsState>(
        builder: (context, voiceSessionsState) {
          final activeVoiceChannelId = switch (voiceSessionsState) {
            VoiceSessionsLoadedDataState(:final connectedChannelId) =>
              connectedChannelId,
            _ => null,
          };
          final voiceParticipantsByChannelId = switch (voiceSessionsState) {
            VoiceSessionsLoadedDataState(:final participantsByChannelId) =>
              participantsByChannelId,
            _ => const <String, List<VoiceParticipant>>{},
          };
          final selfParticipantUserId = switch (voiceSessionsState) {
            VoiceSessionsLoadedDataState(:final activeConnection) =>
              activeConnection?.participantUserId,
            _ => null,
          };
          final isSelfDeafened = switch (voiceSessionsState) {
            VoiceSessionsLoadedDataState(:final isSelfDeafened) =>
              isSelfDeafened,
            _ => false,
          };

          return BlocBuilder<ChannelsBloc, ChannelsState>(
            builder: (context, channelsState) {
              final isLoading = channelsState is ChannelsInitialState ||
                  channelsState is ChannelsLoadingState;
              final loadedData = channelsState is ChannelsLoadedDataState
                  ? channelsState
                  : null;
              final errorMessage = channelsState is ChannelsExceptionState
                  ? channelsState.error.toString()
                  : null;

              if (errorMessage != null) {
                return SomethingWentWrongWidget(message: errorMessage);
              }

              final channels = loadedData == null
                  ? const <Channel>[]
                  : <Channel>[
                      ...loadedData.textChannels,
                      ...loadedData.voiceChannels,
                    ];
              final visibleChannels = isLoading && channels.isEmpty
                  ? _skeletonChannels()
                  : channels;

              final visibleVoiceChannelIds = visibleChannels
                  .expand(
                    (channel) => switch (channel) {
                      TextChannel() => const <String>[],
                      VoiceChannel() => <String>[channel.id],
                    },
                  )
                  .where((channelId) => channelId.isNotEmpty)
                  .toList();
              final visibleVoiceChannelIdsKey =
                  visibleVoiceChannelIds.join("|");

              if (!isLoading &&
                  _lastVisibleVoiceChannelIdsKey != visibleVoiceChannelIdsKey) {
                _lastVisibleVoiceChannelIdsKey = visibleVoiceChannelIdsKey;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }

                  context.read<VoiceSessionsBloc>().add(
                        RefreshVoiceParticipantsRequested(
                          channelIds: visibleVoiceChannelIds,
                        ),
                      );
                });
              }

              return Skeletonizer(
                enabled: isLoading,
                child: ChannelPaneWidget(
                  channels: visibleChannels,
                  selectedChannelId: switch (loadedData?.selectionMode) {
                    ChannelSelectionMode.voice =>
                      loadedData?.selectedVoiceChannelId,
                    ChannelSelectionMode.text =>
                      loadedData?.selectedTextChannelId,
                    null => null,
                  },
                  voiceParticipantCount: 0,
                  voiceParticipantsByChannelId: voiceParticipantsByChannelId,
                  connectedVoiceChannelId: activeVoiceChannelId,
                  selfParticipantUserId: selfParticipantUserId,
                  isSelfDeafened: isSelfDeafened,
                  isLoading: isLoading,
                  createController: widget.createController,
                  title: widget.serverName ?? "",
                  showCreateControls: !isLoading && channels.isEmpty,
                  onTap: (channel) => switch (channel) {
                    TextChannel() => _onTextChannelTapped(context, channel),
                    VoiceChannel() => _onVoiceChannelTapped(context, channel),
                  },
                  onCreateChannel: ({
                    required channelName,
                    required channelType,
                  }) =>
                      _createChannel(
                    context: context,
                    serverId: loadedData?.serverId ?? "",
                    channelName: channelName,
                    channelType: channelType,
                  ),
                  onDeleteChannel: (channel) => unawaited(
                    _showDeleteChannelConfirmationDialog(context, channel),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
