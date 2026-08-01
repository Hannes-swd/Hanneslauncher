import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Colors the user has added themselves through the "+" on any color
/// picker, on top of the fixed palette in `app_list_settings_controller.dart`.
/// Shared globally - one added here shows up on every color picker in the
/// app, immediately, since it's just appended to the same palette everything
/// already indexes into.
///
/// Append-only: removing one would shift every index after it, silently
/// repointing anything already saved with a later index at the wrong color.
class CustomColorsController extends ValueNotifier<List<Color>> {
  CustomColorsController._() : super(const []);

  static final CustomColorsController instance = CustomColorsController._();

  static const _key = 'custom_colors';

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    value = [
      for (final entry in raw)
        if (int.tryParse(entry) != null) Color(int.parse(entry)),
    ];
  }

  /// Adds a color, unless it's already in the custom list - picking the same
  /// one twice would otherwise just clutter the row with a duplicate.
  Future<void> add(Color color) async {
    if (value.contains(color)) return;
    value = [...value, color];
    await _persist();
  }

  /// Replaces the whole custom list wholesale - used to restore a settings
  /// backup, where the order (and so the index every `colorIndex` above the
  /// base palette's length points into) must come back exactly as exported.
  Future<void> restore(List<Color> colors) async {
    value = colors;
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [
      for (final c in value) c.toARGB32().toString(),
    ]);
  }
}
