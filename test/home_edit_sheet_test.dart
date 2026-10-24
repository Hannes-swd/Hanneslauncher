import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/design_controller.dart';
import 'package:hanneslauncher/design_tokens.dart';
import 'package:hanneslauncher/home_edit_sheet.dart';
import 'package:hanneslauncher/launcher_entries_controller.dart';
import 'package:hanneslauncher/locale_controller.dart';
import 'package:hanneslauncher/pinned_apps_controller.dart';
import 'package:installed_apps/app_category.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/platform_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The menu behind a long press on the home screen: the pinned apps side by
/// side as round icons with a "+" after them. Drawn here full - all six
/// places taken, long names - on a narrow phone, because a row of icons is
/// exactly the layout that runs out of width first.
void main() {
  AppInfo app(String name, String package) => AppInfo(
    name: name,
    icon: null,
    packageName: package,
    versionName: '1.0.0',
    versionCode: 1,
    platformType: PlatformType.nativeOrOthers,
    installedTimestamp: 0,
    isSystemApp: false,
    isLaunchableApp: true,
    category: AppCategory.undefined,
  );

  final apps = [
    for (var i = 0; i < PinnedAppsController.maxPinned; i++)
      app('An app with a rather long name $i', 'com.example.app$i'),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocaleController.instance.value = AppLanguage.de;
    await DesignController.instance.update(DesignSettings());
    LauncherEntriesController.instance.debugSetInstalledApps(apps);
    await PinnedAppsController.instance.restore([
      for (final app in apps) app.packageName,
    ]);
  });

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = DesignController.instance.value;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(settings),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showHomeEditSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a full row fits on a narrow phone', (tester) async {
    await openSheet(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('6/6'), findsOneWidget);
    expect(find.text('Neu'), findsOneWidget);
    // All of them side by side at once, none scrolled off the edge.
    expect(tester.getRect(find.text('Neu')).right, lessThan(360));
    for (final app in apps) {
      expect(find.text(app.name).hitTestable(), findsOneWidget);
    }
    // The four shortcuts under the row.
    expect(find.text('Uhr'), findsOneWidget);
    expect(find.text('Hintergrund'), findsOneWidget);
  });

  testWidgets('the minus on an icon unpins it', (tester) async {
    await openSheet(tester);
    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pumpAndSettle();
    expect(PinnedAppsController.instance.value, hasLength(5));
    expect(find.text('5/6'), findsOneWidget);
  });
}
