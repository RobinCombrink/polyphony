import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/settings/presentation/settings_search_index.dart";

void main() {
  group("searchSettings", () {
    test("returns all sections for empty query", () {
      final results = searchSettings("");
      expect(results, settingsSearchIndex);
    });

    test("returns all sections for whitespace-only query", () {
      final results = searchSettings("   ");
      expect(results, settingsSearchIndex);
    });

    test("matches section by title substring", () {
      final results = searchSettings("Display");
      expect(results.length, 1);
      expect(results.first.id, "display_name");
    });

    test("matches section by keyword", () {
      final results = searchSettings("microphone");
      expect(results.length, 1);
      expect(results.first.id, "audio_devices");
    });

    test("matches section by category label", () {
      final results = searchSettings("Notifications");
      expect(results.length, 2);
      expect(
        results.map((entry) => entry.id).toList(),
        containsAll(<String>["notifications", "voice_notifications"]),
      );
    });

    test("is case-insensitive", () {
      final results = searchSettings("DARK");
      expect(results.any((entry) => entry.id == "appearance"), isTrue);
    });

    test("returns empty list when no sections match", () {
      final results = searchSettings("zznonexistentzzz");
      expect(results, isEmpty);
    });

    test("matches keybindings by shortcut synonym", () {
      final results = searchSettings("shortcut");
      expect(results.length, 1);
      expect(results.first.id, "keybindings");
    });

    test("matches developer options by debug synonym", () {
      final results = searchSettings("debug");
      expect(results.length, 1);
      expect(results.first.id, "developer");
    });

    test("matches appearance by theme keyword", () {
      final results = searchSettings("theme");
      expect(results.length, 1);
      expect(results.first.id, "appearance");
    });

    test("matches display name by profile keyword", () {
      final results = searchSettings("profile");
      expect(results.length, 1);
      expect(results.first.id, "display_name");
    });
  });

  group("SettingsCategory", () {
    test("every section has a non-empty title", () {
      for (final entry in settingsSearchIndex) {
        expect(entry.title, isNotEmpty, reason: "Section ${entry.id}");
      }
    });

    test("every section has at least one keyword", () {
      for (final entry in settingsSearchIndex) {
        expect(entry.keywords, isNotEmpty, reason: "Section ${entry.id}");
      }
    });

    test("section ids are unique", () {
      final ids = settingsSearchIndex.map((entry) => entry.id).toSet();
      expect(ids.length, settingsSearchIndex.length);
    });
  });
}
