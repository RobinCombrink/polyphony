import "dart:async";

import "package:bloc_concurrency/bloc_concurrency.dart";
import "package:collection/collection.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";

part "voice_sessions_event.dart";
part "voice_sessions_participant_status_reducer.dart";
part "voice_sessions_state.dart";

class VoiceSessionsBloc extends Bloc<VoiceSessionsEvent, VoiceSessionsState> {
  VoiceSessionsBloc({
    required VoiceSessionRepo voiceSessionRepo,
    required MediaRuntimeService voiceRuntimeService,
    required ProfileRepo profileRepo,
  })  : _voiceSessionRepo = voiceSessionRepo,
        _voiceRuntimeService = voiceRuntimeService,
        _profileRepo = profileRepo,
        super(const VoiceSessionsInitialState()) {
    on<VoiceSessionsEvent>(
      _onVoiceSessionsEvent,
      transformer: sequential(),
    );

    _participantUserIdsSubscription =
        _voiceRuntimeService.participantUserIds().listen((participantUserIds) {
      add(
        ParticipantUserIdsUpdated(
          participantUserIds: participantUserIds,
        ),
      );
    });

    _participantStatusUpdatesSubscription =
        _voiceRuntimeService.participantStatusUpdates().listen((update) {
      add(
        ParticipantStatusUpdated(update: update),
      );
    });

    _participantVideoTracksSubscription = _voiceRuntimeService
        .participantVideoTracks()
        .listen((participantVideoTracks) {
      add(
        ParticipantVideoTracksUpdated(
          participantVideoTracks: participantVideoTracks,
        ),
      );
    });
  }

  final VoiceSessionRepo _voiceSessionRepo;
  final MediaRuntimeService _voiceRuntimeService;
  final ProfileRepo _profileRepo;
  StreamSubscription<Set<String>>? _participantUserIdsSubscription;
  StreamSubscription<ParticipantStatusUpdate>?
      _participantStatusUpdatesSubscription;
  StreamSubscription<Map<String, Object>>? _participantVideoTracksSubscription;
  var _speakingParticipantUserIds = const <String>{};
  ChannelId? _lastConnectedChannelId;

  Future<void> _onVoiceSessionsEvent(
    VoiceSessionsEvent event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    switch (event) {
      case ResetVoiceSessionsRequested():
        await _voiceRuntimeService.disconnect();
        _speakingParticipantUserIds = const <String>{};
        _lastConnectedChannelId = null;
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
      case SetSelfScreenShareEnabledRequested():
        await _onSetSelfScreenShareEnabledRequested(event, emit);
      case SetEchoCancellationEnabledRequested():
        await _onSetEchoCancellationEnabledRequested(event, emit);
      case SetNoiseSuppressionEnabledRequested():
        await _onSetNoiseSuppressionEnabledRequested(event, emit);
      case ParticipantStatusUpdated():
        _onParticipantStatusUpdated(event, emit);
      case ParticipantUserIdsUpdated():
        await _onParticipantUserIdsUpdated(event, emit);
      case ParticipantVideoTracksUpdated():
        _onParticipantVideoTracksUpdated(event, emit);
    }
  }

