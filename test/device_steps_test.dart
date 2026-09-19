import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/device_stats_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What "steps today" actually counts.
///
/// Android's step counter only ever reports a running total since the
/// device last booted - there is no history to ask for, so "since
/// midnight" has to be reconstructed from readings the app took itself.
/// Which reading stands in for midnight is the whole question, and getting
/// it wrong is not visible as an error: the number just reads low.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hanneslauncher/device_stats');

  late int sensor;

  /// One reading, the way the panel takes one. Which day the controller
  /// thinks it is comes from what is already in SharedPreferences, so a
  /// "yesterday" is set up by seeding those keys rather than by moving the
  /// clock.
  Future<int?> read(int raw) async {
    sensor = raw;
    await DeviceStatsController.instance.refresh(wantsSteps: true);
    return DeviceStatsController.instance.stepsToday;
  }

  setUp(() {
    sensor = 0;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'hasStepsPermission':
              return true;
            case 'stepCounterRaw':
              return sensor;
            case 'battery':
              return <String, Object?>{'percent': 50, 'charging': false};
            case 'storage':
              return <String, Object?>{'freeBytes': 1, 'totalBytes': 2};
            case 'connectionType':
              return 'wifi';
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  String today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  test('the first ever reading starts the count at zero', () async {
    // Nothing from before exists to count up from, so today starts here -
    // this is the one case where the old behaviour was the only option.
    expect(await read(5000), 0);
  });

  test('later readings the same day count up from it', () async {
    await read(5000);
    expect(await read(5600), 600);
  });

  test('a new day counts from the last reading before midnight', () async {
    // The defect this replaces: the baseline used to be whatever the
    // counter read when the panel was first opened, so opening it at two
    // in the afternoon answered 0 and threw the whole morning away.
    SharedPreferences.setMockInitialValues({
      'steps_baseline_count': 1000,
      'steps_baseline_date': 'yesterday',
      'steps_last_raw': 9000,
      'steps_last_raw_date': 'yesterday',
    });

    // Woke up, walked 1200 steps, and only now pulled the panel down.
    expect(await read(10200), 1200);
  });

  test('a reboot mid-day counts on from the reboot, not from zero forever', () async {
    await read(8000);
    expect(await read(8500), 500);

    // The phone restarts: the sensor begins again at zero, below the stored
    // baseline. The count before it is gone - the sensor no longer knows
    // it - but what comes after has to keep counting.
    expect(await read(0), 0);
    expect(await read(300), 300);
    expect(await read(900), 900);
  });

  test('the baseline is written back on a reboot, not only used', () async {
    // The bug underneath the one above: the reset used to answer 0 without
    // storing anything, so every later reading kept comparing against a
    // number the counter would not reach again and the count stayed at 0
    // for the rest of the day.
    await read(8000);
    await read(20);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('steps_baseline_count'), 0);
  });

  test('a reboot overnight counts from the reboot', () async {
    // The last reading from yesterday is higher than the counter now, so
    // the counter restarted in between. Its own zero is then the only
    // honest floor - and the closest one, since a phone restarted
    // overnight has been counting from roughly the start of the day.
    SharedPreferences.setMockInitialValues({
      'steps_baseline_count': 1000,
      'steps_baseline_date': 'yesterday',
      'steps_last_raw': 12000,
      'steps_last_raw_date': 'yesterday',
    });

    expect(await read(450), 450);
  });

  test('every reading is kept, so tomorrow has one from before midnight', () async {
    await read(7100);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('steps_last_raw'), 7100);
    expect(prefs.getString('steps_last_raw_date'), today());
  });
}
