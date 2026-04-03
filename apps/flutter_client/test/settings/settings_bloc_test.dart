import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

import "../test_doubles/chat_repository_fakes.dart";

final class _TestPreferencesStore implements PreferencesStore {
  _TestPreferencesStore();

  var developerModeEnabled = false;
  var darkModeEnabled = false;
  var channelJoinNotificationsEnabled = false;
  var channelJoinNotificationChannelIds = const <String>[];
  String? audioInputDeviceId;
  String? audioOutputDeviceId;
  String? backendBaseUrlOverride;

  @override
  Future<bool> readDeveloperModeEnabled() async {
    return developerModeEnabled;
  }

  @override
  Future<void> writeDeveloperModeEnabled(bool enabled) async {
    developerModeEnabled = enabled;
  }

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
  Future<String?> readAudioInputDeviceId() async {
    return audioInputDeviceId;
  }

  @override
  Future<void> writeAudioInputDeviceId(String? deviceId) async {
    audioInputDeviceId = deviceId;
  }

  @override
  Future<String?> readAudioOutputDeviceId() async {
    return audioOutputDeviceId;
  }

  @override
  Future<void> writeAudioOutputDeviceId(String? deviceId) async {
    audioOutputDeviceId = deviceId;
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

  @override
  Future<String?> readBackendBaseUrlOverride() async {
    return backendBaseUrlOverride;
  }

  @override
  Future<void> writeBackendBaseUrlOverride(String baseUrl) async {
    backendBaseUrlOverride = baseUrl;
  }

  @override
  Future<void> clearBackendBaseUrlOverride() async {
    backendBaseUrlOverride = null;
  }
}

void main() {
  group("SettingsBloc", () {
    late _TestPreferencesStore preferencesStore;
    late FakeAudioDeviceRuntimeService audioDeviceRuntimeService;

    setUp(() {
      preferencesStore = _TestPreferencesStore();
      audioDeviceRuntimeService = FakeAudioDeviceRuntimeService();
    });

    blocTest<SettingsBloc, SettingsState>(
      "restores persisted dark mode preference",
      build: () {
        preferencesStore.darkModeEnabled = true;
        return SettingsBloc(
          preferencesStore: preferencesStore,
          audioDeviceRuntimeService: audioDeviceRuntimeService,
        );
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
            )
            .having(
              (state) => state.selectedAudioInputDeviceId,
              "selectedAudioInputDeviceId",
              isNull,
            )
            .having(
              (state) => state.selectedAudioOutputDeviceId,
              "selectedAudioOutputDeviceId",
              isNull,
            ),
      ],
    );

    blocTest<SettingsBloc, SettingsState>(
      "restores channel join notifications disabled by default",
      build: () {
        return SettingsBloc(
          preferencesStore: preferencesStore,
          audioDeviceRuntimeService: audioDeviceRuntimeService,
        );
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
        return SettingsBloc(
          preferencesStore: preferencesStore,
          audioDeviceRuntimeService: audioDeviceRuntimeService,
        );
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
        return SettingsBloc(
          preferencesStore: preferencesStore,
          audioDeviceRuntimeService: audioDeviceRuntimeService,
        );
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
        return SettingsBloc(
          preferencesStore: preferencesStore,
          audioDeviceRuntimeService: audioDeviceRuntimeService,
        );
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

    blocTest<SettingsBloc, SettingsState>(
      "restores persisted audio device ids when available",
      build: () {
        preferencesStore
          ..audioInputDeviceId = "mic-usb"
          ..audioOutputDeviceId = "spk-usb";
        return SettingsBloc(
          preferencesStore: preferencesStore,
          audioDeviceRuntimeService: audioDeviceRuntimeService,
        );
      },
      act: (bloc) => bloc.add(const SettingsPreferencesRestoreRequested()),
      expect: () => <Matcher>[
        isA<SettingsLoadedState>()
            .having(
              (state) => state.selectedAudioInputDeviceId,
              "selectedAudioInputDeviceId",
              "mic-usb",
            )
            .having(
              (state) => state.selectedAudioOutputDeviceId,
              "selectedAudioOutputDeviceId",
              "spk-usb",
            ),
      ],
      verify: (_) {
        expect(
          audioDeviceRuntimeService.selectedAudioInputDeviceId(),
          "mic-usb",
        );
        expect(
          audioDeviceRuntimeService.selectedAudioOutputDeviceId(),
          "spk-usb",
        );
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      "persists and applies selected audio input device",
      build: () {
        return SettingsBloc(
          preferencesStore: preferencesStore,
          audioDeviceRuntimeService: audioDeviceRuntimeService,
        );
      },
      act: (bloc) async {
        bloc.add(const SettingsPreferencesRestoreRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const SettingsAudioInputDeviceSetRequested(deviceId: "mic-usb"),
        );
      },
      verify: (_) {
        expect(preferencesStore.audioInputDeviceId, "mic-usb");
        expect(
          audioDeviceRuntimeService.selectedAudioInputDeviceId(),
          "mic-usb",
        );
      },
    );
  });
}
