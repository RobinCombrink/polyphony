import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:polyphony_flutter_client/main.dart";

void main() {
  testWidgets("shows app title", (tester) async {
    await tester.pumpWidget(const PolyphonyApp());

    expect(find.text("Polyphony MVP Client"), findsOneWidget);
    expect(find.text("Sign In"), findsOneWidget);
    expect(find.byType(FilledButton), findsWidgets);
  });
}
