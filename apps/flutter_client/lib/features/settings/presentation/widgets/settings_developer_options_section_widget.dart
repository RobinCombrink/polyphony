import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";

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
      const SnackBar(content: Text("Token copied")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          "Developer options",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Enable developer options"),
          value: _developerOptionsEnabled,
          onChanged: (value) {
            setState(() {
              _developerOptionsEnabled = value;
            });
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _developerOptionsEnabled && widget.bearerToken.isNotEmpty
                ? () => unawaited(_copyToken())
                : null,
            child: const Text("Copy token"),
          ),
        ),
        if (_developerOptionsEnabled) ...<Widget>[
          const SizedBox(height: 16),
          Text(
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
        ],
      ],
    );
  }
}
