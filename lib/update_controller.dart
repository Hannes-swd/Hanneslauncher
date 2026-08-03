import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the release APKs are published. Everything else about the check is
/// derived from this - the API call, the release page, the download link.
const String kUpdateRepo = 'Hannes-swd/Hanneslouncher';

/// A release as GitHub reports it, reduced to the parts this app shows or
/// acts on. Kept as JSON in preferences so the "update available" mark
/// survives a restart without needing a connection to prove itself again.
class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.apkUrl,
    required this.pageUrl,
    required this.notes,
    required this.publishedAt,
  });

  /// The tag with a leading "v" stripped, i.e. what a version name looks
  /// like: `1.2.0`.
  final String version;

  /// Empty when the release carries no .apk asset - the release page is
  /// still worth offering in that case, but there's nothing to install.
  final String apkUrl;

  final String pageUrl;
  final String notes;
  final DateTime? publishedAt;

  Map<String, dynamic> toJson() => {
    'version': version,
    'apkUrl': apkUrl,
    'pageUrl': pageUrl,
    'notes': notes,
    'publishedAt': publishedAt?.toIso8601String(),
  };

  static UpdateRelease? fromJson(Map<String, dynamic> json) {
    final version = json['version'] as String?;
    if (version == null || version.isEmpty) return null;
    return UpdateRelease(
      version: version,
      apkUrl: json['apkUrl'] as String? ?? '',
      pageUrl: json['pageUrl'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
    );
  }

  /// Parses GitHub's `/releases/latest` payload. Returns null for anything
  /// that isn't a usable release (a draft, or a tag that isn't a version).
  static UpdateRelease? fromGitHub(Map<String, dynamic> json) {
    if (json['draft'] == true) return null;
    final tag = (json['tag_name'] as String? ?? '').trim();
    final version = normalizeVersion(tag);
    if (version.isEmpty) return null;

    var apkUrl = '';
    final assets = json['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = asset['name'] as String? ?? '';
        if (!name.toLowerCase().endsWith('.apk')) continue;
        apkUrl = asset['browser_download_url'] as String? ?? '';
        if (apkUrl.isNotEmpty) break;
      }
    }

    return UpdateRelease(
      version: version,
      apkUrl: apkUrl,
      pageUrl:
          json['html_url'] as String? ??
          'https://github.com/$kUpdateRepo/releases',
      notes: (json['body'] as String? ?? '').trim(),
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
    );
  }
}

/// What the update row and the update screen read: the installed version,
/// the newest release known so far, and how the last check went.
@immutable
class UpdateState {
  const UpdateState({
    this.installedVersion = '',
    this.latest,
    this.checking = false,
    this.lastCheck,
    this.lastCheckFailed = false,
    this.downloading = false,
    this.downloadedFraction = 0,
    this.downloadFailed = false,
    this.needsInstallPermission = false,
  });

  /// Empty until the platform has answered - which is also the state on a
  /// platform that has no answer at all, so nothing below claims an update
  /// while this is empty.
  final String installedVersion;

  final UpdateRelease? latest;
  final bool checking;
  final DateTime? lastCheck;
  final bool lastCheckFailed;

  /// The APK is being fetched right now; [downloadedFraction] runs 0..1 and
  /// stays at 0 while the server doesn't say how big the file is.
  final bool downloading;
  final double downloadedFraction;
  final bool downloadFailed;

  /// Android won't let this app hand a file to the installer yet - the
  /// screen says so and offers the settings switch instead of failing
  /// silently, which is what the browser route did.
  final bool needsInstallPermission;

  bool get available {
    final release = latest;
    if (release == null || installedVersion.isEmpty) return false;
    return compareVersions(release.version, installedVersion) > 0;
  }

  UpdateState copyWith({
    String? installedVersion,
    UpdateRelease? latest,
    bool? checking,
    DateTime? lastCheck,
    bool? lastCheckFailed,
    bool? downloading,
    double? downloadedFraction,
    bool? downloadFailed,
    bool? needsInstallPermission,
  }) {
    return UpdateState(
      installedVersion: installedVersion ?? this.installedVersion,
      latest: latest ?? this.latest,
      checking: checking ?? this.checking,
      lastCheck: lastCheck ?? this.lastCheck,
      lastCheckFailed: lastCheckFailed ?? this.lastCheckFailed,
      downloading: downloading ?? this.downloading,
      downloadedFraction: downloadedFraction ?? this.downloadedFraction,
      downloadFailed: downloadFailed ?? this.downloadFailed,
      needsInstallPermission:
          needsInstallPermission ?? this.needsInstallPermission,
    );
  }
}

