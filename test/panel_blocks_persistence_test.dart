import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslouncher/panel_blocks_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final controller = PanelBlocksController.instance;

  /// Puts the shared singleton back to how it looks before the first load.
  void startFresh([Map<String, Object> stored = const {}]) {
    SharedPreferences.setMockInitialValues(stored);
    controller.value = const [];
    controller.debugResetLoadedForTest();
  }

  test('blocks and their settings survive a reload', () async {
    startFresh();

    final row = await controller.addAppRow();
    final widget = await controller.addWidget('Wetter');
    await controller.update(
      row.copyWith(
        itemKeys: ['com.example.mail', 'web:1', 'folder:2'],
        columns: 5,
        showLabels: true,
      ),
    );

    // Simulate a fresh app start: drop what's in memory and read back.
    controller.value = const [];
    controller.debugResetLoadedForTest();
    await controller.load();

    expect(controller.value.length, 2);
    final loadedRow = controller.value.first;
    expect(loadedRow.id, row.id);
    expect(loadedRow.type, PanelBlockType.appRow);
    expect(loadedRow.itemKeys, ['com.example.mail', 'web:1', 'folder:2']);
    expect(loadedRow.columns, 5);
    expect(loadedRow.showLabels, true);

    final loadedWidget = controller.value.last;
    expect(loadedWidget.id, widget.id);
    expect(loadedWidget.type, PanelBlockType.widget);
    expect(loadedWidget.title, 'Wetter');
    expect(controller.byId(widget.id)?.title, 'Wetter');
  });

  test('remove drops only the named block', () async {
    startFresh();

    final first = await controller.addWidget('Uhr');
    final second = await controller.addAppRow();
    await controller.remove(first.id);

    controller.value = const [];
    controller.debugResetLoadedForTest();
    await controller.load();

    expect(controller.value.map((b) => b.id), [second.id]);
    expect(controller.byId(first.id), isNull);
  });

  test('reorder moves a block and survives a restart', () async {
    startFresh();

    final a = await controller.addWidget('A');
    final b = await controller.addWidget('B');
    final c = await controller.addWidget('C');

    // As ReorderableListView reports it: A dropped onto the slot after C.
    await controller.reorder(0, 3);
    expect(controller.value.map((block) => block.title), ['B', 'C', 'A']);

    // And back up: A dragged to the front again.
    await controller.reorder(2, 0);
    expect(controller.value.map((block) => block.title), ['A', 'B', 'C']);

    await controller.reorder(2, 1);

    controller.value = const [];
    controller.debugResetLoadedForTest();
    await controller.load();

    expect(controller.value.map((block) => block.id), [a.id, c.id, b.id]);
  });

  test('a later load does not drop blocks added meanwhile', () async {
    startFresh();

    await controller.load();
    final row = await controller.addAppRow();
    // The panel rebuilding (e.g. after Android recreated the launcher) must
    // not wipe what was created in the meantime.
    await controller.load();

    expect(controller.value.map((block) => block.id), [row.id]);
  });

  test('a single unreadable entry does not take the others with it', () async {
    final good = const PanelBlock(
      id: '42',
      type: PanelBlockType.appRow,
      itemKeys: ['com.example.mail'],
      columns: 6,
      showLabels: true,
    );
    startFresh({
      'panel_blocks': <String>[
        'kein json',
        jsonEncode({'id': '7', 'type': 'nichts_bekanntes'}),
        jsonEncode(good.toJson()),
      ],
    });

    await controller.load();

    expect(controller.value.length, 1);
    expect(controller.value.single.id, '42');
    expect(controller.value.single.itemKeys, ['com.example.mail']);
    expect(controller.value.single.columns, 6);
    expect(controller.value.single.showLabels, true);
  });
}
