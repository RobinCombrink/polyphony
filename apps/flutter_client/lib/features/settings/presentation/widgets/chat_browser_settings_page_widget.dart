import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/identity/presentation/widgets/settings_display_name_section_widget.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_preferences_bloc.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_developer_profile_bloc.dart";
import "package:polyphony_flutter_client/features/settings/presentation/settings_search_index.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_appearance_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_audio_devices_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_developer_options_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_keybindings_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_notification_preferences_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_voice_notifications_section_widget.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:polyphony_flutter_client/shared/services/profile_service.dart";

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
  final _searchController = TextEditingController();
  var _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _reloadNotificationPreferences();
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _reloadNotificationPreferences() {
    context.read<NotificationPreferencesBloc>().add(
          const LoadNotificationPreferencesRequested(
            serverId: null,
            channelId: null,
          ),
        );
  }

  bool _isSectionVisible(String sectionId) {
    final visibleSections = searchSettings(_searchQuery);
    return visibleSections.any((entry) => entry.id == sectionId);
  }

  bool _isCategoryVisible(SettingsCategory category) {
    final visibleSections = searchSettings(_searchQuery);
    return visibleSections.any((entry) => entry.category == category);
  }

  void _resetAppearance() {
    context.read<SettingsBloc>().add(
          const SettingsDarkModeToggledRequested(enabled: false),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Appearance reset to default.")),
    );
  }

  void _resetNotifications() {
    context.read<NotificationPreferencesBloc>().add(
          const GlobalMuteToggledRequested(muted: false),
        );
    context.read<NotificationPreferencesBloc>().add(
          const GlobalNotificationCategoryChangedRequested(
            notificationCategory: ApiNotificationCategoryPreference.allMessages,
          ),
        );
    context.read<NotificationPreferencesBloc>().add(
          const GlobalChannelDefaultCategoryChangedRequested(
            channelDefaultCategory:
                ApiNotificationCategoryPreference.allMessages,
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Notification preferences reset.")),
    );
  }

  void _resetVoiceNotifications() {
    context.read<SettingsBloc>().add(
          const SettingsChannelJoinNotificationsToggledRequested(
              enabled: false),
        );
    context.read<SettingsBloc>().add(
          const SettingsChannelJoinNotificationChannelsSetRequested(
            channelIds: <String>[],
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Voice notifications reset.")),
    );
  }

  void _resetAudioDevices() {
    context.read<SettingsBloc>().add(
          const SettingsAudioInputDeviceSetRequested(deviceId: null),
        );
    context.read<SettingsBloc>().add(
          const SettingsAudioOutputDeviceSetRequested(deviceId: null),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Audio devices reset to automatic.")),
    );
  }

  void _resetKeybindings() {
    unawaited(
      context.read<PreferencesStore>().writeKeybindingsPreferences(
            const KeybindingsPreferences.unset(),
          ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Keybindings cleared. Re-open settings to refresh."),
      ),
    );
  }

  void _resetDeveloper() {
    context.read<SettingsBloc>().add(
          const SettingsDeveloperModeToggledRequested(enabled: false),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Developer options disabled.")),
    );
  }

  List<Widget> _buildCategoryGroup(
    SettingsCategory category,
    List<Widget> sectionWidgets,
  ) {
    if (sectionWidgets.isEmpty || !_isCategoryVisible(category)) {
      return const <Widget>[];
    }

    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
        child: Text(
          category.label,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      ...sectionWidgets,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search settings...",
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _searchController.clear,
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                ..._buildCategoryGroup(
                  SettingsCategory.account,
                  <Widget>[
                    if (_isSectionVisible("display_name"))
                      _SettingsSectionWidget(
                        child: SettingsDisplayNameSectionWidget(
                          initialDisplayName: widget.initialDisplayName,
                          onSaveDisplayName: widget.onSaveDisplayName,
                        ),
                      ),
                  ],
                ),
                ..._buildCategoryGroup(
                  SettingsCategory.appearance,
                  <Widget>[
                    if (_isSectionVisible("appearance"))
                      _SettingsSectionWidget(
                        onResetToDefault: _resetAppearance,
                        child: const SettingsAppearanceSectionWidget(),
                      ),
                  ],
                ),
                ..._buildCategoryGroup(
                  SettingsCategory.notifications,
                  <Widget>[
                    if (_isSectionVisible("notifications"))
                      _SettingsSectionWidget(
                        onResetToDefault: _resetNotifications,
                        child:
                            const SettingsNotificationPreferencesSectionWidget(
                          showServer: false,
                          showChannel: false,
                          description: "Control global notification behavior.",
                        ),
                      ),
                    if (_isSectionVisible("voice_notifications"))
                      _SettingsSectionWidget(
                        onResetToDefault: _resetVoiceNotifications,
                        child: const SettingsVoiceNotificationsSectionWidget(),
                      ),
                  ],
                ),
                ..._buildCategoryGroup(
                  SettingsCategory.audio,
                  <Widget>[
                    if (_isSectionVisible("audio_devices"))
                      _SettingsSectionWidget(
                        onResetToDefault: _resetAudioDevices,
                        child: const SettingsAudioDevicesSectionWidget(),
                      ),
                  ],
                ),
                ..._buildCategoryGroup(
                  SettingsCategory.keybindings,
                  <Widget>[
                    if (_isSectionVisible("keybindings"))
                      _SettingsSectionWidget(
                        onResetToDefault: _resetKeybindings,
                        child: const SettingsKeybindingsSectionWidget(),
                      ),
                  ],
                ),
                ..._buildCategoryGroup(
                  SettingsCategory.developer,
                  <Widget>[
                    if (_isSectionVisible("developer"))
                      _SettingsSectionWidget(
                        onResetToDefault: _resetDeveloper,
                        child: BlocProvider<SettingsDeveloperProfileBloc>(
                          create: (context) => SettingsDeveloperProfileBloc(
                            profileService: context.read<ProfileService>(),
                          ),
                          child: SettingsDeveloperOptionsSectionWidget(
                            bearerToken: widget.bearerToken,
                          ),
                        ),
                      ),
                  ],
                ),
                if (searchSettings(_searchQuery).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text("No settings match your search."),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionWidget extends StatelessWidget {
  const _SettingsSectionWidget({
    required this.child,
    this.onResetToDefault,
  });

  final Widget child;
  final VoidCallback? onResetToDefault;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              child,
              if (onResetToDefault != null) ...<Widget>[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onResetToDefault,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text("Reset to default"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
