import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/home/presentation/home_page_widget.dart";
import "package:polyphony_flutter_client/features/servers/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/text_session_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/message_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/preferences_store.dart";

class AuthenticationGateWidget extends StatefulWidget {
  const AuthenticationGateWidget({super.key});

  @override
  State<AuthenticationGateWidget> createState() =>
      _AuthenticationGateWidgetState();
}

class _AuthenticationGateWidgetState extends State<AuthenticationGateWidget> {
  var _isSigningIn = false;
  var _hasTriggeredWebSignIn = false;
  var _rememberEmailAddress = false;
  String? _signInError;
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
      unawaited(_restoreSession());
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

  Future<void> _restoreSession() async {
    final accessTokenResult =
        await context.read<AccessTokenProvider>().getPersistedAccessToken();

    if (!mounted) {
      return;
    }

    switch (accessTokenResult) {
      case Ok<String?>(:final value):
        final accessToken = value;
        if (accessToken == null || accessToken.trim().isEmpty) {
          if (kIsWeb && !_hasTriggeredWebSignIn) {
            _hasTriggeredWebSignIn = true;
            unawaited(_signInWithAuth0());
          }

          return;
        }

        context
            .read<AuthenticationBloc>()
            .add(AuthenticationLoginRequested(bearerToken: accessToken));
      case Error<String?>(:final error):
        setState(() {
          _signInError = error.toString();
        });
    }
  }

  Future<void> _signInWithAuth0({String? loginHint}) async {
    await _persistRememberedEmailAddressPreference();

    setState(() {
      _isSigningIn = true;
      _signInError = null;
    });

    final accessTokenResult = await context
        .read<AccessTokenProvider>()
        .getAccessToken(loginHint: loginHint);

    if (!mounted) {
      return;
    }

    switch (accessTokenResult) {
      case Ok<String>(:final value):
        context
            .read<AuthenticationBloc>()
            .add(AuthenticationLoginRequested(bearerToken: value));
      case Error<String>(:final error):
        final errorMessage = error.toString();
        if (errorMessage.contains("Redirecting to Auth0 for sign in.")) {
          setState(() {
            _isSigningIn = false;
          });
          return;
        }

        setState(() {
          _signInError = errorMessage;
        });
    }

    setState(() {
      _isSigningIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        if (state is AuthenticationAuthenticatedState) {
          return MultiBlocProvider(
            key: ValueKey<String>(state.bearerToken),
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
              BlocProvider<ProfileBloc>(
                create: (context) =>
                    ProfileBloc(profileRepo: context.read<ProfileRepo>()),
              ),
              BlocProvider<ServerMembersBloc>(
                create: (context) => ServerMembersBloc(
                  serverRepo: context.read<ServerRepo>(),
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
          );
        }

        if (kIsWeb) {
          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_isSigningIn
                      ? "Redirecting to Auth0..."
                      : "Signing in..."),
                  if (_signInError != null) ...<Widget>[
                    const SizedBox(height: 12),
                    SelectableText(_signInError!),
                  ],
                ],
              ),
            ),
          );
        }

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
                          controller: _emailAddressController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const <String>[AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: "Email address",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _rememberEmailAddress,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text("Remember email address"),
                          onChanged: (value) {
                            final shouldRememberEmail = value ?? false;
                            setState(() {
                              _rememberEmailAddress = shouldRememberEmail;
                            });

                            unawaited(
                              _persistRememberedEmailAddressPreference(),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _isSigningIn
                              ? null
                              : () {
                                  unawaited(
                                    _signInWithAuth0(
                                      loginHint: _emailAddressController.text,
                                    ),
                                  );
                                },
                          child: Text(
                            _isSigningIn ? "Continuing..." : "Continue",
                          ),
                        ),
                        if (_signInError != null) ...<Widget>[
                          const SizedBox(height: 12),
                          SelectableText(_signInError!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