/// Strips a leading "v" and anything the Android version name can't carry
/// anyway (a `+build` suffix, trailing whitespace), so a `v1.2.0` tag and a
/// `1.2.0` version name compare as the same thing. Returns '' for a tag that
/// doesn't start with a number at all.
String normalizeVersion(String raw) {
  var text = raw.trim();
  if (text.startsWith('v') || text.startsWith('V')) text = text.substring(1);
  final plus = text.indexOf('+');
  if (plus >= 0) text = text.substring(0, plus);
  text = text.trim();
  if (text.isEmpty || int.tryParse(text.split('.').first) == null) return '';
  return text;
}

/// Compares two dotted version names numerically: >0 when [a] is newer.
/// Numeric on purpose - a plain string comparison would put 1.10.0 before
/// 1.9.0. Parts that aren't numbers count as 0, and a missing part counts as
/// 0 too, so 1.2 and 1.2.0 are the same version.
int compareVersions(String a, String b) {
  final left = a.split('.');
  final right = b.split('.');
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? int.tryParse(left[i].trim()) ?? 0 : 0;
    final r = i < right.length ? int.tryParse(right[i].trim()) ?? 0 : 0;
    if (l != r) return l > r ? 1 : -1;
  }
  return 0;
}

/// Asks GitHub whether a newer release than the installed version exists,
/// and fetches the APK when asked to.
///
/// The download happens here rather than in the browser: a browser download
/// needs the *browser* to be allowed to install apps, and when it isn't, the
/// install simply doesn't happen - with no message saying why. Doing it here
/// means this app asks for that permission itself, once, and can say what is
/// missing. Installing is still Android's own installer, as it has to be.
class UpdateController extends ValueNotifier<UpdateState> {
  UpdateController._() : super(const UpdateState());

  static final UpdateController instance = UpdateController._();

  static const _channel = MethodChannel('hanneslouncher/app_info');

  static const _releaseKey = 'update_latest_release';
  static const _checkedAtKey = 'update_checked_at';

  /// How long a check stays good for. The panel being pulled down is what
  /// triggers one, and that happens many times a day - without this, every
  /// single pull would cost a request against GitHub's 60-per-hour limit for
  /// unauthenticated callers.
  static const _interval = Duration(hours: 6);

  static const _timeout = Duration(seconds: 10);

  /// Set by the tests; the real app always goes through a fresh client.
  http.Client? debugClientOverride;

  /// Reads the installed version and whatever the last check found. No
  /// network - so the update mark is already right on the first frame.
  Future<void> load() async {
    final installed = await _installedVersion();
    final prefs = await SharedPreferences.getInstance();

    UpdateRelease? release;
    final stored = prefs.getString(_releaseKey);
    if (stored != null) {
      try {
        final decoded = jsonDecode(stored);
        if (decoded is Map<String, dynamic>) {
          release = UpdateRelease.fromJson(decoded);
        }
      } catch (_) {
        // A leftover from an older format: just check again.
      }
    }

    value = UpdateState(
      installedVersion: installed,
      latest: release,
      lastCheck: DateTime.tryParse(prefs.getString(_checkedAtKey) ?? ''),
    );
  }

  /// Checks only if the last check has aged past [_interval]. This is what
  /// the app calls on its own; [check] is the button.
  Future<void> refreshStale() async {
    final last = value.lastCheck;
    if (last != null && DateTime.now().difference(last) < _interval) return;
    await check();
  }

