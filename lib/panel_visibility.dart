import 'package:flutter/foundation.dart';

/// Whether the pull-down panel is on screen.
///
/// The panel is never taken out of the tree - it sits translated off-screen
/// so it can be dragged in without being rebuilt. For a row of icons that
/// costs nothing. A code widget is a running web page, though, and a phone
/// whose launcher quietly keeps three of those alive behind a panel nobody
/// has opened is a phone with a worse battery for no reason at all.
class PanelVisibility extends ValueNotifier<bool> {
  PanelVisibility._() : super(false);

  static final PanelVisibility instance = PanelVisibility._();

  /// Whether the panel's heavy cards - code widgets, Android app widgets -
  /// may be built. Once true it stays true: taking a page down again on
  /// every close would mean a reload, and the loss of whatever the page was
  /// holding, each time the panel is opened.
  ///
  /// Set by the first pull-down, or by [warmUp] shortly after start,
  /// whichever comes first. Waiting for the pull-down alone put the creation
  /// of every web view and widget view into the very first frames of that
  /// drag - the one moment it is watched most closely - and the first
  /// opening after each start stuttered while later ones ran smoothly.
  final ValueNotifier<bool> warm = ValueNotifier(false);

  bool get everOpened => warm.value;

  /// Lets the heavy cards be built now, with the panel still shut. Called
  /// once the home screen has been up and idle for a moment, so their cost
  /// falls where nothing is moving.
  void warmUp() => warm.value = true;

  @override
  set value(bool open) {
    if (open) warm.value = true;
    super.value = open;
  }
}
