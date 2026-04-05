import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/direct_messages/bloc/direct_messages_bloc.dart";
import "package:polyphony_flutter_client/features/direct_messages/presentation/widgets/direct_messages_pane_widget.dart";
import "package:polyphony_flutter_client/features/friends/presentation/widgets/friends_pane_widget.dart";

class DirectMessagesWorkspaceWidget extends StatelessWidget {
  const DirectMessagesWorkspaceWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 320,
          child: FriendsPaneWidget(
            onStartDirectMessage: (userId) {
              context.read<DirectMessagesBloc>().add(
                    OpenDirectMessageThreadRequested(userId: userId),
                  );
            },
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: DirectMessagesPaneWidget(),
        ),
      ],
    );
  }
}
