import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/models/notification_preference.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

sealed class GetNotificationPreferenceQuery {
  const GetNotificationPreferenceQuery();
}

final class GetGlobalNotificationPreferenceQuery
    extends GetNotificationPreferenceQuery {
  const GetGlobalNotificationPreferenceQuery();
}

final class GetServerNotificationPreferenceQuery
    extends GetNotificationPreferenceQuery {
  const GetServerNotificationPreferenceQuery({required this.serverId});

  final ServerId serverId;
}

final class GetChannelNotificationPreferenceQuery
    extends GetNotificationPreferenceQuery {
  const GetChannelNotificationPreferenceQuery({required this.channelId});

  final ChannelId channelId;
}

sealed class NotificationPreferenceData {
  const NotificationPreferenceData();
}

final class GlobalNotificationPreferenceData
    extends NotificationPreferenceData {
  const GlobalNotificationPreferenceData({required this.preference});

  final NotificationGlobalPreference preference;
}

final class ServerNotificationPreferenceData
    extends NotificationPreferenceData {
  const ServerNotificationPreferenceData({required this.preference});

  final NotificationServerPreference preference;
}

final class ChannelNotificationPreferenceData
    extends NotificationPreferenceData {
  const ChannelNotificationPreferenceData({required this.preference});

  final NotificationChannelPreference preference;
}

sealed class UpdateNotificationPreferenceCommand {
  const UpdateNotificationPreferenceCommand();
}

final class UpdateGlobalNotificationPreferenceCommand
    extends UpdateNotificationPreferenceCommand {
  const UpdateGlobalNotificationPreferenceCommand({
    this.muteState,
    this.notificationCategory,
    this.channelDefaultCategory,
  });

  final NotificationMuteState? muteState;
  final NotificationCategoryPreference? notificationCategory;
  final NotificationCategoryPreference? channelDefaultCategory;
}

final class UpdateServerNotificationPreferenceCommand
    extends UpdateNotificationPreferenceCommand {
  const UpdateServerNotificationPreferenceCommand({
    required this.serverId,
    this.muteState,
    this.notificationCategory,
  });

  final ServerId serverId;
  final NotificationMuteState? muteState;
  final NotificationCategoryPreference? notificationCategory;
}

final class UpdateChannelNotificationCategoryCommand
    extends UpdateNotificationPreferenceCommand {
  const UpdateChannelNotificationCategoryCommand({
    required this.channelId,
    required this.notificationCategory,
  });

  final ChannelId channelId;
  final NotificationCategoryPreference notificationCategory;
}

final class MuteChannelCommand extends UpdateNotificationPreferenceCommand {
  const MuteChannelCommand({
    required this.channelId,
    required this.durationMinutes,
  });

  final ChannelId channelId;
  final int durationMinutes;
}

final class UnmuteChannelCommand extends UpdateNotificationPreferenceCommand {
  const UnmuteChannelCommand({required this.channelId});

  final ChannelId channelId;
}

abstract interface class NotificationPreferenceRepo
    with
        RepositoryGetOne<NotificationPreferenceData,
            GetNotificationPreferenceQuery>,
        RepositoryUpdateOne<void, UpdateNotificationPreferenceCommand> {}
