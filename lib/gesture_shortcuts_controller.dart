import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;
import 'color_swatch_picker.dart' show autoColorIndex;
import 'gesture_action.dart';
import 'gesture_stroke.dart';

/// One saved shape and what drawing it does.
class GestureShortcut {
  const GestureShortcut({
    required this.id,
    required this.name,
    required this.stroke,
    required this.action,
    this.enabled = true,
  });

  /// Creation time, the same way web apps and folders get theirs - see
  /// [GestureShortcutsController._newId] for why it can differ from the
  /// clock.
  final String id;

  /// What it is called in the list and in the message the home screen shows
  /// when it fires. Not the same thing as the action: "Musik" can open
  /// Spotify.
  final String name;

  final GestureStroke stroke;
  final GestureAction action;

  /// Switched off keeps the shape and its action but takes it out of the
  /// home screen's matching - the way to stop a shape that keeps firing by
  /// accident without having to draw it again later.
  final bool enabled;

  GestureShortcut copyWith({
    String? name,
    GestureStroke? stroke,
    GestureAction? action,
    bool? enabled,
  }) {
    return GestureShortcut(
      id: id,
      name: name ?? this.name,
      stroke: stroke ?? this.stroke,
      action: action ?? this.action,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'stroke': stroke.toJson(),
    'action': action.toJson(),
    if (!enabled) 'enabled': false,
  };

  /// Returns null rather than throwing for anything unreadable, so one
  /// damaged shortcut in the stored list (or in a backup file) costs only
  /// that one.
  static GestureShortcut? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    final stroke = GestureStroke.fromJson(json['stroke']);
    final action = GestureAction.fromJson(json['action']);
    if (stroke == null || action == null) return null;
    return GestureShortcut(
      id: id,
      name: name,
      stroke: stroke,
      action: action,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// The saved shapes, in the order they were added.
///
/// Also the one place the list the home screen matches against is built
/// ([templates]) - so a shape that is switched off, or one whose action has
/// gone missing, can never be recognised into something that then does
/// nothing.
class GestureShortcutsController extends ValueNotifier<List<GestureShortcut>> {
  GestureShortcutsController._() : super(const []);

  static final GestureShortcutsController instance =
      GestureShortcutsController._();

  static const _key = 'gesture_shortcuts';

  /// How many can be saved. Not a storage limit - every drawing is compared
  /// against every saved shape, and past a couple of dozen shapes the odds
  /// that two of them look alike to a finger get worse than the feature is
  /// worth.
  static const int maxShortcuts = 24;

  bool _loaded = false;

  bool get isFull => value.length >= maxShortcuts;

  /// Reads the stored shapes once. Later calls do nothing: what is in memory
  /// is by then the newer state, and re-reading would throw away anything
  /// added since.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null) return;
    final loaded = <GestureShortcut>[];
    for (final entry in raw) {
      try {
        final shortcut = GestureShortcut.fromJson(jsonDecode(entry));
        if (shortcut != null) loaded.add(shortcut);
      } catch (_) {
        // Skip just the unreadable one. Dropping the whole list here would
        // be permanent: the next save would write the shortened list back.
      }
    }
    value = loaded;
  }

  /// Lets a test pretend the app restarted; there is no other way to make
  /// the one-shot [load] read again.
  @visibleForTesting
  void debugResetLoadedForTest() => _loaded = false;

  GestureShortcut? byId(String id) {
    for (final shortcut in value) {
      if (shortcut.id == id) return shortcut;
    }
    return null;
  }

  /// What a freshly drawn stroke is matched against: the shapes that are
  /// switched on and actually point at something.
  List<StrokeTemplate> get templates => [
    for (final shortcut in value)
      if (shortcut.enabled && shortcut.action.isComplete)
        StrokeTemplate(id: shortcut.id, stroke: shortcut.stroke),
  ];

  /// The saved shape a drawing looks most like, and how much - regardless of
  /// whether it is switched on, and ignoring [skipId] (the shape being
  /// edited, which of course looks like itself).
  ///
  /// This is what the editor warns with before saving: two shapes that look
  /// alike are not an error, but finding out on the home screen weeks later
  /// that neither of them fires reliably is a bad way to learn it.
  ({GestureShortcut shortcut, double score})? closestTo(
    GestureStroke stroke, {
    String? skipId,
  }) {
    GestureShortcut? best;
    var bestScore = 0.0;
    for (final shortcut in value) {
      if (shortcut.id == skipId) continue;
      final score = strokeScore(stroke, shortcut.stroke);
      if (best == null || score > bestScore) {
        best = shortcut;
        bestScore = score;
      }
    }
    if (best == null) return null;
    return (shortcut: best, score: bestScore);
  }

  Future<GestureShortcut?> add({
    required String name,
    required GestureStroke stroke,
    required GestureAction action,
  }) async {
    if (isFull) return null;
    final shortcut = GestureShortcut(
      id: _newId(),
      name: name.trim(),
      stroke: stroke,
      action: action,
    );
    await _save([...value, shortcut]);
    return shortcut;
  }

  Future<void> update(
    String id, {
    String? name,
    GestureStroke? stroke,
    GestureAction? action,
    bool? enabled,
  }) async {
    await _save([
      for (final shortcut in value)
        if (shortcut.id == id)
          shortcut.copyWith(
            name: name?.trim(),
            stroke: stroke,
            action: action,
            enabled: enabled,
          )
        else
          shortcut,
    ]);
  }

  Future<void> remove(String id) async {
    await _save([
      for (final shortcut in value)
        if (shortcut.id != id) shortcut,
    ]);
  }

  /// Replaces every shortcut wholesale - used to restore a settings backup.
  Future<void> replaceAll(List<GestureShortcut> shortcuts) =>
      _save(shortcuts.take(maxShortcuts).toList());

  /// Ids are the creation time. If the clock hasn't advanced since the last
  /// one, two shortcuts would share an id and then be edited and deleted
  /// together. Step past anything already taken.
  String _newId() {
    var stamp = DateTime.now().microsecondsSinceEpoch;
    while (byId(stamp.toString()) != null) {
      stamp++;
    }
    return stamp.toString();
  }

  Future<void> _save(List<GestureShortcut> shortcuts) async {
    value = shortcuts;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [
      for (final shortcut in shortcuts) jsonEncode(shortcut.toJson()),
    ]);
  }
}

/// How the home screen answers a finger that is drawing: whether it watches
/// for shapes at all, whether the line is drawn under the finger while it
/// happens, and in what colour.
class GestureDrawingSettings {
  const GestureDrawingSettings({
    this.enabled = true,
    this.showTrail = true,
    this.colorIndex = autoColorIndex,
  });

