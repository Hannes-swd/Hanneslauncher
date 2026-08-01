import 'package:flutter/material.dart';

import 'app_strings.dart';

/// Single-field prompt (rename an app, change a web app's address, ...).
/// Pops the entered text, or null when cancelled.
///
/// Stateful so it owns its text controller: disposing one from the caller
/// right after `showDialog` returns would tear it down while the dialog is
/// still playing its exit animation, which then rebuilds the field and
/// throws "A TextEditingController was used after being disposed".
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.label,
    required this.initialValue,
    required this.s,
  });

  final String title;
  final String label;
  final String initialValue;
  final AppStrings s;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _field = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _field,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: Text(widget.s.save),
        ),
      ],
    );
  }
}
