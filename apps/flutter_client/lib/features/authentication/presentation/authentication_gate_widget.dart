import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:http/http.dart" as http;
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/home/presentation/home_page_widget.dart";
import "package:polyphony_flutter_client/features/identity/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/messages/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_center_bloc.dart";
import "package:polyphony_flutter_client/features/notifications/bloc/notification_preferences_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/voice_sessions/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/authenticated_http_client.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/network/polyphony_api_client.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/notification_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/server_member_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_member_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/text_session_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/text_session_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repository.dart";
import "package:polyphony_flutter_client/shared/services/channel_service.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/message_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/message_service.dart";
import "package:polyphony_flutter_client/shared/services/notification_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/notification_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";
import "package:polyphony_flutter_client/shared/services/profile_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_channel_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_message_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_notification_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_profile_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_server_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_text_session_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_voice_session_service.dart";
import "package:polyphony_flutter_client/shared/services/server_service.dart";
import "package:polyphony_flutter_client/shared/services/text_session_service.dart";
import "package:polyphony_flutter_client/shared/services/voice_session_service.dart";
import "package:provider/provider.dart";

class AuthenticationGateWidget extends StatefulWidget {
  const AuthenticationGateWidget({super.key});

  @override
  State<AuthenticationGateWidget> createState() =>
      _AuthenticationGateWidgetState();
}

class _AuthenticationGateWidgetState extends State<AuthenticationGateWidget> {
  var _rememberEmailAddress = false;
  final _emailAddressController = TextEditingController();

  @override
  void dispose() {
    _emailAddressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(_restoreRememberedEmailAddressPreference());
      context.read<AuthenticationBloc>().add(
            const AuthenticationSessionRestoreRequested(),
          );
    });
  }

  Future<void> _restoreRememberedEmailAddressPreference() async {
    if (kIsWeb) {
      return;
    }

    try {
      final preferencesStore = context.read<PreferencesStore>();
      final shouldRememberEmail =
          await preferencesStore.readRememberEmailEnabled();
      final rememberedEmailAddress =
          await preferencesStore.readRememberedEmailAddress();

      if (!mounted) {
        return;
      }

      setState(() {
        _rememberEmailAddress = shouldRememberEmail;
      });

      if (shouldRememberEmail &&
          rememberedEmailAddress != null &&
          rememberedEmailAddress.trim().isNotEmpty) {
        _emailAddressController.text = rememberedEmailAddress;
      }
    } on Exception {
      return;
    }
  }

  Future<void> _persistRememberedEmailAddressPreference() async {
    if (kIsWeb) {
      return;
    }

    final trimmedEmailAddress = _emailAddressController.text.trim();

    try {
      final preferencesStore = context.read<PreferencesStore>();
      await preferencesStore.writeRememberEmailEnabled(_rememberEmailAddress);

      if (_rememberEmailAddress && trimmedEmailAddress.isNotEmpty) {
        await preferencesStore.writeRememberedEmailAddress(trimmedEmailAddress);
      } else {
        await preferencesStore.clearRememberedEmailAddress();
      }
    } on Exception {
      return;
    }
  }

  Future<void> _requestSignIn({String? loginHint}) async {
    final trimmedLoginHint = loginHint?.trim();

    await _persistRememberedEmailAddressPreference();
    if (!mounted) {
      return;
    }

    context.read<AuthenticationBloc>().add(
          AuthenticationSignInRequested(
            loginHint: trimmedLoginHint == null || trimmedLoginHint.isEmpty
                ? null
                : trimmedLoginHint,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        return switch (state) {
          AuthenticationAuthenticatedState(:final metadata) =>
            _AuthenticatedShell(metadata: metadata),
          AuthenticationAuthenticatingState() when kIsWeb =>
            const _WebAuthenticatingView(),
          AuthenticationAuthenticatingState() => _NativeSignInView(
              isSigningIn: true,
              signInError: null,
              emailAddressController: _emailAddressController,
              rememberEmailAddress: _rememberEmailAddress,
              onRememberEmailAddressChanged: (shouldRememberEmail) {
                setState(() {
                  _rememberEmailAddress = shouldRememberEmail;
                });

                unawaited(_persistRememberedEmailAddressPreference());
              },
              onSignInRequested: () {
                unawaited(
                  _requestSignIn(
                    loginHint: _emailAddressController.text,
                  ),
                );
              },
            ),
          AuthenticationUnauthenticatedState(:final error) when kIsWeb =>
            _WebAuthenticatingView(signInError: error?.toString()),
          AuthenticationUnauthenticatedState(:final error) => _NativeSignInView(
              isSigningIn: false,
              signInError: error?.toString(),
              emailAddressController: _emailAddressController,
              rememberEmailAddress: _rememberEmailAddress,
              onRememberEmailAddressChanged: (shouldRememberEmail) {
                setState(() {
                  _rememberEmailAddress = shouldRememberEmail;
                });

                unawaited(_persistRememberedEmailAddressPreference());
              },
              onSignInRequested: () {
                unawaited(
                  _requestSignIn(
                    loginHint: _emailAddressController.text,
                  ),
                );
              },
            ),
        };
      },
    );
  }
}

