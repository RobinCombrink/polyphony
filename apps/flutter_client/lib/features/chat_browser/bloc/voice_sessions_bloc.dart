import "package:flutter_bloc/flutter_bloc.dart";

import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "voice_sessions_event.dart";
part "voice_sessions_state.dart";

class VoiceSessionsBloc extends Bloc<VoiceSessionsEvent, VoiceSessionsState> {
  VoiceSessionsBloc({required VoiceSessionRepo voiceSessionRepo})
      : _voiceSessionRepo = voiceSessionRepo,
        super(const VoiceSessionsInitialState()) {
    on<ResetVoiceSessionsRequested>(_onResetVoiceSessionsRequested);
    on<LoadVoiceSessionsRequested>(_onLoadVoiceSessionsRequested);
    on<JoinVoiceSessionRequested>(_onJoinVoiceSessionRequested);
    on<LeaveVoiceSessionRequested>(_onLeaveVoiceSessionRequested);
  }

  final VoiceSessionRepo _voiceSessionRepo;

  void _onResetVoiceSessionsRequested(
    ResetVoiceSessionsRequested event,
    Emitter<VoiceSessionsState> emit,
  ) {
    emit(const VoiceSessionsInitialState());
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
        voiceSessions: loadedState.voiceSessions,
        channelId: loadedState.channelId,
      ));
      return;
    }

    emit(const VoiceSessionsLoadingState());

    final listVoiceSessionsResult = await _voiceSessionRepo.listVoiceSessions(
      baseUrl: event.baseUrl.trim(),
      channelId: trimmedChannelId,
    );

    switch (listVoiceSessionsResult) {
      case Ok<List<VoiceSession>>(:final value):
        emit(VoiceSessionsLoadedState(
          voiceSessions: value,
          channelId: trimmedChannelId,
        ));
      case Error<List<VoiceSession>>(:final error):
        emit(VoiceSessionsExceptionState(error: error));
    }
  }

  Future<void> _onJoinVoiceSessionRequested(
    JoinVoiceSessionRequested event,
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
        voiceSessions: loadedState.voiceSessions,
        channelId: loadedState.channelId,
      ));
      return;
    }

    emit(const VoiceSessionsLoadingState());

    final joinVoiceSessionResult = await _voiceSessionRepo.joinVoiceSession(
      baseUrl: event.baseUrl.trim(),
      channelId: trimmedChannelId,
    );

    switch (joinVoiceSessionResult) {
      case Ok<VoiceSession>():
        final listVoiceSessionsResult =
            await _voiceSessionRepo.listVoiceSessions(
          baseUrl: event.baseUrl.trim(),
          channelId: trimmedChannelId,
        );
        switch (listVoiceSessionsResult) {
          case Ok<List<VoiceSession>>(:final value):
            emit(VoiceSessionsLoadedState(
              voiceSessions: value,
              channelId: trimmedChannelId,
            ));
          case Error<List<VoiceSession>>(:final error):
            emit(VoiceSessionsExceptionState(error: error));
        }
      case Error<VoiceSession>(:final error):
        emit(VoiceSessionsExceptionState(error: error));
    }
  }

  Future<void> _onLeaveVoiceSessionRequested(
    LeaveVoiceSessionRequested event,
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
        voiceSessions: loadedState.voiceSessions,
        channelId: loadedState.channelId,
      ));
      return;
    }

    emit(const VoiceSessionsLoadingState());

    final leaveVoiceSessionResult = await _voiceSessionRepo.leaveVoiceSession(
      baseUrl: event.baseUrl.trim(),
      channelId: trimmedChannelId,
    );

    switch (leaveVoiceSessionResult) {
      case Ok<void>():
        final listVoiceSessionsResult =
            await _voiceSessionRepo.listVoiceSessions(
          baseUrl: event.baseUrl.trim(),
          channelId: trimmedChannelId,
        );
        switch (listVoiceSessionsResult) {
          case Ok<List<VoiceSession>>(:final value):
            emit(VoiceSessionsLoadedState(
              voiceSessions: value,
              channelId: trimmedChannelId,
            ));
          case Error<List<VoiceSession>>(:final error):
            emit(VoiceSessionsExceptionState(error: error));
        }
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
