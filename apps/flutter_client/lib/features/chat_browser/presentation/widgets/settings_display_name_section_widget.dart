import "package:flutter/material.dart";

class SettingsDisplayNameSectionWidget extends StatefulWidget {
  const SettingsDisplayNameSectionWidget({
    required this.initialDisplayName,
    required this.onSaveDisplayName,
    super.key,
  });

  final String? initialDisplayName;
  final ValueChanged<String> onSaveDisplayName;

  @override
  State<SettingsDisplayNameSectionWidget> createState() =>
      _SettingsDisplayNameSectionWidgetState();
}

class _SettingsDisplayNameSectionWidgetState
    extends State<SettingsDisplayNameSectionWidget> {
  late final TextEditingController _displayNameController;

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.initialDisplayName ?? "");
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _saveDisplayName() {
    widget.onSaveDisplayName(_displayNameController.text);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Display name updated")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          "Display name",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _displayNameController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveDisplayName(),
          decoration: const InputDecoration(
            labelText: "Display name",
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _saveDisplayName,
            child: const Text("Save"),
          ),
        ),
      ],
    );
  }
}
