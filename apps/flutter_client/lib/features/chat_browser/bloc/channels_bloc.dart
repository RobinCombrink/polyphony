import "package:flutter_bloc/flutter_bloc.dart";

import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "channels_event.dart";
part "channels_state.dart";

class ChannelsBloc extends Bloc<ChannelsEvent, ChannelsState> {
  ChannelsBloc({required ChannelRepo channelRepo})
      : _channelRepo = channelRepo,
        super(const ChannelsInitialState()) {
    on<ResetChannelsRequested>(_onResetChannelsRequested);
    on<LoadChannelsRequested>(_onLoadChannelsRequested);
    on<CreateChannelRequested>(_onCreateChannelRequested);
    on<DeleteChannelRequested>(_onDeleteChannelRequested);
    on<SelectTextChannelRequested>(_onSelectTextChannelRequested);
    on<SelectVoiceChannelRequested>(_onSelectVoiceChannelRequested);
  }

  final ChannelRepo _channelRepo;

  void _onResetChannelsRequested(
    ResetChannelsRequested event,
    Emitter<ChannelsState> emit,
  ) {
    emit(const ChannelsInitialState());
  }

  Future<void> _onLoadChannelsRequested(
    LoadChannelsRequested event,
    Emitter<ChannelsState> emit,
  ) async {
    final trimmedServerId = event.serverId.trim();
    final loadedState = _loadedStateOrNull(state);

    if (trimmedServerId.isEmpty) {
      if (loadedState == null) {
        emit(ChannelsExceptionState(
          error: Exception("Channels must be loaded before validation."),
        ));
        return;
      }

      emit(ChannelsValidationFailedState(
        issue: ChannelsValidationIssue.serverSelectionRequired,
        channels: loadedState.channels,
        serverId: loadedState.serverId,
        selectedTextChannelId: loadedState.selectedTextChannelId,
        selectedVoiceChannelId: loadedState.selectedVoiceChannelId,
        selectionMode: loadedState.selectionMode,
      ));
      return;
    }

    emit(const ChannelsLoadingState());

    final listChannelsResult = await _channelRepo.getMany(
      query: GetChannelsQuery(
        serverId: trimmedServerId,
      ),
    );

    switch (listChannelsResult) {
      case Ok<Iterable<Channel>>(:final value):
        emit(ChannelsLoadedState(
          channels: value.toList(),
          serverId: trimmedServerId,
          selectedTextChannelId: null,
          selectedVoiceChannelId: null,
          selectionMode: ChannelSelectionMode.text,
        ));
      case Error<Iterable<Channel>>(:final error):
        emit(ChannelsExceptionState(error: error));
    }
  }

  Future<void> _onCreateChannelRequested(
    CreateChannelRequested event,
    Emitter<ChannelsState> emit,
  ) async {
    final trimmedServerId = event.serverId.trim();
    final trimmedChannelName = event.channelName.trim();
    final loadedState = _loadedStateOrNull(state);

    if (loadedState == null) {
      emit(ChannelsExceptionState(
        error: Exception("Channels must be loaded before creating a channel."),
      ));
      return;
    }

    if (trimmedServerId.isEmpty) {
      emit(ChannelsValidationFailedState(
        issue: ChannelsValidationIssue.serverSelectionRequired,
        channels: loadedState.channels,
        serverId: loadedState.serverId,
        selectedTextChannelId: loadedState.selectedTextChannelId,
        selectedVoiceChannelId: loadedState.selectedVoiceChannelId,
        selectionMode: loadedState.selectionMode,
      ));
      return;
    }

    if (trimmedChannelName.isEmpty) {
      emit(ChannelsValidationFailedState(
        issue: ChannelsValidationIssue.channelNameRequired,
        channels: loadedState.channels,
        serverId: trimmedServerId,
        selectedTextChannelId: loadedState.selectedTextChannelId,
        selectedVoiceChannelId: loadedState.selectedVoiceChannelId,
        selectionMode: loadedState.selectionMode,
      ));
      return;
    }

    emit(const ChannelsLoadingState());

    final createChannelResult = await _channelRepo.createOne(
      command: CreateChannelCommand(
        serverId: trimmedServerId,
        name: trimmedChannelName,
      ),
    );

    switch (createChannelResult) {
      case Ok<Channel>(:final value):
        final createdChannel = value;
        final channels = <Channel>[
          ...loadedState.channels,
          if (!loadedState.channels.any(
            (channel) => channel.id == createdChannel.id,
          ))
            createdChannel,
        ];

        emit(ChannelsLoadedState(
          channels: channels,
          serverId: trimmedServerId,
          selectedTextChannelId: createdChannel.id,
          selectedVoiceChannelId: loadedState.selectedVoiceChannelId,
          selectionMode: ChannelSelectionMode.text,
        ));
      case Error<Channel>(:final error):
        emit(ChannelsExceptionState(error: error));
    }
  }

