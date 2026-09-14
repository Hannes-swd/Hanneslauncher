import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pinned_apps_controller.dart';

/// Proof that the secret folder's password was entered.
///
/// The constructor is private to this library, so the only way to hold one is
/// to be handed it by [SecretAppsController.unlock] or
/// [SecretAppsController.setPassword] - a screen cannot get at the secret
/// entries by simply asking for them. [SecretAppsController.isUnlockedWith]
/// checks a token against the controller's current unlock on top of that, so
/// one kept around after [SecretAppsController.lock] is worthless rather than
/// a permanent key.
class SecretUnlock {
  SecretUnlock._();
}

/// The apps hidden behind the secret folder's password, held as
/// [LauncherEntry.key]s - which is what lets an installed app and a web app
/// go in through the same code path.
///
/// What makes this safe against being forgotten: keys listed here are left
/// out of [LauncherEntriesController] entirely instead of being filtered
/// where they would be drawn. The app list, the search, folders, pinned
/// apps, the widget pickers and the code widgets' `open` all read from that
/// one list, so a feature added later is covered without knowing this class
/// exists. `test/secret_apps_guard_test.dart` keeps it that way by failing
/// when a new way of reaching an app appears.
///
/// This hides apps, it does not protect them: they stay installed and remain
/// visible in Android's own settings, the recents switcher, the share sheet
/// and the notification shade.
class SecretAppsController extends ValueNotifier<Set<String>> {
  SecretAppsController._() : super(const {});

  static final SecretAppsController instance = SecretAppsController._();

  static const _keysKey = 'secret_app_keys';
  static const _hashKey = 'secret_password_hash';
  static const _saltKey = 'secret_password_salt';
  static const _recoveryHashKey = 'secret_recovery_hash';
  static const _recoverySaltKey = 'secret_recovery_salt';

  /// The characters a recovery code is built from: 32 of them, so each one
  /// carries 5 bits, and none that can be confused when copying by hand (no
  /// 0/O, no 1/I/L).
  static const _codeAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  /// 20 characters, so about 100 bits - far past guessing, while still short
  /// enough to write on a piece of paper.
  static const _codeLength = 20;

  String? _hash;
  String? _salt;

  // Stored exactly like the password: only the hash, so the code itself
  // exists in one place only - wherever the user put it.
  String? _recoveryHash;
  String? _recoverySalt;

  /// The token handed out by the last successful unlock, or null while
  /// locked. Compared by identity, so only the exact object the caller was
  /// given counts.
  SecretUnlock? _activeUnlock;

  bool _loaded = false;

  /// False until a password has ever been set - the first tap on the folder
  /// then asks for a new one instead of an existing one.
  bool get hasPassword => _hash != null;

  bool get isUnlocked => _activeUnlock != null;

  bool contains(String key) => value.contains(key);

  /// Whether [token] is the one currently unlocked. Public because
  /// [LauncherEntriesController] has to ask before handing out the secret
  /// entries.
  bool isUnlockedWith(SecretUnlock token) =>
      _activeUnlock != null && identical(token, _activeUnlock);

  /// False when no recovery code was ever made - the password prompt then
  /// offers no way past it, because there is none.
  bool get hasRecoveryCode => _recoveryHash != null;

  /// The stored hashes and their salts, for the settings backup. A hash is not
  /// the password (nor the code), but see the class comment: a backup file is
  /// plain text and lists the hidden keys next to it.
  String? get passwordHash => _hash;
  String? get passwordSalt => _salt;
  String? get recoveryHash => _recoveryHash;
  String? get recoverySalt => _recoverySalt;

