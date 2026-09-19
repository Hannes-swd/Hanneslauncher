import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pinned_apps_controller.dart';

/// How many times a password is run through the hash before what comes out
/// is stored.
///
/// Measured rather than picked: 100,000 rounds is a fifth of a second on a
/// desktop and near a second on a phone, which is the most that can be
/// spent without the unlock feeling broken. Every round is a round an
/// attacker holding the backup file has to spend on each guess too, and
/// that is the whole of what this buys - see [SecretAppsController].
const int _pbkdf2Iterations = 100000;

/// What marks a stored hash as the stretched kind. A stored value carries
/// its own round count after it, so this number can be raised later without
/// invalidating anything already written.
const String _pbkdf2Prefix = 'pbkdf2';

/// The stored form of a secret: the marker, the rounds it took, and the key.
///
/// Top-level and pure so it can be handed to [compute] - most of a second
/// of arithmetic on the thread that draws the home screen would be a
/// visible freeze every time a password is checked.
String derivePasswordHash((String, String, int) input) {
  final (secret, salt, rounds) = input;
  final key = _pbkdf2(
    password: utf8.encode(secret),
    salt: utf8.encode(salt),
    iterations: rounds,
    length: 32,
  );
  return '$_pbkdf2Prefix\$$rounds\$${base64Url.encode(key)}';
}

