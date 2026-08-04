import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the home button opens this launcher, and which app it opens
/// instead when it doesn't.
@immutable
class DefaultLauncherState {
  const DefaultLauncherState({
    this.isDefault = false,
    this.otherName,
    this.checked = false,
  });

  final bool isDefault;

  /// The launcher currently set as the default, when it isn't this one.
  /// Null when the phone has no default set at all - Android then answers
  /// with its own chooser, which has no name worth showing.
  final String? otherName;

  /// False until the first answer came back. Nothing is claimed before that:
  /// a fresh install would otherwise flash "not the home app" at someone who
  /// just made it exactly that.
  final bool checked;

  @override
  bool operator ==(Object other) =>
      other is DefaultLauncherState &&
      other.isDefault == isDefault &&
      other.otherName == otherName &&
      other.checked == checked;

  @override
  int get hashCode => Object.hash(isDefault, otherName, checked);
}

/// Asks Android which app is the home app, and sends the user to where that
/// can be changed - see the "hanneslauncher/system_apps" channel in
/// `MainActivity.kt`.
///
/// An installed launcher that was never made the default is a dead end
/// nobody sees: it only opens by tapping its icon, so the one thing the app
/// is for never happens. This is what the settings use to notice and say so.
class DefaultLauncherController extends ValueNotifier<DefaultLauncherState> {
  DefaultLauncherController._() : super(const DefaultLauncherState());

  static final DefaultLauncherController instance =
      DefaultLauncherController._();

  static const _channel = MethodChannel('hanneslauncher/system_apps');

  /// Remembers that the nudge on startup has had its one turn. Deliberately
  /// not part of the settings backup: it says what this install has already
  /// shown, not something the user configured, and carrying it to a fresh
  /// install would swallow the one prompt that install still needs.
  static const _promptShownKey = 'default_launcher_prompt_shown';

  /// Re-reads the current state. Cheap enough to call whenever the app comes
  /// back to the foreground, which is exactly when it can have changed -
  /// setting the default happens outside this app, in a system dialog.
  Future<void> refresh() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'defaultLauncher',
      );
      if (result == null) return;
      value = DefaultLauncherState(
        isDefault: result['isThisApp'] as bool? ?? false,
        otherName: result['name'] as String?,
        checked: true,
      );
    } catch (_) {
      // No channel (tests, another platform) - leave the state untouched
      // rather than claiming this isn't the home app.
    }
  }

  /// Whether the startup nudge should be shown now: this install has never
  /// shown it, and the home button still opens something else.
  ///
  /// Marks it as shown as it answers, so it stays a one-off however the user
  /// deals with it. Answers false while the state can't be read at all
  /// (which leaves the one turn unspent for the next start).
  Future<bool> takeFirstRunPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_promptShownKey) ?? false) return false;
    await refresh();
    if (!value.checked || value.isDefault) return false;
    await prefs.setBool(_promptShownKey, true);
    return true;
  }

  /// Opens the system dialog or settings screen where the home app is
  /// picked. False if Android offered no way in at all, which is when the
  /// written instructions are the only thing left.
  Future<bool> chooseDefault() async {
    try {
      final opened = await _channel.invokeMethod<bool>('chooseDefaultLauncher');
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }
}
