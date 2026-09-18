import 'package:flutter/foundation.dart';

/// Ticks once every time the home button is pressed while the launcher is
/// already the thing on screen.
///
/// Everywhere else on a phone, home means "back to the start". This launcher
/// was the one app that ignored it: Android hands a second press to a
/// running home app as a new intent rather than by restarting it, so nothing
/// in Flutter noticed, and the panel stayed open over a screen whose whole
/// job is to be where you end up.
///
/// A counter rather than a bare notifier so a listener can tell two presses
/// apart, and the same singleton-notifier shape as every other bit of shared
/// state here. What "the start" means is each screen's own business -
/// [AppListView] closes its search and scrolls up, `main.dart` shuts the
/// panel.
final ValueNotifier<int> homeResetSignal = ValueNotifier<int>(0);

void signalHomeReset() => homeResetSignal.value++;
