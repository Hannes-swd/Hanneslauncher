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

  /// Whether the panel has been pulled down at least once since the app
  /// started. A code widget waits for this and then keeps running: taking
  /// its page down again on every close would mean a reload - and the loss
  /// of whatever the page was holding - each time the panel is opened.
  bool get everOpened => _everOpened;
  bool _everOpened = false;

  @override
  set value(bool open) {
    if (open) _everOpened = true;
    super.value = open;
  }
}
