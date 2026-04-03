import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/settings/presentation/reducers/keybinding_reducer.dart";
import "package:polyphony_flutter_client/features/voice_sessions/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

class VoiceKeybindingsFocusWidget extends StatefulWidget {
  const VoiceKeybindingsFocusWidget({
    required this.refreshToken,
    required this.child,
    super.key,
  });

  final int refreshToken;
  final Widget child;

  @override
  State<VoiceKeybindingsFocusWidget> createState() =>
      _VoiceKeybindingsFocusWidgetState();
}

class _VoiceKeybindingsFocusWidgetState
    extends State<VoiceKeybindingsFocusWidget> {
  var _keybindingsPreferences = const KeybindingsPreferences.unset();

  @override
  void initState() {
    super.initState();
    unawaited(_loadKeybindingsPreferences());
  }

  @override
  void didUpdateWidget(covariant VoiceKeybindingsFocusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshToken == widget.refreshToken) {
      return;
    }

    unawaited(_loadKeybindingsPreferences());
  }

  Future<void> _loadKeybindingsPreferences() async {
    final keybindingsPreferences =
        await context.read<PreferencesStore>().readKeybindingsPreferences();
    if (!mounted) {
      return;
    }

    setState(() {
      _keybindingsPreferences = keybindingsPreferences;
    });
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent keyEvent) {
    if (keyEvent is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (_isEditableTextFocused()) {
      return KeyEventResult.ignored;
    }

    final voiceState = context.read<VoiceSessionsBloc>().state;
    if (voiceState is! VoiceSessionsLoadedDataState) {
      return KeyEventResult.ignored;
    }

    final connectedChannelId = voiceState.connectedChannelId;
    if (connectedChannelId == null || connectedChannelId.value.isEmpty) {
      return KeyEventResult.ignored;
    }

    final modifierState = keybindingModifierStateFromKeyboard(
      HardwareKeyboard.instance,
    );

    if (doesLogicalKeyMatchChord(
      logicalKey: keyEvent.logicalKey,
      modifiers: modifierState,
      chord: _keybindingsPreferences.mute,
    )) {
      context.read<VoiceSessionsBloc>().add(
            SetSelfMutedRequested(muted: !voiceState.isSelfMuted),
          );
      return KeyEventResult.handled;
    }

    if (doesLogicalKeyMatchChord(
      logicalKey: keyEvent.logicalKey,
      modifiers: modifierState,
      chord: _keybindingsPreferences.deafen,
    )) {
      context.read<VoiceSessionsBloc>().add(
            SetSelfDeafenedRequested(deafened: !voiceState.isSelfDeafened),
          );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _isEditableTextFocused() {
    final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
    return focusedWidget is EditableText;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }
}
