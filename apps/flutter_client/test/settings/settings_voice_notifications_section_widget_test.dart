import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_voice_notifications_section_widget.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

Widget _buildTestApp(SettingsBloc settingsBloc, ChannelsBloc channelsBloc) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<SettingsBloc>.value(value: settingsBloc),
        BlocProvider<ChannelsBloc>.value(value: channelsBloc),
      ],
      child: const Scaffold(
        body: SettingsVoiceNotificationsSectionWidget(),
      ),
    ),
  );
}

Future<void> _pumpUi(WidgetTester tester) async {
  // Use bounded pumping to avoid waiting forever on unrelated scheduled frames.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  group("SettingsVoiceNotificationsSectionWidget", () {
    testWidgets("disables channel selector when voice notifications are off",
        (tester) async {
      final fixture = EntitySeeder().chatApiFixture();
      final preferencesStore = InMemoryPreferencesStore();
      final settingsBloc = SettingsBloc(preferencesStore: preferencesStore)
        ..add(const SettingsPreferencesRestoreRequested());
      final channelsBloc = ChannelsBloc(
        channelRepo: FakeChannelRepository(fixture: fixture),
      )..add(LoadChannelsRequested(serverId: fixture.listedServer.id));
      addTearDown(() async {
        await settingsBloc.close();
        await channelsBloc.close();
      });

      await tester.pumpWidget(_buildTestApp(settingsBloc, channelsBloc));
      await _pumpUi(tester);

      expect(find.text("All voice channels are allowed."), findsOneWidget);

      final selectButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, "Select voice channels"),
      );
      expect(selectButton.onPressed, isNull);
    });

    testWidgets("saves selected channel ids and updates summary",
        (tester) async {
      final fixture = EntitySeeder().chatApiFixture();
      final preferencesStore = InMemoryPreferencesStore();
      final settingsBloc = SettingsBloc(preferencesStore: preferencesStore)
        ..add(const SettingsPreferencesRestoreRequested());
      final channelsBloc = ChannelsBloc(
        channelRepo: FakeChannelRepository(fixture: fixture),
      )..add(LoadChannelsRequested(serverId: fixture.listedServer.id));
      addTearDown(() async {
        await settingsBloc.close();
        await channelsBloc.close();
      });

      await tester.pumpWidget(_buildTestApp(settingsBloc, channelsBloc));
      await _pumpUi(tester);

      await tester.tap(find.byType(SwitchListTile));
      await _pumpUi(tester);

      await tester
          .tap(find.widgetWithText(OutlinedButton, "Select voice channels"));
      await _pumpUi(tester);

      await tester.tap(find.byType(CheckboxListTile).first);
      await _pumpUi(tester);
      await tester.tap(find.widgetWithText(FilledButton, "Save"));
      await _pumpUi(tester);

      expect(find.text("1 channel(s) selected."), findsOneWidget);
      expect(
        await preferencesStore.readChannelJoinNotificationChannelIds(),
        const <String>["vch-1"],
      );
    });

    testWidgets("use all channels clears selected channel ids", (tester) async {
      final fixture = EntitySeeder().chatApiFixture();
      final preferencesStore = InMemoryPreferencesStore();
      await preferencesStore.writeChannelJoinNotificationsEnabled(true);
      await preferencesStore.writeChannelJoinNotificationChannelIds(
        const <String>["vch-1"],
      );
      final settingsBloc = SettingsBloc(preferencesStore: preferencesStore)
        ..add(const SettingsPreferencesRestoreRequested());
      final channelsBloc = ChannelsBloc(
        channelRepo: FakeChannelRepository(fixture: fixture),
      )..add(LoadChannelsRequested(serverId: fixture.listedServer.id));
      addTearDown(() async {
        await settingsBloc.close();
        await channelsBloc.close();
      });

      await tester.pumpWidget(_buildTestApp(settingsBloc, channelsBloc));
      await _pumpUi(tester);

      expect(find.text("1 channel(s) selected."), findsOneWidget);

      await tester
          .tap(find.widgetWithText(OutlinedButton, "Select voice channels"));
      await _pumpUi(tester);

      await tester.tap(find.widgetWithText(TextButton, "Use all channels"));
      await _pumpUi(tester);

      expect(find.text("All voice channels are allowed."), findsOneWidget);
      expect(
        await preferencesStore.readChannelJoinNotificationChannelIds(),
        isEmpty,
      );
    });
  });
}
