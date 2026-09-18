import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/entry_match.dart';

/// Ranks [names] the way the search does, so a test can read as "these come
/// out in this order".
List<String> ranked(List<String> names, String query) {
  final scored = <({String name, int score})>[];
  for (final name in names) {
    final score = rankName(name, query);
    if (score != null) scored.add((name: name, score: score));
  }
  scored.sort((a, b) {
    if (a.score != b.score) return b.score - a.score;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return [for (final hit in scored) hit.name];
}

void main() {
  group('what matches at all', () {
    test('a name that has nothing to do with the query does not', () {
      expect(rankName('Calculator', 'spotify'), isNull);
    });

    test('the old behaviour is still the floor', () {
      // Everything `contains` used to find is still found.
      expect(rankName('Visitenkarte', 'karte'), isNotNull);
    });

    test('an empty query matches everything, unranked', () {
      expect(rankName('Anything', ''), 0);
      expect(rankName('Anything', '   '), 0);
    });

    test('case and the query being padded make no difference', () {
      expect(rankName('WhatsApp', '  WHATS '), rankName('WhatsApp', 'whats'));
    });
  });

  group('the order it puts things in', () {
    test('the beginning of a name beats the middle of one', () {
      expect(ranked(['Visitenkarte', 'Karten'], 'karte'), [
        'Karten',
        'Visitenkarte',
      ]);
    });

    test('an exact name beats a longer one that starts the same', () {
      expect(ranked(['Mailbox Pro', 'Mail'], 'mail'), [
        'Mail',
        'Mailbox Pro',
      ]);
    });

    test('among equals the shorter name wins', () {
      expect(ranked(['Acrobat Reader Professional', 'Acrobat'], 'acro'), [
        'Acrobat',
        'Acrobat Reader Professional',
      ]);
    });

    test('a word inside the name beats a match mid-word', () {
      // "Music" starts the second word of one and sits inside the other.
      expect(ranked(['Amusica', 'YouTube Music'], 'music'), [
        'YouTube Music',
        'Amusica',
      ]);
    });
  });

  group('how names actually get shortened', () {
    test('initials find a name of several words', () {
      expect(rankName('YouTube Music', 'ytm'), isNotNull);
      expect(rankName('Google Play Store', 'gps'), isNotNull);
    });

    test('initials work on a name written without spaces', () {
      // The capitals are the word boundaries.
      expect(rankName('YouTubeMusic', 'ytm'), isNotNull);
    });

    test('a word inside a run-together name is found', () {
      expect(rankName('YouTubeMusic', 'music'), isNotNull);
    });

    test('a name that starts with the query beats initials that spell it', () {
      // Typing "gm" with both installed means Gmail. Initials are the way
      // in when nothing simpler fits, not ahead of it.
      expect(ranked(['Google Maps', 'Gmail'], 'gm'), [
        'Gmail',
        'Google Maps',
      ]);
    });

    test('a single-word name has no initials to match', () {
      // Otherwise "s" would match every app beginning with s twice over,
      // and worse, "ab" would match "Abc" as initials.
      expect(rankName('Spotify', 'sp'), isNotNull);
      expect(rankName('Telegram', 'xyz'), isNull);
    });

    test('a long query is not read as initials', () {
      // Without the bound, "abcdefgh" would start matching any long name
      // whose words happen to begin with those letters.
      expect(rankName('Alpha Beta Center Delta', 'abcd'), isNotNull);
      expect(rankName('Alpha Beta Center Delta Echo Foxtrot', 'abcdef'),
          isNull);
    });
  });

  group('what it deliberately will not do', () {
    test('a subsequence is not a match', () {
      // "ytbmsc" hits nothing. A search that always finds something never
      // gets to say "nothing here is called that", and that answer is the
      // useful one when an app really is not installed.
      expect(rankName('YouTube Music', 'ytbmsc'), isNull);
      expect(rankName('Telegram', 'tlgm'), isNull);
    });
  });

  group('names people actually have', () {
    test('German umlauts survive the word split', () {
      expect(rankName('Öffi Fahrplan', 'fahr'), isNotNull);
      expect(rankName('Öffi Fahrplan', 'öf'), isNotNull);
    });

    test('punctuation between words is a word boundary', () {
      expect(rankName('K-9 Mail', 'mail'), isNotNull);
      expect(rankName('Adobe Acrobat: Reader', 'reader'), isNotNull);
    });

    test('digits count as part of a word', () {
      expect(rankName('2FAS Auth', '2fas'), isNotNull);
    });
  });
}