  Future<void> _onLoadVoiceSessionsRequested(
    LoadVoiceSessionsRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final loadedState = _loadedStateOrNull(state);

    if (event.channelId.value.trim().isEmpty) {
      emit(
        switch (state) {
          final VoiceSessionsLoadedDataState loadedState =>
            VoiceSessionsValidationFailedState(
              issue: VoiceSessionsValidationIssue.channelSelectionRequired,
              activeConnection: loadedState.activeConnection,
              selectedChannelId: loadedState.selectedChannelId,
              participants: loadedState.participants,
              participantsByChannelId: loadedState.participantsByChannelId,
              participantVideoTracks: loadedState.participantVideoTracks,
              isSelfMuted: loadedState.isSelfMuted,
              isSelfDeafened: loadedState.isSelfDeafened,
              isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
              isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
              isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
            ),
          _ => const VoiceSessionsExceptionState(
              error: VoiceSessionPreconditionException(
                operation: VoiceSessionOperation.load,
                issue: VoiceSessionPreconditionIssue.loadedStateRequired,
              ),
            ),
        },
      );
      return;
    }

    final participantsResult = await _loadParticipantsForChannel(
      channelId: event.channelId,
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
          ..[event.channelId] = participants;

    emit(VoiceSessionsLoadedState(
      activeConnection: loadedState?.activeConnection,
      selectedChannelId: event.channelId,
      participants: participants,
      participantsByChannelId: participantsByChannelId,
      participantVideoTracks: _participantVideoTracksFromState(loadedState),
      isSelfMuted: _isSelfMutedFromParticipants(
        activeConnection: loadedState?.activeConnection,
        participantsByChannelId: participantsByChannelId,
      ),
      isSelfDeafened: loadedState?.isSelfDeafened ?? false,
      isSelfScreenShareEnabled: loadedState?.isSelfScreenShareEnabled ?? false,
      isEchoCancellationEnabled: loadedState?.isEchoCancellationEnabled ?? true,
      isNoiseSuppressionEnabled: loadedState?.isNoiseSuppressionEnabled ?? true,
    ));
  }

  Future<void> _onRefreshVoiceParticipantsRequested(
    RefreshVoiceParticipantsRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final loadedState = _loadedStateOrNull(state);
    final validChannelIds = event.channelIds
        .where((channelId) => channelId.value.trim().isNotEmpty)
        .toSet()
        .toList();

    if (validChannelIds.isEmpty) {
      return;
    }

    if (loadedState == null) {
      return;
    }

    final participantsByChannelId =
        _participantsByChannelIdFromState(loadedState);
    final participantEntries = await Future.wait(validChannelIds.map(
        (channelId) => _loadParticipantsForChannel(
              channelId: channelId,
              loadedState: loadedState,
            ).then((participantsResult) =>
                MapEntry(channelId, participantsResult))));

    final firstError = participantEntries
        .map((entry) => entry.value)
        .whereType<Error<List<VoiceParticipant>>>()
        .firstOrNull;

    if (firstError != null) {
      emit(VoiceSessionsExceptionState(error: firstError.error));
      return;
    }

    final newParticipants = participantEntries
        .map((entry) => switch (entry.value) {
              Ok(:final value) => MapEntry(entry.key, value),
              Error() => null,
            })
        .nonNulls;

    final refreshedParticipantsByChannelId = {
      ...participantsByChannelId,
      ...Map<ChannelId, List<VoiceParticipant>>.fromEntries(newParticipants),
    };

    final selectedChannelId = loadedState.selectedChannelId;
    final selectedParticipants = selectedChannelId.value.isEmpty
        ? loadedState.participants
        : refreshedParticipantsByChannelId[selectedChannelId] ??
            const <VoiceParticipant>[];

    emit(VoiceSessionsLoadedState(
      activeConnection: loadedState.activeConnection,
      selectedChannelId: selectedChannelId,
      participants: selectedParticipants,
      participantsByChannelId: refreshedParticipantsByChannelId,
      participantVideoTracks: _participantVideoTracksFromState(loadedState),
      isSelfMuted: _isSelfMutedFromParticipants(
        activeConnection: loadedState.activeConnection,
        participantsByChannelId: refreshedParticipantsByChannelId,
      ),
      isSelfDeafened: loadedState.isSelfDeafened,
      isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
      isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
      isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
    ));
  }

  Future<void> _onConnectVoiceSessionRequested(
    ConnectVoiceSessionRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final loadedState = switch (state) {
      final VoiceSessionsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(const VoiceSessionsExceptionState(
        error: VoiceSessionPreconditionException(
          operation: VoiceSessionOperation.connect,
          issue: VoiceSessionPreconditionIssue.loadedStateRequired,
        ),
      ));
      return;
    }
    final previousConnectedChannelId = loadedState.connectedChannelId;

    if (event.channelId.value.trim().isEmpty) {
      emit(VoiceSessionsValidationFailedState(
        issue: VoiceSessionsValidationIssue.channelSelectionRequired,
        activeConnection: loadedState.activeConnection,
        selectedChannelId: loadedState.selectedChannelId,
        participants: loadedState.participants,
        participantsByChannelId: loadedState.participantsByChannelId,
        participantVideoTracks: loadedState.participantVideoTracks,
        isSelfMuted: loadedState.isSelfMuted,
        isSelfDeafened: loadedState.isSelfDeafened,
        isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
        isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
        isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
      ));
      return;
    }

    final activeConnection = loadedState.activeConnection;
    if (activeConnection != null &&
        activeConnection.channelId == event.channelId) {
      final participantsResult = await _loadParticipantsForChannel(
        channelId: event.channelId,
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
      )..[event.channelId] = participants;
      emit(VoiceSessionsLoadedState(
        activeConnection: activeConnection,
        selectedChannelId: event.channelId,
        participants: participants,
        participantsByChannelId: participantsByChannelId,
        participantVideoTracks: loadedState.participantVideoTracks,
        isSelfMuted: _isSelfMutedFromParticipants(
          activeConnection: activeConnection,
          participantsByChannelId: participantsByChannelId,
        ),
        isSelfDeafened: loadedState.isSelfDeafened,
        isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
        isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
        isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
      ));
      return;
    }

    if (activeConnection != null &&
        activeConnection.channelId != event.channelId) {
      final runtimeDisconnectResult = await _voiceRuntimeService.disconnect();
      if (runtimeDisconnectResult case Error<void>(:final error)) {
        emit(VoiceSessionsExceptionState(error: error));
        return;
      }
    }

    emit(
      VoiceSessionsLoadingState(
        operation: _isReconnectAttempt(
          loadedState: loadedState,
          channelId: event.channelId,
        )
            ? VoiceSessionsLoadingOperation.reconnecting
            : VoiceSessionsLoadingOperation.connecting,
        channelId: event.channelId,
      ),
    );

    final connectVoiceSessionResult = await _voiceSessionRepo.createOne(
      command: ConnectVoiceSessionCommand(
        channelId: event.channelId,
      ),
    );

    switch (connectVoiceSessionResult) {
      case Ok<VoiceConnectSession>(:final value):
        final runtimeConnectResult = await _voiceRuntimeService.connect(
          livekitUrl: value.livekitUrl,
          accessToken: value.accessToken,
          audioProcessingOptions: VoiceAudioProcessingOptions(
            isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
            isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
          ),
        );

        switch (runtimeConnectResult) {
          case Ok<void>():
            final participantsResult = await _loadParticipantsForChannel(
              channelId: event.channelId,
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
            )..[event.channelId] = participants;

            final switchedFromChannelId = previousConnectedChannelId;
            if (switchedFromChannelId != null &&
                switchedFromChannelId.value.isNotEmpty &&
                switchedFromChannelId != event.channelId) {
              participantsByChannelId[switchedFromChannelId] =
                  const <VoiceParticipant>[];
            }

            _lastConnectedChannelId = event.channelId;

            emit(VoiceSessionsLoadedState(
              activeConnection: value,
              selectedChannelId: event.channelId,
              participants: participants,
              participantsByChannelId: participantsByChannelId,
              participantVideoTracks:
                  _voiceRuntimeService.currentParticipantVideoTracks(),
              isSelfMuted: _isSelfMutedFromParticipants(
                activeConnection: value,
                participantsByChannelId: participantsByChannelId,
              ),
              isSelfDeafened: _voiceRuntimeService.isSelfDeafened(),
              isSelfScreenShareEnabled:
                  _voiceRuntimeService.isSelfScreenShareEnabled(),
              isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
              isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
            ));
          case Error<void>(:final error):
            if (_emitLifecycleIssueState(
              error: error,
              channelId: event.channelId,
              loadedState: loadedState,
              emit: emit,
            )) {
              return;
            }

            emit(VoiceSessionsExceptionState(error: error));
        }
      case Error<VoiceConnectSession>(:final error):
        if (_emitLifecycleIssueState(
          error: error,
          channelId: event.channelId,
          loadedState: loadedState,
          emit: emit,
        )) {
          return;
        }

        emit(VoiceSessionsExceptionState(error: error));
    }
  }

  Future<void> _onDisconnectVoiceSessionRequested(
    DisconnectVoiceSessionRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final loadedState = switch (state) {
      final VoiceSessionsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(const VoiceSessionsExceptionState(
        error: VoiceSessionPreconditionException(
          operation: VoiceSessionOperation.disconnect,
          issue: VoiceSessionPreconditionIssue.loadedStateRequired,
        ),
      ));
      return;
    }

    if (event.channelId.value.trim().isEmpty) {
      emit(VoiceSessionsValidationFailedState(
        issue: VoiceSessionsValidationIssue.channelSelectionRequired,
        activeConnection: loadedState.activeConnection,
        selectedChannelId: loadedState.selectedChannelId,
        participants: loadedState.participants,
        participantsByChannelId: loadedState.participantsByChannelId,
        participantVideoTracks: loadedState.participantVideoTracks,
        isSelfMuted: loadedState.isSelfMuted,
        isSelfDeafened: loadedState.isSelfDeafened,
        isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
        isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
        isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
      ));
      return;
    }

    emit(
      VoiceSessionsLoadingState(
        operation: VoiceSessionsLoadingOperation.disconnecting,
        channelId: event.channelId,
      ),
    );

    final runtimeDisconnectResult = await _voiceRuntimeService.disconnect();

    if (runtimeDisconnectResult case Error<void>(:final error)) {
      emit(VoiceSessionsExceptionState(error: error));
      return;
    }

    emit(VoiceSessionsLoadedState(
      activeConnection: null,
      selectedChannelId: event.channelId,
      participants: const <VoiceParticipant>[],
      participantsByChannelId: _participantsByChannelIdFromState(
        loadedState,
      )..[event.channelId] = const <VoiceParticipant>[],
      participantVideoTracks: const <String, Object>{},
      isSelfMuted: false,
      isSelfDeafened: false,
      isSelfScreenShareEnabled: false,
      isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
      isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
    ));

    _lastConnectedChannelId = event.channelId;
  }

  Future<void> _onSetSelfMutedRequested(
    SetSelfMutedRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final loadedState = switch (state) {
      final VoiceSessionsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(const VoiceSessionsExceptionState(
        error: VoiceSessionPreconditionException(
          operation: VoiceSessionOperation.setMute,
          issue: VoiceSessionPreconditionIssue.loadedStateRequired,
        ),
      ));
      return;
    }

    final resolvedActiveConnection = loadedState.activeConnection;
    if (resolvedActiveConnection == null) {
      emit(VoiceSessionsValidationFailedState(
        issue: VoiceSessionsValidationIssue.channelSelectionRequired,
        activeConnection: loadedState.activeConnection,
        selectedChannelId: loadedState.selectedChannelId,
        participants: loadedState.participants,
        participantsByChannelId: loadedState.participantsByChannelId,
        participantVideoTracks: loadedState.participantVideoTracks,
        isSelfMuted: loadedState.isSelfMuted,
        isSelfDeafened: loadedState.isSelfDeafened,
        isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
        isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
        isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
      ));
      return;
    }

    final activeConnection = resolvedActiveConnection;

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
          participantVideoTracks: loadedState.participantVideoTracks,
          isSelfMuted: _voiceRuntimeService.isSelfMuted(),
          isSelfDeafened: isSelfDeafened,
          isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
          isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
          isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
        ));
      case Error<void>(:final error):
        emit(VoiceSessionsExceptionState(error: error));
    }
  }

  Future<void> _onSetSelfDeafenedRequested(
    SetSelfDeafenedRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final loadedState = switch (state) {
      final VoiceSessionsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(const VoiceSessionsExceptionState(
        error: VoiceSessionPreconditionException(
          operation: VoiceSessionOperation.setDeafen,
          issue: VoiceSessionPreconditionIssue.loadedStateRequired,
        ),
      ));
      return;
    }

    final resolvedActiveConnection = loadedState.activeConnection;
    if (resolvedActiveConnection == null) {
      emit(VoiceSessionsValidationFailedState(
        issue: VoiceSessionsValidationIssue.channelSelectionRequired,
        activeConnection: loadedState.activeConnection,
        selectedChannelId: loadedState.selectedChannelId,
        participants: loadedState.participants,
        participantsByChannelId: loadedState.participantsByChannelId,
        participantVideoTracks: loadedState.participantVideoTracks,
        isSelfMuted: loadedState.isSelfMuted,
        isSelfDeafened: loadedState.isSelfDeafened,
        isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
        isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
        isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
      ));
      return;
    }

    final activeConnection = resolvedActiveConnection;

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
          participantVideoTracks: loadedState.participantVideoTracks,
          isSelfMuted: isSelfMuted,
          isSelfDeafened: _voiceRuntimeService.isSelfDeafened(),
          isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
          isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
          isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
        ));
      case Error<void>(:final error):
        emit(VoiceSessionsExceptionState(error: error));
    }
  }

  Future<void> _onSetSelfScreenShareEnabledRequested(
    SetSelfScreenShareEnabledRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final loadedState = switch (state) {
      final VoiceSessionsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(const VoiceSessionsExceptionState(
        error: VoiceSessionPreconditionException(
          operation: VoiceSessionOperation.toggleScreenShare,
          issue: VoiceSessionPreconditionIssue.loadedStateRequired,
        ),
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
        participantVideoTracks: loadedState.participantVideoTracks,
        isSelfMuted: loadedState.isSelfMuted,
        isSelfDeafened: loadedState.isSelfDeafened,
        isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
        isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
        isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
      ));
      return;
    }

    final setScreenShareEnabledResult =
        await _voiceRuntimeService.setSelfScreenShareEnabled(
      enabled: event.enabled,
      sourceId: event.sourceId,
    );

    switch (setScreenShareEnabledResult) {
      case Ok<void>():
        emit(VoiceSessionsLoadedState(
          activeConnection: loadedState.activeConnection,
          selectedChannelId: loadedState.selectedChannelId,
          participants: loadedState.participants,
          participantsByChannelId: loadedState.participantsByChannelId,
          participantVideoTracks:
              _voiceRuntimeService.currentParticipantVideoTracks(),
          isSelfMuted: loadedState.isSelfMuted,
          isSelfDeafened: loadedState.isSelfDeafened,
          isSelfScreenShareEnabled:
              _voiceRuntimeService.isSelfScreenShareEnabled(),
          isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
          isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
        ));
      case Error<void>(:final error):
        emit(VoiceSessionsExceptionState(error: error));
    }
  }

  Future<void> _onSetEchoCancellationEnabledRequested(
    SetEchoCancellationEnabledRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final loadedState = switch (state) {
      final VoiceSessionsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    if (loadedState.activeConnection != null) {
      await _voiceRuntimeService.applyVoiceAudioProcessingOptions(
        audioProcessingOptions: VoiceAudioProcessingOptions(
          isEchoCancellationEnabled: event.enabled,
          isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
        ),
      );
    }

    emit(VoiceSessionsLoadedState(
      activeConnection: loadedState.activeConnection,
      selectedChannelId: loadedState.selectedChannelId,
      participants: loadedState.participants,
      participantsByChannelId: loadedState.participantsByChannelId,
      participantVideoTracks: loadedState.participantVideoTracks,
      isSelfMuted: loadedState.isSelfMuted,
      isSelfDeafened: loadedState.isSelfDeafened,
      isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
      isEchoCancellationEnabled: event.enabled,
      isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
    ));
  }

  Future<void> _onSetNoiseSuppressionEnabledRequested(
    SetNoiseSuppressionEnabledRequested event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final loadedState = switch (state) {
      final VoiceSessionsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    if (loadedState.activeConnection != null) {
      await _voiceRuntimeService.applyVoiceAudioProcessingOptions(
        audioProcessingOptions: VoiceAudioProcessingOptions(
          isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
          isNoiseSuppressionEnabled: event.enabled,
        ),
      );
    }

    emit(VoiceSessionsLoadedState(
      activeConnection: loadedState.activeConnection,
      selectedChannelId: loadedState.selectedChannelId,
      participants: loadedState.participants,
      participantsByChannelId: loadedState.participantsByChannelId,
      participantVideoTracks: loadedState.participantVideoTracks,
      isSelfMuted: loadedState.isSelfMuted,
      isSelfDeafened: loadedState.isSelfDeafened,
      isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
      isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
      isNoiseSuppressionEnabled: event.enabled,
    ));
  }

  bool _isReconnectAttempt({
    required VoiceSessionsLoadedDataState? loadedState,
    required ChannelId channelId,
  }) {
    if (channelId.value.isEmpty) {
      return false;
    }

    if (_lastConnectedChannelId == channelId) {
      return true;
    }

    return switch (loadedState) {
      final VoiceSessionsLoadedDataState loadedState =>
        loadedState.selectedChannelId == channelId &&
            (loadedState.participantsByChannelId[channelId] ??
                    const <VoiceParticipant>[])
                .isNotEmpty,
      _ => false,
    };
  }

  bool _emitLifecycleIssueState({
    required Exception error,
    required ChannelId channelId,
    required VoiceSessionsLoadedDataState? loadedState,
    required Emitter<VoiceSessionsState> emit,
  }) {
    final issue = _classifyLifecycleIssue(error);
    if (issue == null) {
      return false;
    }

    final participantsByChannelId =
        _participantsByChannelIdFromState(loadedState);
    final selectedParticipants = participantsByChannelId[channelId] ??
        loadedState?.participants ??
        const <VoiceParticipant>[];

    emit(VoiceSessionsLifecycleIssueState(
      issue: issue,
      activeConnection: null,
      selectedChannelId: channelId,
      participants: selectedParticipants,
      participantsByChannelId: participantsByChannelId,
      participantVideoTracks: _participantVideoTracksFromState(loadedState),
      isSelfMuted: loadedState?.isSelfMuted ?? false,
      isSelfDeafened: loadedState?.isSelfDeafened ?? false,
      isSelfScreenShareEnabled: loadedState?.isSelfScreenShareEnabled ?? false,
      isEchoCancellationEnabled: loadedState?.isEchoCancellationEnabled ?? true,
      isNoiseSuppressionEnabled: loadedState?.isNoiseSuppressionEnabled ?? true,
    ));

    return true;
  }

  VoiceSessionsLifecycleIssue? _classifyLifecycleIssue(Exception error) {
    if (error is AuthenticationRequiredException) {
      return VoiceSessionsLifecycleIssue.tokenExpired;
    }

    if (error is ApiRequestException) {
      return switch (error.statusCode) {
        401 => VoiceSessionsLifecycleIssue.tokenExpired,
        403 => VoiceSessionsLifecycleIssue.channelForbidden,
        _ => null,
      };
    }

    if (error is RuntimeConnectionException) {
      return VoiceSessionsLifecycleIssue.reconnectRequired;
    }

    return null;
  }

  VoiceSessionsLoadedDataState? _loadedStateOrNull(VoiceSessionsState state) {
    return switch (state) {
      VoiceSessionsLoadedDataState() => state,
      _ => null,
    };
  }

  Map<ChannelId, List<VoiceParticipant>> _participantsByChannelIdFromState(
    VoiceSessionsLoadedDataState? loadedState,
  ) {
    return switch (loadedState) {
      final VoiceSessionsLoadedDataState loadedState =>
        Map<ChannelId, List<VoiceParticipant>>.fromEntries(
          loadedState.participantsByChannelId.entries.map(
            (entry) =>
                MapEntry(entry.key, List<VoiceParticipant>.from(entry.value)),
          ),
        ),
      _ => <ChannelId, List<VoiceParticipant>>{},
    };
  }

  Map<String, Object> _participantVideoTracksFromState(
    VoiceSessionsLoadedDataState? loadedState,
  ) {
    return switch (loadedState) {
      final VoiceSessionsLoadedDataState loadedState =>
        Map<String, Object>.from(loadedState.participantVideoTracks),
      _ => const <String, Object>{},
    };
  }

  Future<Result<List<VoiceParticipant>>> _loadParticipantsForChannel({
    required ChannelId channelId,
    required VoiceSessionsLoadedDataState? loadedState,
    VoiceConnectSession? activeConnection,
  }) async {
    final resolvedActiveConnection =
        activeConnection ?? loadedState?.activeConnection;
    if (resolvedActiveConnection == null ||
        resolvedActiveConnection.channelId != channelId) {
      return const Ok<List<VoiceParticipant>>(<VoiceParticipant>[]);
    }

    final runtimeParticipantUserIds = _voiceRuntimeService
        .currentParticipantUserIds()
        .toSet()
      ..add(resolvedActiveConnection.participantUserId.value);
    final mutedParticipantUserIds =
        _voiceRuntimeService.currentMutedParticipantUserIds();
    final deafenedParticipantUserIds =
        _voiceRuntimeService.currentDeafenedParticipantUserIds();
    final mutedByUserId = <String, bool>{
      ...Map<String, bool>.fromEntries(
        runtimeParticipantUserIds.map(
          (participantUserId) => MapEntry(
            participantUserId,
            mutedParticipantUserIds.contains(participantUserId),
          ),
        ),
      ),
      resolvedActiveConnection.participantUserId.value:
          _voiceRuntimeService.isSelfMuted(),
    };
    final deafenedByUserId = <String, bool>{
      ...Map<String, bool>.fromEntries(
        runtimeParticipantUserIds.map(
          (participantUserId) => MapEntry(
            participantUserId,
            deafenedParticipantUserIds.contains(participantUserId),
          ),
        ),
      ),
      resolvedActiveConnection.participantUserId.value:
          _voiceRuntimeService.isSelfDeafened(),
    };
    final participants = await _resolveParticipants(
      participantUserIds: runtimeParticipantUserIds.toList(),
      mutedByUserId: mutedByUserId,
      deafenedByUserId: deafenedByUserId,
      existingDisplayNamesByUserId: _participantDisplayNamesFromState(
        loadedState: loadedState,
      ),
    );

    return Ok<List<VoiceParticipant>>(participants);
  }

  Map<String, String?> _participantDisplayNamesFromState({
    required VoiceSessionsLoadedDataState? loadedState,
  }) {
    if (loadedState == null) {
      return const <String, String?>{};
    }

    final allParticipants = <VoiceParticipant>[
      ...loadedState.participantsByChannelId.values.expand(
        (participants) => participants,
      ),
      ...loadedState.participants,
    ];

    return allParticipants.fold(<String, String?>{}, (
      displayNamesByUserId,
      participant,
    ) {
      final trimmedUserId = participant.userId.value.trim();
      if (trimmedUserId.isEmpty ||
          displayNamesByUserId.containsKey(trimmedUserId)) {
        return displayNamesByUserId;
      }

      final trimmedDisplayName = participant.displayName.trim();
      final normalizedDisplayName =
          trimmedDisplayName.isEmpty || trimmedDisplayName == "Member"
              ? null
              : trimmedDisplayName;

      return {
        ...displayNamesByUserId,
        trimmedUserId: normalizedDisplayName,
      };
    });
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
    required Map<String, bool> deafenedByUserId,
    Map<String, String?> existingDisplayNamesByUserId =
        const <String, String?>{},
  }) async {
    final resolvedParticipantUserIds = _participantUserIdsOrFallback(
      participantUserIds: participantUserIds,
    );

    if (resolvedParticipantUserIds.isEmpty) {
      return const <VoiceParticipant>[];
    }

    return Future.wait(
      resolvedParticipantUserIds.map((participantUserId) async {
        final resolvedDisplayName = existingDisplayNamesByUserId.containsKey(
          participantUserId,
        )
            ? existingDisplayNamesByUserId[participantUserId]
            : switch (await _profileRepo.getOne(
                query: GetUserQuery(userId: UserId(participantUserId)),
              )) {
                Ok<UserProfile>(:final value) => value.displayName?.trim(),
                Error<UserProfile>() => null,
              };

        final resolvedParticipantDisplayName = switch (resolvedDisplayName) {
          final String name when name.isNotEmpty => name,
          _ => "Member",
        };

        return VoiceParticipant(
          userId: UserId(participantUserId),
          displayName: resolvedParticipantDisplayName,
          isMuted: mutedByUserId[participantUserId] ?? false,
          isDeafened: deafenedByUserId[participantUserId] ?? false,
          isSpeaking: _speakingParticipantUserIds.contains(participantUserId),
        );
      }),
    );
  }

  bool _isSelfMutedFromParticipants({
    required VoiceConnectSession? activeConnection,
    required Map<ChannelId, List<VoiceParticipant>> participantsByChannelId,
  }) {
    final _ = participantsByChannelId;

    if (activeConnection == null) {
      return false;
    }

    return _voiceRuntimeService.isSelfMuted();
  }

  Future<void> _onParticipantUserIdsUpdated(
    ParticipantUserIdsUpdated event,
    Emitter<VoiceSessionsState> emit,
  ) async {
    final _ = event;

    final loadedState = switch (state) {
      final VoiceSessionsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    final activeConnection = loadedState.activeConnection;
    if (activeConnection == null) {
      return;
    }

    final participantsResult = await _loadParticipantsForChannel(
      channelId: activeConnection.channelId,
      loadedState: loadedState,
      activeConnection: activeConnection,
    );

    if (participantsResult case Error<List<VoiceParticipant>>(:final error)) {
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
      participantVideoTracks: loadedState.participantVideoTracks,
      isSelfMuted: _voiceRuntimeService.isSelfMuted(),
      isSelfDeafened: loadedState.isSelfDeafened,
      isSelfScreenShareEnabled: loadedState.isSelfScreenShareEnabled,
      isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
      isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
    ));
  }

  void _onParticipantVideoTracksUpdated(
    ParticipantVideoTracksUpdated event,
    Emitter<VoiceSessionsState> emit,
  ) {
    final loadedState = switch (state) {
      final VoiceSessionsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    emit(VoiceSessionsLoadedState(
      activeConnection: loadedState.activeConnection,
      selectedChannelId: loadedState.selectedChannelId,
      participants: loadedState.participants,
      participantsByChannelId: loadedState.participantsByChannelId,
      participantVideoTracks: Map<String, Object>.from(
        event.participantVideoTracks,
      ),
      isSelfMuted: loadedState.isSelfMuted,
      isSelfDeafened: loadedState.isSelfDeafened,
      isSelfScreenShareEnabled: _voiceRuntimeService.isSelfScreenShareEnabled(),
      isEchoCancellationEnabled: loadedState.isEchoCancellationEnabled,
      isNoiseSuppressionEnabled: loadedState.isNoiseSuppressionEnabled,
    ));
  }

  void _onParticipantStatusUpdated(
    ParticipantStatusUpdated event,
    Emitter<VoiceSessionsState> emit,
  ) {
    final loadedState = switch (state) {
      final VoiceSessionsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    final reduced = ParticipantStatusReducer.reduce(
      loadedState: loadedState,
      statusUpdate: event.update,
      speakingParticipantUserIds: _speakingParticipantUserIds,
    );
    _speakingParticipantUserIds = reduced.speakingParticipantUserIds;

    final nextState = reduced.nextState;
    if (nextState == null) {
      return;
    }

    emit(nextState);
  }

  @override
  Future<void> close() async {
    await _participantUserIdsSubscription?.cancel();
    await _participantStatusUpdatesSubscription?.cancel();
    await _participantVideoTracksSubscription?.cancel();
    return super.close();
  }
}
