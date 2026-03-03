import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/reducers/keybinding_reducer.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

class SettingsKeybindingsSectionWidget extends StatefulWidget {
  const SettingsKeybindingsSectionWidget({super.key});

  @override
  State<SettingsKeybindingsSectionWidget> createState() =>
      _SettingsKeybindingsSectionWidgetState();
}

class _SettingsKeybindingsSectionWidgetState
    extends State<SettingsKeybindingsSectionWidget> {
  KeybindingChord? _muteKeybind;
  KeybindingChord? _deafenKeybind;

  @override
  void initState() {
    super.initState();
    unawaited(_loadKeybindingsPreferences());
  }

  Future<void> _loadKeybindingsPreferences() async {
    final keybindingsPreferences =
        await context.read<PreferencesStore>().readKeybindingsPreferences();

    if (!mounted) {
      return;
    }

    setState(() {
      _muteKeybind = keybindingsPreferences.mute;
      _deafenKeybind = keybindingsPreferences.deafen;
    });
  }

  Future<void> _saveKeybindings() async {
    await context.read<PreferencesStore>().writeKeybindingsPreferences(
          KeybindingsPreferences(
            mute: _muteKeybind,
            deafen: _deafenKeybind,
          ),
        );

    if (!mounted) {
      return;
    }

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Keybindings saved")),
    );
  }

  Future<void> _captureMuteKeybind() async {
    final capturedKeybind = await _showKeybindCaptureDialog();
    if (capturedKeybind == null || !mounted) {
      return;
    }

    setState(() {
      _muteKeybind = capturedKeybind;
    });
  }

  Future<void> _captureDeafenKeybind() async {
    final capturedKeybind = await _showKeybindCaptureDialog();
    if (capturedKeybind == null || !mounted) {
      return;
    }

    setState(() {
      _deafenKeybind = capturedKeybind;
    });
  }

  Future<KeybindingChord?> _showKeybindCaptureDialog() {
    return showDialog<KeybindingChord?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Focus(
          autofocus: true,
          onKeyEvent: (_, keyEvent) {
            if (keyEvent is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }

            if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(dialogContext).pop();
              return KeyEventResult.handled;
            }

            final keybind = reduceCapturedKeybindingChord(
              logicalKey: keyEvent.logicalKey,
              modifiers: keybindingModifierStateFromKeyboard(
                HardwareKeyboard.instance,
              ),
            );
            if (keybind == null) {
              return KeyEventResult.ignored;
            }

            Navigator.of(dialogContext).pop(keybind);
            return KeyEventResult.handled;
          },
          child: AlertDialog(
            title: const Text("Press keybind"),
            content:
                const Text("Press your desired key combination. Esc cancels."),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text("Cancel"),
              ),
            ],
          ),
        );
      },
    );
  }

  String _resolveKeyLabel(int keyId) {
    return LogicalKeyboardKey.findKeyByKeyId(keyId)?.keyLabel ?? "";
  }

  String _keybindLabel(KeybindingChord? keybind) {
    return keybindingChordLabel(
      chord: keybind,
      resolveKeyLabel: _resolveKeyLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          "Keybindings",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(child: Text("Mute: ${_keybindLabel(_muteKeybind)}")),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => unawaited(_captureMuteKeybind()),
              child: const Text("Set"),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _muteKeybind = null;
                });
              },
              child: const Text("Clear"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(child: Text("Deafen: ${_keybindLabel(_deafenKeybind)}")),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => unawaited(_captureDeafenKeybind()),
              child: const Text("Set"),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _deafenKeybind = null;
                });
              },
              child: const Text("Clear"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => unawaited(_saveKeybindings()),
            child: const Text("Save keybindings"),
          ),
        ),
      ],
    );
  }
}
