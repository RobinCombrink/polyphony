import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/network/domain_extensions/api_model_extensions.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_preference_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_service.dart";

class NotificationPreferenceRepository implements NotificationPreferenceRepo {
  const NotificationPreferenceRepository({
    required NotificationService notificationService,
  }) : _notificationService = notificationService;

  final NotificationService _notificationService;

  @override
  Future<Result<NotificationPreferenceData>> getOne({
    required GetNotificationPreferenceQuery query,
  }) {
    return switch (query) {
      GetGlobalNotificationPreferenceQuery() => _getGlobal(),
      GetServerNotificationPreferenceQuery(:final serverId) =>
        _getServer(serverId.value),
      GetChannelNotificationPreferenceQuery(:final channelId) =>
        _getChannel(channelId.value),
    };
  }

  @override
  Future<Result<void>> updateOne({
    required UpdateNotificationPreferenceCommand command,
  }) {
    return switch (command) {
      UpdateGlobalNotificationPreferenceCommand() =>
        _notificationService.updateGlobalNotificationPreference(
          muteState: command.muteState?.toApi(),
          notificationCategory: command.notificationCategory?.toApi(),
          channelDefaultCategory: command.channelDefaultCategory?.toApi(),
        ),
      UpdateServerNotificationPreferenceCommand() =>
        _notificationService.updateServerNotificationPreference(
          serverId: command.serverId.value,
          muteState: command.muteState?.toApi(),
          notificationCategory: command.notificationCategory?.toApi(),
        ),
      UpdateChannelNotificationCategoryCommand() =>
        _notificationService.updateChannelNotificationPreference(
          channelId: command.channelId.value,
          notificationCategory: command.notificationCategory.toApi(),
        ),
      MuteChannelCommand() =>
        _notificationService.muteChannelNotifications(
          channelId: command.channelId.value,
          durationMinutes: command.durationMinutes,
        ),
      UnmuteChannelCommand() =>
        _notificationService.unmuteChannelNotifications(
          channelId: command.channelId.value,
        ),
    };
  }

  Future<Result<NotificationPreferenceData>> _getGlobal() async {
    final result =
        await _notificationService.getGlobalNotificationPreference();
    return switch (result) {
      Ok<ApiNotificationGlobalPreference>(:final value) =>
        Ok(GlobalNotificationPreferenceData(preference: value.toDomain())),
      Error<ApiNotificationGlobalPreference>(:final error) => Error(error),
    };
  }

  Future<Result<NotificationPreferenceData>> _getServer(
    String serverId,
  ) async {
    final result =
        await _notificationService.getServerNotificationPreference(
      serverId: serverId,
    );
    return switch (result) {
      Ok<ApiNotificationServerPreference>(:final value) =>
        Ok(ServerNotificationPreferenceData(preference: value.toDomain())),
      Error<ApiNotificationServerPreference>(:final error) => Error(error),
    };
  }

  Future<Result<NotificationPreferenceData>> _getChannel(
    String channelId,
  ) async {
    final result =
        await _notificationService.getChannelNotificationPreference(
      channelId: channelId,
    );
    return switch (result) {
      Ok<ApiNotificationChannelPreference>(:final value) =>
        Ok(ChannelNotificationPreferenceData(preference: value.toDomain())),
      Error<ApiNotificationChannelPreference>(:final error) => Error(error),
    };
  }
}
