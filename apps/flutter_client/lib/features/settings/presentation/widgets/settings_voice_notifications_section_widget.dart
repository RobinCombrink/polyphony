import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/channels/channels.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";

final class _VoiceNotificationChannelOption {
  const _VoiceNotificationChannelOption({
    required this.id,
    required this.label,
    required this.isUnavailable,
  });

  final String id;
  final String label;
  final bool isUnavailable;
}

class SettingsVoiceNotificationsSectionWidget extends StatelessWidget {
  const SettingsVoiceNotificationsSectionWidget({super.key});

  Future<void> _showChannelFilterEditor(
    BuildContext context,
    List<String> channelIds,
    List<VoiceChannel> availableVoiceChannels,
  ) async {
    final settingsBloc = context.read<SettingsBloc>();
    final channelOptions = _buildChannelOptions(
      selectedChannelIds: channelIds,
      availableVoiceChannels: availableVoiceChannels,
    );
    var selectedChannelIdSet = channelIds.toSet();

    final submittedChannelIds = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Voice notification channels"),
              content: SizedBox(
                width: 440,
                child: channelOptions.isEmpty
                    ? const Text(
                        "No voice channels are currently loaded. Use all channels or load a server's channels first.",
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: channelOptions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final option = channelOptions[index];
                          return CheckboxListTile(
                            value: selectedChannelIdSet.contains(option.id),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked ?? false) {
                                  selectedChannelIdSet = <String>{
                                    ...selectedChannelIdSet,
                                    option.id,
                                  };
                                  return;
                                }

                                selectedChannelIdSet = selectedChannelIdSet
                                    .where(
                                        (channelId) => channelId != option.id)
                                    .toSet();
                              });
                            },
                            title: Text(option.label),
                            subtitle: option.isUnavailable
                                ? const Text(
                                    "Previously selected channel (currently unavailable)",
                                  )
                                : null,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actionsOverflowButtonSpacing: 8,
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(const <String>[]);
                  },
                  child: const Text("Use all channels"),
                ),
                FilledButton(
                  onPressed: () {
                    final orderedSelectedChannelIds = channelOptions
                        .where((option) =>
                            selectedChannelIdSet.contains(option.id))
                        .map((option) => option.id)
                        .toList(growable: false);
                    Navigator.of(dialogContext).pop(orderedSelectedChannelIds);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );

    if (submittedChannelIds == null) {
      return;
    }

    settingsBloc.add(
      SettingsChannelJoinNotificationChannelsSetRequested(
        channelIds: submittedChannelIds,
      ),
    );
  }

  List<_VoiceNotificationChannelOption> _buildChannelOptions({
    required List<String> selectedChannelIds,
    required List<VoiceChannel> availableVoiceChannels,
  }) {
    final availableById = <ChannelId, VoiceChannel>{
      for (final voiceChannel in availableVoiceChannels)
        voiceChannel.id: voiceChannel,
    };

    final availableOptions = availableVoiceChannels
        .map(
          (voiceChannel) => _VoiceNotificationChannelOption(
            id: voiceChannel.id.value,
            label: voiceChannel.name,
            isUnavailable: false,
          ),
        )
        .toList(growable: false);

    final unavailableSelectedOptions = selectedChannelIds
        .where((channelId) => !availableById.containsKey(ChannelId(channelId)))
        .map(
          (channelId) => _VoiceNotificationChannelOption(
            id: channelId,
            label: channelId,
            isUnavailable: true,
          ),
        )
        .toList(growable: false);

    return <_VoiceNotificationChannelOption>[
      ...availableOptions,
      ...unavailableSelectedOptions,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final channelsState = context.watch<ChannelsBloc>().state;
        final availableVoiceChannels = switch (channelsState) {
          ChannelsLoadedDataState(:final voiceChannels) => voiceChannels,
          _ => const <VoiceChannel>[],
        };

        final isChannelJoinNotificationsEnabled = switch (settingsState) {
          SettingsLoadedState(:final isChannelJoinNotificationsEnabled) =>
            isChannelJoinNotificationsEnabled,
          SettingsExceptionState(:final isChannelJoinNotificationsEnabled) =>
            isChannelJoinNotificationsEnabled,
          _ => false,
        };
        final channelJoinNotificationChannelIds = switch (settingsState) {
          SettingsLoadedState(:final channelJoinNotificationChannelIds) =>
            channelJoinNotificationChannelIds,
          SettingsExceptionState(:final channelJoinNotificationChannelIds) =>
            channelJoinNotificationChannelIds,
          _ => const <String>[],
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              "Voice notifications",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              "Channel join notifications are disabled by default.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Enable channel join notifications"),
              value: isChannelJoinNotificationsEnabled,
              onChanged: (enabled) {
                context.read<SettingsBloc>().add(
                      SettingsChannelJoinNotificationsToggledRequested(
                        enabled: enabled,
                      ),
                    );
              },
            ),
            const SizedBox(height: 8),
            Text(
              "Selected channels",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              channelJoinNotificationChannelIds.isEmpty
                  ? "All voice channels are allowed."
                  : "${channelJoinNotificationChannelIds.length} channel(s) selected.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: isChannelJoinNotificationsEnabled
                  ? () => _showChannelFilterEditor(
                        context,
                        channelJoinNotificationChannelIds,
                        availableVoiceChannels,
                      )
                  : null,
              child: const Text("Select voice channels"),
            ),
            if (settingsState case SettingsExceptionState(:final error))
              Text(
                "Could not save voice notification setting: $error",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
          ],
        );
      },
    );
  }
}
