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
      case RefreshVoiceParticipantsRequested():
        await _onRefreshVoiceParticipantsRequested(event, emit);
      case ConnectVoiceSessionRequested():
        await _onConnectVoiceSessionRequested(event, emit);
      case DisconnectVoiceSessionRequested():
        await _onDisconnectVoiceSessionRequested(event, emit);
      case SetSelfMutedRequested():
        await _onSetSelfMutedRequested(event, emit);
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
        selectedChannelId: loadedState.selectedChannelId,
        participants: loadedState.participants,
        participantsByChannelId: loadedState.participantsByChannelId,
        isSelfMuted: loadedState.isSelfMuted,
      ));
      return;
    }

    final participantsResult = await _loadParticipantsForChannel(
      channelId: trimmedChannelId,
      loadedState: loadedState,
    );

    if (participantsResult case Error<List<VoiceParticipant>>(:final error)) {
      emit(VoiceSessionsExceptionState(error: error));
      return;
    }

    final participants =
        (participantsResult as Ok<List<VoiceParticipant>>).value;
    final participantsByChannelId =
        _participantsByChannelIdFromState(loadedState)
          ..[trimmedChannelId] = participants;

    emit(VoiceSessionsLoadedState(
      activeConnection: loadedState?.activeConnection,
      selectedChannelId: trimmedChannelId,
      participants: participants,
      participantsByChannelId: participantsByChannelId,
      isSelfMuted: _isSelfMutedFromParticipants(
        activeConnection: loadedState?.activeConnection,
        participantsByChannelId: participantsByChannelId,
      ),
    ));
  }

  Future<void> _onRefreshVoiceParticipantsRequested(
    RefreshVoiceParticipantsRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final loadedState = _loadedStateOrNull(state);
    final trimmedChannelIds = event.channelIds
        .map((channelId) => channelId.trim())
        .where((channelId) => channelId.isNotEmpty)
        .toSet()
        .toList();

    if (trimmedChannelIds.isEmpty) {
      return;
    }

    final participantsByChannelId =
        _participantsByChannelIdFromState(loadedState);

    for (final channelId in trimmedChannelIds) {
      final participantsResult = await _loadParticipantsForChannel(
        channelId: channelId,
        loadedState: loadedState,
      );

      if (participantsResult case Error<List<VoiceParticipant>>(:final error)) {
        emit(VoiceSessionsExceptionState(error: error));
        return;
      }

      participantsByChannelId[channelId] =
          (participantsResult as Ok<List<VoiceParticipant>>).value;
    }

    final selectedChannelId = loadedState?.selectedChannelId ?? "";
    final selectedParticipants = selectedChannelId.isEmpty
        ? loadedState?.participants ?? const <VoiceParticipant>[]
        : participantsByChannelId[selectedChannelId] ??
            const <VoiceParticipant>[];

    emit(VoiceSessionsLoadedState(
      activeConnection: loadedState?.activeConnection,
      selectedChannelId: selectedChannelId,
      participants: selectedParticipants,
      participantsByChannelId: participantsByChannelId,
      isSelfMuted: _isSelfMutedFromParticipants(
        activeConnection: loadedState?.activeConnection,
        participantsByChannelId: participantsByChannelId,
      ),
    ));
  }

  Future<void> _onConnectVoiceSessionRequested(
    ConnectVoiceSessionRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final trimmedChannelId = event.channelId.trim();
    final loadedState = _loadedStateOrNull(state);
    final previousConnectedChannelId = loadedState?.connectedChannelId;

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
        selectedChannelId: loadedState.selectedChannelId,
        participants: loadedState.participants,
        participantsByChannelId: loadedState.participantsByChannelId,
        isSelfMuted: loadedState.isSelfMuted,
      ));
      return;
    }

    final activeConnection = loadedState.activeConnection;
    if (activeConnection != null &&
        activeConnection.channelId == trimmedChannelId) {
      final participantsResult = await _loadParticipantsForChannel(
        channelId: trimmedChannelId,
        loadedState: loadedState,
      );
      if (participantsResult case Error<List<VoiceParticipant>>(:final error)) {
        emit(VoiceSessionsExceptionState(error: error));
        return;
      }
      final participants =
          (participantsResult as Ok<List<VoiceParticipant>>).value;
      final participantsByChannelId = _participantsByChannelIdFromState(
        loadedState,
      )..[trimmedChannelId] = participants;
      emit(VoiceSessionsLoadedState(
        activeConnection: activeConnection,
        selectedChannelId: trimmedChannelId,
        participants: participants,
        participantsByChannelId: participantsByChannelId,
        isSelfMuted: _isSelfMutedFromParticipants(
          activeConnection: activeConnection,
          participantsByChannelId: participantsByChannelId,
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
            final participantsResult = await _loadParticipantsForChannel(
              channelId: trimmedChannelId,
              loadedState: loadedState,
            );

            if (participantsResult
                case Error<List<VoiceParticipant>>(:final error)) {
              emit(VoiceSessionsExceptionState(error: error));
              return;
            }

            final participants =
                (participantsResult as Ok<List<VoiceParticipant>>).value;
            final participantsByChannelId = _participantsByChannelIdFromState(
              loadedState,
            )..[trimmedChannelId] = participants;

            final switchedFromChannelId = previousConnectedChannelId;
            if (switchedFromChannelId != null &&
                switchedFromChannelId.isNotEmpty &&
                switchedFromChannelId != trimmedChannelId) {
              final previousChannelParticipantsResult =
                  await _loadParticipantsForChannel(
                channelId: switchedFromChannelId,
                loadedState: loadedState,
              );

              if (previousChannelParticipantsResult
                  case Error<List<VoiceParticipant>>(:final error)) {
                emit(VoiceSessionsExceptionState(error: error));
                return;
              }

              participantsByChannelId[switchedFromChannelId] =
                  (previousChannelParticipantsResult
                          as Ok<List<VoiceParticipant>>)
                      .value;
            }

            emit(VoiceSessionsLoadedState(
              activeConnection: value,
              selectedChannelId: trimmedChannelId,
              participants: participants,
              participantsByChannelId: participantsByChannelId,
              isSelfMuted: _isSelfMutedFromParticipants(
                activeConnection: value,
                participantsByChannelId: participantsByChannelId,
              ),
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
        selectedChannelId: loadedState.selectedChannelId,
        participants: loadedState.participants,
        participantsByChannelId: loadedState.participantsByChannelId,
        isSelfMuted: loadedState.isSelfMuted,
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
          selectedChannelId: trimmedChannelId,
          participants: const <VoiceParticipant>[],
          participantsByChannelId: _participantsByChannelIdFromState(
            loadedState,
          )..[trimmedChannelId] = const <VoiceParticipant>[],
          isSelfMuted: false,
        ));
      case Error<void>(:final error):
        emit(VoiceSessionsExceptionState(error: error));
    }
  }

  Future<void> _onSetSelfMutedRequested(
    SetSelfMutedRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final loadedState = _loadedStateOrNull(state);

    if (loadedState == null) {
      emit(VoiceSessionsExceptionState(
        error: Exception("Voice sessions must be loaded before muting."),
      ));
      return;
    }

    if (loadedState.activeConnection == null) {
      emit(VoiceSessionsValidationFailedState(
        issue: VoiceSessionsValidationIssue.channelSelectionRequired,
        activeConnection: loadedState.activeConnection,
        selectedChannelId: loadedState.selectedChannelId,
        participants: loadedState.participants,
        participantsByChannelId: loadedState.participantsByChannelId,
        isSelfMuted: loadedState.isSelfMuted,
      ));
      return;
    }

    final activeConnection = loadedState.activeConnection;
    if (activeConnection == null) {
      emit(VoiceSessionsExceptionState(
        error: Exception("Voice connection was lost while muting."),
      ));
      return;
    }

    final setMutedResult = await _voiceRuntimeService.setSelfMuted(
      muted: event.muted,
    );

    switch (setMutedResult) {
      case Ok<void>():
        final backendSetMutedResult = await _voiceSessionRepo.updateOne(
          command: SetSelfVoiceSessionMuteCommand(
            channelId: activeConnection.channelId,
            isMuted: event.muted,
          ),
        );

        if (backendSetMutedResult case Error<void>(:final error)) {
          emit(VoiceSessionsExceptionState(error: error));
          return;
        }

        final participantsResult = await _loadParticipantsForChannel(
          channelId: activeConnection.channelId,
          loadedState: loadedState,
        );

        if (participantsResult
            case Error<List<VoiceParticipant>>(:final error)) {
          emit(VoiceSessionsExceptionState(error: error));
          return;
        }

        final activeChannelParticipants =
            (participantsResult as Ok<List<VoiceParticipant>>).value;
        final participantsByChannelId = _participantsByChannelIdFromState(
          loadedState,
        )..[activeConnection.channelId] = activeChannelParticipants;

        final selectedParticipants =
            loadedState.selectedChannelId == activeConnection.channelId
                ? activeChannelParticipants
                : loadedState.participants;

        final isSelfMuted = activeChannelParticipants.any(
          (participant) =>
              participant.userId == activeConnection.participantUserId &&
              participant.isMuted,
        );

        emit(VoiceSessionsLoadedState(
          activeConnection: activeConnection,
          selectedChannelId: loadedState.selectedChannelId,
          participants: selectedParticipants,
          participantsByChannelId: participantsByChannelId,
          isSelfMuted: isSelfMuted,
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

  Map<String, List<VoiceParticipant>> _participantsByChannelIdFromState(
    VoiceSessionsLoadedDataState? loadedState,
  ) {
    if (loadedState == null) {
      return <String, List<VoiceParticipant>>{};
    }

    return Map<String, List<VoiceParticipant>>.fromEntries(
      loadedState.participantsByChannelId.entries.map(
        (entry) =>
            MapEntry(entry.key, List<VoiceParticipant>.from(entry.value)),
      ),
    );
  }

  Future<Result<List<VoiceParticipant>>> _loadParticipantsForChannel({
    required String channelId,
    required VoiceSessionsLoadedDataState? loadedState,
  }) async {
    final voiceSessionsResult = await _voiceSessionRepo.getMany(
      query: GetVoiceSessionsQuery(channelId: channelId),
    );

    if (voiceSessionsResult case Error<Iterable<VoiceSession>>(:final error)) {
      return Error<List<VoiceParticipant>>(error);
    }

    final voiceSessions =
        (voiceSessionsResult as Ok<Iterable<VoiceSession>>).value;
    final backendParticipantUserIds =
        voiceSessions.map((session) => session.participantUserId).toList();
    final mutedByUserId = <String, bool>{
      for (final session in voiceSessions)
        session.participantUserId: session.isMuted,
    };
    final participants = await _resolveParticipants(
      participantUserIds: backendParticipantUserIds,
      mutedByUserId: mutedByUserId,
    );

    return Ok<List<VoiceParticipant>>(participants);
  }

  List<String> _participantUserIdsOrFallback({
    required List<String> participantUserIds,
  }) {
    if (participantUserIds.isNotEmpty) {
      return participantUserIds.toSet().toList();
    }

    return const <String>[];
  }

  Future<List<VoiceParticipant>> _resolveParticipants({
    required List<String> participantUserIds,
    required Map<String, bool> mutedByUserId,
  }) async {
    final resolvedParticipantUserIds = _participantUserIdsOrFallback(
      participantUserIds: participantUserIds,
    );

    if (resolvedParticipantUserIds.isEmpty) {
      return const <VoiceParticipant>[];
    }

    final participants = <VoiceParticipant>[];
    for (final participantUserId in resolvedParticipantUserIds) {
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
          isMuted: mutedByUserId[participantUserId] ?? false,
        ),
      );
    }

    return participants;
  }

  bool _isSelfMutedFromParticipants({
    required VoiceConnectSession? activeConnection,
    required Map<String, List<VoiceParticipant>> participantsByChannelId,
  }) {
    if (activeConnection == null) {
      return false;
    }

    final activeParticipants =
        participantsByChannelId[activeConnection.channelId] ??
            const <VoiceParticipant>[];

    return activeParticipants.any(
      (participant) =>
          participant.userId == activeConnection.participantUserId &&
          participant.isMuted,
    );
  }
}
