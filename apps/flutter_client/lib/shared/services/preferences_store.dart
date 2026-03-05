import "dart:convert";

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

final class KeybindingChord {
  const KeybindingChord({
    required this.keyId,
    required this.isControlPressed,
    required this.isShiftPressed,
    required this.isAltPressed,
    required this.isMetaPressed,
  });

  final int keyId;
  final bool isControlPressed;
  final bool isShiftPressed;
  final bool isAltPressed;
  final bool isMetaPressed;

  Map<String, Object> toJson() {
    return <String, Object>{
      "keyId": keyId,
      "isControlPressed": isControlPressed,
      "isShiftPressed": isShiftPressed,
      "isAltPressed": isAltPressed,
      "isMetaPressed": isMetaPressed,
    };
  }

  static KeybindingChord? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final keyIdValue = value["keyId"];
    if (keyIdValue is! num) {
      return null;
    }

    final isControlPressedValue = value["isControlPressed"];
    final isShiftPressedValue = value["isShiftPressed"];
    final isAltPressedValue = value["isAltPressed"];
    final isMetaPressedValue = value["isMetaPressed"];

    if (isControlPressedValue is! bool ||
        isShiftPressedValue is! bool ||
        isAltPressedValue is! bool ||
        isMetaPressedValue is! bool) {
      return null;
    }

    return KeybindingChord(
      keyId: keyIdValue.toInt(),
      isControlPressed: isControlPressedValue,
      isShiftPressed: isShiftPressedValue,
      isAltPressed: isAltPressedValue,
      isMetaPressed: isMetaPressedValue,
    );
  }
}

final class KeybindingsPreferences {
  const KeybindingsPreferences({
    required this.mute,
    required this.deafen,
  });

  const KeybindingsPreferences.unset()
      : mute = null,
        deafen = null;

  final KeybindingChord? mute;
  final KeybindingChord? deafen;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      "mute": mute?.toJson(),
      "deafen": deafen?.toJson(),
    };
  }

  static KeybindingsPreferences fromJson(Map<String, Object?> json) {
    return KeybindingsPreferences(
      mute: KeybindingChord.fromJson(json["mute"]),
      deafen: KeybindingChord.fromJson(json["deafen"]),
    );
  }
}

abstract interface class PreferencesStore {
  Future<bool> readDarkModeEnabled();
  Future<void> writeDarkModeEnabled(bool enabled);
  Future<bool> readRememberEmailEnabled();
  Future<void> writeRememberEmailEnabled(bool enabled);
  Future<String?> readRememberedEmailAddress();
  Future<void> writeRememberedEmailAddress(String emailAddress);
  Future<void> clearRememberedEmailAddress();
  Future<KeybindingsPreferences> readKeybindingsPreferences();
  Future<void> writeKeybindingsPreferences(KeybindingsPreferences value);
}

