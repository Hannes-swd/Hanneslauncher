import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'panel_blocks_controller.dart';
import 'panel_visibility.dart';
import 'pinned_apps_controller.dart';

/// The walk-through of the basics, run on the real home screen.
///
/// It does not draw a copy of anything. Each task asks for a real gesture -
/// holding the home screen, swiping the letters, pulling the panel down - and
/// the walk-through notices when it happens. Until then the thing to touch is
/// outlined on the real screen, and the short line saying what to do is in
/// intro_tutorial_overlay.dart.
///
/// Whether the walk-through has been shown on this install is remembered as
/// well. It is about this install, not the home screen, so it stays out of the
/// backup: a fresh phone restored from one still gets it once.
class IntroTutorialController {
  IntroTutorialController._() {
    PinnedAppsController.instance.addListener(_check);
    PanelVisibility.instance.addListener(_onPanelVisibility);
    PanelBlocksController.instance.addListener(_check);
  }

  static final IntroTutorialController instance = IntroTutorialController._();

  static const _doneKey = 'intro_tutorial_done';

  /// Step 0 is the language, then one step per task.
  static const taskCount = 5;

  /// How long a finished task stays on screen before the next one comes.
  static const advanceDelay = Duration(milliseconds: 900);

  /// The step on screen, or null while the walk-through is not running.
  final ValueNotifier<int?> step = ValueNotifier(null);

  /// Whether the real gesture for the current task has happened.
  final ValueNotifier<bool> achieved = ValueNotifier(false);

  /// Whether the home screen's menu is open right now. The first task has two
  /// parts - opening the menu, then picking an app in it - and the words on
  /// the card depend on which one is due.
  final ValueNotifier<bool> homeEditOpen = ValueNotifier(false);

  // Counted rather than flagged, so a task can ask for something new: a letter
  // touched after the step started, a settings page opened after it started.
  int _letterTouches = 0;
  int _settingsOpenings = 0;
  int _panelOpenings = 0;

  // What the counted and listed things were at the start of the current step.
  int _baseline = 0;

  Timer? _advance;
  Completer<void>? _finished;

  /// True exactly once per install. Marks it as shown while it answers, so
  /// leaving the walk-through half way still counts as having seen it.
  Future<bool> takeFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey) ?? false) return false;
    await prefs.setBool(_doneKey, true);
    return true;
  }

  /// Starts the walk-through on the home screen. The future completes when it
  /// is closed, however that happens.
  Future<void> start() {
    _finished?.complete();
    _finished = Completer<void>();
    _enter(0);
    return _finished!.future;
  }

  void next() {
    final current = step.value;
    if (current == null) return;
    if (current >= taskCount) {
      finish();
    } else {
      _enter(current + 1);
    }
  }

  void back() {
    final current = step.value;
    if (current == null || current == 0) return;
    _enter(current - 1);
  }

  void finish() {
    _advance?.cancel();
    _advance = null;
    step.value = null;
    achieved.value = false;
    homeEditOpen.value = false;
    _finished?.complete();
    _finished = null;
  }

  /// Called by the app list whenever a letter of the alphabet bar is picked.
  void noteLetter() {
    _letterTouches++;
    _check();
  }

  // Only a panel that was not open a moment ago counts - one left open from the
  // step before must not finish this task on its own.
  void _onPanelVisibility() {
    if (PanelVisibility.instance.value) _panelOpenings++;
    _check();
  }

  /// Called by the settings screen when it opens.
  void noteSettingsOpened() {
    _settingsOpenings++;
    _check();
  }

  /// Called when the home screen's menu opens and closes. The next task waits
  /// while the menu is still up, so the card does not jump ahead behind it.
  void noteHomeEditOpened() => homeEditOpen.value = true;

  void noteHomeEditClosed() {
    homeEditOpen.value = false;
    if (achieved.value) _scheduleAdvance();
  }

  void _enter(int next) {
    _advance?.cancel();
    _advance = null;
    step.value = next;
    achieved.value = false;
    _baseline = switch (next) {
      1 => PinnedAppsController.instance.value.length,
      2 => _letterTouches,
      3 => _panelOpenings,
      4 => PanelBlocksController.instance.value.length,
      5 => _settingsOpenings,
      _ => 0,
    };
    // The gesture may already have happened, e.g. the panel is still open
    // from the step before.
    _check();
  }

  void _check() {
    final current = step.value;
    if (current == null || achieved.value) return;
    final done = switch (current) {
      1 => PinnedAppsController.instance.value.length > _baseline,
      2 => _letterTouches > _baseline,
      3 => _panelOpenings > _baseline,
      4 => PanelBlocksController.instance.value.length > _baseline,
      5 => _settingsOpenings > _baseline,
      _ => false,
    };
    if (!done) return;
    achieved.value = true;
    if (!homeEditOpen.value) _scheduleAdvance();
  }

  void _scheduleAdvance() {
    _advance?.cancel();
    final current = step.value;
    _advance = Timer(advanceDelay, () {
      if (step.value != current || !achieved.value) return;
      if (homeEditOpen.value) return;
      next();
    });
  }
}
