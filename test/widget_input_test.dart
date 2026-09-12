import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/data_sources_controller.dart';
import 'package:hanneslauncher/locale_controller.dart';
import 'package:hanneslauncher/panel_blocks_controller.dart';
import 'package:hanneslauncher/widget_element.dart';
import 'package:hanneslauncher/widget_input_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final blocks = PanelBlocksController.instance;
  final sources = DataSourcesController.instance;
  final inputs = WidgetInputStore.instance;

  /// Puts the shared singletons back to how they look before the first load,
  /// and hands back a widget card carrying one input element named [name].
  Future<PanelBlock> cardWithInput(String name) async {
    SharedPreferences.setMockInitialValues({});
    sources.value = const [];
    sources.debugResetLoadedForTest();
    blocks.value = const [];
    blocks.debugResetLoadedForTest();

    final block = await blocks.addWidget('Suche');
    final withField = block.copyWith(
      elements: [
        WidgetElement(
          id: '1',
          type: WidgetElementType.input,
          inputName: name,
        ),
      ],
    );
    await blocks.update(withField);
    return withField;
  }

  test('what is typed into a field is readable as a placeholder', () async {
    await cardWithInput('suche');

    // Nothing typed yet: the field exists, so it resolves - to nothing.
    expect(sources.resolve('[{{eingabe.suche}}]'), '[]');

    inputs.setText('suche', 'Kaffeemaschine');
    expect(sources.resolve('{{eingabe.suche}}'), 'Kaffeemaschine');
    // Both spellings always resolve, whatever the app's language is.
    expect(sources.resolve('{{input.suche}}'), 'Kaffeemaschine');
  });

  test('a name that no field goes by shows as a dash, not as blank', () async {
    await cardWithInput('suche');
    inputs.setText('suche', 'etwas');

    // The whole point: a typo has to be visible on the card rather than
    // looking like an empty field.
    expect(sources.resolve('{{eingabe.such}}'), '-');
    expect(sources.resolve('{{eingabe}}'), '-');
  });

  test('the name is matched regardless of case and punctuation', () async {
    await cardWithInput('Meine Suche');

    inputs.setText('meine_suche', 'hallo');
    expect(sources.resolve('{{eingabe.Meine Suche}}'), 'hallo');
    expect(sources.resolve('{{eingabe.MEINE_SUCHE}}'), 'hallo');
  });

  test('|url makes the value safe to put in an address', () async {
    await cardWithInput('suche');
    inputs.setText('suche', 'kaffee & kuchen');

    // Without the modifier the space would cut the address in half at the
    // first one - which is exactly the mistake this exists to prevent.
    expect(
      sources.resolve('https://x.test/?q={{eingabe.suche|url}}'),
      'https://x.test/?q=kaffee+%26+kuchen',
    );
    expect(
      sources.resolve('https://x.test/?q={{eingabe.suche}}'),
      'https://x.test/?q=kaffee & kuchen',
    );
  });

  test('a lone pipe in a path is not mistaken for a modifier', () async {
    await cardWithInput('a|b');

    // Normalised to "a_b", so this is really about resolve() not eating the
    // pipe before the name is ever looked up.
    inputs.setText('a_b', 'x');
    expect(sources.resolve('{{eingabe.a_b}}'), 'x');
    expect(sources.resolve('{{eingabe.a_b|nonsense}}'), '-');
  });

  test('renaming a field drops what the old name held', () async {
    final block = await cardWithInput('suche');
    inputs.setText('suche', 'alt');
    expect(inputs.textOf('suche'), 'alt');

    await blocks.update(
      block.copyWith(
        elements: [block.elements.first.copyWith(inputName: 'frage')],
      ),
    );

    // The old slot is gone rather than lying in wait to reappear if the
    // name is ever used again.
    expect(inputs.textOf('suche'), isNull);
    expect(inputs.textOf('frage'), '');
  });

  test('a field is offered for picking, spelled in the app language', () async {
    await cardWithInput('suche');
    inputs.setText('suche', 'jetzt');

    PlaceholderOption inputOption() =>
        sources.options().where((o) => o.isInput).single;

    // Which spelling is offered follows the language, the same way the
    // built-in keys do - both keep resolving either way.
    LocaleController.instance.value = AppLanguage.en;
    expect(inputOption().placeholder, '{{input.suche}}');
    expect(inputOption().preview, 'jetzt');

    LocaleController.instance.value = AppLanguage.de;
    expect(inputOption().placeholder, '{{eingabe.suche}}');
  });

  test('the new element settings survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    blocks.value = const [];
    blocks.debugResetLoadedForTest();

    final block = await blocks.addWidget('Suche');
    await blocks.update(
      block.copyWith(
        elements: [
          const WidgetElement(
            id: '1',
            type: WidgetElementType.input,
            inputName: 'suche',
            inputHint: 'Was suchst du?',
            inputKeyboard: WidgetInputKeyboard.url,
          ),
          const WidgetElement(
            id: '2',
            type: WidgetElementType.action,
            template: 'search',
            actionKind: WidgetActionKind.open,
            actionUrl: 'https://duckduckgo.com/?q={{eingabe.suche|url}}',
          ),
        ],
      ),
    );

    blocks.value = const [];
    blocks.debugResetLoadedForTest();
    await blocks.load();

    final elements = blocks.value.single.elements;
    expect(elements.first.type, WidgetElementType.input);
    expect(elements.first.inputName, 'suche');
    expect(elements.first.inputHint, 'Was suchst du?');
    expect(elements.first.inputKeyboard, WidgetInputKeyboard.url);
    expect(elements.last.actionKind, WidgetActionKind.open);
    expect(
      elements.last.actionUrl,
      'https://duckduckgo.com/?q={{eingabe.suche|url}}',
    );
  });

  test('a card stored before any of this reads back as a request button', () {
    // Every action element written before buttons could open something sent
    // a request, so that has to be what a missing actionKind means.
    final element = WidgetElement.fromJson({
      'id': '1',
      'type': 'action',
      'actionUrl': 'http://192.168.1.50/toggle',
    });
    expect(element.actionKind, WidgetActionKind.http);
    expect(element.inputName, '');
    expect(element.inputKeyboard, WidgetInputKeyboard.text);
  });
}
