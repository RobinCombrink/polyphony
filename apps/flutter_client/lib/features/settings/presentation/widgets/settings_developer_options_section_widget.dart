import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:polyphony_flutter_client/features/settings/bloc/settings_developer_profile_bloc.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";

class SettingsDeveloperOptionsSectionWidget extends StatefulWidget {
  const SettingsDeveloperOptionsSectionWidget({
    required this.bearerToken,
    super.key,
  });

  final String bearerToken;

  @override
  State<SettingsDeveloperOptionsSectionWidget> createState() =>
      _SettingsDeveloperOptionsSectionWidgetState();
}

class _SettingsDeveloperOptionsSectionWidgetState
    extends State<SettingsDeveloperOptionsSectionWidget> {
  var _developerOptionsEnabled = false;

  Map<String, String> get _configValues => const <String, String>{
        "POLYPHONY_BACKEND_BASE_URL": PolyphonyConfig.backendBaseUrl,
        "AUTH0_DOMAIN": PolyphonyConfig.auth0Domain,
        "AUTH0_NATIVE_CLIENT_ID": PolyphonyConfig.auth0NativeClientId,
        "AUTH0_WEB_CLIENT_ID": PolyphonyConfig.auth0WebClientId,
        "AUTH0_AUDIENCE": PolyphonyConfig.auth0Audience,
        "AUTH0_SCOPES": PolyphonyConfig.auth0Scopes,
        "AUTH0_MOBILE_REDIRECT_URI": PolyphonyConfig.auth0MobileRedirectUri,
        "AUTH0_DESKTOP_REDIRECT_URI": PolyphonyConfig.auth0DesktopRedirectUri,
      };

  Future<void> _copyToken() async {
    await Clipboard.setData(ClipboardData(text: widget.bearerToken));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: SelectableText("Token copied")),
    );
  }

  void _loadMe() {
    context.read<SettingsDeveloperProfileBloc>().add(
          const SettingsDeveloperProfileLoadRequested(),
        );
  }

  List<String> _meLines(SettingsDeveloperProfileLoadedState state) {
    final displayName = state.me.displayName;

    return <String>[
      "user_id: ${state.me.userId}",
      "display_name: ${displayName ?? "<null>"}",
      "issuer: ${state.me.issuer}",
    ];
  }

  String _describeLoadMeError(Exception error) {
    if (error
        case ApiRequestException(:final statusCode, :final responseBody)) {
      final compactBody = responseBody.replaceAll(RegExp(r"\s+"), " ").trim();
      final preview = compactBody.length > 180
          ? "${compactBody.substring(0, 180)}..."
          : compactBody;

      return "Failed to load /me (HTTP $statusCode)${preview.isEmpty ? "" : ": $preview"}";
    }

    return "Failed to load /me: $error";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SelectableText(
          "Developer options",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const SelectableText("Enable developer options"),
          value: _developerOptionsEnabled,
          onChanged: (value) {
            setState(() {
              _developerOptionsEnabled = value;
            });

            if (value) {
              _loadMe();
            }
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _developerOptionsEnabled && widget.bearerToken.isNotEmpty
                ? () => unawaited(_copyToken())
                : null,
            child: const SelectableText("Copy token"),
          ),
        ),
        if (_developerOptionsEnabled) ...<Widget>[
          const SizedBox(height: 16),
          SelectableText(
            "Configuration",
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ..._configValues.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText("${entry.key}: ${entry.value}"),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: SelectableText(
                  "/me response",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: _loadMe,
                child: const SelectableText("Refresh /me"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BlocBuilder<SettingsDeveloperProfileBloc,
              SettingsDeveloperProfileState>(
            builder: (context, state) {
              return switch (state) {
                SettingsDeveloperProfileLoadedState() => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _meLines(state)
                        .map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SelectableText(line),
                          ),
                        )
                        .toList(growable: false),
                  ),
                SettingsDeveloperProfileExceptionState(:final error) =>
                  SelectableText(_describeLoadMeError(error)),
                SettingsDeveloperProfileLoadingState() => const Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                SettingsDeveloperProfileInitialState() => const SelectableText(
                    "Tap \"Refresh /me\" to load current profile data.",
                  ),
              };
            },
          ),
        ],
      ],
    );
  }
}
