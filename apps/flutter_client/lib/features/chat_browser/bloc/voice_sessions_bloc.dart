import "dart:async";

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

    _speakingParticipantUserIdsSubscription = _voiceRuntimeService
        .speakingParticipantUserIds()
        .listen((speakingParticipantUserIds) {
      add(
        SpeakingParticipantUserIdsUpdated(
          speakingParticipantUserIds: speakingParticipantUserIds,
        ),
      );
    });
  }

  final VoiceSessionRepo _voiceSessionRepo;
  final VoiceRuntimeService _voiceRuntimeService;
  final ProfileRepo _profileRepo;
  StreamSubscription<Set<String>>? _speakingParticipantUserIdsSubscription;
  Set<String> _speakingParticipantUserIds = const <String>{};

  Future<void> _onVoiceSessionsEvent(
    VoiceSessionsEvent event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    switch (event) {
      case ResetVoiceSessionsRequested():
        await _voiceRuntimeService.disconnect();
        _speakingParticipantUserIds = const <String>{};
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
      case SetSelfDeafenedRequested():
        await _onSetSelfDeafenedRequested(event, emit);
      case SpeakingParticipantUserIdsUpdated():
        _onSpeakingParticipantUserIdsUpdated(event, emit);
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
        isSelfDeafened: loadedState.isSelfDeafened,
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
      isSelfDeafened: loadedState?.isSelfDeafened ?? false,
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
      isSelfDeafened: loadedState?.isSelfDeafened ?? false,
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
        isSelfDeafened: loadedState.isSelfDeafened,
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
        isSelfDeafened: loadedState.isSelfDeafened,
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
              activeConnection: value,
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
              participantsByChannelId[switchedFromChannelId] =
                  const <VoiceParticipant>[];
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
              isSelfDeafened: _voiceRuntimeService.isSelfDeafened(),
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
        isSelfDeafened: loadedState.isSelfDeafened,
      ));
      return;
    }

    emit(const VoiceSessionsLoadingState());

    final runtimeDisconnectResult = await _voiceRuntimeService.disconnect();

    if (runtimeDisconnectResult case Error<void>(:final error)) {
      emit(VoiceSessionsExceptionState(error: error));
      return;
    }

    emit(VoiceSessionsLoadedState(
      activeConnection: null,
      selectedChannelId: trimmedChannelId,
      participants: const <VoiceParticipant>[],
      participantsByChannelId: _participantsByChannelIdFromState(
        loadedState,
      )..[trimmedChannelId] = const <VoiceParticipant>[],
      isSelfMuted: false,
      isSelfDeafened: false,
    ));
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
        isSelfDeafened: loadedState.isSelfDeafened,
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

    var effectiveMuted = event.muted;
    var isSelfDeafened = loadedState.isSelfDeafened;

    if (!event.muted && loadedState.isSelfDeafened) {
      final undeafenResult = await _voiceRuntimeService.setSelfDeafened(
        deafened: false,
      );

      if (undeafenResult case Error<void>(:final error)) {
        emit(VoiceSessionsExceptionState(error: error));
        return;
      }

      isSelfDeafened = false;
      effectiveMuted = false;
    }

    final setMutedResult = await _voiceRuntimeService.setSelfMuted(
      muted: effectiveMuted,
    );

    switch (setMutedResult) {
      case Ok<void>():
        final participantsResult = await _loadParticipantsForChannel(
          channelId: activeConnection.channelId,
          loadedState: loadedState,
          activeConnection: activeConnection,
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

        emit(VoiceSessionsLoadedState(
          activeConnection: activeConnection,
          selectedChannelId: loadedState.selectedChannelId,
          participants: selectedParticipants,
          participantsByChannelId: participantsByChannelId,
          isSelfMuted: _voiceRuntimeService.isSelfMuted(),
          isSelfDeafened: isSelfDeafened,
        ));
      case Error<void>(:final error):
        emit(VoiceSessionsExceptionState(error: error));
    }
  }

  Future<void> _onSetSelfDeafenedRequested(
    SetSelfDeafenedRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final loadedState = _loadedStateOrNull(state);

    if (loadedState == null) {
      emit(VoiceSessionsExceptionState(
        error: Exception("Voice sessions must be loaded before deafening."),
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
        isSelfDeafened: loadedState.isSelfDeafened,
      ));
      return;
    }

    final activeConnection = loadedState.activeConnection;
    if (activeConnection == null) {
      emit(VoiceSessionsExceptionState(
        error: Exception("Voice connection was lost while deafening."),
      ));
      return;
    }

    final setDeafenedResult = await _voiceRuntimeService.setSelfDeafened(
      deafened: event.deafened,
    );

    switch (setDeafenedResult) {
      case Ok<void>():
        final participantsResult = await _loadParticipantsForChannel(
          channelId: activeConnection.channelId,
          loadedState: loadedState,
          activeConnection: activeConnection,
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
          isSelfDeafened: _voiceRuntimeService.isSelfDeafened(),
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
    VoiceConnectSession? activeConnection,
  }) async {
    final resolvedActiveConnection =
        activeConnection ?? loadedState?.activeConnection;
    if (resolvedActiveConnection == null ||
        resolvedActiveConnection.channelId != channelId) {
      return const Ok<List<VoiceParticipant>>(<VoiceParticipant>[]);
    }

    final runtimeParticipantUserIds =
        _voiceRuntimeService.currentParticipantUserIds().toList();
    final mutedByUserId = <String, bool>{
      for (final participantUserId in runtimeParticipantUserIds)
        participantUserId: false,
      resolvedActiveConnection.participantUserId:
          _voiceRuntimeService.isSelfMuted(),
    };
    final participants = await _resolveParticipants(
      participantUserIds: runtimeParticipantUserIds,
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
          isSpeaking: _speakingParticipantUserIds.contains(participantUserId),
        ),
      );
    }

    return participants;
  }

  bool _isSelfMutedFromParticipants({
    required VoiceConnectSession? activeConnection,
    required Map<String, List<VoiceParticipant>> participantsByChannelId,
  }) {
    final _ = participantsByChannelId;

    if (activeConnection == null) {
      return false;
    }

    return _voiceRuntimeService.isSelfMuted();
  }

  void _onSpeakingParticipantUserIdsUpdated(
    SpeakingParticipantUserIdsUpdated event,
    Emitter<VoiceSessionsState> emit,
  ) {
    _speakingParticipantUserIds = event.speakingParticipantUserIds;

    final loadedState = _loadedStateOrNull(state);
    if (loadedState == null) {
      return;
    }

    final participantsByChannelId =
        Map<String, List<VoiceParticipant>>.fromEntries(
      loadedState.participantsByChannelId.entries.map(
        (entry) => MapEntry(
          entry.key,
          entry.value
              .map(
                (participant) => VoiceParticipant(
                  userId: participant.userId,
                  displayName: participant.displayName,
                  isMuted: participant.isMuted,
                  isSpeaking:
                      _speakingParticipantUserIds.contains(participant.userId),
                ),
              )
              .toList(),
        ),
      ),
    );

    final selectedParticipants =
        participantsByChannelId[loadedState.selectedChannelId] ??
            loadedState.participants
                .map(
                  (participant) => VoiceParticipant(
                    userId: participant.userId,
                    displayName: participant.displayName,
                    isMuted: participant.isMuted,
                    isSpeaking: _speakingParticipantUserIds
                        .contains(participant.userId),
                  ),
                )
                .toList();

    emit(VoiceSessionsLoadedState(
      activeConnection: loadedState.activeConnection,
      selectedChannelId: loadedState.selectedChannelId,
      participants: selectedParticipants,
      participantsByChannelId: participantsByChannelId,
      isSelfMuted: loadedState.isSelfMuted,
      isSelfDeafened: loadedState.isSelfDeafened,
    ));
  }

  @override
  Future<void> close() async {
    await _speakingParticipantUserIdsSubscription?.cancel();
    return super.close();
  }
}
