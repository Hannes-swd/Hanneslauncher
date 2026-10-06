import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'charging_animation_controller.dart';
import 'charging_animation_presets.dart';
import 'design_tokens.dart';
import 'locale_controller.dart';

/// Preview level: a made-up 75 % so the animations that show the battery
/// have something to show.
const _previewLevel = 75;

class ChargingAnimationSettingsScreen extends StatelessWidget {
  const ChargingAnimationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        final en = language == AppLanguage.en;
        final controller = ChargingAnimationController.instance;
        return ValueListenableBuilder<ChargingAnimationSettings>(
          valueListenable: controller,
          builder: (context, settings, child) {
            Widget tile({
              required String id,
              required String name,
              required String html,
              required VoidCallback onEdit,
              required IconData editIcon,
              required String editTooltip,
            }) {
              final selected = settings.selectedId == id;
              return ListTile(
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(name),
                onTap: () => controller.update(settings.copyWith(selectedId: id)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: s.chargingAnimationPreview,
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () =>
                          controller.play(html: html, level: _previewLevel),
                    ),
                    IconButton(
                      tooltip: editTooltip,
                      icon: Icon(editIcon),
                      onPressed: onEdit,
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(title: Text(s.chargingAnimation)),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () =>
                    _edit(context, name: s.chargingAnimationNew,
                        html: chargingAnimationTemplate),
                icon: const Icon(Icons.add),
                label: Text(s.chargingAnimationNew),
              ),
              body: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  SwitchListTile(
                    title: Text(s.chargingAnimationEnabled),
                    subtitle: Text(s.chargingAnimationHint),
                    value: settings.enabled,
                    onChanged: (on) =>
                        controller.update(settings.copyWith(enabled: on)),
                  ),
                  ListTile(
                    title: Text(
                      s.chargingAnimationDuration(settings.durationMs / 1000),
                    ),
                    subtitle: Slider(
                      min: minChargingDurationMs.toDouble(),
                      max: maxChargingDurationMs.toDouble(),
                      divisions:
                          (maxChargingDurationMs - minChargingDurationMs) ~/
                          250,
                      value: settings.durationMs.toDouble(),
                      onChanged: (v) => controller.update(
                        settings.copyWith(durationMs: v.round()),
                      ),
                    ),
                  ),
                  _header(context, s.chargingAnimationPresets),
                  for (final preset in chargingAnimationPresets)
                    tile(
                      id: preset.id,
                      name: preset.name(en),
                      html: preset.html,
                      editIcon: Icons.copy,
                      editTooltip: s.chargingAnimationCopy,
                      onEdit: () => _edit(
                        context,
                        name: preset.name(en),
                        html: preset.html,
                      ),
                    ),
                  if (settings.custom.isNotEmpty)
                    _header(context, s.chargingAnimationOwn),
                  for (final animation in settings.custom)
                    tile(
                      id: animation.id,
                      name: animation.name,
                      html: animation.html,
                      editIcon: Icons.edit,
                      editTooltip: s.chargingAnimationOwn,
                      onEdit: () => _edit(
                        context,
                        id: animation.id,
                        name: animation.name,
                        html: animation.html,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      text,
      style: TextStyle(
        color: context.design.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  /// Without an [id] this makes a new animation (from scratch or as a copy
  /// of a preset), which is how a preset gets edited without being changed.
  void _edit(
    BuildContext context, {
    String? id,
    required String name,
    required String html,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ChargingAnimationEditorScreen(id: id, name: name, html: html),
      ),
    );
  }
}

class ChargingAnimationEditorScreen extends StatefulWidget {
  const ChargingAnimationEditorScreen({
    super.key,
    this.id,
    required this.name,
    required this.html,
  });

  final String? id;
  final String name;
  final String html;

  @override
  State<ChargingAnimationEditorScreen> createState() =>
      _ChargingAnimationEditorScreenState();
}

class _ChargingAnimationEditorScreenState
    extends State<ChargingAnimationEditorScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.name,
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.html,
  );

  /// Set on the first save of a new one, so saving twice doesn't make two.
  late String? _id = widget.id;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final controller = ChargingAnimationController.instance;
    final settings = controller.value;
    final id = _id ?? 'own:${DateTime.now().microsecondsSinceEpoch}';
    final animation = CustomChargingAnimation(
      id: id,
      name: _name.text.trim(),
      html: _code.text,
    );
    final custom = [...settings.custom];
    final index = custom.indexWhere((a) => a.id == id);
    if (index >= 0) {
      custom[index] = animation;
    } else {
      custom.add(animation);
    }
    // A freshly made animation is almost always the one wanted next.
    await controller.update(
      settings.copyWith(
        custom: custom,
        selectedId: _id == null ? id : null,
      ),
    );
    _id = id;
  }

  Future<void> _delete() async {
    final controller = ChargingAnimationController.instance;
    final settings = controller.value;
    await controller.update(
      settings.copyWith(
        custom: [
          for (final a in settings.custom)
            if (a.id != _id) a,
        ],
        selectedId: settings.selectedId == _id
            ? chargingAnimationPresets.first.id
            : null,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(LocaleController.instance.value);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.chargingAnimation),
        actions: [
          IconButton(
            tooltip: s.chargingAnimationPreview,
            icon: const Icon(Icons.play_arrow),
            onPressed: () => ChargingAnimationController.instance.play(
              html: _code.text,
              level: _previewLevel,
            ),
          ),
          if (_id != null)
            IconButton(
              tooltip: s.chargingAnimationDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              await _save();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: s.codeWidgetName),
          ),
          const SizedBox(height: 12),
          Text(
            s.chargingAnimationCodeHelp,
            style: TextStyle(color: context.design.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            maxLines: null,
            minLines: 16,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }
}
