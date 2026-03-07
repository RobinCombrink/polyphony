import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_preferences_bloc.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";

class SettingsNotificationPreferencesSectionWidget extends StatelessWidget {
  const SettingsNotificationPreferencesSectionWidget({
    this.selectedServerId,
    this.selectedChannelId,
    this.showGlobal = true,
    this.showServer = true,
    this.showChannel = true,
    this.title = "Notifications",
    this.description =
        "Control global, server, and channel notification behavior.",
    super.key,
  });

  final String? selectedServerId;
  final String? selectedChannelId;
  final bool showGlobal;
  final bool showServer;
  final bool showChannel;
  final String title;
  final String description;

  String _categoryLabel(ApiNotificationCategoryPreference value) {
    return switch (value) {
      ApiNotificationCategoryPreference.allMessages => "All messages",
      ApiNotificationCategoryPreference.onlyMentions => "Only mentions",
      ApiNotificationCategoryPreference.none => "None",
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationPreferencesBloc,
        NotificationPreferencesState>(
      builder: (context, state) {
        final loadedData = switch (state) {
          NotificationPreferencesLoadedDataState() => state,
          _ => null,
        };
        final isLoading = state is NotificationPreferencesLoadingState;

        if (loadedData == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text("Loading notification preferences..."),
            ],
          );
        }

        final globalPreference = loadedData.globalPreference;
        final serverPreference = loadedData.serverPreference;
        final channelPreference = loadedData.channelPreference;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (showGlobal) ...<Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Globally mute notifications"),
                value: globalPreference.muteState ==
                    ApiNotificationMuteState.muted,
                onChanged: isLoading
                    ? null
                    : (muted) {
                        context.read<NotificationPreferencesBloc>().add(
                              GlobalMuteToggledRequested(muted: muted),
                            );
                      },
              ),
              DropdownButtonFormField<ApiNotificationCategoryPreference>(
                initialValue: globalPreference.notificationCategory,
                decoration: const InputDecoration(
                  labelText: "Global notification category",
                ),
                items: ApiNotificationCategoryPreference.values
                    .map(
                      (value) =>
                          DropdownMenuItem<ApiNotificationCategoryPreference>(
                        value: value,
                        child: Text(_categoryLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: isLoading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        context.read<NotificationPreferencesBloc>().add(
                              GlobalNotificationCategoryChangedRequested(
                                notificationCategory: value,
                              ),
                            );
                      },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ApiNotificationCategoryPreference>(
                initialValue: globalPreference.channelDefaultCategory,
                decoration: const InputDecoration(
                  labelText: "Default channel notification category",
                ),
                items: ApiNotificationCategoryPreference.values
                    .map(
                      (value) =>
                          DropdownMenuItem<ApiNotificationCategoryPreference>(
                        value: value,
                        child: Text(_categoryLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: isLoading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        context.read<NotificationPreferencesBloc>().add(
                              GlobalChannelDefaultCategoryChangedRequested(
                                channelDefaultCategory: value,
                              ),
                            );
                      },
              ),
              const SizedBox(height: 16),
            ],
            if (showServer) ...<Widget>[
              Text(
                "Selected server preference",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              if (selectedServerId == null || serverPreference == null)
                Text(
                  "Select a server to configure server-level notifications.",
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else ...<Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Mute selected server"),
                  value: serverPreference.muteState ==
                      ApiNotificationMuteState.muted,
                  onChanged: isLoading
                      ? null
                      : (muted) {
                          context.read<NotificationPreferencesBloc>().add(
                                ServerMuteToggledRequested(
                                  serverId: selectedServerId!,
                                  muted: muted,
                                ),
                              );
                        },
                ),
                DropdownButtonFormField<ApiNotificationCategoryPreference>(
                  initialValue: serverPreference.notificationCategory,
                  decoration: const InputDecoration(
                    labelText: "Server notification category",
                  ),
                  items: ApiNotificationCategoryPreference.values
                      .map(
                        (value) =>
                            DropdownMenuItem<ApiNotificationCategoryPreference>(
                          value: value,
                          child: Text(_categoryLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: isLoading
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          context.read<NotificationPreferencesBloc>().add(
                                ServerNotificationCategoryChangedRequested(
                                  serverId: selectedServerId!,
                                  notificationCategory: value,
                                ),
                              );
                        },
                ),
              ],
              const SizedBox(height: 16),
            ],
            if (showChannel) ...<Widget>[
              Text(
                "Selected channel preference",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              if (selectedChannelId == null || channelPreference == null)
                Text(
                  "Select a channel to configure channel-level notifications.",
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else ...<Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Temporarily mute selected channel (30m)"),
                  value: channelPreference.muteState ==
                      ApiNotificationMuteState.muted,
                  onChanged: isLoading
                      ? null
                      : (muted) {
                          context.read<NotificationPreferencesBloc>().add(
                                ChannelMuteToggledRequested(
                                  channelId: selectedChannelId!,
                                  muted: muted,
                                ),
                              );
                        },
                ),
                DropdownButtonFormField<ApiNotificationCategoryPreference>(
                  initialValue: channelPreference.notificationCategory,
                  decoration: const InputDecoration(
                    labelText: "Channel notification category",
                  ),
                  items: ApiNotificationCategoryPreference.values
                      .map(
                        (value) =>
                            DropdownMenuItem<ApiNotificationCategoryPreference>(
                          value: value,
                          child: Text(_categoryLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: isLoading
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          context.read<NotificationPreferencesBloc>().add(
                                ChannelNotificationCategoryChangedRequested(
                                  channelId: selectedChannelId!,
                                  notificationCategory: value,
                                ),
                              );
                        },
                ),
                if (channelPreference.mutedUntilEpochSeconds != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Muted until epoch seconds: ${channelPreference.mutedUntilEpochSeconds}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ],
            if (state case NotificationPreferencesExceptionState(:final error))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Could not update notification preferences: $error",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
          ],
        );
      },
    );
  }
}
