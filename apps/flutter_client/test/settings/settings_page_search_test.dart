import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_preferences_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/use_cases/mute_channel_notifications_use_case.dart";
import "package:polyphony_flutter_client/features/notifications/use_cases/unmute_channel_notifications_use_case.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/chat_browser_settings_page_widget.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:polyphony_flutter_client/shared/services/profile_service.dart";
import "package:provider/provider.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

class _FakeProfileService implements ProfileService {
  @override
  Future<Result<ApiMe>> getMe() async {
    return const Ok<ApiMe>(
      ApiMe(
        userId: "auth0|test",
        displayName: "Test User",
        issuer: "test",
      ),
    );
  }

  @override
  Future<Result<ApiMe>> updateDisplayName({
    required String displayName,
  }) async {
    return Ok<ApiMe>(
      ApiMe(
        userId: "auth0|test",
        displayName: displayName,
        issuer: "test",
      ),
    );
  }

  @override
  Future<Result<ApiUserLookup>> getUserById({
    required String userId,
  }) async {
    return Error<ApiUserLookup>(Exception("Not used in test."));
  }
}

Widget _buildSettingsTestApp({
  required SettingsBloc settingsBloc,
  required ChannelsBloc channelsBloc,
  required NotificationPreferencesBloc notificationPreferencesBloc,
  required PreferencesStore preferencesStore,
}) {
  return MaterialApp(
    home: MultiProvider(
      providers: <Provider<dynamic>>[
        Provider<PreferencesStore>.value(value: preferencesStore),
        Provider<ProfileService>(create: (_) => _FakeProfileService()),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<ChannelsBloc>.value(value: channelsBloc),
          BlocProvider<NotificationPreferencesBloc>.value(
            value: notificationPreferencesBloc,
          ),
        ],
        child: const ChatBrowserSettingsPageWidget(
          bearerToken: "test-token",
          initialDisplayName: "Test User",
          onSaveDisplayName: _noopSaveDisplayName,
        ),
      ),
    ),
  );
}

