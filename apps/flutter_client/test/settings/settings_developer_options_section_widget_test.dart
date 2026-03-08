import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_developer_profile_bloc.dart";
import "package:polyphony_flutter_client/features/settings/presentation/widgets/settings_developer_options_section_widget.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/profile_service.dart";

class _FakeProfileService implements ProfileService {
  const _FakeProfileService({required this.meResult});

  final Result<ApiMe> meResult;

  @override
  Future<Result<ApiMe>> getMe() async {
    return meResult;
  }

  @override
  Future<Result<ApiUserLookup>> getUserById({required String userId}) {
    throw UnimplementedError();
  }

  @override
  Future<Result<ApiMe>> updateDisplayName({required String displayName}) {
    throw UnimplementedError();
  }
}

Widget _buildTestApp({
  required String token,
  required ProfileService profileService,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<SettingsDeveloperProfileBloc>(
        create: (_) => SettingsDeveloperProfileBloc(
          profileService: profileService,
        ),
        child: SettingsDeveloperOptionsSectionWidget(
          bearerToken: token,
        ),
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
      await tester.pumpWidget(
        _buildTestApp(
          token: "test-token",
          profileService: const _FakeProfileService(
            meResult: Ok<ApiMe>(
              ApiMe(
                userId: "auth0|user",
                displayName: "Polyphony User",
                issuer: "https://example.auth0.com/",
              ),
            ),
          ),
        ),
      );
      await _pumpUi(tester);

      expect(find.text("Configuration"), findsNothing);
      expect(find.text("/me response"), findsNothing);
      expect(
        find.text(
          "POLYPHONY_BACKEND_BASE_URL: ${PolyphonyConfig.backendBaseUrl}",
        ),
        findsNothing,
      );
    });

    testWidgets("shows all config values when developer options are enabled",
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          token: "test-token",
          profileService: const _FakeProfileService(
            meResult: Ok<ApiMe>(
              ApiMe(
                userId: "auth0|user",
                displayName: "Polyphony User",
                issuer: "https://example.auth0.com/",
              ),
            ),
          ),
        ),
      );
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
      expect(find.text("/me response"), findsOneWidget);
      expect(find.text("user_id: auth0|user"), findsOneWidget);
      expect(find.text("display_name: Polyphony User"), findsOneWidget);
      expect(
        find.text("issuer: https://example.auth0.com/"),
        findsOneWidget,
      );
    });
  });
}