  Future<void> _onDeleteChannelRequested(
    DeleteChannelRequested event,
    Emitter<ChannelsState> emit,
  ) async {
    final loadedState = _loadedStateOrNull(state);

    if (loadedState == null) {
      emit(ChannelsExceptionState(
        error: Exception("Channels must be loaded before deleting a channel."),
      ));
      return;
    }

    final trimmedChannelId = event.channelId.trim();
    if (trimmedChannelId.isEmpty ||
        !loadedState.channels
            .any((channel) => channel.id == trimmedChannelId)) {
      emit(ChannelsValidationFailedState(
        issue: ChannelsValidationIssue.channelSelectionRequired,
        channels: loadedState.channels,
        serverId: loadedState.serverId,
        selectedTextChannelId: loadedState.selectedTextChannelId,
        selectedVoiceChannelId: loadedState.selectedVoiceChannelId,
        selectionMode: loadedState.selectionMode,
      ));
      return;
    }

    emit(const ChannelsLoadingState());

    final deleteChannelResult = await _channelRepo.deleteOne(
      command: DeleteChannelCommand(channelId: trimmedChannelId),
    );

    switch (deleteChannelResult) {
      case Ok<void>():
        final channels = loadedState.channels
            .where((channel) => channel.id != trimmedChannelId)
            .toList();

        final selectedTextChannelId =
            loadedState.selectedTextChannelId == trimmedChannelId
                ? null
                : loadedState.selectedTextChannelId;
        final selectedVoiceChannelId =
            loadedState.selectedVoiceChannelId == trimmedChannelId
                ? null
                : loadedState.selectedVoiceChannelId;
        final selectionMode =
            loadedState.selectionMode == ChannelSelectionMode.voice &&
                    selectedVoiceChannelId == null
                ? ChannelSelectionMode.text
                : loadedState.selectionMode;

        emit(ChannelsLoadedState(
          channels: channels,
          serverId: loadedState.serverId,
          selectedTextChannelId: selectedTextChannelId,
          selectedVoiceChannelId: selectedVoiceChannelId,
          selectionMode: selectionMode,
        ));
      case Error<void>(:final error):
        emit(ChannelsExceptionState(error: error));
    }
  }

  void _onSelectTextChannelRequested(
    SelectTextChannelRequested event,
    Emitter<ChannelsState> emit,
  ) {
    final loadedState = _loadedStateOrNull(state);
    if (loadedState == null) {
      return;
    }

    final trimmedChannelId = event.channelId.trim();
    final selectedTextChannelId = loadedState.channels.any(
      (channel) => channel.id == trimmedChannelId,
    )
        ? trimmedChannelId
        : null;

    emit(ChannelsLoadedState(
      channels: loadedState.channels,
      serverId: loadedState.serverId,
      selectedTextChannelId: selectedTextChannelId,
      selectedVoiceChannelId: loadedState.selectedVoiceChannelId,
      selectionMode: ChannelSelectionMode.text,
    ));
  }

  void _onSelectVoiceChannelRequested(
    SelectVoiceChannelRequested event,
    Emitter<ChannelsState> emit,
  ) {
    final loadedState = _loadedStateOrNull(state);
    if (loadedState == null) {
      return;
    }

    final trimmedChannelId = event.channelId.trim();
    final selectedVoiceChannelId = loadedState.channels.any(
      (channel) => channel.id == trimmedChannelId,
    )
        ? trimmedChannelId
        : null;

    emit(ChannelsLoadedState(
      channels: loadedState.channels,
      serverId: loadedState.serverId,
      selectedTextChannelId: loadedState.selectedTextChannelId,
      selectedVoiceChannelId: selectedVoiceChannelId,
      selectionMode: ChannelSelectionMode.voice,
    ));
  }

  ChannelsLoadedDataState? _loadedStateOrNull(ChannelsState state) {
    return switch (state) {
      ChannelsLoadedDataState() => state,
      _ => null,
    };
  }
}
