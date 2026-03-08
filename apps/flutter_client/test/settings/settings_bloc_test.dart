import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

final class _TestPreferencesStore implements PreferencesStore {
  _TestPreferencesStore();

  var darkModeEnabled = false;
  var channelJoinNotificationsEnabled = false;
  var channelJoinNotificationChannelIds = const <String>[];

  @override
  Future<bool> readDarkModeEnabled() async {
    return darkModeEnabled;
  }

  @override
  Future<void> writeDarkModeEnabled(bool enabled) async {
    darkModeEnabled = enabled;
  }

  @override
  Future<bool> readChannelJoinNotificationsEnabled() async {
    return channelJoinNotificationsEnabled;
  }

  @override
  Future<void> writeChannelJoinNotificationsEnabled(bool enabled) async {
    channelJoinNotificationsEnabled = enabled;
  }

  @override
  Future<List<String>> readChannelJoinNotificationChannelIds() async {
    return channelJoinNotificationChannelIds;
  }

  @override
  Future<void> writeChannelJoinNotificationChannelIds(
    List<String> channelIds,
  ) async {
    channelJoinNotificationChannelIds = channelIds;
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
        isA<SettingsLoadedState>()
            .having(
              (state) => state.isDarkModeEnabled,
              "isDarkModeEnabled",
              isTrue,
            )
            .having(
              (state) => state.isChannelJoinNotificationsEnabled,
              "isChannelJoinNotificationsEnabled",
              isFalse,
            )
            .having(
              (state) => state.channelJoinNotificationChannelIds,
              "channelJoinNotificationChannelIds",
              isEmpty,
            ),
      ],
    );

    blocTest<SettingsBloc, SettingsState>(
      "restores channel join notifications disabled by default",
      build: () {
        return SettingsBloc(preferencesStore: preferencesStore);
      },
      act: (bloc) => bloc.add(const SettingsPreferencesRestoreRequested()),
      expect: () => <Matcher>[
        isA<SettingsLoadedState>()
            .having(
              (state) => state.isChannelJoinNotificationsEnabled,
              "isChannelJoinNotificationsEnabled",
              isFalse,
            )
            .having(
              (state) => state.channelJoinNotificationChannelIds,
              "channelJoinNotificationChannelIds",
              isEmpty,
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
        isA<SettingsLoadedState>()
            .having(
              (state) => state.isDarkModeEnabled,
              "isDarkModeEnabled",
              isTrue,
            )
            .having(
              (state) => state.isChannelJoinNotificationsEnabled,
              "isChannelJoinNotificationsEnabled",
              isFalse,
            )
            .having(
              (state) => state.channelJoinNotificationChannelIds,
              "channelJoinNotificationChannelIds",
              isEmpty,
            ),
      ],
      verify: (_) {
        expect(preferencesStore.darkModeEnabled, isTrue);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      "emits loaded state and persists channel join notifications toggle",
      build: () {
        return SettingsBloc(preferencesStore: preferencesStore);
      },
      act: (bloc) => bloc.add(
        const SettingsChannelJoinNotificationsToggledRequested(enabled: true),
      ),
      expect: () => <Matcher>[
        isA<SettingsLoadedState>()
            .having(
              (state) => state.isChannelJoinNotificationsEnabled,
              "isChannelJoinNotificationsEnabled",
              isTrue,
            )
            .having(
              (state) => state.channelJoinNotificationChannelIds,
              "channelJoinNotificationChannelIds",
              isEmpty,
            ),
      ],
      verify: (_) {
        expect(preferencesStore.channelJoinNotificationsEnabled, isTrue);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      "emits loaded state and persists selected channel join notification channels",
      build: () {
        return SettingsBloc(preferencesStore: preferencesStore);
      },
      act: (bloc) => bloc.add(
        const SettingsChannelJoinNotificationChannelsSetRequested(
          channelIds: <String>["voice-1", "voice-2", "voice-1"],
        ),
      ),
      expect: () => <Matcher>[
        isA<SettingsLoadedState>().having(
          (state) => state.channelJoinNotificationChannelIds,
          "channelJoinNotificationChannelIds",
          const <String>["voice-1", "voice-2"],
        ),
      ],
      verify: (_) {
        expect(
          preferencesStore.channelJoinNotificationChannelIds,
          const <String>["voice-1", "voice-2"],
        );
      },
    );
  });
}