  /// Asks GitHub now, regardless of when the last check was.
  Future<void> check() async {
    if (value.checking) return;
    value = value.copyWith(checking: true, lastCheckFailed: false);

    // The installed version can still be missing when the very first check
    // runs before [load] finished - without it there is nothing to compare
    // against, so it's worth a second attempt here.
    var installed = value.installedVersion;
    if (installed.isEmpty) installed = await _installedVersion();

    final client = debugClientOverride ?? http.Client();
    UpdateRelease? release;
    var failed = false;
    try {
      final response = await client
          .get(
            Uri.parse('https://api.github.com/repos/$kUpdateRepo/releases/latest'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          release = UpdateRelease.fromGitHub(decoded);
        }
      } else if (response.statusCode != 404) {
        // 404 is what a repo with no release yet answers: a real answer, and
        // it means there is nothing newer. Anything else (rate limit, server
        // trouble) is a check that didn't happen.
        failed = true;
      }
    } catch (_) {
      // No connection, timeout, or something that isn't JSON: all the same
      // from here, the previous result stays and the screen says so.
      failed = true;
    } finally {
      if (debugClientOverride == null) client.close();
    }

    final now = DateTime.now();
    value = UpdateState(
      installedVersion: installed,
      // A failed check must not erase what the last good one found, or the
      // update mark would disappear the moment the phone is offline.
      latest: release ?? value.latest,
      checking: false,
      lastCheck: failed ? value.lastCheck : now,
      lastCheckFailed: failed,
      // A check can run while a download is in flight (pulling the panel
      // down starts one), and rebuilding the state from scratch here would
      // otherwise wipe the progress bar mid-download.
      downloading: value.downloading,
      downloadedFraction: value.downloadedFraction,
      downloadFailed: value.downloadFailed,
      needsInstallPermission: value.needsInstallPermission,
    );

    if (failed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_checkedAtKey, now.toIso8601String());
    if (release != null) {
      await prefs.setString(_releaseKey, jsonEncode(release.toJson()));
    }
  }

  /// Fetches the release APK and hands it to Android's installer. Progress
  /// lands in [value] so the screen can show it; the install dialog itself
  /// is Android's, and this app is replaced in place - every setting stays.
  Future<void> downloadAndInstall() async {
    final release = value.latest;
    if (release == null || release.apkUrl.isEmpty || value.downloading) return;

    // Asked before the download, not after: nobody wants to wait for 50 MB
    // only to be told the app isn't allowed to install anything.
    if (!await _canInstallApks()) {
      value = value.copyWith(needsInstallPermission: true, downloadFailed: false);
      return;
    }

    value = value.copyWith(
      downloading: true,
      downloadedFraction: 0,
      downloadFailed: false,
      needsInstallPermission: false,
    );

    final client = debugClientOverride ?? http.Client();
    try {
      // Wiped first: a half-finished file from a download that was cut off
      // would otherwise sit there and be handed to the installer.
      final directory = Directory(
        '${(await getTemporaryDirectory()).path}/update',
      );
      if (directory.existsSync()) directory.deleteSync(recursive: true);
      directory.createSync(recursive: true);
      final file = File(
        '${directory.path}/hanneslouncher-${release.version}.apk',
      );

      final response = await client.send(
        http.Request('GET', Uri.parse(release.apkUrl)),
      );
      if (response.statusCode != 200) {
        throw HttpException('${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;
      var lastPercent = -1;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total <= 0) continue;
        // One rebuild per percent instead of one per chunk - a 50 MB file
        // arrives in thousands of them.
        final percent = received * 100 ~/ total;
        if (percent == lastPercent) continue;
        lastPercent = percent;
        value = value.copyWith(downloadedFraction: received / total);
      }
      await sink.close();

      final started = await _installApk(file.path);
      value = value.copyWith(
        downloading: false,
        downloadedFraction: 1,
        downloadFailed: !started,
      );
    } catch (_) {
      // No connection, no space, a server that answered with something else:
      // all the same to the screen, which offers the release page instead.
      value = value.copyWith(downloading: false, downloadFailed: true);
    } finally {
      if (debugClientOverride == null) client.close();
    }
  }

  /// Opens the system switch that lets this app install apps.
  Future<void> requestInstallPermission() async {
    try {
      await _channel.invokeMethod('requestInstallPermission');
    } catch (_) {
      // Nothing to do here: the screen keeps offering the release page.
    }
  }

  /// Called when the update screen comes back into view - the permission may
  /// have been granted in the settings in the meantime.
  Future<void> refreshInstallPermission() async {
    if (!value.needsInstallPermission) return;
    if (await _canInstallApks()) {
      value = value.copyWith(needsInstallPermission: false);
    }
  }

  Future<bool> _canInstallApks() async {
    try {
      return await _channel.invokeMethod<bool>('canInstallApks') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _installApk(String path) async {
    try {
      return await _channel.invokeMethod<bool>('installApk', {'path': path}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<String> _installedVersion() async {
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('version');
      return normalizeVersion(info?['versionName'] as String? ?? '');
    } catch (_) {
      // Not Android, or the channel isn't there (a test): leave it empty,
      // which is the state that never claims an update.
      return '';
    }
  }
}
