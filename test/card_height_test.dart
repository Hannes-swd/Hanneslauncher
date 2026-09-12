import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/panel_blocks_controller.dart';
import 'package:hanneslauncher/widget_card_view.dart';
import 'package:hanneslauncher/widget_element.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an element asks for a height that follows its own settings', () {
    // The point of working these out rather than measuring them: the answer
    // must not depend on how tall the card currently is, or sizing the card
    // from them would chase its own tail.
    const text = WidgetElement(
      id: '1',
      type: WidgetElementType.text,
      fontSize: 20,
    );
    const bigText = WidgetElement(
      id: '2',
      type: WidgetElementType.text,
      fontSize: 40,
    );
    expect(
      naturalElementHeight(bigText),
      greaterThan(naturalElementHeight(text)),
    );

    const box = WidgetElement(
      id: '3',
      type: WidgetElementType.box,
      height: 123,
    );
    expect(naturalElementHeight(box), 123);

    // A results list asks for its ceiling until it says otherwise.
    const results = WidgetElement(
      id: '4',
      type: WidgetElementType.results,
      height: 200,
    );
    expect(naturalElementHeight(results), 200);

    // Every type has to answer, or a card with one on it sizes to nothing.
    for (final type in WidgetElementType.values) {
      expect(
        naturalElementHeight(WidgetElement(id: 'x', type: type)),
        greaterThan(0),
        reason: '$type asks for no height at all',
      );
    }
  });

  test('the card keeps its fixed height by default', () async {
    SharedPreferences.setMockInitialValues({});
    final blocks = PanelBlocksController.instance;
    blocks.value = const [];
    blocks.debugResetLoadedForTest();

    final block = await blocks.addWidget('Karte');
    // Every card built before flexible height existed was a fixed one, and
    // must not start resizing itself now.
    expect(block.cardHeightFlexible, isFalse);
    expect(block.cardHeight, 160);
  });

  test('a card stored before flexible height reads back as fixed', () {
    final loaded = PanelBlock.fromJson({
      'id': '1',
      'type': 'widget',
      'cardHeight': 220.0,
    });
    expect(loaded.cardHeightFlexible, isFalse);
    expect(loaded.cardHeight, 220);
    expect(loaded.cardMaxHeight, 320);
  });

  test('the height settings survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final blocks = PanelBlocksController.instance;
    blocks.value = const [];
    blocks.debugResetLoadedForTest();

    final block = await blocks.addWidget('Karte');
    await blocks.update(
      block.copyWith(
        cardHeightFlexible: true,
        cardHeight: 60,
        cardMaxHeight: 480,
      ),
    );

    blocks.value = const [];
    blocks.debugResetLoadedForTest();
    await blocks.load();

    final loaded = blocks.value.single;
    expect(loaded.cardHeightFlexible, isTrue);
    expect(loaded.cardHeight, 60);
    expect(loaded.cardMaxHeight, 480);
  });
}
