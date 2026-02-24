import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import '../features/chat_browser/application/chat_browser_bloc.dart';
import '../features/chat_browser/presentation/chat_browser_page.dart';

class PolyphonyApp extends StatelessWidget {
  const PolyphonyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChatBrowserBloc>(
      create: (_) => ChatBrowserBloc(httpClient: http.Client()),
      child: const MaterialApp(
        title: 'Polyphony Client',
        home: ChatBrowserPage(),
      ),
    );
  }
}
