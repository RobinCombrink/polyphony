import "package:polyphony_flutter_client/shared/repositories/repository_mixins.dart";

class GetNotificationUnreadCountQuery {
  const GetNotificationUnreadCountQuery();
}

abstract interface class NotificationRepo
    with RepositoryGetOne<int, GetNotificationUnreadCountQuery> {}
