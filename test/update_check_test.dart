import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/update_controller.dart';

/// A GitHub `/releases/latest` payload, cut down to the fields the app reads.
Map<String, dynamic> payload({
  String tag = 'v1.1.0',
  List<Map<String, dynamic>>? assets,
  bool draft = false,
}) {
  return {
    'tag_name': tag,
    'draft': draft,
    'html_url': 'https://github.com/$kUpdateRepo/releases/tag/$tag',
    'body': 'Neue Uhr-Stile',
    'published_at': '2026-08-03T10:00:00Z',
    'assets':
        assets ??
        [
          {
            'name': 'hanneslauncher-1.1.0.apk',
            'browser_download_url': 'https://example.test/app.apk',
          },
        ],
  };
}

void main() {
  group('version comparison', () {
    test('a higher number anywhere wins', () {
      expect(compareVersions('1.1.0', '1.0.0'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.0.1', '1.0.0'), greaterThan(0));
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    });

    test('compares numerically, not as text', () {
      // The one a plain string comparison gets wrong.
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('1.2.10', '1.2.9'), greaterThan(0));
    });

    test('a missing part counts as zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.1', '1.2'), greaterThan(0));
    });
  });

  group('tag normalisation', () {
    test('strips the leading v and a build suffix', () {
      expect(normalizeVersion('v1.2.0'), '1.2.0');
      expect(normalizeVersion('V1.2.0'), '1.2.0');
      expect(normalizeVersion(' 1.2.0 '), '1.2.0');
      expect(normalizeVersion('1.2.0+7'), '1.2.0');
    });

    test('a tag that is not a version is rejected', () {
      expect(normalizeVersion('nightly'), '');
      expect(normalizeVersion(''), '');
    });
  });

  group('reading a release', () {
    test('takes the tag and the first apk asset', () {
      final release = UpdateRelease.fromGitHub(payload())!;
      expect(release.version, '1.1.0');
      expect(release.apkUrl, 'https://example.test/app.apk');
      expect(release.notes, 'Neue Uhr-Stile');
      expect(release.publishedAt, isNotNull);
    });

    test('ignores assets that are not an apk', () {
      final release = UpdateRelease.fromGitHub(
        payload(
          assets: [
            {
              'name': 'backup.json',
              'browser_download_url': 'https://example.test/backup.json',
            },
            {
              'name': 'app-release.apk',
              'browser_download_url': 'https://example.test/real.apk',
            },
          ],
        ),
      )!;
      expect(release.apkUrl, 'https://example.test/real.apk');
    });

    test('a release without an apk still points at its page', () {
      final release = UpdateRelease.fromGitHub(payload(assets: []))!;
      expect(release.apkUrl, isEmpty);
      expect(release.pageUrl, isNotEmpty);
    });

    test('drafts and non-version tags are not releases to offer', () {
      expect(UpdateRelease.fromGitHub(payload(draft: true)), isNull);
      expect(UpdateRelease.fromGitHub(payload(tag: 'latest')), isNull);
    });

    test('survives a round trip through preferences', () {
      final release = UpdateRelease.fromGitHub(payload())!;
      final restored = UpdateRelease.fromJson(release.toJson())!;
      expect(restored.version, release.version);
      expect(restored.apkUrl, release.apkUrl);
      expect(restored.notes, release.notes);
    });
  });

  group('when the mark is shown', () {
    UpdateState state(String installed, String? latest) => UpdateState(
      installedVersion: installed,
      latest: latest == null
          ? null
          : UpdateRelease(
              version: latest,
              apkUrl: '',
              pageUrl: '',
              notes: '',
              publishedAt: null,
            ),
    );

    test('only for a release that is actually newer', () {
      expect(state('1.0.0', '1.1.0').available, isTrue);
      expect(state('1.1.0', '1.1.0').available, isFalse);
      // A local build ahead of the last release must not be told to
      // "update" back down to it.
      expect(state('1.2.0', '1.1.0').available, isFalse);
    });

    test('never while the installed version is unknown', () {
      // Otherwise a platform that can't answer would claim an update
      // forever, and the dot could never be cleared.
      expect(state('', '1.1.0').available, isFalse);
    });

    test('never without a release to compare against', () {
      expect(state('1.0.0', null).available, isFalse);
    });
  });
}
