import "package:flutter_bloc/flutter_bloc.dart";

import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/repositories/pinned_message_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/pinned_message_service.dart";

part "pinned_messages_event.dart";
part "pinned_messages_state.dart";

class PinnedMessagesBloc
    extends Bloc<PinnedMessagesEvent, PinnedMessagesState> {
  PinnedMessagesBloc({required PinnedMessageRepo pinnedMessageRepo})
      : _pinnedMessageRepo = pinnedMessageRepo,
        super(const PinnedMessagesInitialState()) {
    on<LoadPinnedMessagesRequested>(_onLoadPinnedMessagesRequested);
    on<PinMessageRequested>(_onPinMessageRequested);
    on<UnpinMessageRequested>(_onUnpinMessageRequested);
  }

  final PinnedMessageRepo _pinnedMessageRepo;

  Future<void> _onLoadPinnedMessagesRequested(
    LoadPinnedMessagesRequested event,
    Emitter<PinnedMessagesState> emit,
  ) async {
    emit(const PinnedMessagesLoadingState());

    final result = await _pinnedMessageRepo.getMany(
      query: ListPinnedMessagesQuery(serverId: event.serverId),
    );

    switch (result) {
      case Ok<Iterable<PinnedMessage>>(:final value):
        emit(PinnedMessagesLoadedState(
          pinnedMessages: value.toList(),
          serverId: event.serverId,
        ));
      case Error<Iterable<PinnedMessage>>(:final error):
        emit(PinnedMessagesExceptionState(error: error));
    }
  }

  Future<void> _onPinMessageRequested(
    PinMessageRequested event,
    Emitter<PinnedMessagesState> emit,
  ) async {
    final pinResult = await _pinnedMessageRepo.createOne(
      command: PinMessageCommand(
        serverId: event.serverId,
        messageId: event.messageId,
      ),
    );

    switch (pinResult) {
      case Ok<void>():
        add(LoadPinnedMessagesRequested(serverId: event.serverId));
      case Error<void>(:final error):
        emit(PinnedMessagesExceptionState(error: error));
    }
  }

  Future<void> _onUnpinMessageRequested(
    UnpinMessageRequested event,
    Emitter<PinnedMessagesState> emit,
  ) async {
    final unpinResult = await _pinnedMessageRepo.deleteOne(
      command: UnpinMessageCommand(
        serverId: event.serverId,
        messageId: event.messageId,
      ),
    );

    switch (unpinResult) {
      case Ok<void>():
        add(LoadPinnedMessagesRequested(serverId: event.serverId));
      case Error<void>(:final error):
        emit(PinnedMessagesExceptionState(error: error));
    }
  }
}
