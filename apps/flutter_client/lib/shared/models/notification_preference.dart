enum NotificationMuteState {
  unmuted,
  muted;
}

enum NotificationCategoryPreference {
  allMessages,
  onlyMentions,
  none;
}

class NotificationGlobalPreference {
  const NotificationGlobalPreference({
    required this.muteState,
    required this.notificationCategory,
    required this.channelDefaultCategory,
  });

  final NotificationMuteState muteState;
  final NotificationCategoryPreference notificationCategory;
  final NotificationCategoryPreference channelDefaultCategory;
}

class NotificationServerPreference {
  const NotificationServerPreference({
    required this.muteState,
    required this.notificationCategory,
  });

  final NotificationMuteState muteState;
  final NotificationCategoryPreference notificationCategory;
}

class NotificationChannelPreference {
  const NotificationChannelPreference({
    required this.muteState,
    required this.mutedUntilEpochSeconds,
    required this.notificationCategory,
    required this.inheritedFromGlobalDefault,
  });

  final NotificationMuteState muteState;
  final int? mutedUntilEpochSeconds;
  final NotificationCategoryPreference notificationCategory;
  final bool inheritedFromGlobalDefault;
}
