import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/home/presentation/widgets/workspace_destination.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/servers/presentation/widgets/servers_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/section_status.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

import "../test_doubles/chat_repository_fakes.dart";

void main() {
  const listedServer = Server(
    id: ServerId("server-1"),
    name: "Alpha",
    ownerUserId: UserId("owner-1"),
  );

  Widget buildWidget({
    required void Function(Server server) onInviteFriend,
    int directMessagesUnreadCount = 0,
  }) {
    return BlocProvider<SettingsBloc>(
      create: (_) => SettingsBloc(
        preferencesStore: InMemoryPreferencesStore(),
        audioDeviceRuntimeService: FakeAudioDeviceRuntimeService(),
      )..add(const SettingsPreferencesRestoreRequested()),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 500,
            child: ServersSectionWidget(
              servers: const <Server>[listedServer],
              selectedDestination: ServerSelectedWorkspaceDestination(
                  serverId: listedServer.id.value),
              directMessagesUnreadCount: directMessagesUnreadCount,
              currentUserId: listedServer.ownerUserId,
              isLoading: false,
              createController: TextEditingController(),
              onSelectDirectMessages: () {},
              onTap: (_) {},
              onAddUser: (_) {},
              onInviteFriend: onInviteFriend,
              onNotificationPreferences: (_) {},
              onRenameServer: (_) {},
              onDeleteServer: (_) {},
              onCreate: () {},
            ),
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

    await tester.longPress(find.byTooltip("Alpha"));
    await tester.pumpAndSettle();

    expect(find.text("Invite friend to server"), findsOneWidget);

    await tester.tap(find.text("Invite friend to server"));
    await tester.pumpAndSettle();

    expect(invitedServer?.id, listedServer.id);
  });

  testWidgets("direct messages avatar shows unread badge", (tester) async {
    await tester.pumpWidget(
      buildWidget(
        onInviteFriend: (_) {},
        directMessagesUnreadCount: 4,
      ),
    );

    expect(
      find.descendant(
        of: find.byTooltip("Direct messages"),
        matching: find.text("4"),
      ),
      findsOneWidget,
    );
  });

  test("servers status includes server selection validation copy", () {
    final status = buildServersSectionStatus(
      const ServersValidationFailedState(
        issue: ServersValidationIssue.serverSelectionRequired,
        servers: <Server>[],
      ),
    );

    expect(status, isA<SectionStatus>());
    expect(
      status?.message,
      "Select a server first.",
    );
    expect(status?.isError, isTrue);
  });
}