  /// Whether shapes are watched for at all.
  ///
  /// Kept apart from the shapes themselves because switching it off has to
  /// leave every saved shape intact - somebody who finds the drawing in the
  /// way while the phone is in a pocket should not have to choose between
  /// that and losing the shortcuts.
  ///
  /// On by default: with no shape saved the home screen behaves exactly as
  /// it always did (see [GestureShortcutsController.templates] - nothing to
  /// match means nothing is claimed), so this only starts mattering once
  /// there is something for it to do.
  final bool enabled;

  /// Whether the stroke is drawn under the finger.
  ///
  /// On by default, because a shape drawn blind is a shape you cannot tell
  /// went wrong: without the line there is no difference between a drawing
  /// that missed and one that was never picked up. Off is for a home screen
  /// that should give nothing away to somebody looking over a shoulder - the
  /// shape still works, it just leaves no trace.
  final bool showTrail;

  /// Index into [appListColorPalette], or [autoColorIndex] for "whatever the
  /// design's accent is" - which is the default, so the line moves with the
  /// theme like everything else in the app until it is given a colour of its
  /// own.
  final int colorIndex;

  /// The chosen colour, or null while it follows the design. Null rather
  /// than the accent itself so this stays out of the design tokens - what
  /// the accent is right now is the drawing widget's business, and it is the
  /// only place that has a context to read it from.
  Color? get fixedColor {
    if (colorIndex == autoColorIndex) return null;
    final palette = appListColorPalette;
    // Clamped rather than indexed straight: a backup from a phone with more
    // hand-picked colours than this one has can name an index past the end.
    return palette[colorIndex.clamp(0, palette.length - 1)];
  }

  GestureDrawingSettings copyWith({
    bool? enabled,
    bool? showTrail,
    int? colorIndex,
  }) {
    return GestureDrawingSettings(
      enabled: enabled ?? this.enabled,
      showTrail: showTrail ?? this.showTrail,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GestureDrawingSettings &&
      other.enabled == enabled &&
      other.showTrail == showTrail &&
      other.colorIndex == colorIndex;

  @override
  int get hashCode => Object.hash(enabled, showTrail, colorIndex);
}

/// What the user picked. Read by the home screen only - a settings screen
/// showing a shape draws it in the accent regardless, since there the line
/// is a picture of a shortcut rather than a finger's own trail.
class GestureDrawingController extends ValueNotifier<GestureDrawingSettings> {
  GestureDrawingController._() : super(const GestureDrawingSettings());

  static final GestureDrawingController instance = GestureDrawingController._();

  static const _enabledKey = 'gesture_drawing_enabled';
  static const _trailKey = 'gesture_trail_visible';
  static const _colorKey = 'gesture_trail_color_index';

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    value = GestureDrawingSettings(
      enabled: prefs.getBool(_enabledKey) ?? true,
      showTrail: prefs.getBool(_trailKey) ?? true,
      colorIndex: prefs.getInt(_colorKey) ?? autoColorIndex,
    );
  }

  /// Lets a test pretend the app restarted; there is no other way to make
  /// the one-shot [load] read again.
  @visibleForTesting
  void debugResetLoadedForTest() => _loaded = false;

  Future<void> update(GestureDrawingSettings settings) async {
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setBool(_trailKey, settings.showTrail);
    await prefs.setInt(_colorKey, settings.colorIndex);
  }
}
