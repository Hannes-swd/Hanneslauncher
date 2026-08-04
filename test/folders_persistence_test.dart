import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/folders_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('folders survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = FoldersController.instance;

    final folder = await controller.add('Spiele');
    await controller.addItem(folder.id, 'com.example.game');
    await controller.setColor(folder.id, 4);

    // Simulate a fresh app start: drop what's in memory and read back.
    controller.value = const [];
    controller.debugResetLoadedForTest();
    await controller.load();

    expect(controller.value.length, 1);
    expect(controller.value.single.name, 'Spiele');
    expect(controller.value.single.colorIndex, 4);
    expect(controller.value.single.itemKeys, ['com.example.game']);
  });

  test('a later load does not drop folders added meanwhile', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = FoldersController.instance;
    controller.value = const [];
    controller.debugResetLoadedForTest();

    await controller.load();
    await controller.add('Arbeit');
    // The app list reloading (e.g. after Android recreated the launcher)
    // must not wipe what was created in the meantime.
    await controller.load();

    expect(controller.value.map((f) => f.name), ['Arbeit']);
  });

  test('rapid unawaited changes all end up stored', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = FoldersController.instance;
    controller.value = const [];
    controller.debugResetLoadedForTest();

    final folder = await controller.add('Tools');
    // How the contents picker fires: a tap per item, none of them awaited.
    controller.addItem(folder.id, 'com.a');
    controller.addItem(folder.id, 'com.b');
    controller.addItem(folder.id, 'com.c');
    await Future<void>.delayed(Duration.zero);

    controller.value = const [];
    controller.debugResetLoadedForTest();
    await controller.load();

    expect(controller.value.single.itemKeys, ['com.a', 'com.b', 'com.c']);
  });
}
