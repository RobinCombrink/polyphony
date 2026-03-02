import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/main.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

void main() {
  testWidgets("shows native login screen", (tester) async {
    await tester.pumpWidget(
      PolyphonyApp(
        preferencesStore: InMemoryPreferencesStore(),
      ),
    );

    expect(find.text("Polyphony"), findsOneWidget);
    expect(find.text("Log in to Polyphony"), findsOneWidget);
    expect(find.text("Email address"), findsOneWidget);
    expect(find.text("Remember email address"), findsOneWidget);
    expect(find.text("Continue"), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
