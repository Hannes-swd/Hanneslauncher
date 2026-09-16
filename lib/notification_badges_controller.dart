import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;
import 'folders_controller.dart';
import 'launcher_entry.dart';
import 'secret_apps_controller.dart';

/// What a pinned app shows while notifications are waiting in it.
enum PinnedBadgeStyle {
  /// Nothing at all - how the launcher behaved before this existed, and
  /// still the default: the badge costs a permission, so it is never on
  /// until it is asked for.
  none,

  /// A single dot: something is there, without saying how much.
  dot,

  /// The number of waiting notifications.
  count,
}

/// How the badge on a pinned app looks: which of the three shapes, and in
/// which color.
class PinnedBadgeSettings {
  const PinnedBadgeSettings({
    this.style = PinnedBadgeStyle.none,
    this.colorIndex = defaultColorIndex,
  });

  /// The red at the end of the base palette. Every launcher's badge is red
  /// for a reason - it is read as "unread" before it is read as a color -
  /// so that is where this starts, and the picker is for taste from there.
  static const defaultColorIndex = 6;

  final PinnedBadgeStyle style;

  /// Index into [appListColorPalette], the same palette every other color
  /// setting in the app uses.
  final int colorIndex;

  /// Clamped rather than indexed straight: a backup from a phone with more
  /// hand-picked colors than this one has can name an index past the end.
  Color get color {
    final palette = appListColorPalette;
    return palette[colorIndex.clamp(0, palette.length - 1)];
  }

  PinnedBadgeSettings copyWith({PinnedBadgeStyle? style, int? colorIndex}) {
    return PinnedBadgeSettings(
      style: style ?? this.style,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PinnedBadgeSettings &&
      other.style == style &&
      other.colorIndex == colorIndex;

  @override
  int get hashCode => Object.hash(style, colorIndex);
}

/// What the user picked. Only the pinned apps on the home screen use it;
/// the app list itself stays plain.
class PinnedBadgeController extends ValueNotifier<PinnedBadgeSettings> {
  PinnedBadgeController._() : super(const PinnedBadgeSettings());

  static final PinnedBadgeController instance = PinnedBadgeController._();

  static const _styleKey = 'pinned_badge_style';
  static const _colorKey = 'pinned_badge_color_index';

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    value = PinnedBadgeSettings(
      style: styleFromName(prefs.getString(_styleKey)),
      colorIndex:
          prefs.getInt(_colorKey) ?? PinnedBadgeSettings.defaultColorIndex,
    );
  }

  Future<void> update(PinnedBadgeSettings settings) async {
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, settings.style.name);
    await prefs.setInt(_colorKey, settings.colorIndex);
  }

  /// Anything unknown (an older or newer backup, a cleared setting) means
  /// "off", which is the one answer that never needs a permission.
  static PinnedBadgeStyle styleFromName(Object? name) {
    for (final style in PinnedBadgeStyle.values) {
      if (style.name == name) return style;
    }
    return PinnedBadgeStyle.none;
  }
}

/// How many notifications each package currently has waiting, read from
/// Android's notification listener - the same permission the offline mode's
/// music line needs, because it is the same service behind both.
///
/// Nothing here keeps a notification's text, sender or icon: the platform
/// side counts them and hands over numbers only.
///
/// The counts are polled rather than pushed: the home screen is the only
/// thing that draws them, so they are only worth reading while it is on
/// screen - [setVisible] is what starts and stops that.
class NotificationCounts extends ValueNotifier<Map<String, int>> {
  NotificationCounts._() : super(const {}) {
    PinnedBadgeController.instance.addListener(_sync);
  }

  static final NotificationCounts instance = NotificationCounts._();

  static const _channel = MethodChannel('hanneslauncher/notifications');

  /// Often enough that a message lands on the badge while looking at the
  /// home screen, rarely enough to stay invisible in the battery stats -
  /// nothing runs at all while the launcher is in the background.
  static const _pollInterval = Duration(seconds: 3);

  Timer? _timer;
  bool _visible = false;

  /// Whether this app is switched on as a notification listener. Without it
  /// every count is zero, and the settings screen offers the way in.
  static Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android's "Notification access" screen. There is no runtime
  /// prompt for this permission - that screen is the only way to grant it.
  static Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Called by the home screen as it comes and goes, so the polling only
  /// runs while somebody is actually looking at the badges.
  void setVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (!_visible ||
        PinnedBadgeController.instance.value.style == PinnedBadgeStyle.none) {
      // Switched off mid-session: drop what was read rather than leaving the
      // last badges frozen on screen.
      if (value.isNotEmpty) value = const {};
      return;
    }
    refresh();
    _timer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    Map<String, int>? counts;
    try {
      counts = await _channel.invokeMapMethod<String, int>('counts');
    } catch (_) {
      counts = null;
    }
    final next = <String, int>{
      for (final entry in (counts ?? const <String, int>{}).entries)
        if (entry.value > 0)
          // A hidden app must not announce itself on the home screen. It
          // can't normally be pinned - putting one into the secret folder
          // unpins it - but the rule belongs here, where the packages
          // arrive, rather than at the icon that happens to draw them today.
          if (!SecretAppsController.instance.contains(entry.key))
            entry.key: entry.value,
    };
    if (!mapEquals(next, value)) value = next;
  }

  /// What to draw on [entry]: a folder answers with everything inside it
  /// added up, so a folder full of messengers doesn't look empty.
  int countFor(LauncherEntry entry) => _countForKey(entry.key, <String>{});

  int _countForKey(String key, Set<String> seen) {
    // Folders can hold folders, and nothing stops one from holding itself
    // by a long enough path - counting each key once ends that.
    if (!seen.add(key)) return 0;
    final folder = FoldersController.instance.byKey(key);
    if (folder == null) return value[key] ?? 0;
    var total = 0;
    for (final itemKey in folder.itemKeys) {
      total += _countForKey(itemKey, seen);
    }
    return total;
  }

  @visibleForTesting
  void debugSetCounts(Map<String, int> counts) => value = Map.of(counts);
}
