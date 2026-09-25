import 'package:flutter/material.dart';

import 'app_strings.dart';

/// The search box put above a long list of apps/entries, wherever one is
/// picked from - a folder's contents, a widget's link, an app row's picks
/// and so on. Kept in one place so all of them look and behave the same
/// instead of each screen growing its own slightly different copy.
class EntrySearchField extends StatelessWidget {
  const EntrySearchField({
    super.key,
    required this.controller,
    required this.s,
    required this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final AppStrings s;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        autocorrect: false,
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          hintText: s.searchApps,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

/// Keeps only the entries whose name contains [query] (case-insensitive),
/// in whatever order they were passed in. A plain substring match rather
/// than the ranked search on the home screen: these lists are deliberately
/// grouped (folders/web apps first, then packages) and a relevance re-sort
/// would undo that grouping.
List<T> filterByName<T>(List<T> entries, String query, String Function(T) nameOf) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return entries;
  return [
    for (final entry in entries)
      if (nameOf(entry).toLowerCase().contains(needle)) entry,
  ];
}
