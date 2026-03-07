import "package:bloc_concurrency/bloc_concurrency.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "notification_preferences_event.dart";
part "notification_preferences_state.dart";

class NotificationPreferencesBloc
    extends Bloc<NotificationPreferencesEvent, NotificationPreferencesState> {
  NotificationPreferencesBloc({
    required NotificationRepo notificationRepo,
  })  : _notificationRepo = notificationRepo,
        super(const NotificationPreferencesInitialState()) {
    on<NotificationPreferencesEvent>(
      _onEvent,
      transformer: sequential(),
    );
  }

  final NotificationRepo _notificationRepo;

  Future<void> _onEvent(
    NotificationPreferencesEvent event,
    Emitter<NotificationPreferencesState> emit,
  ) async {
    switch (event) {
      case LoadNotificationPreferencesRequested():
        await _loadPreferences(
          emit,
          serverId: event.serverId,
          channelId: event.channelId,
          emitLoadingState: true,
        );
      case GlobalMuteToggledRequested():
        await _updateAndReload(
          emit,
          operation: () => _notificationRepo.updateGlobalNotificationPreference(
            muteState: event.muted
                ? ApiNotificationMuteState.muted
                : ApiNotificationMuteState.unmuted,
          ),
        );
      case GlobalNotificationCategoryChangedRequested():
        await _updateAndReload(
          emit,
          operation: () => _notificationRepo.updateGlobalNotificationPreference(
            notificationCategory: event.notificationCategory,
          ),
        );
      case GlobalChannelDefaultCategoryChangedRequested():
        await _updateAndReload(
          emit,
          operation: () => _notificationRepo.updateGlobalNotificationPreference(
            channelDefaultCategory: event.channelDefaultCategory,
          ),
        );
      case ServerMuteToggledRequested():
        await _updateAndReload(
          emit,
          operation: () => _notificationRepo.updateServerNotificationPreference(
            serverId: event.serverId,
            muteState: event.muted
                ? ApiNotificationMuteState.muted
                : ApiNotificationMuteState.unmuted,
          ),
        );
      case ServerNotificationCategoryChangedRequested():
        await _updateAndReload(
          emit,
          operation: () => _notificationRepo.updateServerNotificationPreference(
            serverId: event.serverId,
            notificationCategory: event.notificationCategory,
          ),
        );
      case ChannelMuteToggledRequested():
        await _updateAndReload(
          emit,
          operation: () {
            if (event.muted) {
              return _notificationRepo.muteChannelNotifications(
                channelId: event.channelId,
                durationMinutes: 30,
              );
            }

            return _notificationRepo.unmuteChannelNotifications(
              channelId: event.channelId,
            );
          },
        );
      case ChannelNotificationCategoryChangedRequested():
        await _updateAndReload(
          emit,
          operation: () =>
              _notificationRepo.updateChannelNotificationPreference(
            channelId: event.channelId,
            notificationCategory: event.notificationCategory,
          ),
        );
    }
  }

  Future<void> _updateAndReload(
    Emitter<NotificationPreferencesState> emit, {
    required Future<Result<void>> Function() operation,
  }) async {
    final loadedDataState = _loadedStateOrNull(state);
    if (loadedDataState == null) {
      return;
    }

    emit(NotificationPreferencesLoadingState(
      globalPreference: loadedDataState.globalPreference,
      serverId: loadedDataState.serverId,
      channelId: loadedDataState.channelId,
      serverPreference: loadedDataState.serverPreference,
      channelPreference: loadedDataState.channelPreference,
    ));

    final operationResult = await operation();
    if (operationResult case Error<void>(:final error)) {
      emit(NotificationPreferencesExceptionState(
        error: error,
        globalPreference: loadedDataState.globalPreference,
        serverId: loadedDataState.serverId,
        channelId: loadedDataState.channelId,
        serverPreference: loadedDataState.serverPreference,
        channelPreference: loadedDataState.channelPreference,
      ));
      return;
    }

    await _loadPreferences(
      emit,
      serverId: loadedDataState.serverId,
      channelId: loadedDataState.channelId,
      emitLoadingState: false,
    );
  }

  Future<void> _loadPreferences(
    Emitter<NotificationPreferencesState> emit, {
    required String? serverId,
    required String? channelId,
    required bool emitLoadingState,
  }) async {
    final loadedDataState = _loadedStateOrNull(state);
    if (emitLoadingState && loadedDataState != null) {
      emit(NotificationPreferencesLoadingState(
        globalPreference: loadedDataState.globalPreference,
        serverId: serverId,
        channelId: channelId,
        serverPreference: loadedDataState.serverPreference,
        channelPreference: loadedDataState.channelPreference,
      ));
    }

    final globalResult =
        await _notificationRepo.getGlobalNotificationPreference();
    final ApiNotificationGlobalPreference globalPreference;
    switch (globalResult) {
      case Ok<ApiNotificationGlobalPreference>(:final value):
        globalPreference = value;
      case Error<ApiNotificationGlobalPreference>(:final error):
        if (loadedDataState != null) {
          emit(NotificationPreferencesExceptionState(
            error: error,
            globalPreference: loadedDataState.globalPreference,
            serverId: serverId,
            channelId: channelId,
            serverPreference: loadedDataState.serverPreference,
            channelPreference: loadedDataState.channelPreference,
          ));
        }
        return;
    }

    ApiNotificationServerPreference? serverPreference;
    final trimmedServerId = serverId?.trim();
    if (trimmedServerId != null && trimmedServerId.isNotEmpty) {
      final serverResult =
          await _notificationRepo.getServerNotificationPreference(
        serverId: trimmedServerId,
      );
      if (serverResult case Ok<ApiNotificationServerPreference>(:final value)) {
        serverPreference = value;
      }
    }

    ApiNotificationChannelPreference? channelPreference;
    final trimmedChannelId = channelId?.trim();
    if (trimmedChannelId != null && trimmedChannelId.isNotEmpty) {
      final channelResult =
          await _notificationRepo.getChannelNotificationPreference(
        channelId: trimmedChannelId,
      );
      if (channelResult
          case Ok<ApiNotificationChannelPreference>(:final value)) {
        channelPreference = value;
      }
    }

    emit(NotificationPreferencesLoadedState(
      globalPreference: globalPreference,
      serverId: trimmedServerId,
      channelId: trimmedChannelId,
      serverPreference: serverPreference,
      channelPreference: channelPreference,
    ));
  }

  NotificationPreferencesLoadedDataState? _loadedStateOrNull(
    NotificationPreferencesState state,
  ) {
    return switch (state) {
      NotificationPreferencesLoadedDataState() => state,
      _ => null,
    };
  }
}
