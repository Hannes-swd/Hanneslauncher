import 'package:flutter/foundation.dart';

import 'panel_blocks_controller.dart';
import 'widget_element.dart';

/// What is currently typed into the input elements on the widget cards,
/// keyed by the field name their element was given.
///
/// Memory only, on purpose: the one thing these fields are for is typing
/// something and sending it somewhere right away. A search box still
/// holding last week's query when the panel is pulled down would be a
/// nuisance, not a convenience - so closing the app empties them.
///
/// The names themselves are not stored here but read off the blocks, so a
/// `{{eingabe.suche}}` in some other element resolves the moment the field
/// exists - it does not have to have been drawn once first, which is what
/// makes it work in the editor's preview too.
class WidgetInputStore extends ChangeNotifier {
  WidgetInputStore._() {
    PanelBlocksController.instance.addListener(_syncNames);
    // Directly, not through _syncNames: the very first access to [instance]
    // is usually a card's build method reaching for something to listen to,
    // and notifying listeners from inside a build is an error.
    _names = _namesOnCards();
  }

  static final WidgetInputStore instance = WidgetInputStore._();

  /// The placeholder prefix, in both spellings. Like the built-in values,
  /// both always resolve whatever the app's language is - a card written on
  /// a German app keeps working on an English one.
  static const String prefixDe = 'eingabe';
  static const String prefixEn = 'input';

  static bool isPrefix(String key) {
    final normalized = key.trim().toLowerCase();
    return normalized == prefixDe || normalized == prefixEn;
  }

  /// The prefix the editor offers, following the app's language.
  static String prefixFor(bool english) => english ? prefixEn : prefixDe;

  /// Field names go into a `{{...}}` reference, so anything that would
  /// break one - a dot, a brace, a space, the `|` a modifier starts with -
  /// is folded away rather than rejected while typing.
  static String normalizeName(String raw) {
    final lowered = raw.trim().toLowerCase();
    final cleaned = lowered.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    return cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  final Map<String, String> _values = {};
  Set<String> _names = const {};

  /// Every field name currently on a card, so the editor can offer them.
  List<String> get names => _names.toList()..sort();

  bool knows(String name) => _names.contains(normalizeName(name));

  /// The text in [name] right now, or null when no field goes by that name -
  /// which is what makes a typo show up as "-" instead of silently blank.
  String? textOf(String name) {
    final key = normalizeName(name);
    if (!_names.contains(key)) return null;
    return _values[key] ?? '';
  }

  void setText(String name, String text) {
    final key = normalizeName(name);
    if (key.isEmpty) return;
    if (_values[key] == text) return;
    _values[key] = text;
    notifyListeners();
  }

  /// Empties a single field - what a search element does once one of its
  /// rows has been tapped: the question has been answered, so the words
  /// that asked it have done their job.
  ///
  /// A name no field goes by is left alone rather than created empty, so a
  /// results element pointing at nothing stays pointing at nothing.
  void clear(String name) {
    if (!knows(name)) return;
    setText(name, '');
  }

  final List<void Function(String name)> _submitListeners = [];

  /// Called with a field's name whenever Enter is pressed in it. The field
  /// and whatever answers it are separate elements, often on separate
  /// cards, so this is the only line between the two.
  void addSubmitListener(void Function(String name) listener) =>
      _submitListeners.add(listener);

  void removeSubmitListener(void Function(String name) listener) =>
      _submitListeners.remove(listener);

  void submit(String name) {
    final key = normalizeName(name);
    if (!_names.contains(key)) return;
    // A copy: a listener acting on it can clear the field, and the rebuild
    // that follows may take a results element off screen mid-loop.
    for (final listener in [..._submitListeners]) {
      listener(key);
    }
  }

  /// Empties every field. Runs when the panel shuts, for the same reason
  /// the values are memory-only in the first place: what was typed belongs
  /// to the moment it was typed in, and finding it still there on the next
  /// pull-down only means deleting it before anything new can be typed.
  void clearAll() {
    if (_values.isEmpty) return;
    _values.clear();
    notifyListeners();
  }

  Set<String> _namesOnCards() {
    final found = <String>{};
    for (final block in PanelBlocksController.instance.value) {
      for (final element in block.elements) {
        if (element.type != WidgetElementType.input) continue;
        final name = normalizeName(element.inputName);
        if (name.isNotEmpty) found.add(name);
      }
    }
    return found;
  }

  /// Collects the field names off the blocks. Values whose field is gone are
  /// dropped with it, so a renamed field doesn't leave its old text behind
  /// to reappear if the name is ever used again.
  void _syncNames() {
    final found = _namesOnCards();
    if (setEquals(found, _names)) return;
    _names = found;
    _values.removeWhere((key, _) => !found.contains(key));
    notifyListeners();
  }
}
