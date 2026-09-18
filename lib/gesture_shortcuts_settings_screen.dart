import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'color_swatch_picker.dart';
import 'design_tokens.dart';
import 'design_widgets.dart';
import 'gesture_action.dart';
import 'gesture_draw_screen.dart';
import 'gesture_shortcuts_controller.dart';
import 'gesture_stroke.dart';
import 'gesture_stroke_view.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'text_prompt_dialog.dart';

/// The saved shapes: what each one looks like, what it does, and the one
/// switch that decides whether the home screen watches for them at all.
class GestureShortcutsSettingsScreen extends StatelessWidget {
  const GestureShortcutsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocaleController.instance,
        GestureShortcutsController.instance,
        GestureDrawingController.instance,
        // The action line under each shape names the app it opens, which a
        // rename or an uninstall changes.
        LauncherEntriesController.instance,
      ]),
      builder: (context, child) {
        final s = AppStrings(LocaleController.instance.value);
        final shortcuts = GestureShortcutsController.instance.value;
        return Scaffold(
          appBar: AppBar(title: Text(s.gestureShortcuts)),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addShortcut(context, s),
            icon: const Icon(Icons.gesture),
            label: Text(s.gestureAdd),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _DrawingSwitch(s: s),
              const Divider(height: 24),
              SettingsHeading(s.gestureSavedShapes),
              if (shortcuts.isEmpty)
                Padding(
                  padding: EdgeInsets.all(context.design.spaceMd),
                  child: Text(
                    s.gestureNoShortcuts,
                    style: TextStyle(color: context.design.textSecondary),
                  ),
                )
              else
                for (final shortcut in shortcuts)
                  _ShortcutRow(shortcut: shortcut, s: s),
            ],
          ),
        );
      },
    );
  }
}

/// Whether the home screen watches for shapes at all, whether the line is
/// drawn while one is being made, and in what colour.
///
/// Switching the whole thing off keeps every shape, and is the way out when
/// the drawing gets in the way rather than helping.
class _DrawingSwitch extends StatelessWidget {
  const _DrawingSwitch({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final controller = GestureDrawingController.instance;
    final settings = controller.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: settings.enabled,
          onChanged: (enabled) =>
              controller.update(settings.copyWith(enabled: enabled)),
          title: Text(s.gestureDrawingEnabled),
          subtitle: Text(s.gestureDrawingEnabledHint),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            design.spaceMd,
            0,
            design.spaceMd,
            design.spaceSm,
          ),
          child: Text(
            s.gestureHomeHint,
            style: TextStyle(
              fontSize: design.typeLabel,
              color: design.textSecondary,
            ),
          ),
        ),
        // Both of these only say something while shapes are being watched
        // for at all - a line that is never drawn has no colour worth
        // picking.
        if (settings.enabled) ...[
          SwitchListTile(
            value: settings.showTrail,
            onChanged: (show) =>
                controller.update(settings.copyWith(showTrail: show)),
            title: Text(s.gestureShowTrail),
            subtitle: Text(s.gestureShowTrailHint),
            secondary: _TrailPreview(settings: settings),
          ),
          if (settings.showTrail)
            Padding(
              padding: design.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(s.gestureTrailColor),
                  ColorSwatchPicker(
                    s: s,
                    selectedIndex: settings.colorIndex,
                    // The first swatch is "whatever the design is using",
                    // which is where this starts out - without it there
                    // would be no way back to following the theme once a
                    // colour had been picked once.
                    autoColor: design.accent,
                    onSelected: (index) =>
                        controller.update(settings.copyWith(colorIndex: index)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// A scrap of a stroke in the chosen colour, next to the switch that turns
/// it on - so the pick is visible as a line rather than only as a dot in the
/// palette, which is the shape it actually takes on the home screen.
class _TrailPreview extends StatelessWidget {
  const _TrailPreview({required this.settings});

  final GestureDrawingSettings settings;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return SizedBox(
      width: 40,
      height: 40,
      child: settings.showTrail
          ? CustomPaint(
              painter: StrokePainter(
                points: _squiggle,
                color: settings.fixedColor ?? design.accent,
                width: 3,
                showStart: false,
              ),
            )
          : Icon(Icons.visibility_off_outlined, color: design.textMuted),
    );
  }

  /// A short wave rather than a straight line: it has to read as something
  /// drawn by a finger at 40 pixels across.
  static const List<Offset> _squiggle = [
    Offset(0, 14),
    Offset(6, 4),
    Offset(12, 0),
    Offset(18, 6),
    Offset(22, 16),
    Offset(28, 22),
    Offset(34, 18),
    Offset(40, 8),
  ];
}

/// One saved shape: what it looks like, what it does, and whether it is
/// being watched for.
class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.shortcut, required this.s});

  final GestureShortcut shortcut;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    // Two shapes that look alike to the recognizer will keep cancelling each
    // other out on the home screen (see StrokeVerdict.ambiguous), and there
    // is no way to tell from the home screen that this is why nothing
    // happened - so it is said here, where it can still be fixed.
    final closest = GestureShortcutsController.instance.closestTo(
      shortcut.stroke,
      skipId: shortcut.id,
    );
    final clashes = closest != null && closest.score >= similarShapeScore;

    return ListTile(
      leading: GestureStrokeThumbnail(
        stroke: shortcut.stroke,
        dimmed: !shortcut.enabled,
      ),
      title: Text(shortcut.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                gestureActionIcon(shortcut.action.kind),
                size: design.typeLabel,
                color: design.textSecondary,
              ),
              SizedBox(width: design.space2xs),
              Expanded(
                child: Text(
                  shortcut.action.describe(s),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (clashes)
            Text(
              s.gestureLooksLike(closest.shortcut.name),
              style: TextStyle(
                fontSize: design.typeCaption,
                color: design.danger,
              ),
            ),
        ],
      ),
      trailing: Switch(
        value: shortcut.enabled,
        onChanged: (enabled) => GestureShortcutsController.instance.update(
          shortcut.id,
          enabled: enabled,
        ),
      ),
      onTap: () => _editShortcut(context, shortcut, s),
    );
  }
}

