import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

abstract interface class PreferencesStore {
  Future<bool> readRememberEmailEnabled();
  Future<void> writeRememberEmailEnabled(bool enabled);
  Future<String?> readRememberedEmailAddress();
  Future<void> writeRememberedEmailAddress(String emailAddress);
  Future<void> clearRememberedEmailAddress();
}

final class SharedPreferencesBackedPreferencesStore
    implements PreferencesStore {
  static const _rememberEmailKey = "auth.remember_email";
  static const _rememberedEmailAddressKey = "auth.remembered_email_address";
  static const _allowList = <String>{
    _rememberEmailKey,
    _rememberedEmailAddressKey,
  };

  SharedPreferencesBackedPreferencesStore()
      : _sharedPreferencesWithCacheFuture = SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(
            allowList: _allowList,
          ),
        );

  final Future<SharedPreferencesWithCache> _sharedPreferencesWithCacheFuture;

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
}

final class InMemoryPreferencesStore implements PreferencesStore {
  var _rememberEmailEnabled = false;
  String? _rememberedEmailAddress;

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
}

final class WebPreferencesStore implements PreferencesStore {
  const WebPreferencesStore();

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
}

PreferencesStore createPreferencesStore() {
  if (kIsWeb) {
    return const WebPreferencesStore();
  }

  return SharedPreferencesBackedPreferencesStore();
}
