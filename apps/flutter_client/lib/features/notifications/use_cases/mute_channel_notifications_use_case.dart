import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_preference_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class MuteChannelNotificationsUseCase {
  const MuteChannelNotificationsUseCase({
    required NotificationPreferenceRepo notificationPreferenceRepo,
  }) : _notificationPreferenceRepo = notificationPreferenceRepo;

  final NotificationPreferenceRepo _notificationPreferenceRepo;

  Future<Result<void>> call({
    required ChannelId channelId,
    required int durationMinutes,
  }) {
    return _notificationPreferenceRepo.updateOne(
      command: MuteChannelCommand(
        channelId: channelId,
        durationMinutes: durationMinutes,
      ),
    );
  }
}