/// Draw, say what it should do, name it. In that order, because the shape is
/// the part that needs a blank screen and full attention.
Future<void> _addShortcut(BuildContext context, AppStrings s) async {
  if (GestureShortcutsController.instance.isFull) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.gestureShortcutsFull(GestureShortcutsController.maxShortcuts),
        ),
      ),
    );
    return;
  }

  final stroke = await drawGestureStroke(context);
  if (stroke == null || !context.mounted) return;
  if (!await _confirmShapeIsDistinct(context, stroke, s, skipId: null)) return;
  if (!context.mounted) return;

  final action = await pickGestureAction(context, s);
  if (action == null || !context.mounted) return;

  final name = await showDialog<String>(
    context: context,
    builder: (context) => TextPromptDialog(
      title: s.gestureNameTitle,
      label: s.nameLabel,
      initialValue: action.describe(s),
      s: s,
    ),
  );
  if (name == null || name.trim().isEmpty) return;

  await GestureShortcutsController.instance.add(
    name: name,
    stroke: stroke,
    action: action,
  );
}

Future<void> _editShortcut(
  BuildContext context,
  GestureShortcut shortcut,
  AppStrings s,
) async {
  final choice = await showModalBottomSheet<_ShortcutEdit>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(context.design.spaceMd),
            child: Row(
              children: [
                GestureStrokeThumbnail(stroke: shortcut.stroke, size: 64),
                SizedBox(width: context.design.spaceMd),
                Expanded(
                  child: Text(
                    shortcut.name,
                    style: context.design.textStyle(TypeRole.heading),
                  ),
                ),
              ],
            ),
          ),
          for (final edit in _ShortcutEdit.values)
            ListTile(
              leading: Icon(edit.icon),
              title: Text(edit.label(s)),
              onTap: () => Navigator.of(context).pop(edit),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  final controller = GestureShortcutsController.instance;
  switch (choice) {
    case _ShortcutEdit.rename:
      final name = await showDialog<String>(
        context: context,
        builder: (context) => TextPromptDialog(
          title: s.gestureNameTitle,
          label: s.nameLabel,
          initialValue: shortcut.name,
          s: s,
        ),
      );
      if (name == null || name.trim().isEmpty) return;
      await controller.update(shortcut.id, name: name);

    case _ShortcutEdit.redraw:
      final stroke = await drawGestureStroke(context, initial: shortcut.stroke);
      if (stroke == null || !context.mounted) return;
      if (!await _confirmShapeIsDistinct(
        context,
        stroke,
        s,
        skipId: shortcut.id,
      )) {
        return;
      }
      await controller.update(shortcut.id, stroke: stroke);

    case _ShortcutEdit.action:
      final action = await pickGestureAction(
        context,
        s,
        initial: shortcut.action,
      );
      if (action == null) return;
      await controller.update(shortcut.id, action: action);

    case _ShortcutEdit.delete:
      await controller.remove(shortcut.id);
  }
}

