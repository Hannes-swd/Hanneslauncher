/// Every key this app writes into `SharedPreferences`, and what happens to
/// it in a backup.
///
/// This file exists because "does the backup still cover everything" was a
/// question nobody could answer by looking. Settings live in twenty-odd
/// controllers, each with its own private `_somethingKey` constant, and the
/// backup is assembled a hundred lines away from any of them - so adding a
/// setting and forgetting the backup is not a mistake, it is the default
/// outcome. Nothing about the code made the omission visible, and it only
/// showed up as "that one thing didn't come back" after a reinstall.
///
/// So the rule stopped being something to remember and became something to
/// fail: `test/settings_keys_test.dart` reads every key literal back out of
/// `lib/` and refuses to pass while one of them is missing here. A new
/// setting therefore cannot be added without this file being touched, and
/// touching this file is where the question gets asked.
///
/// It is deliberately only a classification, not a mapping to JSON fields.
/// Saying *where* in the document a key ends up would be a second thing to
/// keep in step with `settings_backup_service.dart`, and a registry that
/// itself drifts is worse than none. The one thing it has to get right is
/// "was this thought about", and that it does get right.
library;

/// What a backup does with a key.
enum KeyFate {
  /// Restored on another install (or on this one after a reinstall).
  /// [SettingsBackupService] carries it, under whatever name it likes.
  backedUp,

  /// Deliberately left out, for a reason given in [settingsKeyNotes]. These
  /// fall into three kinds: caches that refill themselves, facts about this
  /// one install that would be wrong anywhere else, and values that are only
  /// true for today.
  deviceLocal,
}

/// Keys whose name is built at runtime, so the scan cannot see the whole
/// string. Listed by the part that is fixed.
const Map<String, KeyFate> settingsKeyPrefixes = {
  // One key per design color role - see DesignController._colorKey. In the
  // backup as the 'design'/'colors' map.
  'design_color_': KeyFate.backedUp,
  // What a code widget's page put in launcher.store(), one key per block.
  // In the backup inside that widget's own entry, next to its HTML and CSS.
  'code_widget_state_': KeyFate.backedUp,
};

/// Why each [KeyFate.deviceLocal] key is one. Kept as prose rather than a
/// comment so the test can insist every exclusion has a reason at all - an
/// undocumented exclusion is how a real setting quietly becomes one.
const Map<String, String> settingsKeyNotes = {
  'auto_backup_at':
      'When the last automatic snapshot was written. Restoring it would tell '
      'a fresh install a backup already happened today, which is the one '
      'moment it most needs to write one.',
  'data_sources_cache':
      'The last answer from each JSON source. Refetched on the next panel '
      'open, and a stale one carried to another day would be worse than none.',
  'default_launcher_prompt_shown':
      'Whether this install already offered to become the home app. About '
      'this install, not about the user.',
  'icon_theme_enabled':
      'Legacy. Migrated into icon_theme_style on load and never written '
      'again; the backup carries the style it became.',
  'location_city': 'Cache of where the phone last was.',
  'location_city_locale': 'Which language that cached town name is in.',
  'location_lat': 'Cache of where the phone last was.',
  'location_lon': 'Cache of where the phone last was.',
  'steps_baseline_count':
      "The step counter's reading at midnight. Only true for today, and the "
      'sensor it is an offset into is reset by a reboot anyway.',
  'steps_baseline_date': 'Which day the step baseline belongs to.',
  'steps_last_raw':
      "The step counter's last reading, so the next new day has a number "
      'from before midnight to count up from. It is an offset into one '
      "phone's sensor since its last boot, and means nothing on any other.",
  'steps_last_raw_date': 'Which day that last reading was taken on.',
  'update_checked_at':
      'When GitHub was last asked for a release. Rechecked on the next panel '
      'open.',
  'update_latest_release':
      'The release GitHub last named. A cache of a fact about the internet, '
      'not a setting.',
};

