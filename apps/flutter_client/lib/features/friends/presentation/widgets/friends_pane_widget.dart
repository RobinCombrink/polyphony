import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/friends/bloc/friends_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";

class FriendsPaneWidget extends StatelessWidget {
  const FriendsPaneWidget({
    this.onStartDirectMessage,
    super.key,
  });

  final void Function(UserId userId)? onStartDirectMessage;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FriendsBloc, FriendsState>(
        listener: (context, state) => switch (state) {
              FriendsInitialState() =>
                context.read<FriendsBloc>().add(const LoadFriendsRequested()),
              _ => null,
            },
        builder: (context, state) {
          final loadedData = state is FriendsLoadedDataState ? state : null;
          final friends = loadedData?.friends ?? const <Friend>[];
          final blockedUserIds = loadedData?.blockedUserIds ?? const <UserId>{};

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    "Friends",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (state is FriendsLoadingState)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state is FriendsExceptionState)
                    Expanded(
                      child: Center(
                        child: Text(
                          state.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else if (friends.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text("No friends found."),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: friends.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          final isBlocked =
                              blockedUserIds.contains(friend.userId);

                          return ListTile(
                            dense: true,
                            title: Text(friend.userId.value),
                            trailing: Wrap(
                              spacing: 4,
                              children: <Widget>[
                                if (onStartDirectMessage != null)
                                  IconButton(
                                    tooltip: "Message",
                                    onPressed: () =>
                                        onStartDirectMessage!(friend.userId),
                                    icon: const Icon(Icons.chat_bubble_outline),
                                  ),
                                TextButton(
                                  onPressed: () {
                                    context.read<FriendsBloc>().add(
                                          isBlocked
                                              ? UnblockUserRequested(
                                                  userId: friend.userId)
                                              : BlockUserFromFriendsRequested(
                                                  userId: friend.userId,
                                                ),
                                        );
                                  },
                                  child: Text(isBlocked ? "Unblock" : "Block"),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        });
  }
}