final class SharedPreferencesBackedPreferencesStore
    implements PreferencesStore {
  static const _darkModeEnabledKey = "settings.dark_mode_enabled";
  static const _rememberEmailKey = "auth.remember_email";
  static const _rememberedEmailAddressKey = "auth.remembered_email_address";
  static const _keybindingsKey = "settings.keybindings";
  static const _allowList = <String>{
    _darkModeEnabledKey,
    _rememberEmailKey,
    _rememberedEmailAddressKey,
    _keybindingsKey,
  };

  SharedPreferencesBackedPreferencesStore()
      : _sharedPreferencesWithCacheFuture = SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(
            allowList: _allowList,
          ),
        );

  final Future<SharedPreferencesWithCache> _sharedPreferencesWithCacheFuture;

  @override
  Future<bool> readDarkModeEnabled() async {
    final sharedPreferences = await _sharedPreferencesWithCacheFuture;
    return sharedPreferences.getBool(_darkModeEnabledKey) ?? false;
  }

  @override
  Future<void> writeDarkModeEnabled(bool enabled) async {
    final sharedPreferences = await _sharedPreferencesWithCacheFuture;
    await sharedPreferences.setBool(_darkModeEnabledKey, enabled);
  }

  @override
  Future<bool> readRememberEmailEnabled() async {
    final sharedPreferences = await _sharedPreferencesWithCacheFuture;
    return sharedPreferences.getBool(_rememberEmailKey) ?? false;
  }

  @override
  Future<void> writeRememberEmailEnabled(bool enabled) async {
    final sharedPreferences = await _sharedPreferencesWithCacheFuture;
    await sharedPreferences.setBool(_rememberEmailKey, enabled);
  }

  @override
  Future<String?> readRememberedEmailAddress() async {
    final sharedPreferences = await _sharedPreferencesWithCacheFuture;
    final rememberedEmailAddress =
        sharedPreferences.getString(_rememberedEmailAddressKey);
    if (rememberedEmailAddress == null) {
      return null;
    }

    final trimmedRememberedEmailAddress = rememberedEmailAddress.trim();
    return trimmedRememberedEmailAddress.isEmpty
        ? null
        : trimmedRememberedEmailAddress;
  }

  @override
  Future<void> writeRememberedEmailAddress(String emailAddress) async {
    final sharedPreferences = await _sharedPreferencesWithCacheFuture;
    await sharedPreferences.setString(
      _rememberedEmailAddressKey,
      emailAddress.trim(),
    );
  }

  @override
  Future<void> clearRememberedEmailAddress() async {
    final sharedPreferences = await _sharedPreferencesWithCacheFuture;
    await sharedPreferences.remove(_rememberedEmailAddressKey);
  }

  @override
  Future<KeybindingsPreferences> readKeybindingsPreferences() async {
    final sharedPreferences = await _sharedPreferencesWithCacheFuture;
    final encoded = sharedPreferences.getString(_keybindingsKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return const KeybindingsPreferences.unset();
    }

    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, Object?>) {
      return const KeybindingsPreferences.unset();
    }

    return KeybindingsPreferences.fromJson(decoded);
  }

  @override
  Future<void> writeKeybindingsPreferences(KeybindingsPreferences value) async {
    final sharedPreferences = await _sharedPreferencesWithCacheFuture;
    await sharedPreferences.setString(
      _keybindingsKey,
      jsonEncode(value.toJson()),
    );
  }
}

final class InMemoryPreferencesStore implements PreferencesStore {
  var _darkModeEnabled = false;
  var _rememberEmailEnabled = false;
  String? _rememberedEmailAddress;
  var _keybindingsPreferences = const KeybindingsPreferences.unset();

  @override
  Future<bool> readDarkModeEnabled() async {
    return _darkModeEnabled;
  }

  @override
  Future<void> writeDarkModeEnabled(bool enabled) async {
    _darkModeEnabled = enabled;
  }

  @override
  Future<bool> readRememberEmailEnabled() async {
    return _rememberEmailEnabled;
  }

  @override
  Future<void> writeRememberEmailEnabled(bool enabled) async {
    _rememberEmailEnabled = enabled;
  }

  @override
  Future<String?> readRememberedEmailAddress() async {
    return _rememberedEmailAddress;
  }

  @override
  Future<void> writeRememberedEmailAddress(String emailAddress) async {
    final trimmedEmailAddress = emailAddress.trim();
    _rememberedEmailAddress =
        trimmedEmailAddress.isEmpty ? null : trimmedEmailAddress;
  }

  @override
  Future<void> clearRememberedEmailAddress() async {
    _rememberedEmailAddress = null;
  }

  @override
  Future<KeybindingsPreferences> readKeybindingsPreferences() async {
    return _keybindingsPreferences;
  }

  @override
  Future<void> writeKeybindingsPreferences(KeybindingsPreferences value) async {
    _keybindingsPreferences = value;
  }
}

final class WebPreferencesStore implements PreferencesStore {
  const WebPreferencesStore();

  @override
  Future<bool> readDarkModeEnabled() async {
    return false;
  }

  @override
  Future<void> writeDarkModeEnabled(bool enabled) async {
    return;
  }

  @override
  Future<bool> readRememberEmailEnabled() async {
    return false;
  }

  @override
  Future<void> writeRememberEmailEnabled(bool enabled) async {
    return;
  }

  @override
  Future<String?> readRememberedEmailAddress() async {
    return null;
  }

  @override
  Future<void> writeRememberedEmailAddress(String emailAddress) async {
    return;
  }

  @override
  Future<void> clearRememberedEmailAddress() async {
    return;
  }

  @override
  Future<KeybindingsPreferences> readKeybindingsPreferences() async {
    return const KeybindingsPreferences.unset();
  }

  @override
  Future<void> writeKeybindingsPreferences(KeybindingsPreferences value) async {
    return;
  }
}

PreferencesStore createPreferencesStore() {
  if (kIsWeb) {
    return const WebPreferencesStore();
  }

  return SharedPreferencesBackedPreferencesStore();
}
