import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/messages/presentation/widgets/messages_section_widget.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/services/emote_service.dart";
import "package:polyphony_flutter_client/shared/services/link_preview_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:provider/provider.dart";

import "../test_doubles/chat_repository_fakes.dart";

const _currentUserId = UserId("auth0|current-user");

Widget _buildWidget({
  required List<Message> messages,
  UserId? currentUserId,
  String? currentUserDisplayName,
  LinkPreviewService? linkPreviewService,
  EmoteService? emoteService,
}) {
  final resolvedUserId = currentUserId ?? _currentUserId;

  return MultiProvider(
    providers: [
      Provider<LinkPreviewService>(
        create: (_) => linkPreviewService ?? FakeLinkPreviewService(),
      ),
      Provider<EmoteService>(
        create: (_) => emoteService ?? FakeEmoteService(),
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
            createController: TextEditingController(),
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

Message _messageWith({required String content}) {
  return Message(
    id: const MessageId("msg-test"),
    channelId: const ChannelId("chn-test"),
    authorUserId: _currentUserId,
    content: content,
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
        MultiProvider(
          providers: [
            Provider<LinkPreviewService>(
              create: (_) => FakeLinkPreviewService(),
            ),
            Provider<EmoteService>(
              create: (_) => FakeEmoteService(),
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
                  messages: const [],
                  currentUser: const UserProfile(
                    userId: _currentUserId,
                    displayName: null,
                  ),
                  authorDisplayNamesByUserId: const <UserId, String?>{},
                  createController: controller,
                  mentionCandidates: const <UserProfile>[],
                  isLoading: false,
                  onCreate: (_) {},
                  onEdit: (_) async {},
                  onDelete: (_) {},
                ),
              ),
            ),
          ),
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
}