void _noopSaveDisplayName(String _) {}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  group("Feature: Settings IA and discoverability", () {
    late InMemoryPreferencesStore preferencesStore;
    late SettingsBloc settingsBloc;
    late ChannelsBloc channelsBloc;
    late NotificationPreferencesBloc notificationPreferencesBloc;

    setUp(() {
      preferencesStore = InMemoryPreferencesStore();
      settingsBloc = SettingsBloc(
        preferencesStore: preferencesStore,
        audioDeviceRuntimeService: FakeAudioDeviceRuntimeService(),
      )..add(const SettingsPreferencesRestoreRequested());
      channelsBloc = ChannelsBloc(
        channelRepo: FakeChannelRepository(fixture: fixture),
      )..add(LoadChannelsRequested(serverId: fixture.listedServer.id));
      final fakeNotificationPreferenceRepo = FakeNotificationPreferenceRepo();
      notificationPreferencesBloc = NotificationPreferencesBloc(
        notificationPreferenceRepo: fakeNotificationPreferenceRepo,
        muteChannelNotificationsUseCase: MuteChannelNotificationsUseCase(
          notificationPreferenceRepo: fakeNotificationPreferenceRepo,
        ),
        unmuteChannelNotificationsUseCase: UnmuteChannelNotificationsUseCase(
          notificationPreferenceRepo: fakeNotificationPreferenceRepo,
        ),
      );
    });

    tearDown(() async {
      await settingsBloc.close();
      await channelsBloc.close();
      await notificationPreferencesBloc.close();
    });

    group("Rule: Settings search finds sections by label and synonyms", () {
      testWidgets(
        "Scenario: All sections are visible when search is empty",
        (tester) async {
          await tester.pumpWidget(
            _buildSettingsTestApp(
              settingsBloc: settingsBloc,
              channelsBloc: channelsBloc,
              notificationPreferencesBloc: notificationPreferencesBloc,
              preferencesStore: preferencesStore,
            ),
          );
          await _pumpUi(tester);

          expect(find.text("Account"), findsOneWidget);
          expect(find.text("Appearance"), findsWidgets);
          expect(
            find.text("No settings match your search."),
            findsNothing,
          );
        },
      );

      testWidgets(
        "Scenario: Searching by keyword filters to matching sections",
        (tester) async {
          await tester.pumpWidget(
            _buildSettingsTestApp(
              settingsBloc: settingsBloc,
              channelsBloc: channelsBloc,
              notificationPreferencesBloc: notificationPreferencesBloc,
              preferencesStore: preferencesStore,
            ),
          );
          await _pumpUi(tester);

          await tester.enterText(
            find.byType(TextField).first,
            "microphone",
          );
          await _pumpUi(tester);

          expect(find.text("Audio"), findsOneWidget);
          expect(find.text("Audio devices"), findsOneWidget);
          expect(find.text("Account"), findsNothing);
          expect(find.text("Developer"), findsNothing);
        },
      );

      testWidgets(
        "Scenario: Searching by section title shows matching section",
        (tester) async {
          await tester.pumpWidget(
            _buildSettingsTestApp(
              settingsBloc: settingsBloc,
              channelsBloc: channelsBloc,
              notificationPreferencesBloc: notificationPreferencesBloc,
              preferencesStore: preferencesStore,
            ),
          );
          await _pumpUi(tester);

          await tester.enterText(
            find.byType(TextField).first,
            "Appearance",
          );
          await _pumpUi(tester);

          expect(find.text("Appearance"), findsWidgets);
          expect(find.text("Audio"), findsNothing);
          expect(find.text("Keybindings"), findsNothing);
        },
      );

      testWidgets(
        "Scenario: No matching results shows empty state",
        (tester) async {
          await tester.pumpWidget(
            _buildSettingsTestApp(
              settingsBloc: settingsBloc,
              channelsBloc: channelsBloc,
              notificationPreferencesBloc: notificationPreferencesBloc,
              preferencesStore: preferencesStore,
            ),
          );
          await _pumpUi(tester);

          await tester.enterText(
            find.byType(TextField).first,
            "zznonexistentzz",
          );
          await _pumpUi(tester);

          expect(
            find.text("No settings match your search."),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        "Scenario: Clearing search restores all sections",
        (tester) async {
          await tester.pumpWidget(
            _buildSettingsTestApp(
              settingsBloc: settingsBloc,
              channelsBloc: channelsBloc,
              notificationPreferencesBloc: notificationPreferencesBloc,
              preferencesStore: preferencesStore,
            ),
          );
          await _pumpUi(tester);

          await tester.enterText(
            find.byType(TextField).first,
            "microphone",
          );
          await _pumpUi(tester);

          expect(find.text("Account"), findsNothing);

          await tester.tap(find.byIcon(Icons.clear));
          await _pumpUi(tester);

          expect(find.text("Account"), findsOneWidget);
          expect(
            find.text("No settings match your search."),
            findsNothing,
          );
        },
      );
    });

    group("Rule: Every feature setting is discoverable without hidden gestures",
        () {
      testWidgets(
        "Scenario: Notification sections are reachable by searching mute",
        (tester) async {
          await tester.pumpWidget(
            _buildSettingsTestApp(
              settingsBloc: settingsBloc,
              channelsBloc: channelsBloc,
              notificationPreferencesBloc: notificationPreferencesBloc,
              preferencesStore: preferencesStore,
            ),
          );
          await _pumpUi(tester);

          await tester.enterText(
            find.byType(TextField).first,
            "mute",
          );
          await _pumpUi(tester);

          expect(find.text("Notifications"), findsWidgets);
        },
      );

      testWidgets(
        "Scenario: Voice notification settings are reachable by searching voice",
        (tester) async {
          await tester.pumpWidget(
            _buildSettingsTestApp(
              settingsBloc: settingsBloc,
              channelsBloc: channelsBloc,
              notificationPreferencesBloc: notificationPreferencesBloc,
              preferencesStore: preferencesStore,
            ),
          );
          await _pumpUi(tester);

          await tester.enterText(
            find.byType(TextField).first,
            "voice",
          );
          await _pumpUi(tester);

          expect(find.text("Voice notifications"), findsOneWidget);
        },
      );
    });

    group("Rule: Settings sections support reset to default", () {
      testWidgets(
        "Scenario: Reset to default button is visible for resettable sections",
        (tester) async {
          await tester.pumpWidget(
            _buildSettingsTestApp(
              settingsBloc: settingsBloc,
              channelsBloc: channelsBloc,
              notificationPreferencesBloc: notificationPreferencesBloc,
              preferencesStore: preferencesStore,
            ),
          );
          await _pumpUi(tester);

          await tester.enterText(
            find.byType(TextField).first,
            "Appearance",
          );
          await _pumpUi(tester);

          expect(
            find.widgetWithText(TextButton, "Reset to default"),
            findsOneWidget,
          );
        },
      );

      test(
        "Scenario: Resetting appearance dispatches dark mode off",
        () async {
          settingsBloc.add(
            const SettingsDarkModeToggledRequested(enabled: true),
          );
          await Future<void>.delayed(Duration.zero);

          settingsBloc.add(
            const SettingsDarkModeToggledRequested(enabled: false),
          );
          await Future<void>.delayed(Duration.zero);

          final isDarkMode = switch (settingsBloc.state) {
            SettingsLoadedState(:final isDarkModeEnabled) => isDarkModeEnabled,
            _ => true,
          };
          expect(isDarkMode, isFalse);
        },
      );

      test(
        "Scenario: Resetting audio devices dispatches null device selection",
        () async {
          settingsBloc.add(
            const SettingsAudioInputDeviceSetRequested(deviceId: "mic-usb"),
          );
          await Future<void>.delayed(Duration.zero);

          settingsBloc
            ..add(const SettingsAudioInputDeviceSetRequested(deviceId: null))
            ..add(const SettingsAudioOutputDeviceSetRequested(deviceId: null));
          await Future<void>.delayed(Duration.zero);

          final selectedInput = switch (settingsBloc.state) {
            SettingsLoadedState(:final selectedAudioInputDeviceId) =>
              selectedAudioInputDeviceId,
            _ => "not-null",
          };
          expect(selectedInput, isNull);
        },
      );

      test(
        "Scenario: Resetting voice notifications disables channel join notifications",
        () async {
          settingsBloc.add(
            const SettingsChannelJoinNotificationsToggledRequested(
              enabled: true,
            ),
          );
          await Future<void>.delayed(Duration.zero);

          settingsBloc
            ..add(
              const SettingsChannelJoinNotificationsToggledRequested(
                enabled: false,
              ),
            )
            ..add(
              const SettingsChannelJoinNotificationChannelsSetRequested(
                channelIds: <String>[],
              ),
            );
          await Future<void>.delayed(Duration.zero);

          final isEnabled = switch (settingsBloc.state) {
            SettingsLoadedState(:final isChannelJoinNotificationsEnabled) =>
              isChannelJoinNotificationsEnabled,
            _ => true,
          };
          expect(isEnabled, isFalse);
        },
      );
    });
  });
}