/// PBKDF2-HMAC-SHA256, written out rather than pulled from a package: it is
/// twenty lines of the standard, and the two packages that offer it bring a
/// whole cipher suite along for them.
///
/// Each block is the first HMAC of the salt, then that HMAC of itself
/// [iterations] times over, with everything along the way XORed together -
/// which is what stops the chain being shortcut.
List<int> _pbkdf2({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  required int length,
}) {
  final hmac = Hmac(sha256, password);
  final out = <int>[];
  for (var block = 1; out.length < length; block++) {
    // The block number goes on the end of the salt, big-endian.
    var u = hmac.convert([
      ...salt,
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ]).bytes;
    final accumulated = List<int>.from(u);
    for (var round = 1; round < iterations; round++) {
      u = hmac.convert(u).bytes;
      for (var i = 0; i < accumulated.length; i++) {
        accumulated[i] ^= u[i];
      }
    }
    out.addAll(accumulated);
  }
  return out.sublist(0, length);
}

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
///
/// The password is stored stretched (PBKDF2-HMAC-SHA256, see
/// [_pbkdf2Iterations]) rather than as the single SHA-256 pass it used to
/// be. That matters because the hash and its salt travel in the settings
/// backup, which is a plain text file in the Downloads folder: whoever has
/// that file can guess at the password offline, as fast as they can compute
/// the hash, and one pass of SHA-256 is as fast as computing gets.
///
/// It does not make a short password safe. Stretching multiplies the cost
/// of each guess; it does nothing about how many guesses there are, and a
/// four-digit PIN is ten thousand of them. A password worth the name is
/// still the only thing that makes this hard.
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

  /// The round count new hashes are written with. Lowered by tests, which
  /// would otherwise spend most of a second on every password they set.
  ///
  /// Only ever lowered here: the number is the whole of what makes a stored
  /// hash expensive to guess. A hash written at one count still verifies
  /// after it changes, because the count it was written with is stored
  /// alongside it.
  @visibleForTesting
  static int debugIterations = _pbkdf2Iterations;

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

  /// The hidden keys, with the stored list guaranteed to have been read.
  ///
  /// Everything that filters against the secret folder from outside
  /// [LauncherEntriesController] - the notification block, the badge on a
  /// pinned icon, the most-used app - runs off the panel being pulled down,
  /// and that can happen before the first [load] has finished. Reading
  /// [value] straight out at that moment gets back the empty set it starts
  /// as, and a filter against an empty set is not a filter: the class
  /// comment on [NotificationsController] promises a hidden app is not in
  /// its list, and the one thing that promise cannot survive is being asked
  /// a fraction of a second too early.
  ///
  /// It happened to hold anyway, because [LauncherEntriesController.load]
  /// awaits this at startup - but that is a coincidence of ordering rather
  /// than a rule, and `test/secret_apps_guard_test.dart` now keeps the
  /// direct reads down to the places that are already inside a load.
  Future<Set<String>> loadedKeys() async {
    await load();
    return value;
  }

  /// Sets the first password and unlocks straight away, so setting one and
  /// putting the first app in is a single trip. Refuses to run when a
  /// password already exists - changing that one goes through
  /// [changePassword], which needs the current unlock.
  Future<SecretUnlock?> setPassword(String password) async {
    if (hasPassword || password.isEmpty) return null;
    _salt = _newSalt();
    _hash = await _hashOf(password, _salt!);
    await _writePassword();
    return _activeUnlock = SecretUnlock._();
  }

  /// Returns a token on the right password, null on a wrong one.
  ///
  /// Asynchronous because checking a password now costs real work - see the
  /// class comment. The app list tries every keystroke against this, so
  /// whoever calls it repeatedly has to wait out the typing first rather
  /// than start a derivation per letter.
  Future<SecretUnlock?> unlock(String password) async {
    final salt = _salt;
    final hash = _hash;
    if (salt == null || hash == null) return null;
    if (!await _matches(password, salt, hash)) return null;
    await _upgradeLegacy(
      secret: password,
      salt: salt,
      stored: hash,
      isRecovery: false,
    );
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
  Future<SecretUnlock?> unlockWithRecoveryCode(String code) async {
    final salt = _recoverySalt;
    final hash = _recoveryHash;
    if (salt == null || hash == null) return null;
    final normalized = normalizeRecoveryCode(code);
    if (normalized.length != _codeLength) return null;
    if (!await _matches(normalized, salt, hash)) return null;
    await _upgradeLegacy(
      secret: normalized,
      salt: salt,
      stored: hash,
      isRecovery: true,
    );
    return _activeUnlock = SecretUnlock._();
  }

  /// Makes a new code, stores its hash and returns the code itself for the one
  /// time it can be shown. Any earlier code stops working, so there is never
  /// more than one way in besides the password.
  Future<String?> newRecoveryCode(SecretUnlock token) async {
    if (!isUnlockedWith(token)) return null;
    final code = _newRecoveryCode();
    _recoverySalt = _newSalt();
    _recoveryHash = await _hashOf(normalizeRecoveryCode(code), _recoverySalt!);
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
    _hash = await _hashOf(password, _salt!);
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

  /// The stored form of [secret] under [salt], in the current format.
  ///
  /// On a background isolate: a hundred thousand rounds is a fifth of a
  /// second on a desktop and closer to a second on a phone, and the home
  /// screen must not stop moving while a password is checked.
  static Future<String> _hashOf(String secret, String salt) =>
      compute(derivePasswordHash, (secret, salt, debugIterations));

  /// Whether [secret] is what [stored] was made from.
  ///
  /// The format is read out of [stored] rather than assumed, which is what
  /// lets a password set before the stretching keep working: the old form
  /// was a bare SHA-256 of `salt:secret` and carries no marker, so anything
  /// unmarked is one of those. The round count is read back out too, so
  /// raising [_pbkdf2Iterations] later never invalidates a stored hash.
  static Future<bool> _matches(
    String secret,
    String salt,
    String stored,
  ) async {
    if (!stored.startsWith('$_pbkdf2Prefix\$')) {
      return _legacyHashOf(secret, salt) == stored;
    }
    final parts = stored.split('\$');
    final rounds = parts.length == 3 ? int.tryParse(parts[1]) : null;
    if (rounds == null || rounds < 1) return false;
    return await compute(derivePasswordHash, (secret, salt, rounds)) == stored;
  }

  /// Rewrites a hash that predates the stretching, at the one moment the
  /// secret behind it is in hand. Costs one extra derivation, once.
  Future<void> _upgradeLegacy({
    required String secret,
    required String salt,
    required String stored,
    required bool isRecovery,
  }) async {
    if (stored.startsWith('$_pbkdf2Prefix\$')) return;
    if (isRecovery) {
      _recoveryHash = await _hashOf(secret, salt);
      await _writeRecovery();
    } else {
      _hash = await _hashOf(secret, salt);
      await _writePassword();
    }
  }

  /// The format used before the stretching: one pass of SHA-256, which a
  /// four-digit PIN falls to faster than the file can be opened. Kept only
  /// so a password set under it is still recognised - and replaced the
  /// first time it is used, by [_upgradeLegacy].
  static String _legacyHashOf(String secret, String salt) =>
      sha256.convert(utf8.encode('$salt:$secret')).toString();

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
