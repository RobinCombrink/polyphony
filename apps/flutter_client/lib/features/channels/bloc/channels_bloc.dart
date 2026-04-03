import "package:collection/collection.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/models/channel_type.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
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
    on<UpdateChannelNameRequested>(_onUpdateChannelNameRequested);
    on<SelectTextChannelRequested>(_onSelectTextChannelRequested);
    on<SelectVoiceChannelRequested>(_onSelectVoiceChannelRequested);
  }

  final ChannelRepo _channelRepo;
  final _selectionByServerId = <ServerId, _ServerChannelSelection>{};

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
    final serverId = event.serverId;

    if (serverId.value.trim().isEmpty) {
      emit(
        switch (state) {
          final ChannelsLoadedState loadedState =>
            loadedState.withValidationIssue(
              issue: ChannelsValidationIssue.serverSelectionRequired,
            ),
          _ => ChannelsExceptionState(
              error: Exception("Channels must be loaded before validation."),
            ),
        },
      );
      return;
    }

    emit(const ChannelsLoadingState());

    final listChannelsResult = await _channelRepo.getMany(
      query: GetChannelsQuery(
        serverId: serverId,
      ),
    );

    switch (listChannelsResult) {
      case Ok<Iterable<Channel>>(:final value):
        final channels = value.toList();
        final (textChannels, voiceChannels) = _partitionChannels(channels);
        final previousSelection = _selectionByServerId[serverId];

        final loadedState = _buildLoadedState(
          previousState: state,
          previousSelection: previousSelection,
          serverId: serverId,
          textChannels: textChannels,
          voiceChannels: voiceChannels,
        );

        _selectionByServerId[serverId] = _selectionFromState(loadedState);

        emit(loadedState);
      case Error<Iterable<Channel>>(:final error):
        emit(ChannelsExceptionState(error: error));
    }
  }

  Future<void> _onCreateChannelRequested(
    CreateChannelRequested event,
    Emitter<ChannelsState> emit,
  ) async {
    final trimmedServerId = event.serverId;
    final trimmedChannelName = event.channelName.trim();
    final loadedState = switch (state) {
      final ChannelsLoadedState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(ChannelsExceptionState(
        error: Exception("Channels must be loaded before creating a channel."),
      ));
      return;
    }

    if (trimmedServerId.value.trim().isEmpty) {
      emit(
        loadedState.withValidationIssue(
          issue: ChannelsValidationIssue.serverSelectionRequired,
        ),
      );
      return;
    }

    if (trimmedChannelName.isEmpty) {
      emit(
        loadedState.withValidationIssue(
          issue: ChannelsValidationIssue.channelNameRequired,
        ),
      );
      return;
    }

    emit(const ChannelsLoadingState());

    final createChannelResult = await _channelRepo.createOne(
      command: CreateChannelCommand(
        serverId: trimmedServerId,
        name: trimmedChannelName,
        channelType: event.channelType,
      ),
    );

    switch (createChannelResult) {
      case Ok<Channel>(:final value):
        final createdChannel = value;
        final textChannels = <TextChannel>[
          ...loadedState.textChannels,
        ];
        final voiceChannels = <VoiceChannel>[
          ...loadedState.voiceChannels,
        ];

        switch (createdChannel) {
          case TextChannel():
            if (!textChannels
                .any((channel) => channel.id == createdChannel.id)) {
              textChannels.add(createdChannel);
            }
          case VoiceChannel():
            if (!voiceChannels
                .any((channel) => channel.id == createdChannel.id)) {
              voiceChannels.add(createdChannel);
            }
        }

        final updatedState = switch (createdChannel) {
          TextChannel() => TextChannelSelected(
              textChannels: textChannels,
              voiceChannels: voiceChannels,
              serverId: trimmedServerId,
              selectedTextChannel: createdChannel,
            ),
          VoiceChannel() => VoiceChannelSelected(
              textChannels: textChannels,
              voiceChannels: voiceChannels,
              serverId: trimmedServerId,
              selectedVoiceChannel: createdChannel,
            ),
        };

        emit(updatedState);

        _selectionByServerId[trimmedServerId] =
            _selectionFromState(updatedState);
      case Error<Channel>(:final error):
        emit(ChannelsExceptionState(error: error));
    }
  }

  Future<void> _onDeleteChannelRequested(
    DeleteChannelRequested event,
    Emitter<ChannelsState> emit,
  ) async {
    final loadedState = switch (state) {
      final ChannelsLoadedState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(ChannelsExceptionState(
        error: Exception("Channels must be loaded before deleting a channel."),
      ));
      return;
    }

    final trimmedChannelId = event.channelId;
    if (trimmedChannelId.value.trim().isEmpty ||
        !_allChannels(loadedState)
            .any((channel) => channel.id == trimmedChannelId)) {
      emit(
        loadedState.withValidationIssue(
          issue: ChannelsValidationIssue.channelSelectionRequired,
        ),
      );
      return;
    }

    emit(const ChannelsLoadingState());

    final deleteChannelResult = await _channelRepo.deleteOne(
      command: DeleteChannelCommand(channelId: trimmedChannelId),
    );

    switch (deleteChannelResult) {
      case Ok<void>():
        final nextTextChannels = loadedState.textChannels
            .where((channel) => channel.id != trimmedChannelId)
            .toList();
        final nextVoiceChannels = loadedState.voiceChannels
            .where((channel) => channel.id != trimmedChannelId)
            .toList();

        final nextState = loadedState.deleteChannel(
          channelId: trimmedChannelId,
          nextTextChannels: nextTextChannels,
          nextVoiceChannels: nextVoiceChannels,
        );

        emit(nextState);

        _selectionByServerId[loadedState.serverId] = _selectionFromState(
          nextState,
        );
      case Error<void>(:final error):
        emit(ChannelsExceptionState(error: error));
    }
  }

  Future<void> _onUpdateChannelNameRequested(
    UpdateChannelNameRequested event,
    Emitter<ChannelsState> emit,
  ) async {
    final loadedState = switch (state) {
      final ChannelsLoadedState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(ChannelsExceptionState(
        error: Exception("Channels must be loaded before renaming a channel."),
      ));
      return;
    }

    final trimmedChannelId = event.channelId;
    final trimmedName = event.name.trim();

    if (trimmedChannelId.value.trim().isEmpty ||
        !_allChannels(loadedState)
            .any((channel) => channel.id == trimmedChannelId)) {
      emit(
        loadedState.withValidationIssue(
          issue: ChannelsValidationIssue.channelSelectionRequired,
        ),
      );
      return;
    }

    if (trimmedName.isEmpty) {
      emit(
        loadedState.withValidationIssue(
          issue: ChannelsValidationIssue.channelNameRequired,
        ),
      );
      return;
    }

    emit(const ChannelsLoadingState());

    final updateResult = await _channelRepo.updateOne(
      command: UpdateChannelNameCommand(
        channelId: trimmedChannelId,
        name: trimmedName,
      ),
    );

    switch (updateResult) {
      case Ok<void>():
        final listChannelsResult = await _channelRepo.getMany(
          query: GetChannelsQuery(serverId: loadedState.serverId),
        );

        switch (listChannelsResult) {
          case Ok<Iterable<Channel>>(:final value):
            final channels = value.toList();
            final (textChannels, voiceChannels) = _partitionChannels(channels);

            final nextState = _buildLoadedState(
              previousState: state,
              previousSelection: _selectionByServerId[loadedState.serverId],
              serverId: loadedState.serverId,
              textChannels: textChannels,
              voiceChannels: voiceChannels,
            );

            _selectionByServerId[loadedState.serverId] =
                _selectionFromState(nextState);

            emit(nextState);
          case Error<Iterable<Channel>>(:final error):
            emit(ChannelsExceptionState(error: error));
        }
      case Error<void>(:final error):
        emit(ChannelsExceptionState(error: error));
    }
  }

  void _onSelectTextChannelRequested(
    SelectTextChannelRequested event,
    Emitter<ChannelsState> emit,
  ) {
    final loadedState = switch (state) {
      final ChannelsLoadedState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    final trimmedChannelId = event.channelId;
    final selectedTextChannel = loadedState.textChannels.firstWhereOrNull(
      (channel) => channel.id == trimmedChannelId,
    );
    final nextState = loadedState.selectTextChannel(
      incomingSelectedTextChannel: selectedTextChannel,
    );

    emit(nextState);

    _selectionByServerId[loadedState.serverId] = _selectionFromState(nextState);
  }

  void _onSelectVoiceChannelRequested(
    SelectVoiceChannelRequested event,
    Emitter<ChannelsState> emit,
  ) {
    final loadedState = switch (state) {
      final ChannelsLoadedState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    final trimmedChannelId = event.channelId;
    final selectedVoiceChannel = loadedState.voiceChannels.firstWhereOrNull(
      (channel) => channel.id == trimmedChannelId,
    );
    final nextState = loadedState.selectVoiceChannel(
      incomingSelectedVoiceChannel: selectedVoiceChannel,
    );

    emit(nextState);

    _selectionByServerId[loadedState.serverId] = _selectionFromState(nextState);
  }

  List<Channel> _allChannels(ChannelsLoadedDataState state) {
    return <Channel>[
      ...state.textChannels,
      ...state.voiceChannels,
    ];
  }

  (List<TextChannel>, List<VoiceChannel>) _partitionChannels(
    List<Channel> channels,
  ) {
    final textChannels = <TextChannel>[];
    final voiceChannels = <VoiceChannel>[];

    for (final channel in channels) {
      switch (channel) {
        case TextChannel():
          textChannels.add(channel);
        case VoiceChannel():
          voiceChannels.add(channel);
      }
    }

    return (textChannels, voiceChannels);
  }

  ChannelsLoadedState _buildLoadedState({
    required ChannelsState previousState,
    required _ServerChannelSelection? previousSelection,
    required ServerId serverId,
    required List<TextChannel> textChannels,
    required List<VoiceChannel> voiceChannels,
  }) {
    final selectedStateFromPrevious = switch (previousSelection) {
      TextServerChannelSelection(:final channelId)
          when textChannels.any((channel) => channel.id == channelId) =>
        TextChannelSelected(
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: serverId,
          selectedTextChannel: textChannels.firstWhere(
            (channel) => channel.id == channelId,
          ),
        ),
      VoiceServerChannelSelection(:final channelId)
          when voiceChannels.any((channel) => channel.id == channelId) =>
        VoiceChannelSelected(
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: serverId,
          selectedVoiceChannel: voiceChannels.firstWhere(
            (channel) => channel.id == channelId,
          ),
        ),
      _ => NoChannelSelected(
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: serverId,
        ),
    };

    return switch (previousState) {
      ChannelsValidationFailedState(:final issue) =>
        selectedStateFromPrevious.withValidationIssue(issue: issue),
      _ => selectedStateFromPrevious,
    };
  }

  _ServerChannelSelection _selectionFromState(ChannelsLoadedState state) {
    return switch (state) {
      TextChannelSelected(:final selectedTextChannel) ||
      TextChannelSelectedValidationFailedState(
        :final selectedTextChannel,
      ) =>
        TextServerChannelSelection(channelId: selectedTextChannel.id),
      VoiceChannelSelected(:final selectedVoiceChannel) ||
      VoiceChannelSelectedValidationFailedState(
        :final selectedVoiceChannel,
      ) =>
        VoiceServerChannelSelection(channelId: selectedVoiceChannel.id),
      _ => const NoServerChannelSelection(),
    };
  }
}

sealed class _ServerChannelSelection {
  const _ServerChannelSelection();
}

final class NoServerChannelSelection extends _ServerChannelSelection {
  const NoServerChannelSelection();
}

final class TextServerChannelSelection extends _ServerChannelSelection {
  const TextServerChannelSelection({required this.channelId});

  final ChannelId channelId;
}

final class VoiceServerChannelSelection extends _ServerChannelSelection {
  const VoiceServerChannelSelection({required this.channelId});

  final ChannelId channelId;
}
