import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";

class SettingsAudioDevicesSectionWidget extends StatelessWidget {
  const SettingsAudioDevicesSectionWidget({super.key});

  String _audioDeviceLabel(RuntimeAudioDevice device) {
    if (!device.isSystemDefault) {
      return device.label;
    }

    return "System Default (${device.label})";
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final audioInputDevices = switch (settingsState) {
          SettingsLoadedState(:final audioInputDevices) => audioInputDevices,
          SettingsExceptionState(:final audioInputDevices) => audioInputDevices,
          _ => const <RuntimeAudioDevice>[],
        };
        final audioOutputDevices = switch (settingsState) {
          SettingsLoadedState(:final audioOutputDevices) => audioOutputDevices,
          SettingsExceptionState(:final audioOutputDevices) =>
            audioOutputDevices,
          _ => const <RuntimeAudioDevice>[],
        };
        final selectedAudioInputDeviceId = switch (settingsState) {
          SettingsLoadedState(:final selectedAudioInputDeviceId) =>
            selectedAudioInputDeviceId,
          SettingsExceptionState(:final selectedAudioInputDeviceId) =>
            selectedAudioInputDeviceId,
          _ => null,
        };
        final selectedAudioOutputDeviceId = switch (settingsState) {
          SettingsLoadedState(:final selectedAudioOutputDeviceId) =>
            selectedAudioOutputDeviceId,
          SettingsExceptionState(:final selectedAudioOutputDeviceId) =>
            selectedAudioOutputDeviceId,
          _ => null,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              "Audio devices",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              "Choose your preferred microphone and speaker. Changes apply immediately and are remembered.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: selectedAudioInputDeviceId,
              decoration: const InputDecoration(
                labelText: "Input device",
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  child: Text("Automatic (Follow system default)"),
                ),
                ...audioInputDevices.map(
                  (device) => DropdownMenuItem<String?>(
                    value: device.id,
                    child: Text(_audioDeviceLabel(device)),
                  ),
                ),
              ],
              onChanged: (selectedDeviceId) {
                context.read<SettingsBloc>().add(
                      SettingsAudioInputDeviceSetRequested(
                        deviceId: selectedDeviceId,
                      ),
                    );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: selectedAudioOutputDeviceId,
              decoration: const InputDecoration(
                labelText: "Output device",
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  child: Text("Automatic (Follow system default)"),
                ),
                ...audioOutputDevices.map(
                  (device) => DropdownMenuItem<String?>(
                    value: device.id,
                    child: Text(_audioDeviceLabel(device)),
                  ),
                ),
              ],
              onChanged: (selectedDeviceId) {
                context.read<SettingsBloc>().add(
                      SettingsAudioOutputDeviceSetRequested(
                        deviceId: selectedDeviceId,
                      ),
                    );
              },
            ),
            if (audioInputDevices.isEmpty ||
                audioOutputDevices.isEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                "Some devices may only appear after granting microphone permissions.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (settingsState
                case SettingsExceptionState(:final error)) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                "Could not save audio device setting: $error",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
          ],
        );
      },
    );
  }
}
