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

    if (trimmedChannelId.isEmpty) {
      emit(VoiceSessionsValidationFailedState(
        issue: VoiceSessionsValidationIssue.channelSelectionRequired,
        voiceSessions: state.voiceSessions,
        channelId: state.channelId,
      ));
      return;
    }

    emit(VoiceSessionsLoadingState(
      voiceSessions: state.voiceSessions,
      channelId: trimmedChannelId,
    ));

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
        emit(VoiceSessionsExceptionState(
          error: error,
          voiceSessions: state.voiceSessions,
          channelId: state.channelId,
        ));
    }
  }

  Future<void> _onJoinVoiceSessionRequested(
    JoinVoiceSessionRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();

    if (trimmedChannelId.isEmpty) {
      emit(VoiceSessionsValidationFailedState(
        issue: VoiceSessionsValidationIssue.channelSelectionRequired,
        voiceSessions: state.voiceSessions,
        channelId: state.channelId,
      ));
      return;
    }

    emit(VoiceSessionsLoadingState(
      voiceSessions: state.voiceSessions,
      channelId: trimmedChannelId,
    ));

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
            emit(VoiceSessionsExceptionState(
              error: error,
              voiceSessions: state.voiceSessions,
              channelId: state.channelId,
            ));
        }
      case Error<VoiceSession>(:final error):
        emit(VoiceSessionsExceptionState(
          error: error,
          voiceSessions: state.voiceSessions,
          channelId: state.channelId,
        ));
    }
  }

  Future<void> _onLeaveVoiceSessionRequested(
    LeaveVoiceSessionRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();

    if (trimmedChannelId.isEmpty) {
      emit(VoiceSessionsValidationFailedState(
        issue: VoiceSessionsValidationIssue.channelSelectionRequired,
        voiceSessions: state.voiceSessions,
        channelId: state.channelId,
      ));
      return;
    }

    emit(VoiceSessionsLoadingState(
      voiceSessions: state.voiceSessions,
      channelId: trimmedChannelId,
    ));

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
            emit(VoiceSessionsExceptionState(
              error: error,
              voiceSessions: state.voiceSessions,
              channelId: state.channelId,
            ));
        }
      case Error<void>(:final error):
        emit(VoiceSessionsExceptionState(
          error: error,
          voiceSessions: state.voiceSessions,
          channelId: state.channelId,
        ));
    }
  }
}
