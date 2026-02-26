import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/list_section_widget.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/section_status.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

SectionStatus? buildServersSectionStatus(ServersState state) {
  if (state is ServersValidationFailedState) {
    return switch (state.issue) {
      ServersValidationIssue.serverNameRequired =>
        const SectionStatus(message: "Server name is required.", isError: true),
    };
  }

  if (state is ServersExceptionState) {
    return SectionStatus(
      message: "Server operation failed: ${state.error}",
      isError: true,
    );
  }

  if (state.servers.isEmpty) {
    return const SectionStatus(
      message: "No servers found for this user.",
      isError: false,
    );
  }

  return null;
}

class ServersSectionWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ListSectionWidget<Server>(
      title: "Servers",
      items: servers,
      isSelected: (server) => selectedServerId == server.id,
      label: (server) => server.name,
      onTap: onTap,
      isLoading: isLoading,
      createController: createController,
      createLabel: "Create server",
      createActionLabel: "Add",
      onCreate: onCreate,
    );
  }
}
