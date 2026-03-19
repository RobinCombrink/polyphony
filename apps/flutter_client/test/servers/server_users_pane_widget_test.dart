import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/servers/presentation/widgets/server_users_pane_widget.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

class _RecordingServerMembersBloc extends ServerMembersBloc {
  _RecordingServerMembersBloc({
    required super.serverMemberRepo,
    required super.profileRepo,
    required super.friendRepo,
    required super.serverRepo,
  });

  final recordedEvents = <ServerMembersEvent>[];

  @override
  void add(ServerMembersEvent event) {
    recordedEvents.add(event);
    super.add(event);
  }

  void emitForTest(ServerMembersState state) {
    emit(state);
  }
}

Widget _buildWidget(ServerMembersBloc bloc) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<ServerMembersBloc>.value(
        value: bloc,
        child: const SizedBox(
          width: 320,
          height: 600,
          child: ServerUsersPaneWidget(),
        ),
      ),
    ),
  );
}

void main() {
  final fixture = EntitySeeder().chatApiFixture();

  _RecordingServerMembersBloc buildBloc() {
    return _RecordingServerMembersBloc(
      serverMemberRepo: FakeServerMemberRepository(fixture: fixture),
      profileRepo: FakeProfileRepository(
        userId: fixture.ownerUserId,
        initialDisplayName: "Owner",
      ),
      friendRepo: FakeFriendRepository(friendUserIds: <String>{}),
      serverRepo: FakeServerRepository(fixture: fixture),
    );
  }

  testWidgets("shows validation status message for pending request conflict",
      (tester) async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.emitForTest(
      const ServerMembersValidationFailedState(
        issue: ServerMembersValidationIssue.sendFriendRequestConflict,
        serverId: "server-1",
        members: <UserProfile>[
          UserProfile(userId: "auth0|u1", displayName: "Owner"),
        ],
        friendUserIds: <String>{},
        pendingOutgoingFriendRequests: <PendingFriendRequest>[],
      ),
    );

    await tester.pumpWidget(_buildWidget(bloc));

    expect(find.text("A friend request is already pending."), findsOneWidget);
  });

  testWidgets("renders pending friend requests section and cancel action",
      (tester) async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.emitForTest(
      const ServerMembersLoadedState(
        serverId: "server-1",
        members: <UserProfile>[
          UserProfile(userId: "auth0|u1", displayName: "Owner"),
        ],
        friendUserIds: <String>{},
        pendingOutgoingFriendRequests: <PendingFriendRequest>[
          PendingFriendRequest(
            id: "pending-request-1",
            requesterUserId: "auth0|self",
            addresseeUserId: "auth0|u1",
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildWidget(bloc));

    expect(find.text("Pending friend requests"), findsOneWidget);
    expect(find.text("Cancel"), findsOneWidget);

    await tester.tap(find.text("Cancel"));
    await tester.pump();

    final cancelEvents = bloc.recordedEvents
        .whereType<CancelOutgoingFriendRequestRequested>()
        .toList(growable: false);

    expect(cancelEvents, hasLength(1));
    expect(cancelEvents.first.friendRequestId, "pending-request-1");
  });

  testWidgets("long-press context menu shows cancel for pending user",
      (tester) async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.emitForTest(
      const ServerMembersLoadedState(
        serverId: "server-1",
        members: <UserProfile>[
          UserProfile(userId: "auth0|u1", displayName: "Owner"),
        ],
        friendUserIds: <String>{},
        pendingOutgoingFriendRequests: <PendingFriendRequest>[
          PendingFriendRequest(
            id: "pending-request-1",
            requesterUserId: "auth0|self",
            addresseeUserId: "auth0|u1",
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildWidget(bloc));

    await tester.longPress(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.text("Cancel friend request"), findsOneWidget);
    expect(find.text("Add friend"), findsNothing);
  });

  testWidgets("long-press context menu shows add friend for non-pending user",
      (tester) async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.emitForTest(
      const ServerMembersLoadedState(
        serverId: "server-1",
        members: <UserProfile>[
          UserProfile(userId: "auth0|u2", displayName: "Member Two"),
        ],
        friendUserIds: <String>{},
        pendingOutgoingFriendRequests: <PendingFriendRequest>[],
      ),
    );

    await tester.pumpWidget(_buildWidget(bloc));

    await tester.longPress(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.text("Add friend"), findsOneWidget);
    expect(find.text("Cancel friend request"), findsNothing);

    await tester.tap(find.text("Add friend"));
    await tester.pumpAndSettle();

    final addEvents = bloc.recordedEvents
        .whereType<SendFriendRequestToServerMemberRequested>()
        .toList(growable: false);

    expect(addEvents, hasLength(1));
    expect(addEvents.first.serverId, "server-1");
    expect(addEvents.first.targetUserId, "auth0|u2");
  });
}
