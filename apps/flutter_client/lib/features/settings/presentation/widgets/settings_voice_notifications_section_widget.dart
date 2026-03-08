import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";

class SettingsVoiceNotificationsSectionWidget extends StatelessWidget {
  const SettingsVoiceNotificationsSectionWidget({super.key});

  Future<void> _showChannelFilterEditor(
    BuildContext context,
    List<String> channelIds,
  ) async {
    final settingsBloc = context.read<SettingsBloc>();
    final controller = TextEditingController(
      text: channelIds.join("\n"),
    );

    final submittedChannelIds = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Voice notification channels"),
          content: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: "One channel id per line",
              border: OutlineInputBorder(),
            ),
          ),
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
                final parsedChannelIds = controller.text
                    .split(RegExp(r"[,\n]"))
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .toList(growable: false);
                Navigator.of(dialogContext).pop(parsedChannelIds);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (submittedChannelIds == null) {
      return;
    }

    settingsBloc.add(
      SettingsChannelJoinNotificationChannelsSetRequested(
        channelIds: submittedChannelIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
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
