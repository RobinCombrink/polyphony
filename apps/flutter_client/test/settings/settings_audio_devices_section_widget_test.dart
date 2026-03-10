import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_audio_devices_section_widget.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

import "../test_doubles/chat_repository_fakes.dart";

Widget _buildTestApp(SettingsBloc settingsBloc) {
  return MaterialApp(
    home: BlocProvider<SettingsBloc>.value(
      value: settingsBloc,
      child: const Scaffold(
        body: SettingsAudioDevicesSectionWidget(),
      ),
    ),
  );
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  group("SettingsAudioDevicesSectionWidget", () {
    testWidgets("shows which devices are system defaults", (tester) async {
      final preferencesStore = InMemoryPreferencesStore();
      final audioDeviceRuntimeService = FakeAudioDeviceRuntimeService();
      final settingsBloc = SettingsBloc(
        preferencesStore: preferencesStore,
        audioDeviceRuntimeService: audioDeviceRuntimeService,
      )..add(const SettingsPreferencesRestoreRequested());
      addTearDown(() async {
        await settingsBloc.close();
      });

      await tester.pumpWidget(_buildTestApp(settingsBloc));
      await _pumpUi(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
      await _pumpUi(tester);
      expect(find.text("System Default (Default microphone)"), findsOneWidget);

      await tester.tap(find.text("Automatic (Follow system default)").last);
      await _pumpUi(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String?>).last);
      await _pumpUi(tester);
      expect(find.text("System Default (Default speakers)"), findsOneWidget);
    });

    testWidgets("selecting input device persists and applies immediately",
        (tester) async {
      final preferencesStore = InMemoryPreferencesStore();
      final audioDeviceRuntimeService = FakeAudioDeviceRuntimeService();
      final settingsBloc = SettingsBloc(
        preferencesStore: preferencesStore,
        audioDeviceRuntimeService: audioDeviceRuntimeService,
      )..add(const SettingsPreferencesRestoreRequested());
      addTearDown(() async {
        await settingsBloc.close();
      });

      await tester.pumpWidget(_buildTestApp(settingsBloc));
      await _pumpUi(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
      await _pumpUi(tester);
      await tester.tap(find.text("USB microphone").last);
      await _pumpUi(tester);

      expect(await preferencesStore.readAudioInputDeviceId(), "mic-usb");
      expect(audioDeviceRuntimeService.selectedAudioInputDeviceId(), "mic-usb");
    });

    testWidgets("selecting output device persists and applies immediately",
        (tester) async {
      final preferencesStore = InMemoryPreferencesStore();
      final audioDeviceRuntimeService = FakeAudioDeviceRuntimeService();
      final settingsBloc = SettingsBloc(
        preferencesStore: preferencesStore,
        audioDeviceRuntimeService: audioDeviceRuntimeService,
      )..add(const SettingsPreferencesRestoreRequested());
      addTearDown(() async {
        await settingsBloc.close();
      });

      await tester.pumpWidget(_buildTestApp(settingsBloc));
      await _pumpUi(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String?>).last);
      await _pumpUi(tester);
      await tester.tap(find.text("USB headphones").last);
      await _pumpUi(tester);

      expect(await preferencesStore.readAudioOutputDeviceId(), "spk-usb");
      expect(
        audioDeviceRuntimeService.selectedAudioOutputDeviceId(),
        "spk-usb",
      );
    });
  });
}
