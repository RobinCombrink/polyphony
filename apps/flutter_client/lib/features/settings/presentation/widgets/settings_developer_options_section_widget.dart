import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

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
      ],
    );
  }
}
