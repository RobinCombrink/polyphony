import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/something_went_wrong_widget.dart";
import "package:skeletonizer/skeletonizer.dart";

enum _ServerUserContextMenuAction {
  addFriend,
  cancelFriendRequest,
}

class ServerUsersPaneWidget extends StatelessWidget {
  const ServerUsersPaneWidget({super.key});

  Future<void> _showUserContextMenu({
    required BuildContext context,
    required ServerMembersLoadedDataState loadedData,
    required UserProfile member,
    required bool isFriend,
    required PendingFriendRequest? pendingRequest,
    required Offset globalPosition,
  }) async {
    if (isFriend) {
      return;
    }

    final hasPendingRequest = pendingRequest != null;

    final selectedAction = await showMenu<_ServerUserContextMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: <PopupMenuEntry<_ServerUserContextMenuAction>>[
        if (!hasPendingRequest)
          const PopupMenuItem<_ServerUserContextMenuAction>(
            value: _ServerUserContextMenuAction.addFriend,
            child: Text("Add friend"),
          ),
        if (hasPendingRequest)
          const PopupMenuItem<_ServerUserContextMenuAction>(
            value: _ServerUserContextMenuAction.cancelFriendRequest,
            child: Text("Cancel friend request"),
          ),
      ],
    );

    if (!context.mounted || selectedAction == null) {
      return;
    }

    switch (selectedAction) {
      case _ServerUserContextMenuAction.addFriend:
        if (hasPendingRequest) {
          return;
        }

        context.read<ServerMembersBloc>().add(
              SendFriendRequestToServerMemberRequested(
                serverId: loadedData.serverId,
                targetUserId: member.userId,
              ),
            );
      case _ServerUserContextMenuAction.cancelFriendRequest:
        if (!hasPendingRequest) {
          return;
        }

        context.read<ServerMembersBloc>().add(
              CancelOutgoingFriendRequestRequested(
                friendRequestId: pendingRequest.id,
              ),
            );
    }
  }

  String _resolvedPendingRequestLabel({
    required PendingFriendRequest pendingRequest,
    required Map<String, String> displayNameByUserId,
  }) {
    final resolvedDisplayName =
        displayNameByUserId[pendingRequest.addresseeUserId];
    if (resolvedDisplayName != null && resolvedDisplayName.isNotEmpty) {
      return resolvedDisplayName;
    }

    return pendingRequest.addresseeUserId;
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
        final pendingOutgoingFriendRequests =
            loadedData?.pendingOutgoingFriendRequests ??
                const <PendingFriendRequest>[];
        final pendingRequestUserIds = pendingOutgoingFriendRequests
            .map((request) => request.addresseeUserId)
            .toSet();
        final pendingRequestByAddresseeUserId = {
          for (final request in pendingOutgoingFriendRequests)
            request.addresseeUserId: request,
        };
        final displayNameByUserId = {
          for (final member in members)
            member.userId: _resolvedDisplayName(member),
        };
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
                              final hasPendingRequest =
                                  pendingRequestUserIds.contains(member.userId);
                              final pendingRequest =
                                  pendingRequestByAddresseeUserId[
                                      member.userId];

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
                                                pendingRequest: pendingRequest,
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
                                                pendingRequest: pendingRequest,
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
                                          : hasPendingRequest
                                              ? const Text("Pending")
                                              : const Text("Not friend"),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                if (!isLoading && pendingOutgoingFriendRequests.isNotEmpty)
                  const SizedBox(height: 8),
                if (!isLoading && pendingOutgoingFriendRequests.isNotEmpty)
                  SizedBox(
                    height: 180,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              "Pending friend requests",
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                itemCount: pendingOutgoingFriendRequests.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final pendingRequest =
                                      pendingOutgoingFriendRequests[index];

                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      _resolvedPendingRequestLabel(
                                        pendingRequest: pendingRequest,
                                        displayNameByUserId:
                                            displayNameByUserId,
                                      ),
                                    ),
                                    subtitle: Text(
                                      pendingRequest.addresseeUserId,
                                    ),
                                    trailing: TextButton(
                                      onPressed: () {
                                        context.read<ServerMembersBloc>().add(
                                              CancelOutgoingFriendRequestRequested(
                                                friendRequestId:
                                                    pendingRequest.id,
                                              ),
                                            );
                                      },
                                      child: const Text("Cancel"),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
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
