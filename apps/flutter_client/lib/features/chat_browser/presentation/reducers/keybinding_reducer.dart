import "package:flutter/services.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

final class KeybindingModifierState {
  const KeybindingModifierState({
    required this.isControlPressed,
    required this.isShiftPressed,
    required this.isAltPressed,
    required this.isMetaPressed,
  });

  final bool isControlPressed;
  final bool isShiftPressed;
  final bool isAltPressed;
  final bool isMetaPressed;
}

KeybindingModifierState keybindingModifierStateFromKeyboard(
  HardwareKeyboard keyboard,
) {
  return KeybindingModifierState(
    isControlPressed: keyboard.isControlPressed,
    isShiftPressed: keyboard.isShiftPressed,
    isAltPressed: keyboard.isAltPressed,
    isMetaPressed: keyboard.isMetaPressed,
  );
}

bool isModifierLogicalKey(LogicalKeyboardKey logicalKey) {
  return logicalKey == LogicalKeyboardKey.control ||
      logicalKey == LogicalKeyboardKey.controlLeft ||
      logicalKey == LogicalKeyboardKey.controlRight ||
      logicalKey == LogicalKeyboardKey.shift ||
      logicalKey == LogicalKeyboardKey.shiftLeft ||
      logicalKey == LogicalKeyboardKey.shiftRight ||
      logicalKey == LogicalKeyboardKey.alt ||
      logicalKey == LogicalKeyboardKey.altLeft ||
      logicalKey == LogicalKeyboardKey.altRight ||
      logicalKey == LogicalKeyboardKey.meta ||
      logicalKey == LogicalKeyboardKey.metaLeft ||
      logicalKey == LogicalKeyboardKey.metaRight;
}

KeybindingChord? reduceCapturedKeybindingChord({
  required LogicalKeyboardKey logicalKey,
  required KeybindingModifierState modifiers,
}) {
  if (isModifierLogicalKey(logicalKey)) {
    return null;
  }

  final keyLabel = logicalKey.keyLabel.trim();
  if (keyLabel.isEmpty) {
    return null;
  }

  return KeybindingChord(
    keyId: logicalKey.keyId,
    isControlPressed: modifiers.isControlPressed,
    isShiftPressed: modifiers.isShiftPressed,
    isAltPressed: modifiers.isAltPressed,
    isMetaPressed: modifiers.isMetaPressed,
  );
}

bool doesLogicalKeyMatchChord({
  required LogicalKeyboardKey logicalKey,
  required KeybindingModifierState modifiers,
  required KeybindingChord? chord,
}) {
  if (chord == null) {
    return false;
  }

  return modifiers.isControlPressed == chord.isControlPressed &&
      modifiers.isShiftPressed == chord.isShiftPressed &&
      modifiers.isAltPressed == chord.isAltPressed &&
      modifiers.isMetaPressed == chord.isMetaPressed &&
      logicalKey.keyId == chord.keyId;
}

String keybindingChordLabel({
  required KeybindingChord? chord,
  required String Function(int keyId) resolveKeyLabel,
}) {
  if (chord == null) {
    return "Unset";
  }

  final resolvedKeyLabel = resolveKeyLabel(chord.keyId).trim();
  final keyLabel =
      resolvedKeyLabel.isEmpty ? "key:${chord.keyId}" : resolvedKeyLabel;

  final modifiers = <String>[
    if (chord.isControlPressed) "ctrl",
    if (chord.isShiftPressed) "shift",
    if (chord.isAltPressed) "alt",
    if (chord.isMetaPressed) "meta",
  ];

  return <String>[...modifiers, keyLabel].join("+");
}
