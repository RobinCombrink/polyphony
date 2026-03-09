import "dart:async";

import "package:bloc_concurrency/bloc_concurrency.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_badge_service.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

part "notification_center_event.dart";
part "notification_center_state.dart";

class NotificationCenterBloc
    extends Bloc<NotificationCenterEvent, NotificationCenterState> {
  NotificationCenterBloc({
    required NotificationRepo notificationRepo,
    required NotificationRuntimeService notificationRuntimeService,
    NotificationBadgeService? notificationBadgeService,
    PreferencesStore? preferencesStore,
  })  : _notificationRepo = notificationRepo,
        _notificationRuntimeService = notificationRuntimeService,
        _notificationBadgeService =
            notificationBadgeService ?? const NoOpNotificationBadgeService(),
        _preferencesStore = preferencesStore ?? const WebPreferencesStore(),
        super(const NotificationCenterInitialState()) {
    on<NotificationCenterEvent>(
      _onEvent,
      transformer: sequential(),
    );
  }

  static const _maxEntries = 20;

  final NotificationRepo _notificationRepo;
  final NotificationRuntimeService _notificationRuntimeService;
  final NotificationBadgeService _notificationBadgeService;
  final PreferencesStore _preferencesStore;
  StreamSubscription<RuntimeNotificationEvent>? _runtimeSubscription;

  @override
  Future<void> close() async {
    final runtimeSubscription = _runtimeSubscription;
    _runtimeSubscription = null;

    if (runtimeSubscription != null) {
      await runtimeSubscription.cancel();
    }

    await _notificationRuntimeService.disconnect();

    return super.close();
  }

  Future<void> _onEvent(
    NotificationCenterEvent event,
    Emitter<NotificationCenterState> emit,
  ) async {
    switch (event) {
      case NotificationCenterStartedRequested():
        await _onStartedRequested(event, emit);
      case _NotificationCenterRuntimeEventReceived():
        await _onRuntimeEventReceived(event, emit);
      case NotificationCenterUnreadCountRefreshRequested():
        await _refreshUnreadCount(emit);
      case NotificationCenterFeedClearedRequested():
        emit(
          NotificationCenterLoadedState(
            entries: const <NotificationCenterEntry>[],
            totalUnreadCount: state.totalUnreadCount,
          ),
        );
    }
  }

  Future<void> _onStartedRequested(
    NotificationCenterStartedRequested event,
    Emitter<NotificationCenterState> emit,
  ) async {
    if (_runtimeSubscription != null) {
      return;
    }

    final connectResult = await _notificationRuntimeService.connect(
      bearerToken: event.bearerToken,
    );

    if (connectResult case Error<void>(:final error)) {
      emit(
        NotificationCenterExceptionState(
          entries: state.entries,
          totalUnreadCount: state.totalUnreadCount,
          error: error,
        ),
      );
      return;
    }

    _runtimeSubscription =
        _notificationRuntimeService.notificationEvents().listen(
      (runtimeEvent) {
        add(
          _NotificationCenterRuntimeEventReceived(event: runtimeEvent),
        );
      },
    );

    await _refreshUnreadCount(emit);
  }

  Future<void> _onRuntimeEventReceived(
    _NotificationCenterRuntimeEventReceived event,
    Emitter<NotificationCenterState> emit,
  ) async {
    if (event.event
        case final FriendJoinedVoiceRuntimeNotificationEvent voiceEvent) {
      final isEnabled =
          await _preferencesStore.readChannelJoinNotificationsEnabled();
      if (!isEnabled) {
        return;
      }

      final allowedChannelIds =
          await _preferencesStore.readChannelJoinNotificationChannelIds();
      if (allowedChannelIds.isNotEmpty &&
          !allowedChannelIds.contains(voiceEvent.channelId)) {
        return;
      }
    }

    final nextEntries = <NotificationCenterEntry>[
      NotificationCenterEntry(
        event: event.event,
        receivedAt: DateTime.now(),
      ),
      ...state.entries,
    ].take(_maxEntries).toList(growable: false);

    emit(
      NotificationCenterLoadedState(
        entries: nextEntries,
        totalUnreadCount: state.totalUnreadCount,
      ),
    );

    await _refreshUnreadCount(emit, entriesOverride: nextEntries);
  }

  Future<void> _refreshUnreadCount(
    Emitter<NotificationCenterState> emit, {
    List<NotificationCenterEntry>? entriesOverride,
  }) async {
    final entries = entriesOverride ?? state.entries;

    final unreadCountResult = await _notificationRepo.getOne(
      query: const GetNotificationUnreadCountQuery(),
    );

    switch (unreadCountResult) {
      case Ok<int>(:final value):
        await _notificationBadgeService.syncUnreadCount(
          totalUnreadCount: value,
        );
        emit(
          NotificationCenterLoadedState(
            entries: entries,
            totalUnreadCount: value,
          ),
        );
      case Error<int>(:final error):
        emit(
          NotificationCenterExceptionState(
            entries: entries,
            totalUnreadCount: state.totalUnreadCount,
            error: error,
          ),
        );
    }
  }
}
