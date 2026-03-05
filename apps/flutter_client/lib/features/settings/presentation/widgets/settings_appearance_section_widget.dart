import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";

class SettingsAppearanceSectionWidget extends StatelessWidget {
  const SettingsAppearanceSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final isDarkModeEnabled = switch (settingsState) {
          SettingsLoadedState(:final isDarkModeEnabled) => isDarkModeEnabled,
          SettingsExceptionState(:final isDarkModeEnabled) => isDarkModeEnabled,
          _ => false,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              "Appearance",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              "Dark mode applies immediately and is remembered on this device.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Enable dark mode"),
              value: isDarkModeEnabled,
              onChanged: (enabled) {
                context.read<SettingsBloc>().add(
                      SettingsDarkModeToggledRequested(enabled: enabled),
                    );
              },
            ),
            if (settingsState case SettingsExceptionState(:final error))
              Text(
                "Could not save appearance setting: $error",
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
