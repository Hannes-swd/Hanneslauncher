import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'note_document.dart';
import 'widget_element.dart';

/// What a block on the panel shows.
enum PanelBlockType {
  /// A row of app icons, taken from [PanelBlock.itemKeys].
  appRow,

  /// A widget hosted by the launcher, named by [PanelBlock.title].
  widget,

  /// An agenda of upcoming events from the device's calendars, filtered to
  /// [PanelBlock.itemKeys] (all calendars if empty) and [PanelBlock.daysAhead].
  calendar,

  /// A written note, named by [PanelBlock.title] and held line by line in
  /// [PanelBlock.notes].
  notes,
}

/// One entry on the panel. The blocks are shown in list order.
class PanelBlock {
  const PanelBlock({
    required this.id,
    required this.type,
    this.itemKeys = const [],
    this.columns = 4,
    this.showLabels = false,
    this.title = '',
    this.elements = const [],
    this.cardHeight = 160,
    this.daysAhead = 7,
    this.linkedKey = '',
    this.notes = const [],
  });

  final String id;
  final PanelBlockType type;

  /// App row: what it holds, in display order. Same keys used for pinning:
  /// a package name, a `web:<id>` or a `folder:<id>`.
  ///
  /// Calendar: which calendars to include, by the device's own calendar id.
  /// Empty means every calendar the device has.
  final List<String> itemKeys;

  /// App row: icons per line, 3..6.
  final int columns;

  /// App row: whether the app names are drawn under the icons.
  final bool showLabels;

  /// The block's display name, used for widget blocks.
  final String title;

  /// Widget: what it draws. The list is the stacking order - the first one
  /// is at the back, the last on top.
  final List<WidgetElement> elements;

  /// Widget: how tall the card is. Elements sit at a relative position
  /// inside it, so this is what they are placed within.
  final double cardHeight;

  /// Calendar: how many days ahead the agenda reaches.
  final int daysAhead;

  /// Widget: the app, web app or folder opened when the card is tapped - a
  /// package name, a `web:<id>` or a `folder:<id>`, same keys as [itemKeys].
  /// Empty means the card isn't linked to anything.
  final String linkedKey;

  /// Notes: the note itself, one entry per line.
  final List<NoteParagraph> notes;

  PanelBlock copyWith({
    List<String>? itemKeys,
    int? columns,
    bool? showLabels,
    String? title,
    List<WidgetElement>? elements,
    double? cardHeight,
    int? daysAhead,
    String? linkedKey,
    List<NoteParagraph>? notes,
  }) {
    return PanelBlock(
      id: id,
      type: type,
      itemKeys: itemKeys ?? this.itemKeys,
      columns: columns ?? this.columns,
      showLabels: showLabels ?? this.showLabels,
      title: title ?? this.title,
      elements: elements ?? this.elements,
      cardHeight: cardHeight ?? this.cardHeight,
      daysAhead: daysAhead ?? this.daysAhead,
      linkedKey: linkedKey ?? this.linkedKey,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    // Stored by name so adding enum values later cannot shift the meaning
    // of already stored blocks the way an index would.
    'type': type.name,
    'itemKeys': itemKeys,
    'columns': columns,
    'showLabels': showLabels,
    'title': title,
    'elements': [for (final element in elements) element.toJson()],
    'cardHeight': cardHeight,
    'daysAhead': daysAhead,
    'linkedKey': linkedKey,
    'notes': [for (final paragraph in notes) paragraph.toJson()],
  };

  static PanelBlock fromJson(Map<String, dynamic> json) => PanelBlock(
    id: json['id'] as String,
    type: _typeFromName(json['type']),
    itemKeys: [
      for (final key in (json['itemKeys'] as List<dynamic>? ?? const []))
        key as String,
    ],
    columns: _columnsInRange(json['columns'] as int? ?? 4),
    showLabels: json['showLabels'] as bool? ?? false,
    title: json['title'] as String? ?? '',
    elements: _elementsFrom(json['elements']),
    cardHeight: (json['cardHeight'] as num?)?.toDouble() ?? 160,
    daysAhead: json['daysAhead'] as int? ?? 7,
    linkedKey: json['linkedKey'] as String? ?? '',
    notes: _notesFrom(json['notes']),
  );

  /// Same reasoning as the elements below: one unreadable line is dropped
  /// rather than taking the whole note down with it.
  static List<NoteParagraph> _notesFrom(Object? stored) {
    final raw = stored as List<dynamic>? ?? const [];
    final paragraphs = <NoteParagraph>[];
    for (final entry in raw) {
      try {
        paragraphs.add(
          NoteParagraph.fromJson(entry as Map<String, dynamic>),
        );
      } catch (_) {
        // Unreadable line - leave it out.
      }
    }
    return paragraphs;
  }

  /// Skips a single unreadable element rather than losing the whole card
  /// with it - same reasoning as the stored blocks themselves.
  static List<WidgetElement> _elementsFrom(Object? stored) {
    final raw = stored as List<dynamic>? ?? const [];
    final elements = <WidgetElement>[];
    for (final element in raw) {
      try {
        final json = element as Map<String, dynamic>;
        final parsed = WidgetElement.fromJson(json);
        elements.add(
          // Cards written before elements could be placed were drawn as
          // rows; spreading them down the card keeps them looking the same
          // instead of piling everything up in the middle.
          WidgetElement.hasNoStoredPosition(json)
              ? parsed.copyWith(
                  y: (elements.length + 0.5) / raw.length,
                  x: 0,
                )
              : parsed,
        );
      } catch (_) {
        // Unreadable element - leave it out.
      }
    }
    return elements;
  }

  /// Keeps a stored column count inside what the layout can draw, in case
  /// an older or hand-edited value falls outside it.
  static int _columnsInRange(int columns) {
    if (columns < 3) return 3;
    if (columns > 6) return 6;
    return columns;
  }

  /// Maps a stored `type` back. Throws on anything unknown so the caller
  /// drops that one entry instead of guessing a type for it.
  static PanelBlockType _typeFromName(Object? name) {
    for (final type in PanelBlockType.values) {
      if (type.name == name) return type;
    }
    throw FormatException('unknown panel block type: $name');
  }
}

/// The user's panel blocks, persisted across restarts.
class PanelBlocksController extends ValueNotifier<List<PanelBlock>> {
  PanelBlocksController._() : super(const []);

