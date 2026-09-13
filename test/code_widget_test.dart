import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_strings.dart';
import 'package:hanneslauncher/code_widget_bridge.dart';
import 'package:hanneslauncher/code_widget_store.dart';
import 'package:hanneslauncher/code_widget_templates.dart';
import 'package:hanneslauncher/default_launcher_controller.dart';
import 'package:hanneslauncher/icon_theme_controller.dart';
import 'package:hanneslauncher/locale_controller.dart';
import 'package:hanneslauncher/panel_blocks_controller.dart';
import 'package:hanneslauncher/settings_catalog.dart';
import 'package:hanneslauncher/update_controller.dart';

void main() {
  group('the composed document', () {
    test('always carries the bridge, whatever the widget holds', () {
      final document = buildCodeDocument(
        const CodeWidgetSource(html: '<p>hallo</p>'),
      );
      expect(document, contains('window.launcher'));
      expect(document, contains('<p>hallo</p>'));
    });

    test('links style.css and script.js only once they hold something', () {
      final bare = buildCodeDocument(
        const CodeWidgetSource(html: '<p>hallo</p>'),
      );
      expect(bare, isNot(contains('style.css')));
      expect(bare, isNot(contains('script.js')));

      final full = buildCodeDocument(
        const CodeWidgetSource(
          html: '<p>hallo</p>',
          css: 'p { color: red; }',
          js: 'launcher.log("da");',
        ),
      );
      expect(full, contains('href="style.css"'));
      expect(full, contains('src="script.js"'));
    });

    test('offers the whole documented API, not half of it', () {
      final document = buildCodeDocument(const CodeWidgetSource(html: 'x'));
      // Every name the help text tells the user to write. Dropping one in a
      // refactor would only show up as a widget that stops working.
      for (final call in [
        'get:',
        'text:',
        'data:',
        'fill:',
        'apply:',
        'onUpdate:',
        'list:',
        'refresh:',
        'fetch:',
        'open:',
        'openUrl:',
        'store:',
        'load:',
        'forget:',
        'toast:',
      ]) {
        expect(document, contains(call), reason: call);
      }
    });

    test('whitespace alone does not count as a stylesheet', () {
      final document = buildCodeDocument(
        const CodeWidgetSource(html: '<p>x</p>', css: '   \n  '),
      );
      expect(document, isNot(contains('style.css')));
    });

    test('only a growing card measures itself', () {
      final fixed = buildCodeDocument(const CodeWidgetSource(html: '<p>x</p>'));
      expect(fixed, isNot(contains("call('height'")));

      final flexible = buildCodeDocument(
        const CodeWidgetSource(html: '<p>x</p>'),
        flexible: true,
      );
      expect(flexible, contains("call('height'"));
      // A card that grows must let the page be its natural height; one that
      // does not hands the page the whole card to lay out in.
      expect(flexible, isNot(contains('height:100%')));
      expect(fixed, contains('height:100%'));
    });
  });

  group('a pasted full page', () {
    test('keeps its style and script, loses only the skeleton', () {
      final stripped = stripDocumentSkeleton(
        '<!DOCTYPE html>\n<html lang="de">\n<head>\n'
        '<style>b { color: red; }</style>\n</head>\n'
        '<body class="x">\n<b>hallo</b>\n<script>let a = 1;</script>\n'
        '</body>\n</html>',
      );
      expect(stripped, contains('<style>b { color: red; }</style>'));
      expect(stripped, contains('<b>hallo</b>'));
      expect(stripped, contains('<script>let a = 1;</script>'));
      expect(stripped, isNot(contains('<html')));
      expect(stripped, isNot(contains('<body')));
      expect(stripped.toLowerCase(), isNot(contains('doctype')));
    });

    test('leaves an ordinary fragment alone', () {
      const fragment = '<div id="karte"><p>nichts zu tun</p></div>';
      expect(stripDocumentSkeleton(fragment), fragment);
    });
  });

  group('file names', () {
    test('are folded into something the HTML can reference', () {
      expect(CodeWidgetStore.sanitizeFileName('Mein Bild.PNG'), 'mein_bild.png');
      expect(CodeWidgetStore.sanitizeFileName('grün&blau.jpg'), 'gr_n_blau.jpg');
      // A path is not a way out of the widget's own folder.
      expect(
        CodeWidgetStore.sanitizeFileName('../../andere/datei.txt'),
        'datei.txt',
      );
    });

    test('never come out empty', () {
      expect(CodeWidgetStore.sanitizeFileName('...'), isNotEmpty);
      expect(CodeWidgetStore.sanitizeFileName('   '), isNotEmpty);
    });
  });

  group('a code block', () {
    test('survives being written and read back', () {
      const block = PanelBlock(
        id: '17',
        type: PanelBlockType.code,
        title: 'Spiel',
        cardHeight: 220,
        cardHeightFlexible: true,
        cardMaxHeight: 400,
        transparentBackground: true,
      );
      final restored = PanelBlock.fromJson(
        jsonDecode(jsonEncode(block.toJson())) as Map<String, dynamic>,
      );
      expect(restored.type, PanelBlockType.code);
      expect(restored.title, 'Spiel');
      expect(restored.cardHeight, 220);
      expect(restored.cardHeightFlexible, isTrue);
      expect(restored.cardMaxHeight, 400);
      expect(restored.transparentBackground, isTrue);
    });

    test('drawn on a card is what a block written before this reads as', () {
      // No 'transparentBackground' key at all - every block stored before the
      // switch existed. Missing must mean "on a card", not "invisible".
      final restored = PanelBlock.fromJson({
        'id': '1',
        'type': 'widget',
        'title': 'alt',
      });
      expect(restored.transparentBackground, isFalse);
    });
  });

  group('templates', () {
    test('all produce something that actually runs', () {
      for (final template in CodeWidgetTemplate.values) {
        final source = template.source;
        expect(source.isEmpty, isFalse, reason: '${template.name} is blank');
        expect(
          buildCodeDocument(source),
          contains('window.launcher'),
          reason: template.name,
        );
      }
    });

    test('are named in both languages', () {
      for (final language in AppLanguage.values) {
        final s = AppStrings(language);
        for (final template in CodeWidgetTemplate.values) {
          expect(template.label(s), isNotEmpty);
          expect(template.description(s), isNotEmpty);
        }
      }
    });
  });

  test('the settings list reaches the code widgets', () {
    final entries = buildSettingsCatalog(
      s: const AppStrings(AppLanguage.de),
      wallpaper: null,
      iconTheme: const IconThemeSettings(),
      folderCount: 0,
      webAppCount: 0,
      pinnedCount: 0,
      pinnedMax: 6,
      dataSourceCount: 0,
      codeWidgetCount: 2,
      deviceDataEnabled: false,
      language: AppLanguage.de,
      update: const UpdateState(),
      defaultLauncher: const DefaultLauncherState(),
    );
    final entry = entries.firstWhere(
      (candidate) => candidate.title == const AppStrings(
        AppLanguage.de,
      ).codeWidgets,
    );
    expect(entry.section, SettingsSection.panelData);
    expect(entry.subtitle, contains('2'));
    // Searching for what someone would actually type has to find it.
    for (final query in ['html', 'javascript', 'programmieren', 'spiel']) {
      expect(entry.matches(query), isTrue, reason: query);
    }
  });
}
