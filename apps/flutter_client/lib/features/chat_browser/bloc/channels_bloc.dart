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

    if (trimmedServerId.isEmpty) {
      emit(ChannelsValidationFailedState(
        issue: ChannelsValidationIssue.serverSelectionRequired,
        channels: state.channels,
        serverId: state.serverId,
      ));
      return;
    }

    emit(ChannelsLoadingState(
      channels: state.channels,
      serverId: trimmedServerId,
    ));

    final listChannelsResult = await _channelRepo.listChannels(
      baseUrl: event.baseUrl.trim(),
      serverId: trimmedServerId,
    );

    switch (listChannelsResult) {
      case Ok<List<Channel>>(:final value):
        emit(ChannelsLoadedState(channels: value, serverId: trimmedServerId));
      case Error<List<Channel>>(:final error):
        emit(ChannelsExceptionState(
          error: error,
          channels: state.channels,
          serverId: state.serverId,
        ));
    }
  }

  Future<void> _onCreateChannelRequested(
    CreateChannelRequested event,
    Emitter<ChannelsState> emit,
  ) async {
    final trimmedServerId = event.serverId.trim();
    final trimmedChannelName = event.channelName.trim();

    if (trimmedServerId.isEmpty) {
      emit(ChannelsValidationFailedState(
        issue: ChannelsValidationIssue.serverSelectionRequired,
        channels: state.channels,
        serverId: state.serverId,
      ));
      return;
    }

    if (trimmedChannelName.isEmpty) {
      emit(ChannelsValidationFailedState(
        issue: ChannelsValidationIssue.channelNameRequired,
        channels: state.channels,
        serverId: trimmedServerId,
      ));
      return;
    }

    emit(ChannelsLoadingState(
      channels: state.channels,
      serverId: trimmedServerId,
    ));

    final createChannelResult = await _channelRepo.createChannel(
      baseUrl: event.baseUrl.trim(),
      serverId: trimmedServerId,
      name: trimmedChannelName,
    );

    switch (createChannelResult) {
      case Ok<Channel>():
        final listChannelsResult = await _channelRepo.listChannels(
          baseUrl: event.baseUrl.trim(),
          serverId: trimmedServerId,
        );
        switch (listChannelsResult) {
          case Ok<List<Channel>>(:final value):
            emit(ChannelsLoadedState(
              channels: value,
              serverId: trimmedServerId,
            ));
          case Error<List<Channel>>(:final error):
            emit(ChannelsExceptionState(
              error: error,
              channels: state.channels,
              serverId: state.serverId,
            ));
        }
      case Error<Channel>(:final error):
        emit(ChannelsExceptionState(
          error: error,
          channels: state.channels,
          serverId: state.serverId,
        ));
    }
  }
}
