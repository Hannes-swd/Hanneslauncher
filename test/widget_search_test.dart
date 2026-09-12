import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_strings.dart';
import 'package:hanneslauncher/locale_controller.dart';
import 'package:hanneslauncher/panel_blocks_controller.dart';
import 'package:hanneslauncher/widget_element.dart';
import 'package:hanneslauncher/widget_search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const s = AppStrings(AppLanguage.de);

  /// A search element with only the piles that need no platform channel -
  /// apps come from a controller that would want the installed-apps plugin,
  /// contacts from Android itself, and neither exists in a test.
  const element = WidgetElement(
    id: '1',
    type: WidgetElementType.results,
    inputName: 'suche',
    searchApps: false,
    searchSettings: false,
    searchContacts: false,
    searchCalculation: true,
    webSearchUrl: 'https://duckduckgo.com/?q=$webSearchQueryToken',
  );

  test('a sum is answered, and the answer comes first', () async {
    final hits = await runWidgetSearch(query: '12*7', element: element, s: s);

    expect(hits.first.kind, SearchHitKind.calculation);
    expect(hits.first.title, '84');
    // The typed sum underneath, so it reads as an answer to something.
    expect(hits.first.subtitle, '12*7');
  });

  test('the web row is always last and always there', () async {
    final hits = await runWidgetSearch(query: '12*7', element: element, s: s);

    expect(hits.last.kind, SearchHitKind.web);
    expect(hits.last.title, contains('12*7'));
    // Named by host, so it is obvious where the tap goes.
    expect(hits.last.subtitle, 'duckduckgo.com');
  });

  test('words produce no answer, only the web row', () async {
    final hits = await runWidgetSearch(
      query: 'whatsapp',
      element: element,
      s: s,
    );

    expect(hits.length, 1);
    expect(hits.single.kind, SearchHitKind.web);
  });

  test('an empty query searches nothing at all', () async {
    expect(await runWidgetSearch(query: '', element: element, s: s), isEmpty);
    expect(
      await runWidgetSearch(query: '   ', element: element, s: s),
      isEmpty,
    );
  });

  test('no web address means no web row', () async {
    final hits = await runWidgetSearch(
      query: '2+2',
      element: element.copyWith(webSearchUrl: ''),
      s: s,
    );

    expect(hits.length, 1);
    expect(hits.single.kind, SearchHitKind.calculation);
  });

  test('the typed words are made url-safe on the way into the address', () {
    // Not the tap itself - that needs a browser - but the address it builds.
    final url = webSearchPresets['DuckDuckGo']!.replaceAll(
      webSearchQueryToken,
      Uri.encodeQueryComponent('kaffee & kuchen'),
    );
    expect(url, 'https://duckduckgo.com/?q=kaffee+%26+kuchen');
  });

  test('every preset has a slot for the query', () {
    for (final entry in webSearchPresets.entries) {
      expect(
        entry.value,
        contains(webSearchQueryToken),
        reason: '${entry.key} would search for nothing',
      );
    }
  });

  test('a search element survives a reload with its tick boxes', () async {
    SharedPreferences.setMockInitialValues({});
    final blocks = PanelBlocksController.instance;
    blocks.value = const [];
    blocks.debugResetLoadedForTest();

    final block = await blocks.addWidget('Suche');
    await blocks.update(
      block.copyWith(
        elements: [
          element.copyWith(searchContacts: true, resultLimit: 7),
          const WidgetElement(
            id: '2',
            type: WidgetElementType.text,
            textMode: WidgetTextMode.calculation,
            inputName: 'suche',
          ),
        ],
      ),
    );

    blocks.value = const [];
    blocks.debugResetLoadedForTest();
    await blocks.load();

    final loaded = blocks.value.single.elements;
    expect(loaded.first.type, WidgetElementType.results);
    expect(loaded.first.searchContacts, isTrue);
    expect(loaded.first.searchApps, isFalse);
    expect(loaded.first.resultLimit, 7);
    expect(loaded.last.textMode, WidgetTextMode.calculation);
    expect(loaded.last.inputName, 'suche');
  });

  test('a search button keeps its field and engine across a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final blocks = PanelBlocksController.instance;
    blocks.value = const [];
    blocks.debugResetLoadedForTest();

    final block = await blocks.addWidget('Suche');
    await blocks.update(
      block.copyWith(
        elements: [
          const WidgetElement(
            id: '1',
            type: WidgetElementType.action,
            template: 'search',
            actionKind: WidgetActionKind.search,
            inputName: 'suche',
            webSearchUrl: 'https://www.youtube.com/results?'
                'search_query=$webSearchQueryToken',
          ),
        ],
      ),
    );

    blocks.value = const [];
    blocks.debugResetLoadedForTest();
    await blocks.load();

    final loaded = blocks.value.single.elements.single;
    expect(loaded.actionKind, WidgetActionKind.search);
    expect(loaded.inputName, 'suche');
    // A search button needs no address of its own, so this stays empty even
    // on a fully set-up one.
    expect(loaded.actionUrl, '');
  });

  test('a search button builds the address the tap opens', () {
    // The tap itself needs a browser; the address it would hand over is the
    // part worth pinning down.
    expect(
      buildSearchUrl(webSearchPresets['YouTube']!, 'lo-fi beats'),
      'https://www.youtube.com/results?search_query=lo-fi+beats',
    );
    // A hand-typed engine with no slot for the query searches for nothing -
    // which is why the editor shows this address rather than hiding it.
    expect(
      buildSearchUrl('https://example.com/', 'egal'),
      'https://example.com/',
    );
  });

  test('a text element stored before all this is still free text', () {
    final loaded = WidgetElement.fromJson({
      'id': '1',
      'type': 'text',
      'template': '{{zeit}}',
    });
    expect(loaded.textMode, WidgetTextMode.free);
    // Contacts is the one box that costs a permission, so it must never
    // arrive already ticked.
    expect(loaded.searchContacts, isFalse);
  });
}
