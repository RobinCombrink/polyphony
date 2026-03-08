import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";

part "notification_feed_event.dart";
part "notification_feed_state.dart";

class NotificationFeedBloc
    extends Bloc<NotificationFeedEvent, NotificationFeedState> {
  NotificationFeedBloc() : super(const NotificationFeedInitialState()) {
    on<NotificationFeedEvent>(_onEvent);
  }

  static const _maxEntries = 20;

  void _onEvent(
    NotificationFeedEvent event,
    Emitter<NotificationFeedState> emit,
  ) {
    switch (event) {
      case NotificationFeedRuntimeEventReceived():
        final nextEntries = <NotificationFeedEntry>[
          NotificationFeedEntry(
            event: event.event,
            receivedAt: DateTime.now(),
          ),
          ...state.entries,
        ].take(_maxEntries).toList(growable: false);

        emit(NotificationFeedLoadedState(entries: nextEntries));
      case NotificationFeedClearedRequested():
        emit(const NotificationFeedLoadedState(
            entries: <NotificationFeedEntry>[]));
    }
  }
}
