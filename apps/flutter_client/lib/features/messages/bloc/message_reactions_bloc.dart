import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/reaction_service.dart";

part "message_reactions_event.dart";
part "message_reactions_state.dart";

class MessageReactionsBloc
    extends Bloc<MessageReactionsEvent, MessageReactionsState> {
  MessageReactionsBloc({
    required ReactionService reactionService,
    required this.channelId,
    required this.messageId,
  })  : _reactionService = reactionService,
        super(const MessageReactionsInitialState()) {
    on<MessageReactionsLoadRequested>(_onLoadRequested);
    on<MessageReactionsToggleRequested>(_onToggleRequested);
  }

  final ReactionService _reactionService;
  final ChannelId channelId;
  final MessageId messageId;

  Future<void> _onLoadRequested(
    MessageReactionsLoadRequested event,
    Emitter<MessageReactionsState> emit,
  ) async {
    emit(const MessageReactionsLoadingState());

    final result = await _reactionService.listReactions(
      channelId: channelId,
      messageId: messageId,
    );

    switch (result) {
      case Ok<List<ReactionSummary>>(:final value):
        emit(MessageReactionsLoadedState(reactions: value));
      case Error<List<ReactionSummary>>(:final error):
        emit(MessageReactionsExceptionState(error: error));
    }
  }

  Future<void> _onToggleRequested(
    MessageReactionsToggleRequested event,
    Emitter<MessageReactionsState> emit,
  ) async {
    await _reactionService.toggleReaction(
      channelId: channelId,
      messageId: messageId,
      emoteId: event.emoteId,
    );

    final result = await _reactionService.listReactions(
      channelId: channelId,
      messageId: messageId,
    );

    switch (result) {
      case Ok<List<ReactionSummary>>(:final value):
        emit(MessageReactionsLoadedState(reactions: value));
      case Error<List<ReactionSummary>>(:final error):
        emit(MessageReactionsExceptionState(error: error));
    }
  }
}
