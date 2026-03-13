import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/servers/presentation/widgets/servers_section_widget.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/section_status.dart";

void main() {
  const listedServer = Server(
    id: "server-1",
    name: "Alpha",
    ownerUserId: "owner-1",
  );

  Widget buildWidget({
    required void Function(Server server) onInviteFriend,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 500,
          child: ServersSectionWidget(
            servers: const <Server>[listedServer],
            selectedServerId: listedServer.id,
            currentUserId: listedServer.ownerUserId,
            isLoading: false,
            createController: TextEditingController(),
            onTap: (_) {},
            onAddUser: (_) {},
            onInviteFriend: onInviteFriend,
            onNotificationPreferences: (_) {},
            onDeleteServer: (_) {},
            onCreate: () {},
          ),
        ),
      ),
    );
  }

  testWidgets("server context menu dispatches invite friend callback",
      (tester) async {
    Server? invitedServer;

    await tester.pumpWidget(
      buildWidget(
        onInviteFriend: (server) {
          invitedServer = server;
        },
      ),
    );

    await tester.longPress(find.byType(CircleAvatar).first);
    await tester.pumpAndSettle();

    expect(find.text("Invite friend to server"), findsOneWidget);

    await tester.tap(find.text("Invite friend to server"));
    await tester.pumpAndSettle();

    expect(invitedServer?.id, listedServer.id);
  });

  test("servers status includes friend invite validation copy", () {
    final status = buildServersSectionStatus(
      const ServersValidationFailedState(
        issue: ServersValidationIssue.inviteFriendForbidden,
        servers: <Server>[],
        selectedServerId: null,
      ),
    );

    expect(status, isA<SectionStatus>());
    expect(
      status?.message,
      "Only server owners can invite existing friends.",
    );
    expect(status?.isError, isTrue);
  });
}
