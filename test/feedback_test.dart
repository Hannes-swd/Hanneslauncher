import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/feedback_mail.dart';

void main() {
  const full = FeedbackEnvironment(
    appVersion: '1.15.0',
    device: 'Google Pixel 7',
    androidVersion: '14 (API 34)',
    language: 'German',
  );

  group('the mail asks for what a report needs', () {
    test('a bug mail asks the three questions that decide a bug', () {
      final body = feedbackBody(FeedbackKind.bug, full);
      expect(body, contains('What went wrong?'));
      expect(body, contains('What did you do right before it happened?'));
      expect(body, contains('What did you expect to happen instead?'));
    });

    test('an idea mail asks what it would be good for', () {
      final body = feedbackBody(FeedbackKind.idea, full);
      expect(body, contains("What's your idea?"));
      expect(body, contains('What would it be good for'));
      // Not a bug form in disguise.
      expect(body, isNot(contains('What went wrong?')));
    });

    test('every question has an empty line under it to write on', () {
      final body = feedbackBody(FeedbackKind.bug, full);
      expect(body, contains('What went wrong?\n\n\n'));
    });
  });

  group('the install is named in the mail', () {
    test('version, phone, Android and language all travel along', () {
      final body = feedbackBody(FeedbackKind.bug, full);
      expect(body, contains('App version: 1.15.0'));
      expect(body, contains('Phone: Google Pixel 7'));
      expect(body, contains('Android: 14 (API 34)'));
      expect(body, contains('App language: German'));
    });

    test('the subject carries the version, so two reports can be told apart', () {
      expect(
        feedbackSubject(FeedbackKind.bug, full),
        'hanneslauncher bug report (1.15.0)',
      );
      expect(
        feedbackSubject(FeedbackKind.idea, full),
        'hanneslauncher idea (1.15.0)',
      );
    });

    test('what could not be read is left out, not sent empty', () {
      // What the emulator, a test, or a channel that isn't there gives.
      const nothing = FeedbackEnvironment();
      final body = feedbackBody(FeedbackKind.bug, nothing);
      expect(body, isNot(contains('App version:')));
      expect(body, isNot(contains('Phone:')));
      expect(body, isNot(contains('please leave this in')));
      // The questions are still all there - the mail is still worth sending.
      expect(body, contains('What went wrong?'));
      expect(feedbackSubject(FeedbackKind.bug, nothing), isNot(contains('(')));
    });
  });

  group('the phone is named the way people name it', () {
    test('manufacturer and model', () {
      expect(describeDevice('Google', 'Pixel 7'), 'Google Pixel 7');
    });

    test('a lowercase manufacturer is capitalised', () {
      expect(describeDevice('samsung', 'SM-G991B'), 'Samsung SM-G991B');
    });

    test('a manufacturer already in the model is not repeated', () {
      expect(describeDevice('Xiaomi', 'Xiaomi 13'), 'Xiaomi 13');
      expect(describeDevice('samsung', 'samsung galaxy'), 'Samsung galaxy');
    });

    test('a spelling of its own is left alone', () {
      expect(describeDevice('OnePlus', 'CPH2399'), 'OnePlus CPH2399');
    });

    test('a missing half still gives something readable', () {
      expect(describeDevice('', 'Pixel 7'), 'Pixel 7');
      expect(describeDevice('google', ''), 'Google');
      expect(describeDevice('', ''), '');
    });

    test('the Android version carries the API level', () {
      expect(describeAndroid('14', 34), '14 (API 34)');
      expect(describeAndroid('14', 0), '14');
      expect(describeAndroid('', 34), 'API 34');
      expect(describeAndroid('', 0), '');
    });
  });

  group('the link the mail app is handed', () {
    final uri = feedbackMailto(FeedbackKind.bug, full);

    test('goes to the one address', () {
      expect(uri.scheme, 'mailto');
      expect(uri.path, kFeedbackAddress);
    });

    test('subject and body arrive as written', () {
      expect(uri.queryParameters['subject'], feedbackSubject(FeedbackKind.bug, full));
      expect(uri.queryParameters['body'], feedbackBody(FeedbackKind.bug, full));
    });

    test('a space is a space, not a plus', () {
      // Uri's own query builder writes spaces as "+", which mail apps drop
      // into the body as literal plus signs - the whole reason this link is
      // assembled by hand.
      expect(uri.toString(), isNot(contains('+')));
      expect(uri.toString(), contains('%20'));
    });
  });

  group('the platform side the screen depends on', () {
    // Both of these fail silently in the app: a method MainActivity does not
    // answer comes back as a MissingPluginException the screen swallows, and
    // a missing <queries> entry makes Android hide every mail app, so the
    // button does nothing at all with no error anywhere.
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/example/hanneslauncher/MainActivity.kt',
    ).readAsStringSync();

    test('the manifest lets the launcher see a mail app', () {
      final queries = manifest.substring(
        manifest.indexOf('<queries>'),
        manifest.indexOf('</queries>'),
      );
      // Line breaks and indentation say nothing here, so they are taken
      // out before looking for the pair.
      final compact = queries.replaceAll(RegExp(r'\s+'), ' ');
      for (final action in ['VIEW', 'SENDTO']) {
        expect(
          compact,
          contains(
            '<action android:name="android.intent.action.$action"/> '
            '<data android:scheme="mailto"/>',
          ),
          reason: 'no <queries> entry for $action on mailto:',
        );
      }
    });

    test('MainActivity answers the method the screen asks for', () {
      final start = kotlin.indexOf('appInfoChannelName)');
      expect(start, isNot(-1));
      final handler = kotlin.substring(start, kotlin.indexOf('else -> result.notImplemented()', start));
      expect(handler, contains('"device" ->'));
    });

    test('the device facts the mail prints are the ones Kotlin sends', () {
      for (final key in ['manufacturer', 'model', 'androidRelease', 'sdkInt']) {
        expect(kotlin, contains('"$key" to'), reason: key);
        expect(
          File('lib/feedback_screen.dart').readAsStringSync(),
          contains("['$key']"),
          reason: key,
        );
      }
    });
  });
}
