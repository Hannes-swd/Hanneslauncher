/// What a report mail says, and the link that opens one already filled in.
///
/// Kept apart from the screen and free of anything platform-specific: the
/// body is the part that has to be right - a report without the version and
/// the phone in it costs a round trip before it can even be looked at - and
/// this way a test can read it.
library;

/// Where reports go.
const String kFeedbackAddress = 'stellarfrog0@gmail.com';

/// The two things someone can send.
enum FeedbackKind { bug, idea }

/// The facts about this install that go at the end of every mail, so nobody
/// has to be asked "which version?" first.
class FeedbackEnvironment {
  const FeedbackEnvironment({
    this.appVersion = '',
    this.device = '',
    this.androidVersion = '',
    this.language = '',
  });

  /// The installed app version, as the update check already reads it.
  final String appVersion;

  /// Manufacturer and model, see [describeDevice].
  final String device;

  /// "14 (API 34)", see [describeAndroid] - the mail's own line already
  /// says the word Android.
  final String androidVersion;

  /// The language the app is running in, spelled out in English like the
  /// rest of the mail.
  final String language;

  /// The lines for the block at the bottom. Anything that couldn't be read
  /// is left out entirely rather than sent as an empty label - a line
  /// saying "Device:" and nothing else only looks like the mail broke.
  List<String> get lines => [
    if (appVersion.isNotEmpty) 'App version: $appVersion',
    if (device.isNotEmpty) 'Phone: $device',
    if (androidVersion.isNotEmpty) 'Android: $androidVersion',
    if (language.isNotEmpty) 'App language: $language',
  ];
}

/// "Google Pixel 7" - but "Samsung SM-G991B" rather than "samsung SM-G991B",
/// and never "Xiaomi Xiaomi 13" either: plenty of manufacturers already put
/// their own name in the model, and repeating it reads like a bug in the
/// report itself.
String describeDevice(String manufacturer, String model) {
  final maker = manufacturer.trim();
  final name = model.trim();
  if (maker.isEmpty) return name;
  if (name.isEmpty) return _capitalized(maker);
  if (name.toLowerCase().startsWith(maker.toLowerCase())) {
    return _capitalized(name);
  }
  return '${_capitalized(maker)} $name';
}

/// "14 (API 34)", for the mail's `Android:` line. The API level is worth
/// carrying along even though it looks redundant: what an Android version is
/// allowed to do is decided by that number, and it's the one Android's own
/// docs are written against.
String describeAndroid(String release, int sdkInt) {
  final version = release.trim();
  if (version.isEmpty) return sdkInt > 0 ? 'API $sdkInt' : '';
  return sdkInt > 0 ? '$version (API $sdkInt)' : version;
}

String _capitalized(String value) {
  if (value.isEmpty) return value;
  // Only the first letter, and only when the word is all lowercase -
  // "samsung" becomes "Samsung", while "OnePlus" and "ZTE" keep their own
  // spelling.
  if (value != value.toLowerCase()) return value;
  return value[0].toUpperCase() + value.substring(1);
}

/// The subject line. Carries the version so two mails about the same thing
/// from different versions can be told apart at a glance.
String feedbackSubject(FeedbackKind kind, FeedbackEnvironment env) {
  final version = env.appVersion.isEmpty ? '' : ' (${env.appVersion})';
  return switch (kind) {
    FeedbackKind.bug => 'hanneslauncher bug report$version',
    FeedbackKind.idea => 'hanneslauncher idea$version',
  };
}

/// The prefilled mail.
///
/// Written in English regardless of the language the app is set to: it is
/// one inbox, and a report that arrives in a language it can be read in
/// beats one that has to be translated first. The mail says outright that
/// answering in German is fine, so nobody is stopped by it.
///
/// Questions with an empty line under each, rather than one "describe the
/// problem" box: the three things that actually decide whether a bug can be
/// found - what you did, what happened, what you expected - are the three
/// people leave out when nothing asks for them.
String feedbackBody(FeedbackKind kind, FeedbackEnvironment env) {
  final questions = switch (kind) {
    FeedbackKind.bug => const [
      'What went wrong?',
      'What did you do right before it happened?',
      'What did you expect to happen instead?',
      'Does it happen every time, or only sometimes?',
      'Anything else? (A screenshot helps a lot.)',
    ],
    FeedbackKind.idea => const [
      "What's your idea?",
      'What would it be good for - what are you trying to do?',
      'How do you imagine it working?',
      'Anything else? (A sketch or a screenshot helps.)',
    ],
  };

  final intro = switch (kind) {
    FeedbackKind.bug =>
      'Thanks for reporting this. Just write under the questions below - '
          'German is fine too, and anything you leave empty is fine as well.',
    FeedbackKind.idea =>
      'Thanks for the idea. Just write under the questions below - German '
          'is fine too, and anything you leave empty is fine as well.',
  };

  final buffer = StringBuffer()
    ..writeln(intro)
    ..writeln();
  for (final question in questions) {
    buffer
      ..writeln(question)
      ..writeln()
      ..writeln();
  }
  final lines = env.lines;
  if (lines.isNotEmpty) {
    buffer
      ..writeln('--- about this install, please leave this in ---')
      ..writeAll(lines, '\n')
      ..writeln();
  }
  return buffer.toString();
}

/// The `mailto:` link that opens the mail app with all of it already in
/// place.
///
/// Built by hand instead of through [Uri]'s own query map: that one encodes
/// a space as `+`, which mail apps drop into the body as a literal plus
/// sign, and a form full of pluses is exactly the kind of thing that makes
/// someone close it again.
Uri feedbackMailto(FeedbackKind kind, FeedbackEnvironment env) {
  final subject = Uri.encodeComponent(feedbackSubject(kind, env));
  final body = Uri.encodeComponent(feedbackBody(kind, env));
  return Uri.parse('mailto:$kFeedbackAddress?subject=$subject&body=$body');
}
