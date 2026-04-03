import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_webrtc/flutter_webrtc.dart" as rtc;
import "package:livekit_client/livekit_client.dart";
import "package:polyphony_flutter_client/features/channels/bloc/channels_bloc.dart";
import "package:polyphony_flutter_client/features/servers/bloc/servers_bloc.dart";
import "package:polyphony_flutter_client/features/voice_sessions/bloc/voice_sessions_bloc.dart";
import "package:polyphony_flutter_client/shared/models/chat_models.dart";
import "package:polyphony_flutter_client/shared/models/entity_ids.dart";
import "package:polyphony_flutter_client/shared/presentation/widgets/top_right_error_toast.dart";

class VoiceQuickActionsOverlayWidget extends StatelessWidget {
  const VoiceQuickActionsOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServersBloc, ServersState>(
      builder: (context, serversState) {
        final selectedServerName = switch (serversState) {
          ServerSelected(:final servers, :final selectedServer) => servers
              .where((server) => server.id == selectedServer.id)
              .map((server) => server.name)
              .firstOrNull,
          _ => null,
        };

        return BlocBuilder<ChannelsBloc, ChannelsState>(
          builder: (context, channelsState) {
            final selectedVoiceChannelId = switch (channelsState) {
              VoiceChannelSelected(:final selectedVoiceChannel) =>
                selectedVoiceChannel.id,
              VoiceChannelSelectedValidationFailedState(
                :final selectedVoiceChannel,
              ) =>
                selectedVoiceChannel.id,
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
                final isEchoCancellationEnabled =
                    loadedData?.isEchoCancellationEnabled ?? true;
                final isNoiseSuppressionEnabled =
                    loadedData?.isNoiseSuppressionEnabled ?? true;
                final lifecycleIssue =
                    loadedData is VoiceSessionsLifecycleIssueState
                        ? loadedData.issue
                        : null;

                final connectedChannelId = activeVoiceConnection?.channelId;
                final hasConnectedChannel = connectedChannelId != null &&
                    connectedChannelId.value.isNotEmpty;
                final loadingState =
                    voiceState is VoiceSessionsLoadingState ? voiceState : null;
                final isConnecting = !hasConnectedChannel &&
                    loadingState?.operation ==
                        VoiceSessionsLoadingOperation.connecting &&
                    selectedVoiceChannelId != null &&
                    selectedVoiceChannelId.value.isNotEmpty;
                final isReconnecting = !hasConnectedChannel &&
                    loadingState?.operation ==
                        VoiceSessionsLoadingOperation.reconnecting;

                if (!hasConnectedChannel &&
                    !isConnecting &&
                    !isReconnecting &&
                    lifecycleIssue == null) {
                  return const SizedBox.shrink();
                }

                final contextualChannelId = hasConnectedChannel
                    ? connectedChannelId
                    : (loadingState?.channelId ??
                        loadedData?.selectedChannelId ??
                        selectedVoiceChannelId);
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
                    connectedChannelId: connectedChannelId,
                    actionChannelId: contextualChannelId,
                    connectionStatus: switch (lifecycleIssue) {
                      VoiceSessionsLifecycleIssue.reconnectRequired =>
                        _VoiceConnectionStatus.reconnectRequired,
                      VoiceSessionsLifecycleIssue.tokenExpired =>
                        _VoiceConnectionStatus.tokenExpired,
                      VoiceSessionsLifecycleIssue.channelForbidden =>
                        _VoiceConnectionStatus.channelForbidden,
                      null => isReconnecting
                          ? _VoiceConnectionStatus.reconnecting
                          : (isConnecting
                              ? _VoiceConnectionStatus.connecting
                              : _VoiceConnectionStatus.connected),
                    },
                    connectionLocationText: connectionLocationText,
                    isSelfMuted: isSelfMuted,
                    isSelfDeafened: isSelfDeafened,
                    isSelfScreenShareEnabled: isSelfScreenShareEnabled,
                    isEchoCancellationEnabled: isEchoCancellationEnabled,
                    isNoiseSuppressionEnabled: isNoiseSuppressionEnabled,
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
  reconnecting,
  reconnectRequired,
  tokenExpired,
  channelForbidden,
  connected,
}

class _VoiceQuickActionsCard extends StatelessWidget {
  const _VoiceQuickActionsCard({
    required this.connectedChannelId,
    required this.actionChannelId,
    required this.connectionStatus,
    required this.connectionLocationText,
    required this.isSelfMuted,
    required this.isSelfDeafened,
    required this.isSelfScreenShareEnabled,
    required this.isEchoCancellationEnabled,
    required this.isNoiseSuppressionEnabled,
  });

  final ChannelId? connectedChannelId;
  final ChannelId? actionChannelId;
  final _VoiceConnectionStatus connectionStatus;
  final String? connectionLocationText;
  final bool isSelfMuted;
  final bool isSelfDeafened;
  final bool isSelfScreenShareEnabled;
  final bool isEchoCancellationEnabled;
  final bool isNoiseSuppressionEnabled;

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
            connectedChannelId != null &&
            connectedChannelId!.value.isNotEmpty;

    final reconnectEnabled =
        connectionStatus == _VoiceConnectionStatus.reconnectRequired &&
            actionChannelId != null &&
            actionChannelId!.value.isNotEmpty;

    final colorScheme = Theme.of(context).colorScheme;
    final (statusLabel, statusColor) = switch (connectionStatus) {
      _VoiceConnectionStatus.connecting => (
          "Connecting",
          colorScheme.secondary
        ),
      _VoiceConnectionStatus.reconnecting => (
          "Reconnecting",
          colorScheme.secondary
        ),
      _VoiceConnectionStatus.reconnectRequired => (
          "Reconnect needed",
          colorScheme.error
        ),
      _VoiceConnectionStatus.tokenExpired => (
          "Session expired",
          colorScheme.error
        ),
      _VoiceConnectionStatus.channelForbidden => (
          "Channel unavailable",
          colorScheme.error
        ),
      _VoiceConnectionStatus.connected => ("Connected", colorScheme.primary),
    };
    final statusDetailText = switch (connectionStatus) {
      _VoiceConnectionStatus.connecting => "Joining voice channel...",
      _VoiceConnectionStatus.reconnecting =>
        "Trying to restore your voice connection.",
      _VoiceConnectionStatus.reconnectRequired =>
        "Connection dropped. Tap reconnect to rejoin.",
      _VoiceConnectionStatus.tokenExpired =>
        "Authentication expired. Sign in again to use voice.",
      _VoiceConnectionStatus.channelForbidden =>
        "You no longer have access to this channel.",
      _VoiceConnectionStatus.connected => null,
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
            if (statusDetailText != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                statusDetailText,
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
                              channelId: connectedChannelId!),
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
                  IconButton(
                    onPressed: () => context.read<VoiceSessionsBloc>().add(
                          SetEchoCancellationEnabledRequested(
                            enabled: !isEchoCancellationEnabled,
                          ),
                        ),
                    tooltip: isEchoCancellationEnabled
                        ? "Disable echo cancellation"
                        : "Enable echo cancellation",
                    icon: Icon(
                      isEchoCancellationEnabled
                          ? Icons.hearing
                          : Icons.hearing_disabled,
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.read<VoiceSessionsBloc>().add(
                          SetNoiseSuppressionEnabledRequested(
                            enabled: !isNoiseSuppressionEnabled,
                          ),
                        ),
                    tooltip: isNoiseSuppressionEnabled
                        ? "Disable noise suppression"
                        : "Enable noise suppression",
                    icon: Icon(
                      isNoiseSuppressionEnabled
                          ? Icons.noise_aware
                          : Icons.surround_sound,
                    ),
                  ),
                ],
              ),
            ] else if (reconnectEnabled) ...<Widget>[
              const SizedBox(height: 4),
              FilledButton.tonalIcon(
                onPressed: () => context.read<VoiceSessionsBloc>().add(
                      ConnectVoiceSessionRequested(channelId: actionChannelId!),
                    ),
                icon: const Icon(Icons.refresh),
                label: const Text("Reconnect"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
