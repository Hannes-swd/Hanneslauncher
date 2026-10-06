import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'charging_animation_presets.dart';

/// One of the user's own charging animations.
class CustomChargingAnimation {
  const CustomChargingAnimation({
    required this.id,
    required this.name,
    required this.html,
  });

  final String id;
  final String name;
  final String html;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'html': html};

  static CustomChargingAnimation? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final html = json['html'];
    if (id is! String || html is! String) return null;
    return CustomChargingAnimation(
      id: id,
      name: json['name'] as String? ?? '',
      html: html,
    );
  }
}

class ChargingAnimationSettings {
  const ChargingAnimationSettings({
    this.enabled = false,
    this.durationMs = 1500,
    this.selectedId = 'preset:rainbow',
    this.custom = const [],
  });

  final bool enabled;
  final int durationMs;

  /// A preset's `preset:` id or one of [custom]'s.
  final String selectedId;
  final List<CustomChargingAnimation> custom;

  ChargingAnimationSettings copyWith({
    bool? enabled,
    int? durationMs,
    String? selectedId,
    List<CustomChargingAnimation>? custom,
  }) {
    return ChargingAnimationSettings(
      enabled: enabled ?? this.enabled,
      durationMs: durationMs ?? this.durationMs,
      selectedId: selectedId ?? this.selectedId,
      custom: custom ?? this.custom,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'durationMs': durationMs,
    'selectedId': selectedId,
    'custom': [for (final a in custom) a.toJson()],
  };

  static ChargingAnimationSettings fromJson(Map<String, dynamic> json) {
    return ChargingAnimationSettings(
      enabled: json['enabled'] as bool? ?? false,
      durationMs: clampDuration(json['durationMs'] as int? ?? 1500),
      selectedId: json['selectedId'] as String? ?? 'preset:rainbow',
      custom: [
        for (final entry in json['custom'] as List<dynamic>? ?? const [])
          ?CustomChargingAnimation.fromJson(entry),
      ],
    );
  }

  /// The HTML of [id], or of the first preset when that one is gone - a
  /// deleted animation must not leave charging silent with the switch on.
  String htmlOf(String id) {
    for (final preset in chargingAnimationPresets) {
      if (preset.id == id) return preset.html;
    }
    for (final animation in custom) {
      if (animation.id == id) return animation.html;
    }
    return chargingAnimationPresets.first.html;
  }
}

const int minChargingDurationMs = 500;
const int maxChargingDurationMs = 10000;

int clampDuration(int ms) =>
    ms.clamp(minChargingDurationMs, maxChargingDurationMs);

/// A request to put an animation on screen right now.
class ChargingAnimationPlay {
  const ChargingAnimationPlay({
    required this.html,
    required this.durationMs,
    required this.level,
  });

  final String html;
  final int durationMs;
  final int level;
}

/// The charging animation's settings, and the one place that decides an
/// animation should play - on a plugged-in cable, or from a preview button.
class ChargingAnimationController
    extends ValueNotifier<ChargingAnimationSettings> {
  ChargingAnimationController._() : super(const ChargingAnimationSettings());

  static final ChargingAnimationController instance =
      ChargingAnimationController._();

  static const _channel = MethodChannel('hanneslauncher/charging');

  static const _enabledKey = 'charging_anim_enabled';
  static const _durationKey = 'charging_anim_duration_ms';
  static const _selectedKey = 'charging_anim_selected';
  static const _customKey = 'charging_anim_custom';

  /// What the overlay should be playing; null when nothing is.
  final ValueNotifier<ChargingAnimationPlay?> playing = ValueNotifier(null);

  /// Whether the launcher is the thing on screen. A cable plugged in while
  /// another app is open, or with the screen off, would play to nobody.
  bool inForeground = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = <CustomChargingAnimation>[];
    try {
      final raw = prefs.getString(_customKey);
      if (raw != null) {
        for (final entry in jsonDecode(raw) as List<dynamic>) {
          final animation = CustomChargingAnimation.fromJson(entry);
          if (animation != null) custom.add(animation);
        }
      }
    } catch (_) {}
    value = ChargingAnimationSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      durationMs: clampDuration(prefs.getInt(_durationKey) ?? 1500),
      selectedId: prefs.getString(_selectedKey) ?? 'preset:rainbow',
      custom: custom,
    );
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'powerConnected') return null;
      final args = call.arguments;
      final level = args is Map ? args['level'] as int? : null;
      if (value.enabled && inForeground) play(level: level ?? -1);
      return null;
    });
  }

  Future<void> update(ChargingAnimationSettings settings) async {
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setInt(_durationKey, settings.durationMs);
    await prefs.setString(_selectedKey, settings.selectedId);
    await prefs.setString(
      _customKey,
      jsonEncode([for (final a in settings.custom) a.toJson()]),
    );
  }

  /// Plays [html] (the selected animation when null) for the set duration.
  void play({String? html, int level = -1}) {
    playing.value = ChargingAnimationPlay(
      html: html ?? value.htmlOf(value.selectedId),
      durationMs: value.durationMs,
      level: level,
    );
  }

  void finished(ChargingAnimationPlay play) {
    if (playing.value == play) playing.value = null;
  }
}
