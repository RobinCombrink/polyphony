import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/settings/presentation/reducers/keybinding_reducer.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

void main() {
  group("isModifierLogicalKey", () {
    test("returns true for modifier variants", () {
      expect(isModifierLogicalKey(LogicalKeyboardKey.control), isTrue);
      expect(isModifierLogicalKey(LogicalKeyboardKey.controlLeft), isTrue);
      expect(isModifierLogicalKey(LogicalKeyboardKey.controlRight), isTrue);
      expect(isModifierLogicalKey(LogicalKeyboardKey.shift), isTrue);
      expect(isModifierLogicalKey(LogicalKeyboardKey.shiftLeft), isTrue);
      expect(isModifierLogicalKey(LogicalKeyboardKey.shiftRight), isTrue);
      expect(isModifierLogicalKey(LogicalKeyboardKey.alt), isTrue);
      expect(isModifierLogicalKey(LogicalKeyboardKey.altLeft), isTrue);
      expect(isModifierLogicalKey(LogicalKeyboardKey.altRight), isTrue);
      expect(isModifierLogicalKey(LogicalKeyboardKey.meta), isTrue);
      expect(isModifierLogicalKey(LogicalKeyboardKey.metaLeft), isTrue);
      expect(isModifierLogicalKey(LogicalKeyboardKey.metaRight), isTrue);
    });

    test("returns false for non-modifier keys", () {
      expect(isModifierLogicalKey(LogicalKeyboardKey.keyA), isFalse);
    });
  });

  group("reduceCapturedKeybindingChord", () {
    test("returns null for modifier-only key press", () {
      final captured = reduceCapturedKeybindingChord(
        logicalKey: LogicalKeyboardKey.altLeft,
        modifiers: const KeybindingModifierState(
          isControlPressed: false,
          isShiftPressed: false,
          isAltPressed: true,
          isMetaPressed: false,
        ),
      );

      expect(captured, isNull);
    });

    test("returns typed chord for non-modifier key", () {
      final captured = reduceCapturedKeybindingChord(
        logicalKey: LogicalKeyboardKey.keyM,
        modifiers: const KeybindingModifierState(
          isControlPressed: true,
          isShiftPressed: false,
          isAltPressed: true,
          isMetaPressed: false,
        ),
      );

      expect(captured, isNotNull);
      expect(captured!.keyId, LogicalKeyboardKey.keyM.keyId);
      expect(captured.isControlPressed, isTrue);
      expect(captured.isShiftPressed, isFalse);
      expect(captured.isAltPressed, isTrue);
      expect(captured.isMetaPressed, isFalse);
    });
  });

  group("doesLogicalKeyMatchChord", () {
    test("returns true when modifiers and key match", () {
      final chord = KeybindingChord(
        keyId: LogicalKeyboardKey.keyD.keyId,
        isControlPressed: true,
        isShiftPressed: false,
        isAltPressed: false,
        isMetaPressed: false,
      );

      final result = doesLogicalKeyMatchChord(
        logicalKey: LogicalKeyboardKey.keyD,
        modifiers: const KeybindingModifierState(
          isControlPressed: true,
          isShiftPressed: false,
          isAltPressed: false,
          isMetaPressed: false,
        ),
        chord: chord,
      );

      expect(result, isTrue);
    });

    test("returns false when any modifier differs", () {
      final chord = KeybindingChord(
        keyId: LogicalKeyboardKey.keyD.keyId,
        isControlPressed: true,
        isShiftPressed: false,
        isAltPressed: false,
        isMetaPressed: false,
      );

      final result = doesLogicalKeyMatchChord(
        logicalKey: LogicalKeyboardKey.keyD,
        modifiers: const KeybindingModifierState(
          isControlPressed: false,
          isShiftPressed: false,
          isAltPressed: false,
          isMetaPressed: false,
        ),
        chord: chord,
      );

      expect(result, isFalse);
    });

    test("returns false for null chord", () {
      final result = doesLogicalKeyMatchChord(
        logicalKey: LogicalKeyboardKey.keyD,
        modifiers: const KeybindingModifierState(
          isControlPressed: false,
          isShiftPressed: false,
          isAltPressed: false,
          isMetaPressed: false,
        ),
        chord: null,
      );

      expect(result, isFalse);
    });
  });

  group("keybindingChordLabel", () {
    test("returns Unset for null chord", () {
      final label = keybindingChordLabel(
        chord: null,
        resolveKeyLabel: (_) => "",
      );

      expect(label, "Unset");
    });

    test("builds modifier + key label string", () {
      final chord = KeybindingChord(
        keyId: LogicalKeyboardKey.keyM.keyId,
        isControlPressed: true,
        isShiftPressed: false,
        isAltPressed: true,
        isMetaPressed: false,
      );

      final label = keybindingChordLabel(
        chord: chord,
        resolveKeyLabel: (_) => "m",
      );

      expect(label, "ctrl+alt+m");
    });

    test("uses key id fallback when key label is empty", () {
      const chord = KeybindingChord(
        keyId: 1337,
        isControlPressed: false,
        isShiftPressed: false,
        isAltPressed: false,
        isMetaPressed: false,
      );

      final label = keybindingChordLabel(
        chord: chord,
        resolveKeyLabel: (_) => "   ",
      );

      expect(label, "key:1337");
    });
  });
}
