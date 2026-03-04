import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/models/channel_type.dart";
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
  final _selectionByServerId = <String, _ServerChannelSelection>{};

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
      emit(
        switch (state) {
          final ChannelsLoadedDataState loadedState =>
            ChannelsValidationFailedState(
              issue: ChannelsValidationIssue.serverSelectionRequired,
              textChannels: loadedState.textChannels,
              voiceChannels: loadedState.voiceChannels,
              serverId: loadedState.serverId,
              selectedTextChannelId: loadedState.selectedTextChannelId,
              selectedVoiceChannelId: loadedState.selectedVoiceChannelId,
              selectionMode: loadedState.selectionMode,
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
        serverId: trimmedServerId,
      ),
    );

    switch (listChannelsResult) {
      case Ok<Iterable<Channel>>(:final value):
        final channels = value.toList();
        final (textChannels, voiceChannels) = _partitionChannels(channels);
        final previousSelection = _selectionByServerId[trimmedServerId];

        final selectedTextChannelId = _resolveSelectedChannelId(
          channels: textChannels,
          channelId: previousSelection?.selectedTextChannelId,
        );
        final selectedVoiceChannelId = _resolveSelectedChannelId(
          channels: voiceChannels,
          channelId: previousSelection?.selectedVoiceChannelId,
        );

        final requestedSelectionMode =
            previousSelection?.selectionMode ?? ChannelSelectionMode.text;
        final selectionMode =
            requestedSelectionMode == ChannelSelectionMode.voice &&
                    selectedVoiceChannelId == null
                ? ChannelSelectionMode.text
                : requestedSelectionMode;

        _selectionByServerId[trimmedServerId] = _ServerChannelSelection(
          selectedTextChannelId: selectedTextChannelId,
          selectedVoiceChannelId: selectedVoiceChannelId,
          selectionMode: selectionMode,
        );

        emit(ChannelsLoadedState(
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: trimmedServerId,
          selectedTextChannelId: selectedTextChannelId,
          selectedVoiceChannelId: selectedVoiceChannelId,
          selectionMode: selectionMode,
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
    final loadedState = switch (state) {
      final ChannelsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(ChannelsExceptionState(
        error: Exception("Channels must be loaded before creating a channel."),
      ));
      return;
    }

    if (trimmedServerId.isEmpty) {
      emit(ChannelsValidationFailedState(
        issue: ChannelsValidationIssue.serverSelectionRequired,
        textChannels: loadedState.textChannels,
        voiceChannels: loadedState.voiceChannels,
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
        textChannels: loadedState.textChannels,
        voiceChannels: loadedState.voiceChannels,
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

        final (selectedTextChannelId, selectedVoiceChannelId, selectionMode) =
            switch (createdChannel) {
          TextChannel() => (
              createdChannel.id,
              loadedState.selectedVoiceChannelId,
              ChannelSelectionMode.text,
            ),
          VoiceChannel() => (
              loadedState.selectedTextChannelId,
              createdChannel.id,
              ChannelSelectionMode.voice,
            ),
        };

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

        emit(ChannelsLoadedState(
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: trimmedServerId,
          selectedTextChannelId: selectedTextChannelId,
          selectedVoiceChannelId: selectedVoiceChannelId,
          selectionMode: selectionMode,
        ));

        _selectionByServerId[trimmedServerId] = _ServerChannelSelection(
          selectedTextChannelId: selectedTextChannelId,
          selectedVoiceChannelId: selectedVoiceChannelId,
          selectionMode: selectionMode,
        );
      case Error<Channel>(:final error):
        emit(ChannelsExceptionState(error: error));
    }
  }

  Future<void> _onDeleteChannelRequested(
    DeleteChannelRequested event,
    Emitter<ChannelsState> emit,
  ) async {
    final loadedState = switch (state) {
      final ChannelsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      emit(ChannelsExceptionState(
        error: Exception("Channels must be loaded before deleting a channel."),
      ));
      return;
    }

    final trimmedChannelId = event.channelId.trim();
    if (trimmedChannelId.isEmpty ||
        !_allChannels(loadedState)
            .any((channel) => channel.id == trimmedChannelId)) {
      emit(ChannelsValidationFailedState(
        issue: ChannelsValidationIssue.channelSelectionRequired,
        textChannels: loadedState.textChannels,
        voiceChannels: loadedState.voiceChannels,
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
        final textChannels = loadedState.textChannels
            .where((channel) => channel.id != trimmedChannelId)
            .toList();
        final voiceChannels = loadedState.voiceChannels
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
          textChannels: textChannels,
          voiceChannels: voiceChannels,
          serverId: loadedState.serverId,
          selectedTextChannelId: selectedTextChannelId,
          selectedVoiceChannelId: selectedVoiceChannelId,
          selectionMode: selectionMode,
        ));

        _selectionByServerId[loadedState.serverId] = _ServerChannelSelection(
          selectedTextChannelId: selectedTextChannelId,
          selectedVoiceChannelId: selectedVoiceChannelId,
          selectionMode: selectionMode,
        );
      case Error<void>(:final error):
        emit(ChannelsExceptionState(error: error));
    }
  }

  void _onSelectTextChannelRequested(
    SelectTextChannelRequested event,
    Emitter<ChannelsState> emit,
  ) {
    final loadedState = switch (state) {
      final ChannelsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    final trimmedChannelId = event.channelId.trim();
    final selectedTextChannelId = loadedState.textChannels.any(
      (channel) => channel.id == trimmedChannelId,
    )
        ? trimmedChannelId
        : null;

    emit(ChannelsLoadedState(
      textChannels: loadedState.textChannels,
      voiceChannels: loadedState.voiceChannels,
      serverId: loadedState.serverId,
      selectedTextChannelId: selectedTextChannelId,
      selectedVoiceChannelId: loadedState.selectedVoiceChannelId,
      selectionMode: ChannelSelectionMode.text,
    ));

    _selectionByServerId[loadedState.serverId] = _ServerChannelSelection(
      selectedTextChannelId: selectedTextChannelId,
      selectedVoiceChannelId: loadedState.selectedVoiceChannelId,
      selectionMode: ChannelSelectionMode.text,
    );
  }

  void _onSelectVoiceChannelRequested(
    SelectVoiceChannelRequested event,
    Emitter<ChannelsState> emit,
  ) {
    final loadedState = switch (state) {
      final ChannelsLoadedDataState loadedState => loadedState,
      _ => null,
    };

    if (loadedState == null) {
      return;
    }

    final trimmedChannelId = event.channelId.trim();
    final selectedVoiceChannelId = loadedState.voiceChannels.any(
      (channel) => channel.id == trimmedChannelId,
    )
        ? trimmedChannelId
        : null;

    emit(ChannelsLoadedState(
      textChannels: loadedState.textChannels,
      voiceChannels: loadedState.voiceChannels,
      serverId: loadedState.serverId,
      selectedTextChannelId: loadedState.selectedTextChannelId,
      selectedVoiceChannelId: selectedVoiceChannelId,
      selectionMode: ChannelSelectionMode.voice,
    ));

    _selectionByServerId[loadedState.serverId] = _ServerChannelSelection(
      selectedTextChannelId: loadedState.selectedTextChannelId,
      selectedVoiceChannelId: selectedVoiceChannelId,
      selectionMode: ChannelSelectionMode.voice,
    );
  }

  String? _resolveSelectedChannelId<T extends Channel>({
    required List<T> channels,
    required String? channelId,
  }) {
    if (channelId == null || channelId.isEmpty) {
      return null;
    }

    final trimmedChannelId = channelId.trim();
    final exists = channels.any((channel) => channel.id == trimmedChannelId);
    return exists ? trimmedChannelId : null;
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
}

final class _ServerChannelSelection {
  const _ServerChannelSelection({
    required this.selectedTextChannelId,
    required this.selectedVoiceChannelId,
    required this.selectionMode,
  });

  final String? selectedTextChannelId;
  final String? selectedVoiceChannelId;
  final ChannelSelectionMode selectionMode;
}
