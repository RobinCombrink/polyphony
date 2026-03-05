import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:http/http.dart" as http;
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/presentation/authentication_gate_widget.dart";
import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/auth/auth0_browser_token_provider.dart";
import "package:polyphony_flutter_client/shared/auth/authentication_profile_service.dart";
import "package:polyphony_flutter_client/shared/auth/authentication_session_service.dart";
import "package:polyphony_flutter_client/shared/auth/refresh_token_store.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/services/livekit/livekit_media_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/livekit/livekit_message_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/message_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:provider/provider.dart";

class PolyphonyApp extends StatelessWidget {
  const PolyphonyApp({
    super.key,
    this.preferencesStore,
  });

  final PreferencesStore? preferencesStore;

  String _auth0ClientIdForCurrentPlatform() {
    if (kIsWeb) {
      return PolyphonyConfig.auth0WebClientId;
    }

    return PolyphonyConfig.auth0NativeClientId;
  }

  AccessTokenProvider _createAccessTokenProvider(BuildContext context) {
    final auth0ClientId = _auth0ClientIdForCurrentPlatform();

    if (kIsWeb) {
      return Auth0WebTokenProvider(
        domain: PolyphonyConfig.auth0Domain,
        clientId: auth0ClientId,
        audience: PolyphonyConfig.auth0Audience,
        scopes: PolyphonyConfig.auth0Scopes,
      );
    }

    return Auth0NativeTokenProvider(
      httpClient: http.Client(),
      refreshTokenStore: context.read<RefreshTokenStore>(),
      domain: PolyphonyConfig.auth0Domain,
      clientId: auth0ClientId,
      audience: PolyphonyConfig.auth0Audience,
      scopes: PolyphonyConfig.auth0Scopes,
      mobileRedirectUri: PolyphonyConfig.auth0MobileRedirectUri,
      desktopRedirectUri: PolyphonyConfig.auth0DesktopRedirectUri,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<RefreshTokenStore>(
          create: (_) => createRefreshTokenStore(),
        ),
        Provider<PreferencesStore>(
          create: (_) => preferencesStore ?? createPreferencesStore(),
        ),
        Provider<AccessTokenProvider>(
          create: _createAccessTokenProvider,
        ),
        Provider<AuthenticationSessionService>(
          create: (context) => AuthenticationSessionService(
            accessTokenProvider: context.read<AccessTokenProvider>(),
            isWeb: kIsWeb,
          ),
        ),
        Provider<AuthenticationProfileService>(
          create: (_) => AuthenticationProfileService(
            httpClient: http.Client(),
          ),
        ),
        BlocProvider<AuthenticationBloc>(
          create: (context) => AuthenticationBloc(
            profileService: context.read<AuthenticationProfileService>(),
            sessionService: context.read<AuthenticationSessionService>(),
          ),
        ),
        Provider<MediaRuntimeService>(
          create: (_) => LivekitMediaRuntimeService(),
        ),
        Provider<MessageRuntimeService>(
          create: (_) => LivekitMessageRuntimeService(),
        ),
      ],
      child: const MaterialApp(
        title: "Polyphony Client",
        home: AuthenticationGateWidget(),
      ),
    );
  }
}
