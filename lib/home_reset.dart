import 'package:flutter/widgets.dart';

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
/// panel and closes the pages above it with [popToHome].
final ValueNotifier<int> homeResetSignal = ValueNotifier<int>(0);

void signalHomeReset() => homeResetSignal.value++;

/// Closes every page and dialog above the home screen, the way the home
/// gesture leaves any other app - the settings above all, which it used to
/// leave standing. True when there was anything above it.
///
/// Each page goes the way back would take it, and one that would refuse
/// back is not forced: the recovery code that must be read before it goes,
/// the terminal's editor that asks whether to save. That one is asked
/// instead, so the editor puts its question and a stray swipe never throws
/// away a file. Whatever sits under it stays too - it is in the way.
bool popToHome(NavigatorState navigator) {
  var popped = false;
  var guarded = false;
  navigator.popUntil((route) {
    if (route.isFirst) return true;
    if (route.popDisposition == RoutePopDisposition.doNotPop) {
      guarded = true;
      return true;
    }
    popped = true;
    return false;
  });
  if (guarded) navigator.maybePop();
  return popped || guarded;
}
