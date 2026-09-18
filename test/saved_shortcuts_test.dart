import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_shortcuts.dart';
import 'package:hanneslauncher/launcher_entries_controller.dart';
import 'package:hanneslauncher/launcher_entry.dart';
import 'package:hanneslauncher/pinned_apps_controller.dart';
import 'package:hanneslauncher/saved_shortcuts_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shortcuts an app publishes about itself, once the user has kept one.
///
/// Nothing here can talk to Android - there is no platform channel under a
/// test - which is deliberately the same situation the launcher is in
/// whenever it isn't the home app. Every call in `app_shortcuts.dart`
/// answers "nothing" then, so what is checked below is the half that has to
/// keep working anyway: what is stored, what it is keyed by, and what
/// happens to a pin when the shortcut behind it goes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final controller = SavedShortcutsController.instance;

  Future<void> reset() async {
    SharedPreferences.setMockInitialValues({});
    controller.value = const [];
    controller.debugResetLoadedForTest();
    PinnedAppsController.instance.value = const [];
  }

  const chat = AppShortcut(
    package: 'com.example.messenger',
    id: 'chat-4711',
    label: 'Mama',
  );

  test('a kept shortcut survives a reload', () async {
    await reset();

    await controller.add(chat);

    // Simulate a fresh app start: drop what's in memory and read back.
    controller.value = const [];
    controller.debugResetLoadedForTest();
    await controller.load();

    expect(controller.value.length, 1);
    final stored = controller.value.single;
    expect(stored.package, 'com.example.messenger');
    expect(stored.shortcutId, 'chat-4711');
    expect(stored.name, 'Mama');
  });

  test('keeping the same shortcut twice keeps one', () async {
    await reset();

    final first = await controller.add(chat);
    final second = await controller.add(chat);

    expect(controller.value.length, 1);
    // Same entry, not a second one wearing a new id - otherwise pinning it
    // would silently pin a different thing than the one shown as kept.
    expect(second.id, first.id);
  });

  test('two shortcuts of one app get ids of their own', () async {
    await reset();

    final mama = await controller.add(chat);
    final papa = await controller.add(
      const AppShortcut(
        package: 'com.example.messenger',
        id: 'chat-4712',
        label: 'Papa',
      ),
    );

    expect(mama.id, isNot(papa.id));
    expect(controller.value.length, 2);
  });

  test('bySource finds what is already kept, and nothing else', () async {
    await reset();
    await controller.add(chat);

    expect(controller.bySource('com.example.messenger', 'chat-4711'), isNotNull);
    expect(controller.bySource('com.example.messenger', 'chat-9999'), isNull);
    expect(controller.bySource('com.example.other', 'chat-4711'), isNull);
  });

  test('the pin key is not a package name', () async {
    await reset();
    final saved = await controller.add(chat);

    final key = SavedShortcutsController.pinKeyFor(saved.id);
    expect(key.startsWith(shortcutKeyPrefix), isTrue);
    // A pinned list holds installed apps by their bare package name, so a
    // shortcut key that could be mistaken for one would resolve to the wrong
    // thing on the home screen.
    expect(key.contains('.'), isFalse);
    expect(LauncherEntry.shortcut(saved).key, key);
  });

  test('removing a kept shortcut takes its pin with it', () async {
    await reset();
    final saved = await controller.add(chat);
    final key = SavedShortcutsController.pinKeyFor(saved.id);

    await PinnedAppsController.instance.toggle(key);
    expect(PinnedAppsController.instance.isPinned(key), isTrue);

    await controller.remove(saved.id);

    expect(controller.value, isEmpty);
    // Left behind, the pin would keep occupying one of the six home screen
    // slots while drawing nothing at all.
    expect(PinnedAppsController.instance.isPinned(key), isFalse);
  });

  test('a kept shortcut is an entry like any other', () async {
    await reset();
    final saved = await controller.add(chat);

    LauncherEntriesController.instance.debugSetInstalledApps(const []);

    final entry = LauncherEntriesController.instance.byKey(
      SavedShortcutsController.pinKeyFor(saved.id),
    );
    expect(entry, isNotNull);
    expect(entry!.isShortcut, isTrue);
    expect(entry.name, 'Mama');
    // Which is what lets it be pinned, put in a folder and drawn as a
    // gesture without any of those knowing shortcuts exist.
    expect(
      LauncherEntriesController.instance.resolve([entry.key]).single.key,
      entry.key,
    );
  });

  test('refresh leaves everything alone when Android answers nothing', () async {
    await reset();
    await controller.add(chat);

    // Exactly what happens while another app is the home app. Dropping the
    // entries here would empty the home screen over something that fixes
    // itself a second later.
    await controller.refresh();

    expect(controller.value.length, 1);
    expect(controller.value.single.name, 'Mama');
  });
}