final class _AuthenticatedShell extends StatelessWidget {
  const _AuthenticatedShell({required this.metadata});

  final AuthenticationMetadata metadata;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      key: ValueKey<String>("${metadata.userId}:${metadata.bearerToken}"),
      providers: [
        Provider<http.Client>(
          create: (_) => AuthenticatedHttpClient(
            innerClient: http.Client(),
            bearerToken: metadata.bearerToken,
          ),
          dispose: (_, client) => client.close(),
        ),
        Provider<ChatApi>(
          create: (context) => PolyphonyApiClient(
            httpClient: context.read<http.Client>(),
          ),
        ),
        Provider<ServerService>(
          create: (context) => RestServerService(
            chatApi: context.read<ChatApi>(),
          ),
        ),
        Provider<ChannelService>(
          create: (context) => RestChannelService(
            chatApi: context.read<ChatApi>(),
          ),
        ),
        Provider<MessageService>(
          create: (context) => RestMessageService(
            chatApi: context.read<ChatApi>(),
          ),
        ),
        Provider<NotificationService>(
          create: (context) => RestNotificationService(
            chatApi: context.read<ChatApi>(),
          ),
        ),
        Provider<ProfileService>(
          create: (context) => RestProfileService(
            chatApi: context.read<ChatApi>(),
          ),
        ),
        Provider<VoiceSessionService>(
          create: (context) => RestVoiceSessionService(
            chatApi: context.read<ChatApi>(),
          ),
        ),
        Provider<TextSessionService>(
          create: (context) => RestTextSessionService(
            chatApi: context.read<ChatApi>(),
          ),
        ),
        Provider<ServerRepo>(
          create: (context) => ServerRepository(
            serverService: context.read<ServerService>(),
          ),
        ),
        Provider<ChannelRepo>(
          create: (context) => ChannelRepository(
            channelService: context.read<ChannelService>(),
          ),
        ),
        Provider<MessageRepo>(
          create: (context) => MessageRepository(
            messageService: context.read<MessageService>(),
          ),
        ),
        Provider<NotificationRepo>(
          create: (context) => NotificationRepository(
            notificationService: context.read<NotificationService>(),
          ),
        ),
        Provider<ProfileRepo>(
          create: (context) => ProfileRepository(
            profileService: context.read<ProfileService>(),
          ),
        ),
        Provider<ServerMemberRepo>(
          create: (context) => ServerMemberRepository(
            serverService: context.read<ServerService>(),
          ),
        ),
        Provider<VoiceSessionRepo>(
          create: (context) => VoiceSessionRepository(
            voiceSessionService: context.read<VoiceSessionService>(),
          ),
        ),
        Provider<TextSessionRepo>(
          create: (context) => TextSessionRepository(
            textSessionService: context.read<TextSessionService>(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ServersBloc>(
            create: (context) =>
                ServersBloc(serverRepo: context.read<ServerRepo>()),
          ),
          BlocProvider<ChannelsBloc>(
            create: (context) =>
                ChannelsBloc(channelRepo: context.read<ChannelRepo>()),
          ),
          BlocProvider<MessagesBloc>(
            create: (context) => MessagesBloc(
              messageRepo: context.read<MessageRepo>(),
              profileRepo: context.read<ProfileRepo>(),
              textSessionRepo: context.read<TextSessionRepo>(),
              messageRuntimeService: context.read<MessageRuntimeService>(),
            ),
          ),
          BlocProvider<NotificationCenterBloc>(
            create: (context) => NotificationCenterBloc(
              notificationRepo: context.read<NotificationRepo>(),
              notificationRuntimeService:
                  context.read<NotificationRuntimeService>(),
              preferencesStore: context.read<PreferencesStore>(),
            )..add(
                NotificationCenterStartedRequested(
                  backendBaseUrl: PolyphonyConfig.backendBaseUrl,
                  bearerToken: metadata.bearerToken,
                ),
              ),
          ),
          BlocProvider<NotificationPreferencesBloc>(
            create: (context) => NotificationPreferencesBloc(
              notificationService: context.read<NotificationService>(),
            ),
          ),
          BlocProvider<ProfileBloc>(
            create: (context) => ProfileBloc(
              profileRepo: context.read<ProfileRepo>(),
              currentUserId: metadata.userId,
            ),
          ),
          BlocProvider<ServerMembersBloc>(
            create: (context) => ServerMembersBloc(
              serverMemberRepo: context.read<ServerMemberRepo>(),
              profileRepo: context.read<ProfileRepo>(),
            ),
          ),
          BlocProvider<VoiceSessionsBloc>(
            create: (context) => VoiceSessionsBloc(
              voiceSessionRepo: context.read<VoiceSessionRepo>(),
              voiceRuntimeService: context.read<MediaRuntimeService>(),
              profileRepo: context.read<ProfileRepo>(),
            ),
          ),
        ],
        child: const HomePageWidget(),
      ),
    );
  }
}

