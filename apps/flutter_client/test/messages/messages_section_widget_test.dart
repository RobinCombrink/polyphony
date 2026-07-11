import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/messages/presentation/widgets/messages_section_widget.dart";
import "package:polyphony_flutter_client/features/messages/use_cases/toggle_reaction_use_case.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/models/reaction_summary.dart";
import "package:polyphony_flutter_client/shared/repositories/emote_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/reaction_repo.dart";
import "package:polyphony_flutter_client/shared/services/link_preview_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:provider/provider.dart";

import "../entity_seeder.dart";
import "../test_doubles/chat_repository_fakes.dart";

final _seeder = EntitySeeder();
final _currentUserId = _seeder.authUserId();
final _channelId = ChannelId("chn-${_seeder.hashCode}");

Message _messageWith({required String content}) {
  return _seeder.message(
    channelId: _channelId,
    authorUserId: _currentUserId,
    content: content,
  );
}

Widget _buildWidget({
  required List<Message> messages,
  UserId? currentUserId,
  String? currentUserDisplayName,
  LinkPreviewService? linkPreviewService,
  EmoteRepo? emoteRepo,
  ReactionRepo? reactionRepo,
  TextEditingController? createController,
}) {
  final resolvedUserId = currentUserId ?? _currentUserId;

  return MultiProvider(
    providers: [
      Provider<LinkPreviewService>(
        create: (_) => linkPreviewService ?? FakeLinkPreviewService(),
      ),
      Provider<EmoteRepo>(
        create: (_) => emoteRepo ?? FakeEmoteRepo(),
      ),
      Provider<ReactionRepo>(
        create: (_) => reactionRepo ?? FakeReactionRepo(),
      ),
      Provider<ToggleReactionUseCase>(
        create: (_) => ToggleReactionUseCase(
          reactionRepo: FakeReactionRepo(),
        ),
      ),
    ],
    child: BlocProvider<SettingsBloc>(
      create: (_) => SettingsBloc(
        preferencesStore: InMemoryPreferencesStore(),
        audioDeviceRuntimeService: FakeAudioDeviceRuntimeService(),
      )..add(const SettingsPreferencesRestoreRequested()),
      child: MaterialApp(
        home: Scaffold(
          body: MessagesSectionWidget(
            messages: messages,
            currentUser: UserProfile(
              userId: resolvedUserId,
              displayName: currentUserDisplayName,
            ),
            authorDisplayNamesByUserId: const <UserId, String?>{},
            createController: createController ?? TextEditingController(),
            mentionCandidates: const <UserProfile>[],
            isLoading: false,
            onCreate: (_) {},
            onEdit: (_) async {},
            onDelete: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group("MessagesSectionWidget markdown rendering", () {
    testWidgets("renders message content using MarkdownBody widget",
        (tester) async {
      await tester.pumpWidget(
        _buildWidget(messages: [_messageWith(content: "plain text message")]),
      );
      await tester.pump();

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.textContaining("plain text message"), findsOneWidget);
    });

    testWidgets("renders bold markdown as styled text", (tester) async {
      await tester.pumpWidget(
        _buildWidget(messages: [_messageWith(content: "hello **bold** world")]),
      );
      await tester.pump();

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.textContaining("bold"), findsOneWidget);
    });

    testWidgets("renders italic markdown as styled text", (tester) async {
      await tester.pumpWidget(
        _buildWidget(messages: [_messageWith(content: "hello _italic_ world")]),
      );
      await tester.pump();

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.textContaining("italic"), findsOneWidget);
    });

    testWidgets("renders inline code markdown", (tester) async {
      await tester.pumpWidget(
        _buildWidget(
            messages: [_messageWith(content: "use `some_function()` here")]),
      );
      await tester.pump();

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.textContaining("some_function()"), findsOneWidget);
    });

    testWidgets("renders emote shortcodes as emoji characters", (tester) async {
      await tester.pumpWidget(
        _buildWidget(messages: [_messageWith(content: "great job :thumbsup:")]),
      );
      await tester.pump();

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.textContaining("\u{1F44D}"), findsOneWidget);
    });

    testWidgets("renders link markdown as tappable text", (tester) async {
      await tester.pumpWidget(
        _buildWidget(messages: [
          _messageWith(content: "visit [my link](https://example.com)"),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.textContaining("my link"), findsOneWidget);
    });

    testWidgets("renders code block markdown", (tester) async {
      await tester.pumpWidget(
        _buildWidget(messages: [
          _messageWith(content: "```\nconst x = 1;\n```"),
        ]),
      );
      await tester.pump();

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.textContaining("const x = 1;"), findsOneWidget);
    });

    testWidgets("does not render SelectableText for message content",
        (tester) async {
      await tester.pumpWidget(
        _buildWidget(messages: [_messageWith(content: "some content")]),
      );
      await tester.pump();

      final selectableTexts = tester.widgetList<SelectableText>(
        find.byType(SelectableText),
      );
      final contentSelectableTexts = selectableTexts.where(
        (widget) => widget.data == "some content",
      );
      expect(contentSelectableTexts, isEmpty);
    });

    testWidgets("renders image markdown as alt text instead of loading image",
        (tester) async {
      await tester.pumpWidget(
        _buildWidget(messages: [
          _messageWith(
              content: "![alt description](https://example.com/img.png)"),
        ]),
      );
      await tester.pump();

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.textContaining("alt description"), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });

  group("MessagesSectionWidget link preview", () {
    testWidgets("renders link preview card for message with URL",
        (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          messages: [
            _messageWith(content: "check https://example.com out"),
          ],
          linkPreviewService: FakeLinkPreviewService(
            preview: const LinkPreview(
              url: "https://example.com",
              title: "Example Domain",
              description: "This domain is for examples.",
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("Example Domain"), findsOneWidget);
      expect(
        find.textContaining("This domain is for examples."),
        findsOneWidget,
      );
    });

    testWidgets("does not render link preview for message without URL",
        (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          messages: [_messageWith(content: "just plain text")],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("Example Title"), findsNothing);
    });

    testWidgets("does not render preview when service returns no content",
        (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          messages: [
            _messageWith(content: "visit https://example.com"),
          ],
          linkPreviewService: FakeLinkPreviewService(
            preview: const LinkPreview(url: "https://example.com"),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("Example Title"), findsNothing);
    });
  });

  group("MessagesSectionWidget emote picker", () {
    testWidgets("shows emote button in composer", (tester) async {
      await tester.pumpWidget(
        _buildWidget(messages: const []),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.emoji_emotions_outlined), findsOneWidget);
    });

    testWidgets("opens emote picker dialog when emote button tapped",
        (tester) async {
      await tester.pumpWidget(
        _buildWidget(messages: const []),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
      await tester.pumpAndSettle();

      expect(find.text("Search emotes..."), findsOneWidget);
      expect(find.text("\u{1F44D}"), findsOneWidget);
      expect(find.text("\u{2764}\u{FE0F}"), findsOneWidget);
    });

    testWidgets("inserts emote shortcode into text field when tapped",
        (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        _buildWidget(
          messages: const [],
          createController: controller,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
      await tester.pumpAndSettle();

      // Tap the thumbsup emoji
      await tester.tap(find.text("\u{1F44D}"));
      await tester.pumpAndSettle();

      expect(controller.text, ":thumbsup:");
    });

    testWidgets("filters emotes when searching", (tester) async {
      await tester.pumpWidget(
        _buildWidget(messages: const []),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, "Search emotes..."),
        "heart",
      );
      await tester.pumpAndSettle();

      expect(find.text("\u{2764}\u{FE0F}"), findsOneWidget);
      expect(find.text("\u{1F44D}"), findsNothing);
    });
  });

  group("MessagesSectionWidget reactions", () {
    testWidgets("shows add reaction button for each message", (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          messages: [_messageWith(content: "hello")],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_reaction_outlined), findsOneWidget);
    });

    testWidgets("renders reaction chips when reactions exist", (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          messages: [_messageWith(content: "hello")],
          reactionRepo: FakeReactionRepo(
            reactions: const [
              ReactionSummary(
                emoteId: "thumbsup",
                count: 3,
                reactedByCurrentUser: true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("thumbsup 3"), findsOneWidget);
    });

    testWidgets("shows emote picker when add reaction button tapped",
        (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          messages: [_messageWith(content: "hello")],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_reaction_outlined));
      await tester.pumpAndSettle();

      expect(find.text("Search emotes..."), findsOneWidget);
    });
  });
}
