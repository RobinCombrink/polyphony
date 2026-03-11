import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/something_went_wrong_widget.dart";
import "package:skeletonizer/skeletonizer.dart";

enum _ServerUserContextMenuAction {
  addFriend,
}

class ServerUsersPaneWidget extends StatelessWidget {
  const ServerUsersPaneWidget({super.key});

  Future<void> _showUserContextMenu({
    required BuildContext context,
    required ServerMembersLoadedDataState loadedData,
    required UserProfile member,
    required bool isFriend,
    required Offset globalPosition,
  }) async {
    if (isFriend) {
      return;
    }

    final selectedAction = await showMenu<_ServerUserContextMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: const <PopupMenuEntry<_ServerUserContextMenuAction>>[
        PopupMenuItem<_ServerUserContextMenuAction>(
          value: _ServerUserContextMenuAction.addFriend,
          child: Text("Add friend"),
        ),
      ],
    );

    if (!context.mounted || selectedAction == null) {
      return;
    }

    switch (selectedAction) {
      case _ServerUserContextMenuAction.addFriend:
        context.read<ServerMembersBloc>().add(
              SendFriendRequestToServerMemberRequested(
                serverId: loadedData.serverId,
                targetUserId: member.userId,
              ),
            );
    }
  }

  List<UserProfile> _skeletonMembers() {
    return List<UserProfile>.generate(
      7,
      (index) => UserProfile(
        userId: "user-skeleton-$index",
        displayName: "Member ${index + 1}",
      ),
    );
  }

  String _resolvedDisplayName(UserProfile member) {
    final displayName = member.displayName?.trim();
    if (displayName == null || displayName.isEmpty) {
      return member.userId;
    }

    return displayName;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServerMembersBloc, ServerMembersState>(
      builder: (context, state) {
        final isLoading = state is ServerMembersInitialState ||
            state is ServerMembersLoadingState;
        final loadedData = state is ServerMembersLoadedDataState ? state : null;
        final errorMessage = state is ServerMembersExceptionState
            ? state.error.toString()
            : null;

        if (errorMessage != null) {
          return SomethingWentWrongWidget(message: errorMessage);
        }

        final members = loadedData?.members ?? const <UserProfile>[];
        final friendUserIds = loadedData?.friendUserIds ?? const <String>{};
        final visibleMembers =
            isLoading && members.isEmpty ? _skeletonMembers() : members;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  "Server users",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Skeletonizer(
                    enabled: isLoading,
                    child: visibleMembers.isEmpty
                        ? const Center(
                            child: Text(
                              "No users found for this server.",
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: visibleMembers.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final member = visibleMembers[index];
                              final displayName = _resolvedDisplayName(member);
                              final hasDisplayName =
                                  member.displayName?.trim().isNotEmpty == true;
                              final isFriend =
                                  friendUserIds.contains(member.userId);

                              return GestureDetector(
                                onSecondaryTapDown:
                                    isLoading || loadedData == null
                                        ? null
                                        : (details) => unawaited(
                                              _showUserContextMenu(
                                                context: context,
                                                loadedData: loadedData,
                                                member: member,
                                                isFriend: isFriend,
                                                globalPosition:
                                                    details.globalPosition,
                                              ),
                                            ),
                                onLongPressStart:
                                    isLoading || loadedData == null
                                        ? null
                                        : (details) => unawaited(
                                              _showUserContextMenu(
                                                context: context,
                                                loadedData: loadedData,
                                                member: member,
                                                isFriend: isFriend,
                                                globalPosition:
                                                    details.globalPosition,
                                              ),
                                            ),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(displayName),
                                  subtitle: hasDisplayName
                                      ? Text(member.userId)
                                      : null,
                                  trailing: isLoading
                                      ? null
                                      : isFriend
                                          ? const Text("Friend")
                                          : const Text("Not friend"),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
