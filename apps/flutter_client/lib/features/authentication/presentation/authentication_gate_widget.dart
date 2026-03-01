import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/profile_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/server_members_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/chat_browser_page_widget.dart";
import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/text_session_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/message_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";

class AuthenticationGateWidget extends StatefulWidget {
  const AuthenticationGateWidget({super.key});

  @override
  State<AuthenticationGateWidget> createState() =>
      _AuthenticationGateWidgetState();
}

class _AuthenticationGateWidgetState extends State<AuthenticationGateWidget> {
  var _isSigningIn = false;
  String? _signInError;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        final authenticationState = context.read<AuthenticationBloc>().state;
        if (authenticationState is AuthenticationUnauthenticatedState) {
          unawaited(_signInWithAuth0());
        }
      });
    }
  }

  String _statusText(AuthenticationState state) {
    return switch (state) {
      AuthenticationAuthenticatedState() => "Authenticated.",
      AuthenticationAuthenticatingState() => "Signing in...",
      AuthenticationUnauthenticatedState(:final issue) => switch (issue) {
          AuthenticationIssue.tokenRequired => "Auth token is required.",
          AuthenticationIssue.signedOut => "Signed out.",
          null => "Sign in with Auth0 to continue.",
        },
    };
  }

  Future<void> _signInWithAuth0() async {
    setState(() {
      _isSigningIn = true;
      _signInError = null;
    });

    final accessTokenResult =
        await context.read<AccessTokenProvider>().getAccessToken();

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
            child: const ChatBrowserPageWidget(),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Polyphony MVP Client")),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FilledButton(
                  onPressed: _isSigningIn ? null : _signInWithAuth0,
                  child: Text(_isSigningIn ? "Signing in..." : "Sign In"),
                ),
                const SizedBox(height: 12),
                if (_signInError != null) ...<Widget>[
                  SelectableText(_signInError!),
                  const SizedBox(height: 12),
                ],
                Text(_statusText(state)),
              ],
            ),
          ),
        );
      },
    );
  }
}
