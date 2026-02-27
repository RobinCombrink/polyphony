import "package:bloc_concurrency/bloc_concurrency.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/voice_runtime_service.dart";

part "voice_sessions_event.dart";
part "voice_sessions_state.dart";

class VoiceSessionsBloc extends Bloc<VoiceSessionsEvent, VoiceSessionsState> {
  VoiceSessionsBloc({
    required VoiceSessionRepo voiceSessionRepo,
    required VoiceRuntimeService voiceRuntimeService,
    required ProfileRepo profileRepo,
  })  : _voiceSessionRepo = voiceSessionRepo,
        _voiceRuntimeService = voiceRuntimeService,
        _profileRepo = profileRepo,
        super(const VoiceSessionsInitialState()) {
    on<VoiceSessionsEvent>(
      _onVoiceSessionsEvent,
      transformer: sequential(),
    );
  }

  final VoiceSessionRepo _voiceSessionRepo;
  final VoiceRuntimeService _voiceRuntimeService;
  final ProfileRepo _profileRepo;

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
        participants: loadedState.participants,
      ));
      return;
    }

    final participants = loadedState?.channelId == trimmedChannelId
        ? await _resolveParticipants(
            runtimeUserIds:
                _voiceRuntimeService.currentParticipantUserIds().toList(),
            fallbackParticipants: loadedState?.participants,
            activeConnection: loadedState?.activeConnection,
          )
        : const <VoiceParticipant>[];

    emit(VoiceSessionsLoadedState(
      activeConnection: loadedState?.channelId == trimmedChannelId
          ? loadedState?.activeConnection
          : null,
      channelId: trimmedChannelId,
      participants: participants,
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
        participants: loadedState.participants,
      ));
      return;
    }

    final activeConnection = loadedState.activeConnection;
    if (activeConnection != null &&
        activeConnection.channelId == trimmedChannelId) {
      final participants = await _resolveParticipants(
        runtimeUserIds:
            _voiceRuntimeService.currentParticipantUserIds().toList(),
        fallbackParticipants: loadedState.participants,
        activeConnection: activeConnection,
      );
      emit(VoiceSessionsLoadedState(
        activeConnection: activeConnection,
        channelId: trimmedChannelId,
        participants: participants,
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
            final participants = await _resolveParticipants(
              runtimeUserIds:
                  _voiceRuntimeService.currentParticipantUserIds().toList(),
              fallbackParticipants: const <VoiceParticipant>[],
              activeConnection: value,
            );
            emit(VoiceSessionsLoadedState(
              activeConnection: value,
              channelId: trimmedChannelId,
              participants: participants,
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
        participants: loadedState.participants,
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
          participants: const <VoiceParticipant>[],
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

  List<String> _participantUserIdsOrFallback({
    required List<String> runtimeUserIds,
    required List<VoiceParticipant>? fallbackParticipants,
    required VoiceConnectSession? activeConnection,
  }) {
    if (runtimeUserIds.isNotEmpty) {
      return runtimeUserIds.toSet().toList();
    }

    final fallbackUserIds =
        fallbackParticipants?.map((participant) => participant.userId).toList();
    if (fallbackUserIds != null && fallbackUserIds.isNotEmpty) {
      return fallbackUserIds.toSet().toList();
    }

    final participantUserId = activeConnection?.participantUserId;
    if (participantUserId != null && participantUserId.isNotEmpty) {
      return <String>[participantUserId];
    }

    return const <String>[];
  }

  Future<List<VoiceParticipant>> _resolveParticipants({
    required List<String> runtimeUserIds,
    required List<VoiceParticipant>? fallbackParticipants,
    required VoiceConnectSession? activeConnection,
  }) async {
    final participantUserIds = _participantUserIdsOrFallback(
      runtimeUserIds: runtimeUserIds,
      fallbackParticipants: fallbackParticipants,
      activeConnection: activeConnection,
    );

    if (participantUserIds.isEmpty) {
      return const <VoiceParticipant>[];
    }

    final participants = <VoiceParticipant>[];
    for (final participantUserId in participantUserIds) {
      final profileResult = await _profileRepo.getUserById(
        query: GetUserProfileByIdQuery(userId: participantUserId),
      );

      final resolvedDisplayName = switch (profileResult) {
        Ok<UserProfile>(:final value) => value.displayName?.trim(),
        Error<UserProfile>() => null,
      };

      participants.add(
        VoiceParticipant(
          userId: participantUserId,
          displayName:
              resolvedDisplayName == null || resolvedDisplayName.isEmpty
                  ? "Member"
                  : resolvedDisplayName,
        ),
      );
    }

    return participants;
  }
}
