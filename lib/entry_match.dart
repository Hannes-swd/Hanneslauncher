/// How well a typed query matches a name, and in what order the matches
/// should be shown.
///
/// The search this replaces was `name.toLowerCase().contains(query)`, which
/// gets two things wrong in a way that is felt every time. It has no idea of
/// *degree* - "Karte" matching at the start of "Karten" and in the middle of
/// "Visitenkarte" come out equal, and the alphabet then decides which one is
/// offered first - and it only knows one way to match, so the way people
/// actually shorten a name does not work at all: nobody types the middle of
/// "YouTube Music", they type `ytm`.
///
/// Four ways to match, in falling order of how sure they make a hit:
///
///   1. the whole name, typed out
///   2. the name's beginning: `whats` for WhatsApp
///   3. the beginning of a word inside it: `music` for YouTube Music, and
///      the initials of the words, `ytm` for the same
///   4. anywhere at all, which is the old behaviour and stays as the floor
///
/// A subsequence match ("ytbmsc") is deliberately *not* in here. It finds
/// something for nearly any query, which sounds generous and in practice
/// means the list never empties and the honest answer - "nothing here is
/// called that" - is never given.
library;

/// The score of [name] against [query], or null when it does not match at
/// all. Higher is better; the numbers themselves mean nothing outside this
/// file.
int? matchScore(String name, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return 0;
  final haystack = name.toLowerCase();

  if (haystack == needle) return 1000;
  if (haystack.startsWith(needle)) {
    // Among names that all start with the query, the shortest is the most
    // likely one meant: typing "mail" when both "Mail" and "Mailbox Pro"
    // are installed means the first.
    return 900 - _lengthPenalty(haystack);
  }

  final words = _wordsOf(haystack);

  // A word inside the name starting with the query. Which word it is
  // matters a little - "Music" in "YouTube Music" is a better answer than
  // the fourth word of a long name would be.
  for (var i = 0; i < words.length; i++) {
    if (words[i].startsWith(needle)) {
      return 800 - i * 10 - _lengthPenalty(haystack);
    }
  }

  // The initials: ytm -> YouTube Music, but only for a query short enough
  // to plausibly be initials. Without that bound a long query would start
  // matching long names by their first letters alone.
  if (needle.length >= 2 && needle.length <= 5 && words.length >= 2) {
    final initials = words.map(_initialOf).join();
    if (initials == needle) return 700;
    if (initials.startsWith(needle)) return 690 - _lengthPenalty(haystack);
  }

  final at = haystack.indexOf(needle);
  if (at >= 0) {
    // Earlier in the name is better, and this whole tier sits below
    // everything above it.
    return 500 - at.clamp(0, 99) - _lengthPenalty(haystack);
  }

  return null;
}

/// Shortness as a tie-breaker, capped so a very long name is not punished
/// out of all proportion to how well it matched.
int _lengthPenalty(String value) => value.length.clamp(0, 40) ~/ 4;

/// What separates one word from the next: anything that is not a letter or
/// a digit, in any alphabet.
///
/// This used to be the literal class `[^a-z0-9äöüß]`, which treated every
/// letter outside German as punctuation - "Pokémon GO" came apart into
/// `pok`, `mon`, `go`, so its initials were `pmg` and `pg` found nothing,
/// and a name in a non-Latin alphabet produced no words at all. The
/// properties below are the same rule without the list of letters that
/// happened to come to mind.
final RegExp _wordBreak = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// A capital in the middle of a word, which is the other way a name is
/// written as several: "YouTube", "OpenVPN". Between a lowercase letter or
/// a digit and a capital, so a run of capitals stays one word.
final RegExp _camelHump = RegExp(r'(?<=[\p{Ll}\p{N}])(?=\p{Lu})', unicode: true);

/// Splits a name the way a person reads it: on spaces and punctuation, and
/// also at a capital in the middle of a word, so "YouTube" is two words and
/// `yt` finds it.
List<String> _wordsOf(String lowered) => [
  for (final part in lowered.split(_wordBreak))
    if (part.isNotEmpty) part,
];

/// Same as [_wordsOf] but on the original spelling, so the capitals are
/// still there to split on.
List<String> searchWords(String name) {
  final split = name.replaceAllMapped(_camelHump, (_) => ' ');
  return [
    for (final part in split.toLowerCase().split(_wordBreak))
      if (part.isNotEmpty) part,
  ];
}

/// A word's first letter, as a whole letter. `word[0]` is one UTF-16 code
/// unit, which is half of any letter outside the basic planes - and half a
/// letter compared against a typed one never matches.
String _initialOf(String word) => String.fromCharCode(word.runes.first);

/// [matchScore] with the camel-hump split applied, which is the one callers
/// should use. Kept apart so the plain version stays easy to reason about.
int? rankName(String name, String query) {
  final direct = matchScore(name, query);
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return direct;

  final words = searchWords(name);
  if (words.length < 2) return direct;

  var best = direct;
  // The initials of the camel-split words: "ytm" for "YouTubeMusic" written
  // without a space, which the plain split above reads as one word.
  //
  // Bounded to short queries for the same reason [matchScore] bounds its
  // copy: past about five letters, "initials" stops describing how anybody
  // shortens a name and starts describing a coincidence between a long
  // query and a long name.
  if (needle.length >= 2 && needle.length <= 5) {
    final initials = words.map(_initialOf).join();
    if (initials == needle) {
      best = _higher(best, 700);
    } else if (initials.startsWith(needle)) {
      best = _higher(best, 690);
    }
  }
  for (var i = 0; i < words.length; i++) {
    if (words[i].startsWith(needle)) {
      best = _higher(best, 800 - i * 10 - _lengthPenalty(name.toLowerCase()));
      break;
    }
  }
  return best;
}

int? _higher(int? a, int b) => a == null ? b : (a > b ? a : b);
