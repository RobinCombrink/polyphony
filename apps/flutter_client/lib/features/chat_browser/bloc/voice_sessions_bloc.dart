import "package:flutter_bloc/flutter_bloc.dart";
import "package:bloc_concurrency/bloc_concurrency.dart";

import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/voice_runtime_service.dart";

part "voice_sessions_event.dart";
part "voice_sessions_state.dart";

class VoiceSessionsBloc extends Bloc<VoiceSessionsEvent, VoiceSessionsState> {
  VoiceSessionsBloc({
    required VoiceSessionRepo voiceSessionRepo,
    required VoiceRuntimeService voiceRuntimeService,
  })  : _voiceSessionRepo = voiceSessionRepo,
        _voiceRuntimeService = voiceRuntimeService,
        super(const VoiceSessionsInitialState()) {
    on<VoiceSessionsEvent>(
      _onVoiceSessionsEvent,
      transformer: sequential(),
    );
  }

  final VoiceSessionRepo _voiceSessionRepo;
  final VoiceRuntimeService _voiceRuntimeService;

  Future<void> _onVoiceSessionsEvent(
    VoiceSessionsEvent event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    switch (event) {
      case ResetVoiceSessionsRequested():
        await _voiceRuntimeService.disconnect();
        emit(const VoiceSessionsInitialState());
      case LoadVoiceSessionsRequested():
        await _onLoadVoiceSessionsRequested(event, emit);
      case ConnectVoiceSessionRequested():
        await _onConnectVoiceSessionRequested(event, emit);
      case DisconnectVoiceSessionRequested():
        await _onDisconnectVoiceSessionRequested(event, emit);
    }
  }

  Future<void> _onLoadVoiceSessionsRequested(
    LoadVoiceSessionsRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();
    final loadedState = _loadedStateOrNull(state);

    if (trimmedChannelId.isEmpty) {
      if (loadedState == null) {
        emit(VoiceSessionsExceptionState(
          error: Exception("Voice sessions must be loaded before validation."),
        ));
        return;
      }

      emit(VoiceSessionsValidationFailedState(
        issue: VoiceSessionsValidationIssue.channelSelectionRequired,
        activeConnection: loadedState.activeConnection,
        channelId: loadedState.channelId,
      ));
      return;
    }

    emit(VoiceSessionsLoadedState(
      activeConnection: loadedState?.channelId == trimmedChannelId
          ? loadedState?.activeConnection
          : null,
      channelId: trimmedChannelId,
    ));
  }

  Future<void> _onConnectVoiceSessionRequested(
    ConnectVoiceSessionRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();
    final loadedState = _loadedStateOrNull(state);

    if (loadedState == null) {
      emit(VoiceSessionsExceptionState(
        error: Exception("Voice sessions must be loaded before joining."),
      ));
      return;
    }

    if (trimmedChannelId.isEmpty) {
      emit(VoiceSessionsValidationFailedState(
        issue: VoiceSessionsValidationIssue.channelSelectionRequired,
        activeConnection: loadedState.activeConnection,
        channelId: loadedState.channelId,
      ));
      return;
    }

    emit(const VoiceSessionsLoadingState());

    final connectVoiceSessionResult =
        await _voiceSessionRepo.connectVoiceSession(
      baseUrl: event.baseUrl.trim(),
      channelId: trimmedChannelId,
    );

    switch (connectVoiceSessionResult) {
      case Ok<VoiceConnectSession>(:final value):
        final runtimeConnectResult = await _voiceRuntimeService.connect(
          livekitUrl: value.livekitUrl,
          accessToken: value.accessToken,
        );

        switch (runtimeConnectResult) {
          case Ok<void>():
            emit(VoiceSessionsLoadedState(
              activeConnection: value,
              channelId: trimmedChannelId,
            ));
          case Error<void>(:final error):
            emit(VoiceSessionsExceptionState(error: error));
        }
      case Error<VoiceConnectSession>(:final error):
        emit(VoiceSessionsExceptionState(error: error));
    }
  }

  Future<void> _onDisconnectVoiceSessionRequested(
    DisconnectVoiceSessionRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();
    final loadedState = _loadedStateOrNull(state);

    if (loadedState == null) {
      emit(VoiceSessionsExceptionState(
        error: Exception("Voice sessions must be loaded before leaving."),
      ));
      return;
    }

    if (trimmedChannelId.isEmpty) {
      emit(VoiceSessionsValidationFailedState(
        issue: VoiceSessionsValidationIssue.channelSelectionRequired,
        activeConnection: loadedState.activeConnection,
        channelId: loadedState.channelId,
      ));
      return;
    }

    emit(const VoiceSessionsLoadingState());

    final runtimeDisconnectResult = await _voiceRuntimeService.disconnect();

    if (runtimeDisconnectResult case Error<void>(:final error)) {
      emit(VoiceSessionsExceptionState(error: error));
      return;
    }

    final backendDisconnectResult =
        await _voiceSessionRepo.disconnectVoiceSession(
      baseUrl: event.baseUrl.trim(),
      channelId: trimmedChannelId,
    );

    switch (backendDisconnectResult) {
      case Ok<void>():
        emit(VoiceSessionsLoadedState(
          activeConnection: null,
          channelId: trimmedChannelId,
        ));
      case Error<void>(:final error):
        emit(VoiceSessionsExceptionState(error: error));
    }
  }

  VoiceSessionsLoadedDataState? _loadedStateOrNull(VoiceSessionsState state) {
    return switch (state) {
      VoiceSessionsLoadedDataState() => state,
      _ => null,
    };
  }
}