/// The whole list. Alphabetical, because the test prints it back and a
/// diff that reorders it would hide what actually changed.
const Map<String, KeyFate> settingsKeyRegistry = {
  'app_language': KeyFate.backedUp,
  'app_overrides': KeyFate.backedUp,
  'app_pairs': KeyFate.backedUp,
  'applist_color_index': KeyFate.backedUp,
  'applist_font_family': KeyFate.backedUp,
  'applist_font_size': KeyFate.backedUp,
  'applist_hand': KeyFate.backedUp,
  'applist_hide_alphabet': KeyFate.backedUp,
  'applist_layout_mode': KeyFate.backedUp,
  'applist_row_height': KeyFate.backedUp,
  'applist_search_blur': KeyFate.backedUp,
  'applist_search_contacts': KeyFate.backedUp,
  'applist_search_extras': KeyFate.backedUp,
  'applist_search_web_url': KeyFate.backedUp,
  'applist_sort_mode': KeyFate.backedUp,
  'auto_backup_at': KeyFate.deviceLocal,
  'clock_alignment': KeyFate.backedUp,
  'clock_bars_filled_color': KeyFate.backedUp,
  'clock_bars_text_color': KeyFate.backedUp,
  'clock_bars_unfilled_color': KeyFate.backedUp,
  'clock_bars_unfilled_opacity': KeyFate.backedUp,
  'clock_digital_color': KeyFate.backedUp,
  'clock_digital_font': KeyFate.backedUp,
  'clock_dot_color': KeyFate.backedUp,
  'clock_enabled': KeyFate.backedUp,
  'clock_orbit_color': KeyFate.backedUp,
  'clock_roman_color': KeyFate.backedUp,
  'clock_side_padding': KeyFate.backedUp,
  'clock_split_flap_bg_color': KeyFate.backedUp,
  'clock_split_flap_bg_opacity': KeyFate.backedUp,
  'clock_split_flap_text_color': KeyFate.backedUp,
  'clock_style': KeyFate.backedUp,
  'clock_top_padding': KeyFate.backedUp,
  'clock_vertical_color': KeyFate.backedUp,
  'clock_word_active_color': KeyFate.backedUp,
  'clock_word_bg_color': KeyFate.backedUp,
  'clock_word_bg_opacity': KeyFate.backedUp,
  'clock_word_inactive_color': KeyFate.backedUp,
  'custom_colors': KeyFate.backedUp,
  'data_sources': KeyFate.backedUp,
  'data_sources_cache': KeyFate.deviceLocal,
  'default_launcher_prompt_shown': KeyFate.deviceLocal,
  'design_card_size': KeyFate.backedUp,
  'design_field_style': KeyFate.backedUp,
  'design_font': KeyFate.backedUp,
  'design_haptics': KeyFate.backedUp,
  'design_motion': KeyFate.backedUp,
  'design_opacity': KeyFate.backedUp,
  'design_preset': KeyFate.backedUp,
  'design_radius': KeyFate.backedUp,
  'design_shadow': KeyFate.backedUp,
  'design_spacing': KeyFate.backedUp,
  'device_data_enabled': KeyFate.backedUp,
  'folders': KeyFate.backedUp,
  'gesture_drawing_enabled': KeyFate.backedUp,
  'gesture_shortcuts': KeyFate.backedUp,
  'gesture_trail_color_index': KeyFate.backedUp,
  'gesture_trail_visible': KeyFate.backedUp,
  'icon_theme_color': KeyFate.backedUp,
  'icon_theme_enabled': KeyFate.deviceLocal,
  'icon_theme_pack': KeyFate.backedUp,
  'icon_theme_style': KeyFate.backedUp,
  'location_city': KeyFate.deviceLocal,
  'location_city_locale': KeyFate.deviceLocal,
  'location_lat': KeyFate.deviceLocal,
  'location_lon': KeyFate.deviceLocal,
  'offline_burn_in_protection': KeyFate.backedUp,
  'offline_color': KeyFate.backedUp,
  'offline_digital_font': KeyFate.backedUp,
  'offline_show_media': KeyFate.backedUp,
  'offline_style': KeyFate.backedUp,
  'panel_blocks': KeyFate.backedUp,
  'pinned_app_packages': KeyFate.backedUp,
  'pinned_apps_left_margin': KeyFate.backedUp,
  'pinned_badge_color_index': KeyFate.backedUp,
  'pinned_badge_style': KeyFate.backedUp,
  'saved_shortcuts': KeyFate.backedUp,
  'secret_app_keys': KeyFate.backedUp,
  'secret_password_hash': KeyFate.backedUp,
  'secret_password_salt': KeyFate.backedUp,
  'secret_recovery_hash': KeyFate.backedUp,
  'secret_recovery_salt': KeyFate.backedUp,
  'steps_baseline_count': KeyFate.deviceLocal,
  'steps_baseline_date': KeyFate.deviceLocal,
  'steps_last_raw': KeyFate.deviceLocal,
  'steps_last_raw_date': KeyFate.deviceLocal,
  'update_checked_at': KeyFate.deviceLocal,
  'update_latest_release': KeyFate.deviceLocal,
  'wallpaper_image_path': KeyFate.backedUp,
  'web_apps': KeyFate.backedUp,
};