enum _ShortcutEdit { rename, redraw, action, delete }

extension on _ShortcutEdit {
  IconData get icon => switch (this) {
    _ShortcutEdit.rename => Icons.edit_outlined,
    _ShortcutEdit.redraw => Icons.gesture,
    _ShortcutEdit.action => Icons.bolt_outlined,
    _ShortcutEdit.delete => Icons.delete_outline,
  };

  String label(AppStrings s) => switch (this) {
    _ShortcutEdit.rename => s.changeName,
    _ShortcutEdit.redraw => s.gestureRedraw,
    _ShortcutEdit.action => s.gestureChangeAction,
    _ShortcutEdit.delete => s.gestureDelete,
  };
}

/// Asks before saving a shape that looks like one already saved. Answering
/// "save anyway" is allowed on purpose - the two may well be told apart
/// perfectly well in practice, and this is a warning, not a rule.
Future<bool> _confirmShapeIsDistinct(
  BuildContext context,
  GestureStroke stroke,
  AppStrings s, {
  required String? skipId,
}) async {
  final closest = GestureShortcutsController.instance.closestTo(
    stroke,
    skipId: skipId,
  );
  if (closest == null || closest.score < similarShapeScore) return true;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(s.gestureTooSimilarTitle),
      content: Text(s.gestureTooSimilarBody(closest.shortcut.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.gestureDrawAgain),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(s.gestureSaveAnyway),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

// --- picking what a shape does ---------------------------------------------

/// The second step: what should happen. Comes back with the finished action,
/// or null if it was left without picking one.
Future<GestureAction?> pickGestureAction(
  BuildContext context,
  AppStrings s, {
  GestureAction? initial,
}) {
  return Navigator.of(context).push<GestureAction>(
    MaterialPageRoute(
      builder: (context) => _ActionKindScreen(initial: initial),
    ),
  );
}

class _ActionKindScreen extends StatelessWidget {
  const _ActionKindScreen({this.initial});

  final GestureAction? initial;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(LocaleController.instance.value);
    final design = context.design;
    return Scaffold(
      appBar: AppBar(title: Text(s.gestureWhatHappens)),
      body: ListView(
        children: [
          for (final kind in GestureActionKind.values)
            ListTile(
              leading: Icon(
                gestureActionIcon(kind),
                color: kind == initial?.kind ? design.accent : null,
              ),
              title: Text(gestureActionKindLabel(kind, s)),
              subtitle: Text(gestureActionKindHint(kind, s)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickTarget(context, kind, s, initial),
            ),
        ],
      ),
    );
  }

  /// Each kind needs a different second question - or, for the settings
  /// panel, none at all. Whatever comes back is popped all the way out to
  /// the caller of [pickGestureAction].
  Future<void> _pickTarget(
    BuildContext context,
    GestureActionKind kind,
    AppStrings s,
    GestureAction? initial,
  ) async {
    // Only carried over when the kind hasn't changed - a package name is not
    // a starting point for an address.
    final previous = initial?.kind == kind ? initial : null;
    final GestureAction? action;
    switch (kind) {
      case GestureActionKind.entry:
        final key = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (context) => const _EntryPickerScreen()),
        );
        action = key == null
            ? null
            : GestureAction(kind: kind, target: key);

      case GestureActionKind.address:
        if (!context.mounted) return;
        final url = await showDialog<String>(
          context: context,
          builder: (context) => TextPromptDialog(
            title: s.gestureActionKindAddress,
            label: s.urlLabel,
            initialValue: previous?.target ?? '',
            s: s,
          ),
        );
        action = url == null || url.trim().isEmpty
            ? null
            : GestureAction(kind: kind, target: url.trim());

      case GestureActionKind.timer:
        if (!context.mounted) return;
        final seconds = await showDialog<int>(
          context: context,
          builder: (context) =>
              _TimerLengthDialog(initialSeconds: previous?.seconds ?? 300),
        );
        action = seconds == null || seconds <= 0
            ? null
            : GestureAction(kind: kind, seconds: seconds);

      case GestureActionKind.settings:
        action = const GestureAction(kind: GestureActionKind.settings);
    }
    if (action == null || !context.mounted) return;
    Navigator.of(context).pop(action);
  }
}

