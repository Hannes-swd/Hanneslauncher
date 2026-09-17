import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/color_swatch_picker.dart';
import 'package:hanneslauncher/design_tokens.dart';
import 'package:hanneslauncher/folders_controller.dart';
import 'package:hanneslauncher/launcher_entries_controller.dart';
import 'package:hanneslauncher/launcher_entry.dart';
import 'package:hanneslauncher/notification_badges_controller.dart';
import 'package:hanneslauncher/pinned_apps_settings_screen.dart';
import 'package:hanneslauncher/secret_apps_controller.dart';
import 'package:installed_apps/app_category.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/platform_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The badge on a pinned app. The counting itself happens on the Android
/// side (only a bound notification listener may see what is waiting), so
/// what is testable here is everything the launcher does with those numbers
/// afterwards: which ones it refuses to show, and how a folder adds up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hanneslauncher/notifications');
  var platformCounts = <String, int>{};
  var platformState = <String, bool>{'enabled': true, 'connected': true};
  var opened = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    platformCounts = <String, int>{};
    platformState = <String, bool>{'enabled': true, 'connected': true};
    opened = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'counts':
              return platformCounts;
            case 'state':
              return platformState;
            case 'requestPermission':
            case 'openAppSettings':
              opened.add(call.method);
              return true;
            default:
              return null;
          }
        });
    SecretAppsController.instance.lock();
    await SecretAppsController.instance.restore(keys: const []);
    await FoldersController.instance.replaceAll(const []);
    await PinnedBadgeController.instance.update(const PinnedBadgeSettings());
    NotificationCounts.instance.debugSetCounts(const {});
  });

  LauncherEntry folderEntry(LauncherFolder folder) =>
      LauncherEntry.folder(folder);

  test('a package with nothing waiting carries no badge', () async {
    platformCounts = {'com.example.mail': 3, 'com.example.quiet': 0};

    await NotificationCounts.instance.refresh();

    expect(NotificationCounts.instance.value, {'com.example.mail': 3});
  });

  test('a hidden app never announces itself with a badge', () async {
    final unlock = await SecretAppsController.instance.setPassword('1234');
    await SecretAppsController.instance.add(unlock!, 'com.example.diary');
    platformCounts = {'com.example.diary': 2, 'com.example.mail': 1};

    await NotificationCounts.instance.refresh();

    expect(NotificationCounts.instance.value, {'com.example.mail': 1});
  });

  test('a folder adds up what is inside it, however deep', () async {
    await FoldersController.instance.replaceAll(const [
      LauncherFolder(
        id: '1',
        name: 'Nachrichten',
        itemKeys: ['com.example.mail', 'folder:2'],
      ),
      LauncherFolder(id: '2', name: 'Arbeit', itemKeys: ['com.example.chat']),
    ]);
    platformCounts = {'com.example.mail': 3, 'com.example.chat': 4};
    await NotificationCounts.instance.refresh();

    final outer = FoldersController.instance.byId('1')!;
    expect(NotificationCounts.instance.countFor(folderEntry(outer)), 7);
  });

  test('a folder holding itself still answers', () async {
    // Not something the UI can build today, but a backup from another phone
    // can name any key at all - and a loop here would hang the home screen.
    await FoldersController.instance.replaceAll(const [
      LauncherFolder(
        id: '1',
        name: 'Rund',
        itemKeys: ['folder:1', 'com.example.mail'],
      ),
    ]);
    platformCounts = {'com.example.mail': 2};
    await NotificationCounts.instance.refresh();

    final folder = FoldersController.instance.byId('1')!;
    expect(NotificationCounts.instance.countFor(folderEntry(folder)), 2);
  });

  test('the platform failing leaves no badges standing', () async {
    platformCounts = {'com.example.mail': 3};
    await NotificationCounts.instance.refresh();
    expect(NotificationCounts.instance.value, isNotEmpty);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'no listener'),
        );
    await NotificationCounts.instance.refresh();

    expect(NotificationCounts.instance.value, isEmpty);
  });

  test('the picked style and color are written where a restart finds them', () async {
    await PinnedBadgeController.instance.update(
      const PinnedBadgeSettings(style: PinnedBadgeStyle.count, colorIndex: 3),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pinned_badge_style'), 'count');
    expect(prefs.getInt('pinned_badge_color_index'), 3);
  });

  testWidgets('the settings screen offers all three, and picks one', (
    tester,
  ) async {
    LauncherEntriesController.instance.debugSetInstalledApps([
      const AppInfo(
        name: 'Mail',
        icon: null,
        packageName: 'com.example.mail',
        versionName: '1.0.0',
        versionCode: 1,
        platformType: PlatformType.nativeOrOthers,
        installedTimestamp: 0,
        isSystemApp: false,
        isLaunchableApp: true,
        category: AppCategory.undefined,
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(home: PinnedAppsSettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing'), findsOneWidget);
    expect(find.text('A dot'), findsOneWidget);
    expect(find.text('A number'), findsOneWidget);
    // Nothing to grant while no badge is wanted.
    expect(find.text('Access granted'), findsNothing);

    await tester.tap(find.text('A number'));
    await tester.pumpAndSettle();

    expect(PinnedBadgeController.instance.value.style, PinnedBadgeStyle.count);
    // The mock channel above answers switched on and connected, so the row
    // says so rather than offering the trip to Android's settings.
    expect(find.text('Access granted'), findsOneWidget);
    // And with it working there is nothing to unblock either.
    expect(find.text('Open app settings'), findsNothing);

    // The color row only appears once a badge is drawn at all. Third swatch
    // in the shared palette: the blue grey.
    expect(find.text('Badge color'), findsOneWidget);
    await tester.tap(find.byType(ColorDot).at(2));
    await tester.pumpAndSettle();

    expect(PinnedBadgeController.instance.value.colorIndex, 2);
    // Picking a color leaves the shape alone.
    expect(PinnedBadgeController.instance.value.style, PinnedBadgeStyle.count);
  });

  /// The settings screen, with one app installed and a badge already asked
  /// for - which is what brings the permission rows out at all.
  Future<void> pumpBadgeSettings(WidgetTester tester) async {
    LauncherEntriesController.instance.debugSetInstalledApps([
      const AppInfo(
        name: 'Mail',
        icon: null,
        packageName: 'com.example.mail',
        versionName: '1.0.0',
        versionCode: 1,
        platformType: PlatformType.nativeOrOthers,
        installedTimestamp: 0,
        isSystemApp: false,
        isLaunchableApp: true,
        category: AppCategory.undefined,
      ),
    ]);
    await PinnedBadgeController.instance.update(
      const PinnedBadgeSettings(style: PinnedBadgeStyle.dot),
    );
    await tester.pumpWidget(const MaterialApp(home: PinnedAppsSettingsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('a listener that is on but not reading says so', (tester) async {
    // The state the old single "granted" answer could not tell apart, and
    // the one a new APK over the old one leaves behind: switched on, bound
    // to nothing, every count zero.
    platformState = {'enabled': true, 'connected': false};

    await pumpBadgeSettings(tester);

    expect(find.text('Access granted'), findsNothing);
    expect(find.text('Switched on, but nothing is arriving'), findsOneWidget);

    // Both ways into Android's settings are offered, because either one can
    // be what is in the way.
    for (final row in const [
      'Switched on, but nothing is arriving',
      'Open app settings',
    ]) {
      await tester.ensureVisible(find.text(row));
      await tester.pumpAndSettle();
      await tester.tap(find.text(row));
      await tester.pumpAndSettle();
    }
    expect(opened, ['requestPermission', 'openAppSettings']);

    // Disposes the screen, and with it the timer that keeps re-asking.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a listener that was never switched on offers the way in', (
    tester,
  ) async {
    platformState = {'enabled': false, 'connected': false};

    await pumpBadgeSettings(tester);

    expect(find.text('Allow notification access'), findsOneWidget);
    // The restricted-settings way in matters most here: on a phone that
    // refuses to keep the switch on, the first row alone is a dead end.
    expect(find.text('Open app settings'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  test('a platform that cannot answer at all is simply not working', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw MissingPluginException(),
        );

    final access = await NotificationCounts.state();

    expect(access, NotificationAccess.none);
    expect(access.working, isFalse);
    expect(access.stalled, isFalse);
  });

  test('the badge text is readable on whatever color was picked', () {
    // White and black are both in the base palette, and a badge in either
    // with fixed white digits on it would be unreadable one way or the
    // other.
    expect(
      DesignTokens.inkOn(Colors.white).computeLuminance(),
      lessThan(0.5),
    );
    expect(
      DesignTokens.inkOn(Colors.black).computeLuminance(),
      greaterThan(0.5),
    );
  });

  test('an unknown stored style means no badge rather than a crash', () {
    expect(
      PinnedBadgeController.styleFromName('something-new'),
      PinnedBadgeStyle.none,
    );
    expect(PinnedBadgeController.styleFromName(null), PinnedBadgeStyle.none);
    expect(
      PinnedBadgeController.styleFromName('dot'),
      PinnedBadgeStyle.dot,
    );
  });
}