final class _WebAuthenticatingView extends StatelessWidget {
  const _WebAuthenticatingView({this.signInError});

  final String? signInError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text("Redirecting to Auth0..."),
            if (signInError != null) ...<Widget>[
              const SizedBox(height: 12),
              SelectableText(signInError!),
            ],
          ],
        ),
      ),
    );
  }
}

final class _NativeSignInView extends StatelessWidget {
  const _NativeSignInView({
    required this.isSigningIn,
    required this.signInError,
    required this.emailAddressController,
    required this.rememberEmailAddress,
    required this.onRememberEmailAddressChanged,
    required this.onSignInRequested,
  });

  final bool isSigningIn;
  final String? signInError;
  final TextEditingController emailAddressController;
  final bool rememberEmailAddress;
  final ValueChanged<bool> onRememberEmailAddressChanged;
  final VoidCallback onSignInRequested;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Stack(
          children: <Widget>[
            const Align(
              alignment: Alignment.topLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.multitrack_audio),
                  SizedBox(width: 10),
                  Text(
                    "Polyphony",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      "Log in to Polyphony",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailAddressController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const <String>[AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: "Email address",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: rememberEmailAddress,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text("Remember email address"),
                      onChanged: (value) {
                        onRememberEmailAddressChanged(value ?? false);
                      },
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: isSigningIn ? null : onSignInRequested,
                      child: Text(
                        isSigningIn ? "Continuing..." : "Continue",
                      ),
                    ),
                    if (signInError != null) ...<Widget>[
                      const SizedBox(height: 12),
                      SelectableText(signInError!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
