import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/messages/use_cases/toggle_reaction_use_case.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/models/reaction_summary.dart";
import "package:polyphony_flutter_client/shared/repositories/reaction_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

part "message_reactions_event.dart";
part "message_reactions_state.dart";

class MessageReactionsBloc
    extends Bloc<MessageReactionsEvent, MessageReactionsState> {
  MessageReactionsBloc({
    required ReactionRepo reactionRepo,
    required ToggleReactionUseCase toggleReactionUseCase,
    required this.channelId,
    required this.messageId,
  })  : _reactionRepo = reactionRepo,
        _toggleReactionUseCase = toggleReactionUseCase,
        super(const MessageReactionsInitialState()) {
    on<MessageReactionsLoadRequested>(_onLoadRequested);
    on<MessageReactionsToggleRequested>(_onToggleRequested);
  }

  final ReactionRepo _reactionRepo;
  final ToggleReactionUseCase _toggleReactionUseCase;
  final ChannelId channelId;
  final MessageId messageId;

  Future<void> _onLoadRequested(
    MessageReactionsLoadRequested event,
    Emitter<MessageReactionsState> emit,
  ) async {
    emit(const MessageReactionsLoadingState());

    final result = await _reactionRepo.getMany(
      query: ListReactionsQuery(channelId: channelId, messageId: messageId),
    );

    switch (result) {
      case Ok<Iterable<ReactionSummary>>(:final value):
        emit(MessageReactionsLoadedState(reactions: value.toList()));
      case Error<Iterable<ReactionSummary>>(:final error):
        emit(MessageReactionsExceptionState(error: error));
    }
  }

  Future<void> _onToggleRequested(
    MessageReactionsToggleRequested event,
    Emitter<MessageReactionsState> emit,
  ) async {
    await _toggleReactionUseCase(
      channelId: channelId,
      messageId: messageId,
      emoteId: event.emoteId,
    );

    final result = await _reactionRepo.getMany(
      query: ListReactionsQuery(channelId: channelId, messageId: messageId),
    );

    switch (result) {
      case Ok<Iterable<ReactionSummary>>(:final value):
        emit(MessageReactionsLoadedState(reactions: value.toList()));
      case Error<Iterable<ReactionSummary>>(:final error):
        emit(MessageReactionsExceptionState(error: error));
    }
  }
}
