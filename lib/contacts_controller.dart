import 'package:flutter/services.dart';

/// One contact a search turned up.
class ContactHit {
  const ContactHit({required this.name, required this.number});

  final String name;

  /// The first number stored for them. Somebody with a mobile and a landline
  /// comes back once, with whichever Android lists first - a search result
  /// row is not the place to make the user choose between two numbers.
  final String number;
}

/// Reads the phone's contacts for a widget card's search element.
///
/// The permission is asked for at the moment somebody actually searches with
/// "Kontakte" ticked, never at startup: a launcher set up without that box
/// should never see the prompt at all.
class ContactsController {
  ContactsController._();

  static final ContactsController instance = ContactsController._();

  static const _channel = MethodChannel('hanneslauncher/contacts');

  /// Cached only once it is a yes: the search element asks on every
  /// keystroke, and a platform call per character would be waste. A no is
  /// never cached for long - see [ensureAvailable].
  bool _granted = false;

  /// Whether Android's own prompt has been put up during this run. Only the
  /// prompt is once-per-run, not the answer.
  bool _asked = false;

  bool get isGranted => _granted;

  Future<bool> refreshPermission() async {
    try {
      _granted = await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } on PlatformException {
      _granted = false;
    }
    return _granted;
  }

  /// Shows Android's own prompt.
  Future<bool> requestPermission() async {
    _asked = true;
    try {
      _granted = await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      _granted = false;
    }
    return _granted;
  }

  /// Whether contacts can be read right now, asking for the permission if it
  /// has not been asked for yet.
  ///
  /// The re-check on the way through matters: turning the permission on by
  /// hand in Android's settings has to start working straight away.
  /// Remembering a "no" instead - which is what this used to do - left
  /// contacts silently dead until the launcher was restarted, with nothing
  /// on screen saying why or offering to ask again.
  ///
  /// The prompt itself still goes up only once per run, so typing on after a
  /// refusal doesn't put a dialog in front of every keystroke.
  Future<bool> ensureAvailable() async {
    if (_granted) return true;
    if (await refreshPermission()) return true;
    if (_asked) return false;
    return requestPermission();
  }

  /// Matches against names and numbers alike, so "mei" and "0171" both work.
  /// Comes back empty rather than throwing when the permission is missing -
  /// the search element then simply shows no contact rows.
  Future<List<ContactHit>> search(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) return const [];
    if (!_granted) return const [];
    try {
      final raw = await _channel.invokeListMethod<Object?>('search', {
        'query': query,
        'limit': limit,
      });
      if (raw == null) return const [];
      return [
        for (final entry in raw)
          if (entry is Map)
            ContactHit(
              name: entry['name'] as String? ?? '',
              number: entry['number'] as String? ?? '',
            ),
      ];
    } on PlatformException {
      return const [];
    }
  }

  /// Puts the number in the dialer and stops there - the user presses the
  /// call button. That needs no CALL_PHONE permission and cannot dial by
  /// accident from a mistapped search result.
  Future<void> dial(String number) async {
    try {
      await _channel.invokeMethod<bool>('dial', {'number': number});
    } on PlatformException {
      // Nothing on the phone answers it; there is no second way to try.
    }
  }
}
