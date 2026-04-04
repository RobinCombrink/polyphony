enum SettingsCategory {
  account("Account"),
  appearance("Appearance"),
  notifications("Notifications"),
  audio("Audio"),
  keybindings("Keybindings"),
  developer("Developer");

  const SettingsCategory(this.label);

  final String label;
}

final class SettingsSectionEntry {
  const SettingsSectionEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.keywords,
  });

  final String id;
  final String title;
  final SettingsCategory category;
  final List<String> keywords;
}

const settingsSearchIndex = <SettingsSectionEntry>[
  SettingsSectionEntry(
    id: "display_name",
    title: "Display name",
    category: SettingsCategory.account,
    keywords: <String>[
      "name",
      "profile",
      "identity",
      "username",
      "account",
      "display",
    ],
  ),
  SettingsSectionEntry(
    id: "appearance",
    title: "Appearance",
    category: SettingsCategory.appearance,
    keywords: <String>[
      "theme",
      "dark",
      "light",
      "mode",
      "appearance",
      "color",
      "colors",
    ],
  ),
  SettingsSectionEntry(
    id: "notifications",
    title: "Notifications",
    category: SettingsCategory.notifications,
    keywords: <String>[
      "notification",
      "notifications",
      "mute",
      "mentions",
      "alerts",
      "category",
      "global",
    ],
  ),
  SettingsSectionEntry(
    id: "voice_notifications",
    title: "Voice notifications",
    category: SettingsCategory.notifications,
    keywords: <String>[
      "voice",
      "channel join",
      "voice notification",
      "join",
    ],
  ),
  SettingsSectionEntry(
    id: "audio_devices",
    title: "Audio devices",
    category: SettingsCategory.audio,
    keywords: <String>[
      "microphone",
      "speaker",
      "audio",
      "input",
      "output",
      "device",
      "sound",
      "headphone",
    ],
  ),
  SettingsSectionEntry(
    id: "keybindings",
    title: "Keybindings",
    category: SettingsCategory.keybindings,
    keywords: <String>[
      "keybinding",
      "shortcut",
      "mute",
      "deafen",
      "keyboard",
      "hotkey",
      "key",
    ],
  ),
  SettingsSectionEntry(
    id: "developer",
    title: "Developer options",
    category: SettingsCategory.developer,
    keywords: <String>[
      "developer",
      "debug",
      "token",
      "backend",
      "api",
      "sentry",
      "configuration",
      "advanced",
    ],
  ),
];

List<SettingsSectionEntry> searchSettings(String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return settingsSearchIndex;
  }

  return settingsSearchIndex.where((entry) {
    if (entry.title.toLowerCase().contains(normalizedQuery)) {
      return true;
    }
    if (entry.category.label.toLowerCase().contains(normalizedQuery)) {
      return true;
    }
    return entry.keywords.any(
      (keyword) => keyword.toLowerCase().contains(normalizedQuery),
    );
  }).toList(growable: false);
}