  static final PanelBlocksController instance = PanelBlocksController._();

  static const _key = 'panel_blocks';

  bool _loaded = false;

  /// Reads the stored blocks once. Later calls do nothing: what's in memory
  /// is by then the newer state, and re-reading would throw away blocks
  /// created since - which is how they'd vanish seemingly at random.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null) return;
    final loaded = <PanelBlock>[];
    for (final entry in raw) {
      try {
        loaded.add(
          PanelBlock.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
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

  PanelBlock? byId(String id) {
    for (final block in value) {
      if (block.id == id) return block;
    }
    return null;
  }

  Future<PanelBlock> addAppRow() async {
    final block = PanelBlock(id: _newId(), type: PanelBlockType.appRow);
    await _save([...value, block]);
    return block;
  }

  Future<PanelBlock> addWidget(String title) async {
    final block = PanelBlock(
      id: _newId(),
      type: PanelBlockType.widget,
      title: title.trim(),
    );
    await _save([...value, block]);
    return block;
  }

  Future<PanelBlock> addNotes(String title) async {
    final block = PanelBlock(
      id: _newId(),
      type: PanelBlockType.notes,
      title: title.trim(),
    );
    await _save([...value, block]);
    return block;
  }

  Future<PanelBlock> addCalendar() async {
    final block = PanelBlock(id: _newId(), type: PanelBlockType.calendar);
    await _save([...value, block]);
    return block;
  }

  /// Replaces the block carrying the same id, keeping its position.
  Future<void> update(PanelBlock block) async {
    await _save([
      for (final existing in value)
        if (existing.id == block.id) block else existing,
    ]);
  }

  Future<void> remove(String id) async {
    await _save([
      for (final block in value)
        if (block.id != id) block,
    ]);
  }

  /// Replaces every block wholesale - used to restore a settings backup.
  Future<void> replaceAll(List<PanelBlock> blocks) => _save(blocks);

  /// Moves a block, taking [oldIndex]/[newIndex] exactly as
  /// `ReorderableListView.onReorder` reports them.
  Future<void> reorder(int oldIndex, int newIndex) async {
    // onReorder counts the target slot with the dragged block still in the
    // list, so moving downwards is one off once it has been taken out.
    if (newIndex > oldIndex) newIndex -= 1;
    final blocks = [...value];
    final block = blocks.removeAt(oldIndex);
    blocks.insert(newIndex, block);
    await _save(blocks);
  }

  /// Ids are the creation time. Windows only advances the clock every few
  /// milliseconds, so two blocks added in quick succession can ask for the
  /// same one - and blocks sharing an id would be edited and removed
  /// together. Step past anything already taken.
  String _newId() {
    var stamp = DateTime.now().microsecondsSinceEpoch;
    while (byId(stamp.toString()) != null) {
      stamp++;
    }
    return stamp.toString();
  }

  Future<void> _save(List<PanelBlock> blocks) async {
    value = blocks;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      [for (final block in blocks) jsonEncode(block.toJson())],
    );
  }
}
