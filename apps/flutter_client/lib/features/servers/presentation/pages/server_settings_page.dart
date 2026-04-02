import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

class ServerSettingsPage extends StatefulWidget {
  const ServerSettingsPage({
    required this.server,
    super.key,
  });

  final Server server;

  @override
  State<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends State<ServerSettingsPage> {
  late final TextEditingController _nameController;
  var _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.server.name);
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final hasChanges = _nameController.text.trim().isNotEmpty &&
        _nameController.text.trim() != widget.server.name;

    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  void _saveServerName() {
    final trimmedName = _nameController.text.trim();

    if (trimmedName.isEmpty || trimmedName == widget.server.name) {
      return;
    }

    context.read<ServersBloc>().add(
          UpdateServerNameRequested(
            serverId: widget.server.id,
            name: trimmedName,
          ),
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Server settings"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "General",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (_hasChanges) {
                          _saveServerName();
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: "Server name",
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _hasChanges ? _saveServerName : null,
                        child: const Text("Save"),
                      ),
                    ),
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
