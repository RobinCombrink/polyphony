import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class GetNotificationUnreadCountQuery {
  const GetNotificationUnreadCountQuery();
}

sealed class NotificationUpdateCommand {
  const NotificationUpdateCommand();
}

final class MarkChannelReadCommand extends NotificationUpdateCommand {
  const MarkChannelReadCommand({required this.channelId});

  final ChannelId channelId;
}

final class MarkMessageAsUnreadCommand extends NotificationUpdateCommand {
  const MarkMessageAsUnreadCommand({
    required this.channelId,
    required this.messageId,
  });

  final ChannelId channelId;
  final MessageId messageId;
}

abstract interface class NotificationRepo
    with
        RepositoryGetOne<int, GetNotificationUnreadCountQuery>,
        RepositoryUpdateOne<void, NotificationUpdateCommand> {}