  /// Reads the stored list and password once. Later calls do nothing: what's
  /// in memory is by then the newer state, and re-reading would throw away
  /// changes made since - the same reason [PinnedAppsController.load] only
  /// runs once.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    value = (prefs.getStringList(_keysKey) ?? const []).toSet();
    _hash = prefs.getString(_hashKey);
    _salt = prefs.getString(_saltKey);
    _recoveryHash = prefs.getString(_recoveryHashKey);
    _recoverySalt = prefs.getString(_recoverySaltKey);
  }

  /// Sets the first password and unlocks straight away, so setting one and
  /// putting the first app in is a single trip. Refuses to run when a
  /// password already exists - changing that one goes through
  /// [changePassword], which needs the current unlock.
  Future<SecretUnlock?> setPassword(String password) async {
    if (hasPassword || password.isEmpty) return null;
    _salt = _newSalt();
    _hash = _hashOf(password, _salt!);
    await _writePassword();
    return _activeUnlock = SecretUnlock._();
  }

  /// Returns a token on the right password, null on a wrong one.
  SecretUnlock? unlock(String password) {
    final salt = _salt;
    final hash = _hash;
    if (salt == null || hash == null) return null;
    if (_hashOf(password, salt) != hash) return null;
    return _activeUnlock = SecretUnlock._();
  }

  /// Unlocks with the recovery code instead of the password - the way back in
  /// after forgetting it.
  ///
  /// The code is not a second, weaker password: it is random, 100 bits wide
  /// and never chosen by a human, so it cannot be guessed the way a password
  /// can. What it does cost is that it exists on paper somewhere, which is why
  /// it is shown once and only ever stored as a hash. It survives being used,
  /// so a cancelled recovery does not leave the folder without a way in;
  /// [newRecoveryCode] is what retires one.
  SecretUnlock? unlockWithRecoveryCode(String code) {
    final salt = _recoverySalt;
    final hash = _recoveryHash;
    if (salt == null || hash == null) return null;
    final normalized = normalizeRecoveryCode(code);
    if (normalized.length != _codeLength) return null;
    if (_hashOf(normalized, salt) != hash) return null;
    return _activeUnlock = SecretUnlock._();
  }

  /// Makes a new code, stores its hash and returns the code itself for the one
  /// time it can be shown. Any earlier code stops working, so there is never
  /// more than one way in besides the password.
  Future<String?> newRecoveryCode(SecretUnlock token) async {
    if (!isUnlockedWith(token)) return null;
    final code = _newRecoveryCode();
    _recoverySalt = _newSalt();
    _recoveryHash = _hashOf(normalizeRecoveryCode(code), _recoverySalt!);
    await _writeRecovery();
    return code;
  }

  /// Drops the unlock. Called when the launcher goes to the background -
  /// which happens the moment a secret app is started, so coming back to the
  /// launcher always finds the folder closed again.
  void lock() => _activeUnlock = null;

  Future<bool> changePassword(SecretUnlock token, String password) async {
    if (!isUnlockedWith(token) || password.isEmpty) return false;
    _salt = _newSalt();
    _hash = _hashOf(password, _salt!);
    await _writePassword();
    return true;
  }

  /// Hides [key]. Also unpins it: a pinned entry is drawn on the home screen
  /// from the same resolved list, so leaving the pin would keep one of the
  /// six slots occupied by something that can never be shown.
  Future<bool> add(SecretUnlock token, String key) async {
    if (!isUnlockedWith(token) || value.contains(key)) return false;
    value = {...value, key};
    await _writeKeys();
    final wasPinned = PinnedAppsController.instance.isPinned(key);
    if (wasPinned) await PinnedAppsController.instance.remove(key);
    return wasPinned;
  }

  Future<void> remove(SecretUnlock token, String key) async {
    if (!isUnlockedWith(token) || !value.contains(key)) return;
    value = {
      for (final entry in value)
        if (entry != key) entry,
    };
    await _writeKeys();
  }

  /// Restores the whole folder from a settings backup, password and recovery
  /// code included - without those the restored list could never be opened
  /// again.
  Future<void> restore({
    required List<String> keys,
    String? hash,
    String? salt,
    String? recoveryHash,
    String? recoverySalt,
  }) async {
    _activeUnlock = null;
    value = keys.toSet();
    // Only a complete pair is usable; half of one would lock the folder for
    // good, so in that case the list is restored without a password and the
    // next tap sets a new one.
    final usable = hash != null && salt != null;
    _hash = usable ? hash : null;
    _salt = usable ? salt : null;
    final usableRecovery = recoveryHash != null && recoverySalt != null;
    _recoveryHash = usableRecovery ? recoveryHash : null;
    _recoverySalt = usableRecovery ? recoverySalt : null;
    await _writeKeys();
    await _writePassword();
    await _writeRecovery();
  }

  /// Strips a code down to what is actually stored: uppercase, and only
  /// characters that can be part of one. That way the grouping dashes, spaces,
  /// a line break from a paste and a lowercase transcription are all accepted.
  static String normalizeRecoveryCode(String code) => [
    for (final char in code.toUpperCase().split(''))
      if (_codeAlphabet.contains(char)) char,
  ].join();

  Future<void> _writeKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keysKey, value.toList());
  }

  Future<void> _writePassword() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = _hash;
    final salt = _salt;
    if (hash == null || salt == null) {
      await prefs.remove(_hashKey);
      await prefs.remove(_saltKey);
      return;
    }
    await prefs.setString(_hashKey, hash);
    await prefs.setString(_saltKey, salt);
  }

  Future<void> _writeRecovery() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = _recoveryHash;
    final salt = _recoverySalt;
    if (hash == null || salt == null) {
      await prefs.remove(_recoveryHashKey);
      await prefs.remove(_recoverySaltKey);
      return;
    }
    await prefs.setString(_recoveryHashKey, hash);
    await prefs.setString(_recoverySaltKey, salt);
  }

  static String _hashOf(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static String _newSalt() {
    final random = Random.secure();
    return base64Url.encode([for (var i = 0; i < 16; i++) random.nextInt(256)]);
  }

  /// A fresh code, in groups of five - which is what makes twenty characters
  /// copyable by hand without losing your place.
  static String _newRecoveryCode() {
    final random = Random.secure();
    final chars = [
      for (var i = 0; i < _codeLength; i++)
        _codeAlphabet[random.nextInt(_codeAlphabet.length)],
    ];
    final groups = [
      for (var start = 0; start < _codeLength; start += 5)
        chars.sublist(start, start + 5).join(),
    ];
    return groups.join('-');
  }
}
