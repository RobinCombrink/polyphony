import "package:bloc_concurrency/bloc_concurrency.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_unread_count_event.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_unread_count_state.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class NotificationUnreadCountBloc
    extends Bloc<NotificationUnreadCountEvent, NotificationUnreadCountState> {
  NotificationUnreadCountBloc({
    required NotificationRepo notificationRepo,
  })  : _notificationRepo = notificationRepo,
        super(const NotificationUnreadCountInitialState()) {
    on<NotificationUnreadCountEvent>(
      _onEvent,
      transformer: sequential(),
    );
  }

  final NotificationRepo _notificationRepo;

  Future<void> _onEvent(
    NotificationUnreadCountEvent event,
    Emitter<NotificationUnreadCountState> emit,
  ) async {
    switch (event) {
      case LoadNotificationUnreadCountRequested():
        await _onLoadNotificationUnreadCountRequested(emit);
    }
  }

  Future<void> _onLoadNotificationUnreadCountRequested(
    Emitter<NotificationUnreadCountState> emit,
  ) async {
    final result = await _notificationRepo.getOne(
      query: const GetNotificationUnreadCountQuery(),
    );

    switch (result) {
      case Ok<int>(:final value):
        emit(NotificationUnreadCountLoadedState(totalUnreadCount: value));
      case Error<int>(:final error):
        final lastKnownTotalUnreadCount = state.totalUnreadCountOrZero();
        emit(
          NotificationUnreadCountExceptionState(
            error: error,
            lastKnownTotalUnreadCount: lastKnownTotalUnreadCount,
          ),
        );
    }
  }
}
