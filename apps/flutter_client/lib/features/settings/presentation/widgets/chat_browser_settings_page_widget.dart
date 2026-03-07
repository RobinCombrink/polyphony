import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/identity/presentation/widgets/settings_display_name_section_widget.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_preferences_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_appearance_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_developer_options_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_keybindings_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_notification_preferences_section_widget.dart";

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
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _reloadNotificationPreferences();
    });
  }

  void _reloadNotificationPreferences() {
    final serversState = context.read<ServersBloc>().state;
    final channelsState = context.read<ChannelsBloc>().state;

    final selectedServerId = switch (serversState) {
      ServersLoadedDataState(:final selectedServerId) => selectedServerId,
      _ => null,
    };
    final selectedChannelId = switch (channelsState) {
      ChannelsLoadedDataState(
        :final selectionMode,
        :final selectedTextChannelId,
        :final selectedVoiceChannelId,
      ) => switch (selectionMode) {
          ChannelSelectionMode.text => selectedTextChannelId,
          ChannelSelectionMode.voice => selectedVoiceChannelId,
        },
      _ => null,
    };

    context.read<NotificationPreferencesBloc>().add(
          LoadNotificationPreferencesRequested(
            serverId: selectedServerId,
            channelId: selectedChannelId,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final serversState = context.watch<ServersBloc>().state;
    final channelsState = context.watch<ChannelsBloc>().state;
    final selectedServerId = switch (serversState) {
      ServersLoadedDataState(:final selectedServerId) => selectedServerId,
      _ => null,
    };
    final selectedChannelId = switch (channelsState) {
      ChannelsLoadedDataState(
        :final selectionMode,
        :final selectedTextChannelId,
        :final selectedVoiceChannelId,
      ) => switch (selectionMode) {
          ChannelSelectionMode.text => selectedTextChannelId,
          ChannelSelectionMode.voice => selectedVoiceChannelId,
        },
      _ => null,
    };
    final notificationPreferencesState =
        context.watch<NotificationPreferencesBloc>().state;
    if (notificationPreferencesState case NotificationPreferencesLoadedDataState(
      :final serverId,
      :final channelId,
    )) {
      final selectedServerIdChanged = serverId != selectedServerId;
      final selectedChannelIdChanged = channelId != selectedChannelId;

      if (selectedServerIdChanged || selectedChannelIdChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          _reloadNotificationPreferences();
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _SettingsSectionWidget(
              child: SettingsDisplayNameSectionWidget(
            initialDisplayName: widget.initialDisplayName,
            onSaveDisplayName: widget.onSaveDisplayName,
          )),
          const SizedBox(height: 16),
          const _SettingsSectionWidget(
              child: SettingsKeybindingsSectionWidget()),
          const SizedBox(height: 16),
          const _SettingsSectionWidget(
              child: SettingsAppearanceSectionWidget()),
          const SizedBox(height: 16),
          _SettingsSectionWidget(
              child: SettingsNotificationPreferencesSectionWidget(
            selectedServerId: selectedServerId,
            selectedChannelId: selectedChannelId,
          )),
          const SizedBox(height: 16),
          _SettingsSectionWidget(
              child: SettingsDeveloperOptionsSectionWidget(
            bearerToken: widget.bearerToken,
          )),
        ],
      ),
    );
  }
}

class _SettingsSectionWidget extends StatelessWidget {
  const _SettingsSectionWidget({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