/// Everything the app list can show, in the order the pinned apps screen
/// uses it: the handful of folders, web apps and built-ins first, the
/// hundreds of packages after them.
class _EntryPickerScreen extends StatefulWidget {
  const _EntryPickerScreen();

  @override
  State<_EntryPickerScreen> createState() => _EntryPickerScreenState();
}

class _EntryPickerScreenState extends State<_EntryPickerScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    LauncherEntriesController.instance.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<LauncherEntry> _entries() {
    final all = LauncherEntriesController.instance.entries;
    final query = _search.text.trim().toLowerCase();
    final matching = [
      for (final entry in all)
        if (query.isEmpty || entry.name.toLowerCase().contains(query)) entry,
    ];
    return [
      for (final entry in matching)
        if (entry.isFolder) entry,
      for (final entry in matching)
        if (entry.isWebApp) entry,
      for (final entry in matching)
        if (entry.isBuiltIn) entry,
      for (final entry in matching)
        if (!entry.isFolder && !entry.isWebApp && !entry.isBuiltIn) entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(LocaleController.instance.value);
    return ListenableBuilder(
      listenable: LauncherEntriesController.instance,
      builder: (context, child) {
        final entries = _entries();
        return Scaffold(
          appBar: AppBar(title: Text(s.whichApp)),
          body: !LauncherEntriesController.instance.isLoaded
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: s.searchApps,
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return ListTile(
                            leading: AppIcon(entry: entry, size: 36),
                            title: Text(entry.name),
                            onTap: () =>
                                Navigator.of(context).pop(entry.key),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// How long the countdown runs. The presets are the ones a kitchen timer has
/// on its face; anything else is typed in as minutes.
class _TimerLengthDialog extends StatefulWidget {
  const _TimerLengthDialog({required this.initialSeconds});

  final int initialSeconds;

  @override
  State<_TimerLengthDialog> createState() => _TimerLengthDialogState();
}

class _TimerLengthDialogState extends State<_TimerLengthDialog> {
  static const _presets = [60, 180, 300, 600, 900, 1800, 2700, 3600];

  late final TextEditingController _minutes = TextEditingController(
    text: (widget.initialSeconds / 60).ceil().toString(),
  );

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(LocaleController.instance.value);
    return AlertDialog(
      title: Text(s.gestureTimerLength),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final seconds in _presets)
                ActionChip(
                  label: Text(formatGestureDuration(seconds, s)),
                  onPressed: () => Navigator.of(context).pop(seconds),
                ),
            ],
          ),
          SizedBox(height: context.design.spaceMd),
          TextField(
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: s.gestureTimerMinutes),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () {
            final minutes = int.tryParse(_minutes.text.trim()) ?? 0;
            if (minutes <= 0) return;
            Navigator.of(context).pop(minutes * 60);
          },
          child: Text(s.save),
        ),
      ],
    );
  }
}
