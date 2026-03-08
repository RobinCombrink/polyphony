import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_developer_options_section_widget.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";

Widget _buildTestApp({required String token}) {
  return MaterialApp(
    home: Scaffold(
      body: SettingsDeveloperOptionsSectionWidget(
        bearerToken: token,
      ),
    ),
  );
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group("SettingsDeveloperOptionsSectionWidget", () {
    testWidgets(
        "hides configuration values while developer options are disabled",
        (tester) async {
      await tester.pumpWidget(_buildTestApp(token: "test-token"));
      await _pumpUi(tester);

      expect(find.text("Configuration"), findsNothing);
      expect(
        find.text(
          "POLYPHONY_BACKEND_BASE_URL: ${PolyphonyConfig.backendBaseUrl}",
        ),
        findsNothing,
      );
    });

    testWidgets("shows all config values when developer options are enabled",
        (tester) async {
      await tester.pumpWidget(_buildTestApp(token: "test-token"));
      await _pumpUi(tester);

      await tester.tap(find.byType(SwitchListTile));
      await _pumpUi(tester);

      expect(find.text("Configuration"), findsOneWidget);
      expect(
        find.text(
          "POLYPHONY_BACKEND_BASE_URL: ${PolyphonyConfig.backendBaseUrl}",
        ),
        findsOneWidget,
      );
      expect(
        find.text("AUTH0_DOMAIN: ${PolyphonyConfig.auth0Domain}"),
        findsOneWidget,
      );
      expect(
        find.text(
          "AUTH0_NATIVE_CLIENT_ID: ${PolyphonyConfig.auth0NativeClientId}",
        ),
        findsOneWidget,
      );
      expect(
        find.text("AUTH0_WEB_CLIENT_ID: ${PolyphonyConfig.auth0WebClientId}"),
        findsOneWidget,
      );
      expect(
        find.text("AUTH0_AUDIENCE: ${PolyphonyConfig.auth0Audience}"),
        findsOneWidget,
      );
      expect(
        find.text("AUTH0_SCOPES: ${PolyphonyConfig.auth0Scopes}"),
        findsOneWidget,
      );
      expect(
        find.text(
          "AUTH0_MOBILE_REDIRECT_URI: ${PolyphonyConfig.auth0MobileRedirectUri}",
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          "AUTH0_DESKTOP_REDIRECT_URI: ${PolyphonyConfig.auth0DesktopRedirectUri}",
        ),
        findsOneWidget,
      );
    });
  });
}
