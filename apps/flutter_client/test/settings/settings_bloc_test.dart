import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

final class _TestPreferencesStore implements PreferencesStore {
  _TestPreferencesStore();

  var darkModeEnabled = false;

  @override
  Future<bool> readDarkModeEnabled() async {
    return darkModeEnabled;
  }

  @override
  Future<void> writeDarkModeEnabled(bool enabled) async {
    darkModeEnabled = enabled;
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

void main() {
  group("SettingsBloc", () {
    late _TestPreferencesStore preferencesStore;

    setUp(() {
      preferencesStore = _TestPreferencesStore();
    });

    blocTest<SettingsBloc, SettingsState>(
      "restores persisted dark mode preference",
      build: () {
        preferencesStore.darkModeEnabled = true;
        return SettingsBloc(preferencesStore: preferencesStore);
      },
      act: (bloc) => bloc.add(const SettingsPreferencesRestoreRequested()),
      expect: () => <Matcher>[
        isA<SettingsLoadedState>().having(
          (state) => state.isDarkModeEnabled,
          "isDarkModeEnabled",
          isTrue,
        ),
      ],
    );

    blocTest<SettingsBloc, SettingsState>(
      "emits loaded state and persists dark mode toggle",
      build: () {
        return SettingsBloc(preferencesStore: preferencesStore);
      },
      act: (bloc) => bloc.add(
        const SettingsDarkModeToggledRequested(enabled: true),
      ),
      expect: () => <Matcher>[
        isA<SettingsLoadedState>().having(
          (state) => state.isDarkModeEnabled,
          "isDarkModeEnabled",
          isTrue,
        ),
      ],
      verify: (_) {
        expect(preferencesStore.darkModeEnabled, isTrue);
      },
    );
  });
}
