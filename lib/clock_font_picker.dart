import 'package:flutter/material.dart';

import 'app_strings.dart';

/// The typefaces the digital clock can draw its digits in.
///
/// All of them are families Android itself ships, addressed by the names it
/// knows them under - so nothing has to be bundled, the APK doesn't grow,
/// and they work with no network. A device missing one of them falls back to
/// its default on its own, which is why an unknown name is harmless.
///
/// The empty string is the default face, stored that way (rather than as
/// "roboto") so a phone whose system font is something else keeps following
/// it.
const List<String> clockFontFamilies = [
  '',
  'sans-serif-condensed',
  'serif',
  'monospace',
  'casual',
  'cursive',
];

String clockFontLabel(String family, AppStrings s) => switch (family) {
  'sans-serif-condensed' => s.fontCondensed,
  'serif' => s.fontSerif,
  'monospace' => s.fontMonospace,
  'casual' => s.fontCasual,
  'cursive' => s.fontCursive,
  _ => s.fontStandard,
};

/// The choice as chips, each one previewing itself: the label is drawn in
/// the face it selects, so the list can be read rather than guessed at.
class ClockFontPicker extends StatelessWidget {
  const ClockFontPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.s,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final family in clockFontFamilies)
          ChoiceChip(
            label: Text(
              // Digits alongside the name, because digits are the only
              // thing the setting actually affects - and the faces differ
              // far more in those than in their letters.
              '${clockFontLabel(family, s)}  12:30',
              style: TextStyle(fontFamily: family.isEmpty ? null : family),
            ),
            selected: selected == family,
            onSelected: (_) => onSelected(family),
          ),
      ],
    );
  }
}
