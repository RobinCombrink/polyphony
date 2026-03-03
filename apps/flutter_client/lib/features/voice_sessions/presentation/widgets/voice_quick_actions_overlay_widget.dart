import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_webrtc/flutter_webrtc.dart" as rtc;
import "package:livekit_client/livekit_client.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/voice_sessions/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/features/chat_browser/presentation/widgets/top_right_error_toast.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";

class VoiceQuickActionsOverlayWidget extends StatelessWidget {
  const VoiceQuickActionsOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServersBloc, ServersState>(
      builder: (context, serversState) {
        final selectedServerId = switch (serversState) {
          ServersLoadedDataState(:final selectedServerId) => selectedServerId,
          _ => null,
        };
        final selectedServerName = switch (serversState) {
          ServersLoadedDataState(:final servers) => servers
              .where((server) => server.id == selectedServerId)
              .map((server) => server.name)
              .firstOrNull,
          _ => null,
        };

        return BlocBuilder<ChannelsBloc, ChannelsState>(
          builder: (context, channelsState) {
            final selectedVoiceChannelId = switch (channelsState) {
              ChannelsLoadedDataState(:final selectedVoiceChannelId) =>
                selectedVoiceChannelId,
              _ => null,
            };
            final voiceChannels = switch (channelsState) {
              ChannelsLoadedDataState(:final voiceChannels) => voiceChannels,
              _ => const <VoiceChannel>[],
            };

            return BlocBuilder<VoiceSessionsBloc, VoiceSessionsState>(
              builder: (context, voiceState) {
                final loadedData = voiceState is VoiceSessionsLoadedDataState
                    ? voiceState
                    : null;
                final activeVoiceConnection = loadedData?.activeConnection;
                final isSelfMuted = loadedData?.isSelfMuted ?? false;
                final isSelfDeafened = loadedData?.isSelfDeafened ?? false;
                final isSelfScreenShareEnabled =
                    loadedData?.isSelfScreenShareEnabled ?? false;

                final connectedChannelId = activeVoiceConnection?.channelId;
                final hasConnectedChannel =
                    connectedChannelId != null && connectedChannelId.isNotEmpty;
                final isConnecting = !hasConnectedChannel &&
                    voiceState is VoiceSessionsLoadingState &&
                    selectedVoiceChannelId != null &&
                    selectedVoiceChannelId.isNotEmpty;

                if (!hasConnectedChannel && !isConnecting) {
                  return const SizedBox.shrink();
                }

                final contextualChannelId = hasConnectedChannel
                    ? connectedChannelId
                    : selectedVoiceChannelId;
                final contextualChannelName = voiceChannels
                    .where((channel) => channel.id == contextualChannelId)
                    .map((channel) => channel.name)
                    .firstOrNull;

                final connectionLocationText = contextualChannelName == null ||
                        contextualChannelName.isEmpty ||
                        selectedServerName == null ||
                        selectedServerName.isEmpty
                    ? null
                    : "$contextualChannelName / $selectedServerName";

                return Positioned(
                  left: 0,
                  bottom: 0,
                  child: _VoiceQuickActionsCard(
                    channelId: connectedChannelId,
                    connectionStatus: isConnecting
                        ? _VoiceConnectionStatus.connecting
                        : _VoiceConnectionStatus.connected,
                    connectionLocationText: connectionLocationText,
                    isSelfMuted: isSelfMuted,
                    isSelfDeafened: isSelfDeafened,
                    isSelfScreenShareEnabled: isSelfScreenShareEnabled,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

enum _VoiceConnectionStatus {
  connecting,
  connected,
}

class _VoiceQuickActionsCard extends StatelessWidget {
  const _VoiceQuickActionsCard({
    required this.channelId,
    required this.connectionStatus,
    required this.connectionLocationText,
    required this.isSelfMuted,
    required this.isSelfDeafened,
    required this.isSelfScreenShareEnabled,
  });

  final String? channelId;
  final _VoiceConnectionStatus connectionStatus;
  final String? connectionLocationText;
  final bool isSelfMuted;
  final bool isSelfDeafened;
  final bool isSelfScreenShareEnabled;

  Future<void> _onToggleScreenSharePressed(BuildContext context) async {
    try {
      final shouldEnable = !isSelfScreenShareEnabled;
      String? sourceId;

      if (shouldEnable && _isDesktopRuntime()) {
        final selectedSource = await showDialog<rtc.DesktopCapturerSource>(
          context: context,
          builder: (_) => ScreenSelectDialog(),
        );

        if (!context.mounted) {
          return;
        }

        if (selectedSource == null) {
          return;
        }

        sourceId = selectedSource.id;
      }

      context.read<VoiceSessionsBloc>().add(
            SetSelfScreenShareEnabledRequested(
              enabled: shouldEnable,
              sourceId: sourceId,
            ),
          );
    } on Exception catch (error) {
      if (context.mounted) {
        showTopRightErrorToast(
          context,
          "Failed to open screen source picker: $error",
        );
      }
    }
  }

  bool _isDesktopRuntime() {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final controlsEnabled =
        connectionStatus == _VoiceConnectionStatus.connected &&
            channelId != null &&
            channelId!.isNotEmpty;

    final (statusLabel, statusColor) = switch (connectionStatus) {
      _VoiceConnectionStatus.connecting => ("Connecting", Colors.yellow),
      _VoiceConnectionStatus.connected => ("Connected", Colors.green),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text("Voice · $statusLabel"),
              ],
            ),
            if (connectionLocationText != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                connectionLocationText!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (controlsEnabled) ...<Widget>[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    onPressed: () => context.read<VoiceSessionsBloc>().add(
                          DisconnectVoiceSessionRequested(
                              channelId: channelId!),
                        ),
                    tooltip: "Disconnect voice",
                    icon: const Icon(Icons.call_end),
                  ),
                  IconButton(
                    onPressed: () => context.read<VoiceSessionsBloc>().add(
                          SetSelfMutedRequested(muted: !isSelfMuted),
                        ),
                    tooltip: isSelfMuted ? "Unmute" : "Mute",
                    icon: Icon(isSelfMuted ? Icons.mic_off : Icons.mic),
                  ),
                  IconButton(
                    onPressed: () => context.read<VoiceSessionsBloc>().add(
                          SetSelfDeafenedRequested(deafened: !isSelfDeafened),
                        ),
                    tooltip: isSelfDeafened ? "Undeafen" : "Deafen",
                    icon: Icon(
                      isSelfDeafened ? Icons.headset_off : Icons.headset,
                    ),
                  ),
                  IconButton(
                    onPressed: () => unawaited(
                      _onToggleScreenSharePressed(context),
                    ),
                    tooltip: isSelfScreenShareEnabled
                        ? "Stop sharing screen"
                        : "Share your screen",
                    icon: Icon(
                      isSelfScreenShareEnabled
                          ? Icons.stop_screen_share
                          : Icons.screen_share,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
