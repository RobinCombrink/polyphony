import "package:flutter/material.dart";
import "package:polyphony_flutter_client/features/chat_browser/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/section_status.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

SectionStatus? buildVoiceChannelsSectionStatus(VoiceSessionsState state) {
  if (state is VoiceSessionsValidationFailedState) {
    return const SectionStatus(
      message: "Select a channel first.",
      isError: true,
    );
  }

  if (state is VoiceSessionsExceptionState) {
    return SectionStatus(
      message: "Voice operation failed: ${state.error}",
      isError: true,
    );
  }

  return null;
}

class VoiceChannelsSectionWidget extends StatelessWidget {
  const VoiceChannelsSectionWidget({
    required this.activeConnection,
    required this.isLoading,
    required this.onConnect,
    required this.onDisconnect,
    super.key,
  });

  final VoiceConnectSession? activeConnection;
  final bool isLoading;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              "Voice",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: isLoading ? null : onConnect,
                  child: const Text("Connect"),
                ),
                FilledButton.tonal(
                  onPressed: isLoading ? null : onDisconnect,
                  child: const Text("Disconnect"),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: <Widget>[
                if (activeConnection == null)
                  const ListTile(
                    leading: Icon(Icons.mic_off),
                    title: Text("No active voice connection"),
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.mic),
                    title: Text(activeConnection!.participantSubject),
                    subtitle: Text("Channel ${activeConnection!.channelId}"),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
