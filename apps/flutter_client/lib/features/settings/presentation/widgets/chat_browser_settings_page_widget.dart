import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/identity/presentation/widgets/settings_display_name_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_developer_options_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_keybindings_section_widget.dart";

class ChatBrowserSettingsPageWidget extends StatefulWidget {
  const ChatBrowserSettingsPageWidget({
    required this.bearerToken,
    required this.initialDisplayName,
    required this.onSaveDisplayName,
    super.key,
  });

  final String bearerToken;
  final String? initialDisplayName;
  final ValueChanged<String> onSaveDisplayName;

  @override
  State<ChatBrowserSettingsPageWidget> createState() =>
      _ChatBrowserSettingsPageWidgetState();
}

class _ChatBrowserSettingsPageWidgetState
    extends State<ChatBrowserSettingsPageWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingsDisplayNameSectionWidget(
              initialDisplayName: widget.initialDisplayName,
              onSaveDisplayName: widget.onSaveDisplayName,
            ),
            const SizedBox(height: 24),
            const SettingsKeybindingsSectionWidget(),
            const SizedBox(height: 24),
            SettingsDeveloperOptionsSectionWidget(
              bearerToken: widget.bearerToken,
            ),
          ],
        ),
      ),
    );
  }
}
