import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/settings/presentation/settings_search_index.dart";

void main() {
  group("Feature: Settings IA and discoverability", () {
    group("Rule: Settings search finds feature toggles by label and synonyms",
        () {
      test(
        "Scenario: Searching for dark returns the appearance section",
        () {
          final results = searchSettings("dark");
          expect(results.length, 1);
          expect(results.first.id, "appearance");
          expect(results.first.category, SettingsCategory.appearance);
        },
      );

      test(
        "Scenario: Searching for mute returns notification and keybinding sections",
        () {
          final results = searchSettings("mute");
          final ids = results.map((entry) => entry.id).toSet();
          expect(ids, contains("notifications"));
          expect(ids, contains("keybindings"));
        },
      );

      test(
        "Scenario: Searching for speaker returns audio devices section",
        () {
          final results = searchSettings("speaker");
          expect(results.length, 1);
          expect(results.first.id, "audio_devices");
        },
      );

      test(
        "Scenario: Searching for hotkey returns keybindings section",
        () {
          final results = searchSettings("hotkey");
          expect(results.length, 1);
          expect(results.first.id, "keybindings");
        },
      );

      test(
        "Scenario: Searching for backend returns developer section",
        () {
          final results = searchSettings("backend");
          expect(results.length, 1);
          expect(results.first.id, "developer");
        },
      );

      test(
        "Scenario: Searching for account returns display name section",
        () {
          final results = searchSettings("account");
          expect(results.length, 1);
          expect(results.first.id, "display_name");
          expect(results.first.category, SettingsCategory.account);
        },
      );
    });

    group("Rule: Every feature flag from phases 5-8 has a settings entry", () {
      test(
        "Scenario: Global notification mute is discoverable",
        () {
          final results = searchSettings("global");
          expect(
            results.any((entry) => entry.id == "notifications"),
            isTrue,
          );
        },
      );

      test(
        "Scenario: Voice channel join notifications are discoverable",
        () {
          final results = searchSettings("channel join");
          expect(
            results.any((entry) => entry.id == "voice_notifications"),
            isTrue,
          );
        },
      );

      test(
        "Scenario: Mention notification behavior is discoverable",
        () {
          final results = searchSettings("mentions");
          expect(
            results.any((entry) => entry.id == "notifications"),
            isTrue,
          );
        },
      );
    });

    group("Rule: No configuration path requires hidden navigation gestures",
        () {
      test(
        "Scenario: All sections are shown when search query is empty",
        () {
          final results = searchSettings("");
          expect(results.length, settingsSearchIndex.length);
        },
      );

      test(
        "Scenario: Search is case-insensitive for accessibility",
        () {
          final upper = searchSettings("DARK");
          final lower = searchSettings("dark");
          final mixed = searchSettings("DaRk");

          expect(
            upper.map((entry) => entry.id).toList(),
            lower.map((entry) => entry.id).toList(),
          );
          expect(
            upper.map((entry) => entry.id).toList(),
            mixed.map((entry) => entry.id).toList(),
          );
        },
      );
    });
  });
}
