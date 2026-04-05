import "package:bloc_concurrency/bloc_concurrency.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/notification_service.dart";

part "notification_preferences_event.dart";
part "notification_preferences_state.dart";

class NotificationPreferencesBloc
    extends Bloc<NotificationPreferencesEvent, NotificationPreferencesState> {
  NotificationPreferencesBloc({
    required NotificationService notificationService,
  })  : _notificationService = notificationService,
        super(const NotificationPreferencesInitialState()) {
    on<NotificationPreferencesEvent>(
      _onEvent,
      transformer: sequential(),
    );
  }

  final NotificationService _notificationService;

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
          operation: () =>
              _notificationService.updateGlobalNotificationPreference(
            muteState: event.muted
                ? ApiNotificationMuteState.muted
                : ApiNotificationMuteState.unmuted,
          ),
        );
      case GlobalNotificationCategoryChangedRequested():
        await _updateAndReload(
          emit,
          operation: () =>
              _notificationService.updateGlobalNotificationPreference(
            notificationCategory: event.notificationCategory,
          ),
        );
      case GlobalChannelDefaultCategoryChangedRequested():
        await _updateAndReload(
          emit,
          operation: () =>
              _notificationService.updateGlobalNotificationPreference(
            channelDefaultCategory: event.channelDefaultCategory,
          ),
        );
      case ServerMuteToggledRequested():
        await _updateAndReload(
          emit,
          operation: () =>
              _notificationService.updateServerNotificationPreference(
            serverId: event.serverId,
            muteState: event.muted
                ? ApiNotificationMuteState.muted
                : ApiNotificationMuteState.unmuted,
          ),
        );
      case ServerNotificationCategoryChangedRequested():
        await _updateAndReload(
          emit,
          operation: () =>
              _notificationService.updateServerNotificationPreference(
            serverId: event.serverId,
            notificationCategory: event.notificationCategory,
          ),
        );
      case ChannelMuteToggledRequested():
        await _updateAndReload(
          emit,
          operation: () {
            if (event.muted) {
              return _notificationService.muteChannelNotifications(
                channelId: event.channelId,
                durationMinutes: 30,
              );
            }

            return _notificationService.unmuteChannelNotifications(
              channelId: event.channelId,
            );
          },
        );
      case ChannelNotificationCategoryChangedRequested():
        await _updateAndReload(
          emit,
          operation: () =>
              _notificationService.updateChannelNotificationPreference(
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

    emit(loadedDataState.toLoading());

    final operationResult = await operation();
    if (operationResult case Error<void>(:final error)) {
      emit(loadedDataState.toException(error: error));
      return;
    }

    final (serverId, channelId) = _scopeIds(loadedDataState.scope);
    await _loadPreferences(
      emit,
      serverId: serverId,
      channelId: channelId,
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
      emit(loadedDataState.toLoading());
    }

    final globalResult =
        await _notificationService.getGlobalNotificationPreference();
    final ApiNotificationGlobalPreference globalPreference;
    switch (globalResult) {
      case Ok<ApiNotificationGlobalPreference>(:final value):
        globalPreference = value;
      case Error<ApiNotificationGlobalPreference>(:final error):
        if (loadedDataState != null) {
          emit(loadedDataState.toException(error: error));
        }
        return;
    }

    ApiNotificationServerPreference? serverPreference;
    final trimmedServerId = serverId?.trim();
    if (trimmedServerId != null && trimmedServerId.isNotEmpty) {
      final serverResult =
          await _notificationService.getServerNotificationPreference(
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
          await _notificationService.getChannelNotificationPreference(
        channelId: trimmedChannelId,
      );
      if (channelResult
          case Ok<ApiNotificationChannelPreference>(:final value)) {
        channelPreference = value;
      }
    }

    emit(NotificationPreferencesLoadedState(
      globalPreference: globalPreference,
      scope: _buildScope(
        serverId: trimmedServerId,
        channelId: trimmedChannelId,
        serverPreference: serverPreference,
        channelPreference: channelPreference,
      ),
    ));
  }

  static (String?, String?) _scopeIds(NotificationPreferencesScope scope) {
    return switch (scope) {
      NotificationPreferencesGlobalScope() => (null, null),
      NotificationPreferencesServerScope(:final serverId) => (serverId, null),
      NotificationPreferencesChannelScope(:final channelId) => (
          null,
          channelId
        ),
    };
  }

  static NotificationPreferencesScope _buildScope({
    required String? serverId,
    required String? channelId,
    required ApiNotificationServerPreference? serverPreference,
    required ApiNotificationChannelPreference? channelPreference,
  }) {
    if (channelId != null && channelId.isNotEmpty) {
      return NotificationPreferencesChannelScope(
        channelId: channelId,
        channelPreference: channelPreference,
      );
    }

    if (serverId != null && serverId.isNotEmpty) {
      return NotificationPreferencesServerScope(
        serverId: serverId,
        serverPreference: serverPreference,
      );
    }

    return const NotificationPreferencesGlobalScope();
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
