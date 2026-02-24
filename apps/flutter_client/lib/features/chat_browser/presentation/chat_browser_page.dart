import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/chat_models.dart';
import '../application/chat_browser_bloc.dart';
import '../application/chat_browser_event.dart';
import '../application/chat_browser_state.dart';

class ChatBrowserPage extends StatefulWidget {
  const ChatBrowserPage({super.key});

  @override
  State<ChatBrowserPage> createState() => _ChatBrowserPageState();
}

class _ChatBrowserPageState extends State<ChatBrowserPage> {
  final TextEditingController tokenController = TextEditingController();
  final TextEditingController baseUrlController =
      TextEditingController(text: 'http://127.0.0.1:5067');
  final TextEditingController createServerController = TextEditingController();
  final TextEditingController createChannelController = TextEditingController();
  final TextEditingController createMessageController = TextEditingController();

  @override
  void dispose() {
    tokenController.dispose();
    baseUrlController.dispose();
    createServerController.dispose();
    createChannelController.dispose();
    createMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Polyphony MVP Client')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<ChatBrowserBloc, ChatBrowserState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: baseUrlController,
                  decoration:
                      const InputDecoration(labelText: 'Backend base URL'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tokenController,
                  decoration:
                      const InputDecoration(labelText: 'Auth0 access token'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: state.isLoading
                      ? null
                      : () => context.read<ChatBrowserBloc>().add(
                            LoadServersRequested(
                              bearerToken: tokenController.text,
                              baseUrl: baseUrlController.text,
                            ),
                          ),
                  child: const Text('Load Servers'),
                ),
                const SizedBox(height: 12),
                Text(state.statusMessage),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildListSection<Server>(
                          title: 'Servers',
                          items: state.servers,
                          isSelected: (server) =>
                              state.selectedServer?.id == server.id,
                          label: (server) => server.name,
                          onTap: (server) => context
                              .read<ChatBrowserBloc>()
                              .add(ServerSelected(server)),
                          isLoading: state.isLoading,
                          createController: createServerController,
                          createLabel: 'Create server',
                          createActionLabel: 'Add',
                          onCreate: () => context.read<ChatBrowserBloc>().add(
                                CreateServerRequested(
                                    createServerController.text),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildListSection<Channel>(
                          title: 'Channels',
                          items: state.channels,
                          isSelected: (channel) =>
                              state.selectedChannel?.id == channel.id,
                          label: (channel) => channel.name,
                          onTap: (channel) => context
                              .read<ChatBrowserBloc>()
                              .add(ChannelSelected(channel)),
                          isLoading: state.isLoading,
                          createController: createChannelController,
                          createLabel: 'Create channel',
                          createActionLabel: 'Add',
                          onCreate: () => context.read<ChatBrowserBloc>().add(
                                CreateChannelRequested(
                                    createChannelController.text),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMessagesSection(
                          messages: state.messages,
                          createController: createMessageController,
                          isLoading: state.isLoading,
                          onCreate: () => context.read<ChatBrowserBloc>().add(
                                CreateMessageRequested(
                                    createMessageController.text),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildListSection<T>({
    required String title,
    required List<T> items,
    required bool Function(T item) isSelected,
    required String Function(T item) label,
    required void Function(T item) onTap,
    required bool isLoading,
    required TextEditingController createController,
    required String createLabel,
    required String createActionLabel,
    required VoidCallback onCreate,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: createController,
                    decoration: InputDecoration(labelText: createLabel),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isLoading ? null : onCreate,
                  child: Text(createActionLabel),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (BuildContext context, int index) {
                final item = items[index];
                return ListTile(
                  selected: isSelected(item),
                  title: Text(label(item)),
                  onTap: isLoading ? null : () => onTap(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesSection({
    required List<Message> messages,
    required TextEditingController createController,
    required bool isLoading,
    required VoidCallback onCreate,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(12),
            child:
                Text('Messages', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: createController,
                    decoration:
                        const InputDecoration(labelText: 'Send message'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isLoading ? null : onCreate,
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (BuildContext context, int index) {
                final message = messages[index];
                return ListTile(
                  title: Text(message.content),
                  subtitle: Text(message.authorSubject),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
