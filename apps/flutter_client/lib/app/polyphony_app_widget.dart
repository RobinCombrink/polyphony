import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:http/http.dart" as http;
import "package:polyphony_flutter_client/features/authentication/bloc/authentication_bloc.dart";
import "package:polyphony_flutter_client/features/authentication/presentation/authentication_gate_widget.dart";
import "package:polyphony_flutter_client/shared/network/chat_api.dart";
import "package:polyphony_flutter_client/shared/network/polyphony_api_client.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/channel_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/message_repository.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repo.dart";
import "package:polyphony_flutter_client/shared/repositories/server_repository.dart";
import "package:polyphony_flutter_client/shared/services/channel_service.dart";
import "package:polyphony_flutter_client/shared/services/message_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_channel_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_message_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_server_service.dart";
import "package:polyphony_flutter_client/shared/services/server_service.dart";
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
      ],
      child: const MaterialApp(
        title: "Polyphony Client",
        home: AuthenticationGateWidget(),
      ),
    );
  }
}
