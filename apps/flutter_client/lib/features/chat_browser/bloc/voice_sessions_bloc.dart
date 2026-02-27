import "package:bloc_concurrency/bloc_concurrency.dart";
import "package:flutter_bloc/flutter_bloc.dart";
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
        participantSubjects: loadedState.participantSubjects,
      ));
      return;
    }

    final participantSubjects = loadedState?.channelId == trimmedChannelId
        ? _participantSubjectsOrFallback(
            runtimeSubjects:
                _voiceRuntimeService.currentParticipantSubjects().toList(),
            fallbackSubjects: loadedState?.participantSubjects,
            activeConnection: loadedState?.activeConnection,
          )
        : const <String>[];

    emit(VoiceSessionsLoadedState(
      activeConnection: loadedState?.channelId == trimmedChannelId
          ? loadedState?.activeConnection
          : null,
      channelId: trimmedChannelId,
      participantSubjects: participantSubjects,
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
        participantSubjects: loadedState.participantSubjects,
      ));
      return;
    }

    final activeConnection = loadedState.activeConnection;
    if (activeConnection != null &&
        activeConnection.channelId == trimmedChannelId) {
      emit(VoiceSessionsLoadedState(
        activeConnection: activeConnection,
        channelId: trimmedChannelId,
        participantSubjects: _participantSubjectsOrFallback(
          runtimeSubjects:
              _voiceRuntimeService.currentParticipantSubjects().toList(),
          fallbackSubjects: loadedState.participantSubjects,
          activeConnection: activeConnection,
        ),
      ));
      return;
    }

    if (activeConnection != null &&
        activeConnection.channelId != trimmedChannelId) {
      final runtimeDisconnectResult = await _voiceRuntimeService.disconnect();
      if (runtimeDisconnectResult case Error<void>(:final error)) {
        emit(VoiceSessionsExceptionState(error: error));
        return;
      }

      final backendDisconnectResult = await _voiceSessionRepo.deleteOne(
        command: DisconnectVoiceSessionCommand(
          channelId: activeConnection.channelId,
        ),
      );

      if (backendDisconnectResult case Error<void>(:final error)) {
        emit(VoiceSessionsExceptionState(error: error));
        return;
      }
    }

    emit(const VoiceSessionsLoadingState());

    final connectVoiceSessionResult = await _voiceSessionRepo.createOne(
      command: ConnectVoiceSessionCommand(
        channelId: trimmedChannelId,
      ),
    );

    switch (connectVoiceSessionResult) {
      case Ok<VoiceConnectSession>(:final value):
        final runtimeConnectResult = await _voiceRuntimeService.connect(
          livekitUrl: value.livekitUrl,
          accessToken: value.accessToken,
        );

        switch (runtimeConnectResult) {
          case Ok<void>():
            final participantSubjects = _participantSubjectsOrFallback(
              runtimeSubjects:
                  _voiceRuntimeService.currentParticipantSubjects().toList(),
              fallbackSubjects: const <String>[],
              activeConnection: value,
            );
            emit(VoiceSessionsLoadedState(
              activeConnection: value,
              channelId: trimmedChannelId,
              participantSubjects: participantSubjects,
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
        participantSubjects: loadedState.participantSubjects,
      ));
      return;
    }

    emit(const VoiceSessionsLoadingState());

    final runtimeDisconnectResult = await _voiceRuntimeService.disconnect();

    if (runtimeDisconnectResult case Error<void>(:final error)) {
      emit(VoiceSessionsExceptionState(error: error));
      return;
    }

    final backendDisconnectResult = await _voiceSessionRepo.deleteOne(
      command: DisconnectVoiceSessionCommand(
        channelId: trimmedChannelId,
      ),
    );

    switch (backendDisconnectResult) {
      case Ok<void>():
        emit(VoiceSessionsLoadedState(
          activeConnection: null,
          channelId: trimmedChannelId,
          participantSubjects: const <String>[],
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

  List<String> _participantSubjectsOrFallback({
    required List<String> runtimeSubjects,
    required List<String>? fallbackSubjects,
    required VoiceConnectSession? activeConnection,
  }) {
    if (runtimeSubjects.isNotEmpty) {
      return runtimeSubjects.toSet().toList();
    }

    if (fallbackSubjects != null && fallbackSubjects.isNotEmpty) {
      return fallbackSubjects.toSet().toList();
    }

    final participantSubject = activeConnection?.participantSubject;
    if (participantSubject != null && participantSubject.isNotEmpty) {
      return <String>[participantSubject];
    }

    return const <String>[];
  }
}
