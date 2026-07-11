import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_service.dart";

class NotificationRepository implements NotificationRepo {
  const NotificationRepository({
    required NotificationService notificationService,
  }) : _notificationService = notificationService;

  final NotificationService _notificationService;

  @override
  Future<Result<int>> getOne({
    required GetNotificationUnreadCountQuery query,
  }) async {
    final serviceResult =
        await _notificationService.getUnreadNotificationCount();

    return switch (serviceResult) {
      Ok<ApiNotificationUnreadCount>(:final value) =>
        Ok<int>(value.totalUnreadCount),
      Error<ApiNotificationUnreadCount>(:final error) => Error<int>(error),
    };
  }

  @override
  Future<Result<void>> updateOne({
    required NotificationUpdateCommand command,
  }) {
    return switch (command) {
      MarkChannelReadCommand(:final channelId) =>
        _notificationService.markChannelNotificationsRead(
          channelId: channelId.value,
        ),
      MarkMessageAsUnreadCommand(:final channelId, :final messageId) =>
        _notificationService.markMessageAsUnread(
          channelId: channelId.value,
          messageId: messageId.value,
        ),
    };
  }
}
