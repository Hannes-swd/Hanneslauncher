import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'builtin_entries.dart';
import 'contacts_controller.dart';
import 'entry_match.dart';
import 'expression_calculator.dart';
import 'folder_sheet.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'settings_catalog.dart';
import 'settings_screen.dart';
import 'widget_action.dart';
import 'widget_element.dart';

/// Which pile a result came out of. Decides its icon and the order the
/// piles appear in.
enum SearchHitKind { calculation, app, setting, contact, web }

/// One row in a search element's result list.
class SearchHit {
  const SearchHit({
    required this.kind,
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.entry,
  });

  final SearchHitKind kind;
  final String title;
  final String subtitle;

  /// Set for app hits, so the row can show the app's real icon instead of a
  /// generic one.
  final LauncherEntry? entry;

  final Future<void> Function(BuildContext context) onTap;

  IconData get icon => switch (kind) {
    SearchHitKind.calculation => Icons.calculate_outlined,
    SearchHitKind.app => Icons.apps,
    SearchHitKind.setting => Icons.settings_outlined,
    SearchHitKind.contact => Icons.person_outline,
    SearchHitKind.web => Icons.public,
  };
}

/// Collects what a search element should show for [query], from whichever
/// piles the element has ticked.
///
/// The order is fixed rather than configurable, and it is the order of how
/// certain a hit is: a sum has exactly one right answer, an app match is
/// unambiguous, a web search is the fallback that always applies. Letting
/// that be rearranged would only ever make the list worse.
Future<List<SearchHit>> runWidgetSearch({
  required String query,
  required WidgetElement element,
  required AppStrings s,
}) => runSearch(
  query: query,
  s: s,
  calculation: element.searchCalculation,
  apps: element.searchApps,
  settings: element.searchSettings,
  contacts: element.searchContacts,
  webSearchUrl: element.webSearchUrl,
  limit: element.resultLimit,
);

/// The search itself, without a widget element in front of it.
///
/// Split out because the home screen's own search - the magnifier at the
/// bottom of the alphabet bar - wants the same piles and had none of them.
/// For a long time the best search in this app was the one you had to build
/// a widget to get at: the magnifier could find an app by name and nothing
/// else, while a search element on the panel could do sums, find a contact
/// and jump to a setting. There was no reason for that beyond where the code
/// happened to live.
Future<List<SearchHit>> runSearch({
  required String query,
  required AppStrings s,
  required bool calculation,
  required bool apps,
  required bool settings,
  required bool contacts,
  required String webSearchUrl,
  required int limit,
}) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];

  final hits = <SearchHit>[];

  if (calculation) {
    final answer = calculateExpression(trimmed);
    if (answer != null) {
      hits.add(
        SearchHit(
          kind: SearchHitKind.calculation,
          title: answer,
          subtitle: trimmed,
          // Nothing to open - the answer is the whole point. Tapping it is
          // a no-op rather than something surprising.
          onTap: (context) async {},
        ),
      );
    }
  }

  if (apps) {
    hits.addAll(_appHits(trimmed, limit));
  }

  if (settings) {
    hits.addAll(_settingHits(trimmed, s, limit));
  }

  if (contacts) {
    hits.addAll(await _contactHits(trimmed, limit));
  }

  // Always last, and never cut off by the limit: it is the row that says
  // "nothing here matched, but this will find something".
  final webUrl = webSearchUrl.trim();
  if (webUrl.isNotEmpty) {
    hits.add(
      SearchHit(
        kind: SearchHitKind.web,
        title: s.searchOnTheWeb(trimmed),
        subtitle: _hostOf(webUrl),
        onTap: (context) async {
          final result = await openWebSearch(webUrl, trimmed);
          // Success is the browser coming up in front, which speaks for
          // itself. Only a failure needs saying, or the tap looks ignored.
          if (result.success || !context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.actionFailed(result.detail ?? ''))),
          );
        },
      ),
    );
  }

  return hits;
}

List<SearchHit> _appHits(String query, int limit) {
  // The same ranking the home screen's list uses - see entry_match.dart.
  // Two searches in one app that disagree about which app "ytm" means is a
  // worse fault than either of them being imperfect.
  final scored = <({LauncherEntry entry, int score})>[];
  for (final entry in LauncherEntriesController.instance.entries) {
    final score = rankName(entry.name, query);
    if (score != null) scored.add((entry: entry, score: score));
  }
  scored.sort((a, b) {
    if (a.score != b.score) return b.score - a.score;
    return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
  });
  final matches = [for (final hit in scored) hit.entry];

  return [
    for (final entry in matches.take(limit))
      SearchHit(
        kind: SearchHitKind.app,
        title: entry.name,
        entry: entry,
        onTap: (context) async {
          if (entry.isFolder) {
            showFolderSheet(context, entry.folder!);
          } else if (entry.isBuiltIn) {
            await openBuiltIn(context, entry.builtIn!);
          } else {
            await entry.launch();
          }
        },
      ),
  ];
}

List<SearchHit> _settingHits(String query, AppStrings s, int limit) {
  final lowered = query.toLowerCase();
  return [
    for (final entry in currentSettingsCatalog(s))
      if (entry.matches(lowered))
        SearchHit(
          kind: SearchHitKind.setting,
          title: entry.title,
          subtitle: entry.section.label(s),
          onTap: (context) async => entry.onTap(context),
        ),
  ].take(limit).toList();
}

Future<List<SearchHit>> _contactHits(String query, int limit) async {
  final contacts = ContactsController.instance;
  // Asked for at the moment somebody actually searches with the box ticked,
  // never at startup - a launcher set up without it should never see the
  // prompt at all.
  if (!await contacts.ensureAvailable()) return const [];

  final found = await contacts.search(query, limit: limit);
  return [
    for (final contact in found)
      SearchHit(
        kind: SearchHitKind.contact,
        title: contact.name,
        subtitle: contact.number,
        // Straight to the dialer with the number filled in - the thing
        // somebody searching for a person from the home screen almost
        // always wants. The contact card is one tap further, in the dialer.
        onTap: (context) => contacts.dial(contact.number),
      ),
  ];
}

String _hostOf(String url) {
  final uri = Uri.tryParse(url.trim());
  final host = uri?.host ?? '';
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// Fills the query into [template] - which holds `{{suche}}` where the words
/// belong - and hands the result to the phone.
Future<WidgetActionResult> openWebSearch(String template, String query) =>
    openExternalUrl(buildSearchUrl(template, query));

/// Fills [query] into a search address the way a tap would, without opening
/// anything. Shared with the editor's preview and with the action button, so
/// none of them can build a different address than the others.
String buildSearchUrl(String template, String query) => template.replaceAll(
  webSearchQueryToken,
  Uri.encodeQueryComponent(query),
);
