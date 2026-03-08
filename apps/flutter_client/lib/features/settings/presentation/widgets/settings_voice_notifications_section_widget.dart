import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";

class SettingsVoiceNotificationsSectionWidget extends StatelessWidget {
  const SettingsVoiceNotificationsSectionWidget({super.key});

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
