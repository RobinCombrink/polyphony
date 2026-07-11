import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_preference_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class UnmuteChannelNotificationsUseCase {
  const UnmuteChannelNotificationsUseCase({
    required NotificationPreferenceRepo notificationPreferenceRepo,
  }) : _notificationPreferenceRepo = notificationPreferenceRepo;

  final NotificationPreferenceRepo _notificationPreferenceRepo;

  Future<Result<void>> call({required ChannelId channelId}) {
    return _notificationPreferenceRepo.updateOne(
      command: UnmuteChannelCommand(channelId: channelId),
    );
  }
}
