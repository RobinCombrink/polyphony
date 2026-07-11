import "dart:async";

import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/channels/presentation/widgets/channel_pane_widget.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_preferences_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/servers/presentation/pages/server_settings_page.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_notification_preferences_section_widget.dart";
import "package:polyphony_flutter_client/features/voice_sessions/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/something_went_wrong_widget.dart";
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
  var _lastVisibleVoiceChannelIdsKey = "";

  ChannelId? _selectedTextChannelId(ChannelsState state) {
    return switch (state) {
      TextChannelSelected(:final selectedTextChannel) => selectedTextChannel.id,
      TextChannelSelectedValidationFailedState(
        :final selectedTextChannel,
      ) =>
        selectedTextChannel.id,
      _ => null,
    };
  }

  ChannelId? _selectedChannelId(ChannelsLoadedDataState state) {
    return switch (state) {
      TextChannelSelected(:final selectedTextChannel) => selectedTextChannel.id,
      VoiceChannelSelected(:final selectedVoiceChannel) =>
        selectedVoiceChannel.id,
      TextChannelSelectedValidationFailedState(
        :final selectedTextChannel,
      ) =>
        selectedTextChannel.id,
      VoiceChannelSelectedValidationFailedState(
        :final selectedVoiceChannel,
      ) =>
        selectedVoiceChannel.id,
      _ => null,
    };
  }

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
        id: ChannelId("txt-skeleton-$index"),
        serverId: const ServerId("srv-skeleton"),
        name: "channel-${index + 1}",
      ),
    );
  }

  void _createChannel({
    required BuildContext context,
    required ServerId serverId,
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

  Future<void> _showRenameChannelDialog(
    BuildContext context,
    Channel channel,
  ) async {
    final controller = TextEditingController(text: channel.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final canRename = controller.text.trim().isNotEmpty &&
                controller.text.trim() != channel.name;

            return AlertDialog(
              title: const Text("Rename channel"),
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
                decoration: const InputDecoration(labelText: "Channel name"),
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

    if (!context.mounted || newName == null) {
      return;
    }

    context.read<ChannelsBloc>().add(
          UpdateChannelNameRequested(
            channelId: channel.id,
            name: newName,
          ),
        );
  }

  void _openServerSettings(BuildContext context, Server server) {
    unawaited(Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<ServersBloc>.value(
          value: context.read<ServersBloc>(),
          child: ServerSettingsPage(server: server),
        ),
      ),
    ));
  }

  Future<void> _showChannelNotificationPreferencesDialog(
    BuildContext context,
    Channel channel,
  ) async {
    final notificationPreferencesBloc =
        context.read<NotificationPreferencesBloc>()
          ..add(
            LoadNotificationPreferencesRequested(
              serverId: null,
              channelId: channel.id,
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
                  selectedChannelId: channel.id,
                  showGlobal: false,
                  showServer: false,
                  title: "Channel notification preferences",
                  description: "Control notifications for this channel.",
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = switch (context.watch<ProfileBloc>().state) {
      ProfileLoadedDataState(:final userId) => userId,
      _ => null,
    };
    final selectedServerOwnerUserId =
        switch (context.watch<ServersBloc>().state) {
      ServerSelected(:final servers, :final selectedServer) => servers
          .firstWhereOrNull((server) => server.id == selectedServer.id)
          ?.ownerUserId,
      _ => null,
    };
    final canDeleteChannels =
        currentUserId != null && currentUserId == selectedServerOwnerUserId;
    final canRenameChannels = canDeleteChannels;
    final selectedServer = switch (context.watch<ServersBloc>().state) {
      ServerSelected(:final selectedServer) => selectedServer,
      _ => null,
    };

    return BlocListener<ChannelsBloc, ChannelsState>(
      listenWhen: (previous, current) {
        final previousSelectedTextChannelId = _selectedTextChannelId(previous);
        final currentSelectedTextChannelId = _selectedTextChannelId(current);

        return previousSelectedTextChannelId != currentSelectedTextChannelId;
      },
      listener: (context, state) {
        final selectedTextChannelId = _selectedTextChannelId(state);

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
            _ => const <ChannelId, List<VoiceParticipant>>{},
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
                      TextChannel() => const <ChannelId>[],
                      VoiceChannel() => <ChannelId>[channel.id],
                    },
                  )
                  .where((channelId) => channelId.value.isNotEmpty)
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
                  selectedChannelId: loadedData == null
                      ? null
                      : _selectedChannelId(loadedData),
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
                    serverId: loadedData?.serverId ?? const ServerId(""),
                    channelName: channelName,
                    channelType: channelType,
                  ),
                  onDeleteChannel: canDeleteChannels
                      ? (channel) => unawaited(
                            _showDeleteChannelConfirmationDialog(
                              context,
                              channel,
                            ),
                          )
                      : null,
                  onRenameChannel: canRenameChannels
                      ? (channel) => unawaited(
                            _showRenameChannelDialog(
                              context,
                              channel,
                            ),
                          )
                      : null,
                  onNotificationPreferences: (channel) => unawaited(
                    _showChannelNotificationPreferencesDialog(context, channel),
                  ),
                  onTitleTap: selectedServer != null && canDeleteChannels
                      ? () => _openServerSettings(context, selectedServer)
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
