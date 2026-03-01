import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:http/http.dart" as http;
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/presentation/authentication_gate_widget.dart";
import "package:polyphony_flutter_client/shared/auth/access_token_provider.dart";
import "package:polyphony_flutter_client/shared/auth/auth0_browser_token_provider.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/network/polyphony_api_client.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/profile_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/text_session_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/text_session_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/voice_session_repository.dart";
import "package:polyphony_flutter_client/shared/services/channel_service.dart";
import "package:polyphony_flutter_client/shared/services/livekit/livekit_message_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/livekit/livekit_media_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/media_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/message_runtime_service.dart";
import "package:polyphony_flutter_client/shared/services/message_service.dart";
import "package:polyphony_flutter_client/shared/services/profile_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_channel_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_message_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_profile_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_server_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_text_session_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_voice_session_service.dart";
import "package:polyphony_flutter_client/shared/services/server_service.dart";
import "package:polyphony_flutter_client/shared/services/text_session_service.dart";
import "package:polyphony_flutter_client/shared/services/voice_session_service.dart";
import "package:provider/provider.dart";

class PolyphonyApp extends StatelessWidget {
  const PolyphonyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<http.Client>(create: (_) => http.Client()),
        BlocProvider<AuthenticationBloc>(
          create: (_) => AuthenticationBloc(),
        ),
        Provider<AccessTokenProvider>(
          create: (context) => Auth0TokenProvider(
            httpClient: context.read<http.Client>(),
            domain: PolyphonyConfig.auth0Domain,
            clientId: PolyphonyConfig.auth0ClientId,
            audience: PolyphonyConfig.auth0Audience,
            scopes: PolyphonyConfig.auth0Scopes,
            mobileRedirectUri: PolyphonyConfig.auth0MobileRedirectUri,
            desktopRedirectUri: PolyphonyConfig.auth0DesktopRedirectUri,
            webRedirectPath: PolyphonyConfig.auth0WebRedirectPath,
          ),
        ),
        Provider<ChatApi>(
          create: (context) => PolyphonyApiClient(
            httpClient: context.read<http.Client>(),
            authenticationStateSource: context.read<AuthenticationBloc>(),
          ),
        ),
        Provider<ServerService>(
          create: (context) => RestServerService(
            chatApi: context.read<ChatApi>(),
            authenticationStateSource: context.read<AuthenticationBloc>(),
          ),
        ),
        Provider<ChannelService>(
          create: (context) => RestChannelService(
            chatApi: context.read<ChatApi>(),
            authenticationStateSource: context.read<AuthenticationBloc>(),
          ),
        ),
        Provider<MessageService>(
          create: (context) => RestMessageService(
            chatApi: context.read<ChatApi>(),
            authenticationStateSource: context.read<AuthenticationBloc>(),
          ),
        ),
        Provider<ProfileService>(
          create: (context) => RestProfileService(
            chatApi: context.read<ChatApi>(),
            authenticationStateSource: context.read<AuthenticationBloc>(),
          ),
        ),
        Provider<VoiceSessionService>(
          create: (context) => RestVoiceSessionService(
            chatApi: context.read<ChatApi>(),
            authenticationStateSource: context.read<AuthenticationBloc>(),
          ),
        ),
        Provider<TextSessionService>(
          create: (context) => RestTextSessionService(
            chatApi: context.read<ChatApi>(),
            authenticationStateSource: context.read<AuthenticationBloc>(),
          ),
        ),
        Provider<MediaRuntimeService>(
          create: (_) => LivekitMediaRuntimeService(),
        ),
        Provider<MessageRuntimeService>(
          create: (_) => LivekitMessageRuntimeService(),
        ),
        Provider<ServerRepo>(
          create: (context) =>
              ServerRepository(serverService: context.read<ServerService>()),
        ),
        Provider<ChannelRepo>(
          create: (context) =>
              ChannelRepository(channelService: context.read<ChannelService>()),
        ),
        Provider<MessageRepo>(
          create: (context) =>
              MessageRepository(messageService: context.read<MessageService>()),
        ),
        Provider<ProfileRepo>(
          create: (context) =>
              ProfileRepository(profileService: context.read<ProfileService>()),
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
      child: const MaterialApp(
        title: "Polyphony Client",
        home: AuthenticationGateWidget(),
      ),
    );
  }
}
