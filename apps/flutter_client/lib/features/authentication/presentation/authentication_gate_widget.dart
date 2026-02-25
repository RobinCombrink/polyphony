import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/messages_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/chat_browser_page_widget.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";

class AuthenticationGateWidget extends StatefulWidget {
  const AuthenticationGateWidget({super.key});

  @override
  State<AuthenticationGateWidget> createState() =>
      _AuthenticationGateWidgetState();
}

class _AuthenticationGateWidgetState extends State<AuthenticationGateWidget> {
  final tokenController = TextEditingController();

  String _statusText(AuthenticationState state) {
    return switch (state) {
      AuthenticationAuthenticatedState() => "Authenticated.",
      AuthenticationAuthenticatingState() => "Signing in...",
      AuthenticationUnauthenticatedState(:final issue) => switch (issue) {
          AuthenticationIssue.tokenRequired => "Auth token is required.",
          AuthenticationIssue.signedOut => "Signed out.",
          null => "Enter Auth0 access token to continue.",
        },
    };
  }

  @override
  void dispose() {
    tokenController.dispose();
    super.dispose();
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
                create: (context) =>
                    MessagesBloc(messageRepo: context.read<MessageRepo>()),
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
                TextField(
                  controller: tokenController,
                  decoration:
                      const InputDecoration(labelText: "Auth0 access token"),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => context.read<AuthenticationBloc>().add(
                        AuthenticationLoginRequested(
                          bearerToken: tokenController.text,
                        ),
                      ),
                  child: const Text("Sign In"),
                ),
                const SizedBox(height: 12),
                Text(_statusText(state)),
              ],
            ),
          ),
        );
      },
    );
  }
}
