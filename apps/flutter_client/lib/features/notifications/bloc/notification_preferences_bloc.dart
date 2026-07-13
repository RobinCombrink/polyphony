import "package:bloc_concurrency/bloc_concurrency.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/use_cases/mute_channel_notifications_use_case.dart";
import "package:polyphony_flutter_client/features/notifications/use_cases/unmute_channel_notifications_use_case.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/models/notification_preference.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_preference_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "notification_preferences_event.dart";
part "notification_preferences_state.dart";

class NotificationPreferencesBloc
    extends Bloc<NotificationPreferencesEvent, NotificationPreferencesState> {
  NotificationPreferencesBloc({
    required NotificationPreferenceRepo notificationPreferenceRepo,
    required MuteChannelNotificationsUseCase muteChannelNotificationsUseCase,
    required UnmuteChannelNotificationsUseCase
        unmuteChannelNotificationsUseCase,
  })  : _notificationPreferenceRepo = notificationPreferenceRepo,
        _muteChannelNotificationsUseCase = muteChannelNotificationsUseCase,
        _unmuteChannelNotificationsUseCase = unmuteChannelNotificationsUseCase,
        super(const NotificationPreferencesInitialState()) {
    on<NotificationPreferencesEvent>(
      _onEvent,
      transformer: sequential(),
    );
  }

  final NotificationPreferenceRepo _notificationPreferenceRepo;
  final MuteChannelNotificationsUseCase _muteChannelNotificationsUseCase;
  final UnmuteChannelNotificationsUseCase _unmuteChannelNotificationsUseCase;

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
          operation: () => _notificationPreferenceRepo.updateOne(
            command: UpdateGlobalNotificationPreferenceCommand(
              muteState: event.muted
                  ? NotificationMuteState.muted
                  : NotificationMuteState.unmuted,
            ),
          ),
        );
      case GlobalNotificationCategoryChangedRequested():
        await _updateAndReload(
          emit,
          operation: () => _notificationPreferenceRepo.updateOne(
            command: UpdateGlobalNotificationPreferenceCommand(
              notificationCategory: event.notificationCategory,
            ),
          ),
        );
      case GlobalChannelDefaultCategoryChangedRequested():
        await _updateAndReload(
          emit,
          operation: () => _notificationPreferenceRepo.updateOne(
            command: UpdateGlobalNotificationPreferenceCommand(
              channelDefaultCategory: event.channelDefaultCategory,
            ),
          ),
        );
      case ServerMuteToggledRequested():
        await _updateAndReload(
          emit,
          operation: () => _notificationPreferenceRepo.updateOne(
            command: UpdateServerNotificationPreferenceCommand(
              serverId: event.serverId,
              muteState: event.muted
                  ? NotificationMuteState.muted
                  : NotificationMuteState.unmuted,
            ),
          ),
        );
      case ServerNotificationCategoryChangedRequested():
        await _updateAndReload(
          emit,
          operation: () => _notificationPreferenceRepo.updateOne(
            command: UpdateServerNotificationPreferenceCommand(
              serverId: event.serverId,
              notificationCategory: event.notificationCategory,
            ),
          ),
        );
      case ChannelMuteToggledRequested():
        await _updateAndReload(
          emit,
          operation: () {
            if (event.muted) {
              return _muteChannelNotificationsUseCase(
                channelId: event.channelId,
                durationMinutes: 30,
              );
            }

            return _unmuteChannelNotificationsUseCase(
              channelId: event.channelId,
            );
          },
        );
      case ChannelNotificationCategoryChangedRequested():
        await _updateAndReload(
          emit,
          operation: () => _notificationPreferenceRepo.updateOne(
            command: UpdateChannelNotificationCategoryCommand(
              channelId: event.channelId,
              notificationCategory: event.notificationCategory,
            ),
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
    required ServerId? serverId,
    required ChannelId? channelId,
    required bool emitLoadingState,
  }) async {
    final loadedDataState = _loadedStateOrNull(state);
    if (emitLoadingState && loadedDataState != null) {
      emit(loadedDataState.toLoading());
    }

    final globalResult = await _notificationPreferenceRepo.getOne(
      query: const GetGlobalNotificationPreferenceQuery(),
    );
    final NotificationGlobalPreference globalPreference;
    switch (globalResult) {
      case Ok<NotificationPreferenceData>(
          value: GlobalNotificationPreferenceData(:final preference)
        ):
        globalPreference = preference;
      case Error<NotificationPreferenceData>(:final error):
        if (loadedDataState != null) {
          emit(loadedDataState.toException(error: error));
        }
        return;
      default:
        return;
    }

    NotificationServerPreference? serverPreference;
    if (serverId != null) {
      final serverResult = await _notificationPreferenceRepo.getOne(
        query: GetServerNotificationPreferenceQuery(serverId: serverId),
      );
      if (serverResult
          case Ok<NotificationPreferenceData>(
            value: ServerNotificationPreferenceData(:final preference)
          )) {
        serverPreference = preference;
      }
    }

    NotificationChannelPreference? channelPreference;
    if (channelId != null) {
      final channelResult = await _notificationPreferenceRepo.getOne(
        query: GetChannelNotificationPreferenceQuery(channelId: channelId),
      );
      if (channelResult
          case Ok<NotificationPreferenceData>(
            value: ChannelNotificationPreferenceData(:final preference)
          )) {
        channelPreference = preference;
      }
    }

    emit(NotificationPreferencesLoadedState(
      globalPreference: globalPreference,
      scope: _buildScope(
        serverId: serverId,
        channelId: channelId,
        serverPreference: serverPreference,
        channelPreference: channelPreference,
      ),
    ));
  }

  static (ServerId?, ChannelId?) _scopeIds(NotificationPreferencesScope scope) {
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
    required ServerId? serverId,
    required ChannelId? channelId,
    required NotificationServerPreference? serverPreference,
    required NotificationChannelPreference? channelPreference,
  }) {
    if (channelId != null) {
      return NotificationPreferencesChannelScope(
        channelId: channelId,
        channelPreference: channelPreference,
      );
    }

    if (serverId != null) {
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
