class ReactionSummary {
  const ReactionSummary({
    required this.emoteId,
    required this.count,
    required this.reactedByCurrentUser,
  });

  final String emoteId;
  final int count;
  final bool reactedByCurrentUser;
}
