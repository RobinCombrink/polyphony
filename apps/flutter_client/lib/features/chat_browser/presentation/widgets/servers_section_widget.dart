import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/section_status.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

SectionStatus? buildServersSectionStatus(ServersState state) {
  if (state is ServersValidationFailedState) {
    return switch (state.issue) {
      ServersValidationIssue.serverNameRequired =>
        const SectionStatus(message: "Server name is required.", isError: true),
      ServersValidationIssue.serverSelectionRequired =>
        const SectionStatus(message: "Select a server first.", isError: true),
      ServersValidationIssue.userSubjectRequired => const SectionStatus(
          message: "User subject is required.",
          isError: true,
        ),
    };
  }

  if (state is ServersExceptionState) {
    return SectionStatus(
      message: "Server operation failed: ${state.error}",
      isError: true,
    );
  }

  if (state is ServersLoadedState && state.servers.isEmpty) {
    return const SectionStatus(
      message: "No servers found for this user.",
      isError: false,
    );
  }

  return null;
}

class ServersSectionWidget extends StatefulWidget {
  const ServersSectionWidget({
    required this.servers,
    required this.selectedServerId,
    required this.isLoading,
    required this.createController,
    required this.onTap,
    required this.onCreate,
    super.key,
  });

  final List<Server> servers;
  final String? selectedServerId;
  final bool isLoading;
  final TextEditingController createController;
  final void Function(Server server) onTap;
  final VoidCallback onCreate;

  @override
  State<ServersSectionWidget> createState() => _ServersSectionWidgetState();
}

class _ServersSectionWidgetState extends State<ServersSectionWidget> {
  var _isCreatingServer = false;

  void _openCreateServerInput() {
    setState(() {
      _isCreatingServer = true;
    });
  }

  void _submitCreateServer() {
    widget.onCreate();
    widget.createController.clear();

    setState(() {
      _isCreatingServer = false;
    });
  }

  void _cancelCreateServer() {
    widget.createController.clear();
    setState(() {
      _isCreatingServer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          if (_isCreatingServer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: widget.createController,
                autofocus: true,
                enabled: !widget.isLoading,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitCreateServer(),
                decoration: InputDecoration(
                  hintText: "Server",
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: "Cancel",
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: _cancelCreateServer,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: "Create server",
              onPressed: widget.isLoading ? null : _openCreateServerInput,
              icon: const Icon(Icons.add),
            ),
          const Divider(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: widget.servers.length,
              itemBuilder: (context, index) {
                final server = widget.servers[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Tooltip(
                    message: server.name,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap:
                          widget.isLoading ? null : () => widget.onTap(server),
                      child: CircleAvatar(
                        radius: 20,
                        child: Text(
                          server.name.isEmpty
                              ? "S"
                              : server.name.substring(0, 1).toUpperCase(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
