import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'clock_settings_controller.dart';
import 'clock_widget.dart';
import 'color_swatch_picker.dart';
import 'locale_controller.dart';

class ClockSettingsScreen extends StatelessWidget {
  const ClockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(title: Text(s.clock)),
          body: ValueListenableBuilder<ClockSettings>(
            valueListenable: ClockSettingsController.instance,
            builder: (context, settings, child) {
              return ListView(
                children: [
                  SwitchListTile(
                    title: Text(s.showClock),
                    value: settings.enabled,
                    onChanged: (value) {
                      ClockSettingsController.instance.update(
                        settings.copyWith(enabled: value),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      s.position,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: settings.enabled ? 1 : 0.4,
                    child: IgnorePointer(
                      ignoring: !settings.enabled,
                      child: _PositionSettings(settings: settings, s: s),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      s.style,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: settings.enabled ? 1 : 0.4,
                    child: IgnorePointer(
                      ignoring: !settings.enabled,
                      child: _StyleGrid(settings: settings, s: s),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      s.appearanceCustom,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: settings.enabled ? 1 : 0.4,
                    child: IgnorePointer(
                      ignoring: !settings.enabled,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        // Only the section for the style actually in use -
                        // the others' colors would sit there unused and just
                        // be confusing to look at.
                        child: switch (settings.style) {
                          ClockStyle.digital => _DigitalAppearance(
                            settings: settings,
                            s: s,
                          ),
                          ClockStyle.word => _WordAppearance(
                            settings: settings,
                            s: s,
                          ),
                          ClockStyle.roman => _RomanAppearance(
                            settings: settings,
                            s: s,
                          ),
                          ClockStyle.bars => _BarsAppearance(
                            settings: settings,
                            s: s,
                          ),
                          ClockStyle.dotMatrix => _DotMatrixAppearance(
                            settings: settings,
                            s: s,
                          ),
                          ClockStyle.splitFlap => _SplitFlapAppearance(
                            settings: settings,
                            s: s,
                          ),
                          ClockStyle.orbit => _OrbitAppearance(
                            settings: settings,
                            s: s,
                          ),
                          ClockStyle.vertical => _VerticalAppearance(
                            settings: settings,
                            s: s,
                          ),
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// The clock styles as a two-column grid of previews.
///
/// One per row would be eight full-width rows to scroll past before the last
/// style is even seen - which is no way to compare things you pick by how
/// they look. Two columns cut that in half and put every style on one
/// screen; the previews stay big enough to tell apart because they scale
/// into the tile instead of being cropped by it.
class _StyleGrid extends StatelessWidget {
  const _StyleGrid({required this.settings, required this.s});

  final ClockSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final styles = <({ClockStyle style, String title, Widget preview})>[
      (style: ClockStyle.digital, title: s.digital, preview: const _DigitalPreview()),
      (style: ClockStyle.word, title: s.custom, preview: const _WordPreview()),
      (style: ClockStyle.roman, title: s.roman, preview: const _RomanPreview()),
      (style: ClockStyle.bars, title: s.bars, preview: const _BarsPreview()),
      (
        style: ClockStyle.dotMatrix,
        title: s.dotMatrix,
        preview: const _DotMatrixPreview(),
      ),
      (
        style: ClockStyle.splitFlap,
        title: s.splitFlap,
        preview: const _SplitFlapPreview(),
      ),
      (style: ClockStyle.orbit, title: s.orbit, preview: const _OrbitPreview()),
      (
        style: ClockStyle.vertical,
        title: s.vertical,
        preview: const _VerticalPreview(),
      ),
    ];

    return GridView(
      // Inside the settings list, so it neither scrolls on its own nor
      // guesses a height - the page it sits in does the scrolling.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // A set height rather than an aspect ratio: tied to the width, the
        // tiles would grow taller on a bigger screen and undo the very
        // saving the grid is here for.
        mainAxisExtent: 128,
      ),
      children: [
        for (final entry in styles)
          _StyleOption(
            title: entry.title,
            selected: settings.style == entry.style,
            preview: entry.preview,
            onTap: () => ClockSettingsController.instance.update(
              settings.copyWith(style: entry.style),
            ),
          ),
      ],
    );
  }
}

class _PositionSettings extends StatelessWidget {
  const _PositionSettings({required this.settings, required this.s});

  final ClockSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final centered = settings.alignment == ClockAlignment.center;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(s.alignLeft),
                selected: settings.alignment == ClockAlignment.left,
                onSelected: (_) => ClockSettingsController.instance.update(
                  settings.copyWith(alignment: ClockAlignment.left),
                ),
              ),
              ChoiceChip(
                label: Text(s.alignCenter),
                selected: centered,
                onSelected: (_) => ClockSettingsController.instance.update(
                  settings.copyWith(alignment: ClockAlignment.center),
                ),
              ),
              ChoiceChip(
                label: Text(s.alignRight),
                selected: settings.alignment == ClockAlignment.right,
                onSelected: (_) => ClockSettingsController.instance.update(
                  settings.copyWith(alignment: ClockAlignment.right),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Label(s.distanceFromTop(settings.topPadding.round())),
          Slider(
            value: settings.topPadding,
            min: 0,
            max: 200,
            divisions: 40,
            onChanged: (value) => ClockSettingsController.instance.update(
              settings.copyWith(topPadding: value),
            ),
          ),
          // Meaningless while centered - there's no edge it's pushed
          // against yet.
          if (!centered) ...[
            const SizedBox(height: 8),
            _Label(s.distanceFromSide(settings.sidePadding.round())),
            Slider(
              value: settings.sidePadding,
              min: 0,
              max: 150,
              divisions: 30,
              onChanged: (value) => ClockSettingsController.instance.update(
                settings.copyWith(sidePadding: value),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DigitalAppearance extends StatelessWidget {
  const _DigitalAppearance({required this.settings, required this.s});

  final ClockSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(s.textColor),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.digitalColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(digitalColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _RomanAppearance extends StatelessWidget {
  const _RomanAppearance({required this.settings, required this.s});

  final ClockSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(s.textColor),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.romanColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(romanColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _DotMatrixAppearance extends StatelessWidget {
  const _DotMatrixAppearance({required this.settings, required this.s});

  final ClockSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(s.textColor),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.dotColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(dotColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SplitFlapAppearance extends StatelessWidget {
  const _SplitFlapAppearance({required this.settings, required this.s});

  final ClockSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(s.backgroundColor),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.splitFlapBgColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(splitFlapBgColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 16),
        _Label(
          s.backgroundStrength((settings.splitFlapBgOpacity * 100).round()),
        ),
        Slider(
          value: settings.splitFlapBgOpacity,
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: (value) {
            ClockSettingsController.instance.update(
              settings.copyWith(splitFlapBgOpacity: value),
            );
          },
        ),
        const SizedBox(height: 8),
        _Label(s.textColor),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.splitFlapTextColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(splitFlapTextColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _OrbitAppearance extends StatelessWidget {
  const _OrbitAppearance({required this.settings, required this.s});

  final ClockSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(s.textColor),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.orbitColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(orbitColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _VerticalAppearance extends StatelessWidget {
  const _VerticalAppearance({required this.settings, required this.s});

  final ClockSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(s.textColor),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.verticalColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(verticalColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _BarsAppearance extends StatelessWidget {
  const _BarsAppearance({required this.settings, required this.s});

  final ClockSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(s.barsFilledColor),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.barsFilledColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(barsFilledColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 16),
        _Label(s.barsUnfilledColor),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.barsUnfilledColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(barsUnfilledColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 16),
        _Label(
          s.barsUnfilledStrength(
            (settings.barsUnfilledOpacity * 100).round(),
          ),
        ),
        Slider(
          value: settings.barsUnfilledOpacity,
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: (value) {
            ClockSettingsController.instance.update(
              settings.copyWith(barsUnfilledOpacity: value),
            );
          },
        ),
        const SizedBox(height: 8),
        _Label(s.barsTextColor),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.barsTextColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(barsTextColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _WordAppearance extends StatelessWidget {
  const _WordAppearance({required this.settings, required this.s});

  final ClockSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(s.backgroundColor),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.wordBgColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(wordBgColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 16),
        _Label(s.backgroundStrength((settings.wordBgOpacity * 100).round())),
        Slider(
          value: settings.wordBgOpacity,
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: (value) {
            ClockSettingsController.instance.update(
              settings.copyWith(wordBgOpacity: value),
            );
          },
        ),
        const SizedBox(height: 8),
        _Label(s.activeLetters),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.wordActiveColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(wordActiveColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 16),
        _Label(s.inactiveLetters),
        ColorSwatchPicker(
          s: s,
          selectedIndex: settings.wordInactiveColorIndex,
          onSelected: (i) {
            ClockSettingsController.instance.update(
              settings.copyWith(wordInactiveColorIndex: i),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}


class _StyleOption extends StatelessWidget {
  const _StyleOption({
    required this.title,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.black : Colors.black26,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Scaled down to whatever the tile leaves rather than cropped:
            // the previews are real clocks of quite different sizes (a whole
            // letter grid next to four digits), and half a word clock says
            // nothing about what it looks like.
            Expanded(
              child: Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: preview),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  const Icon(Icons.check_circle, size: 14),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DigitalPreview extends StatelessWidget {
  const _DigitalPreview();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 60,
      child: Center(child: DigitalClock(fontSize: 28)),
    );
  }
}

class _WordPreview extends StatelessWidget {
  const _WordPreview();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 90,
      child: FittedBox(child: WordClock()),
    );
  }
}

class _RomanPreview extends StatelessWidget {
  const _RomanPreview();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 60,
      child: Center(child: RomanClock(fontSize: 28)),
    );
  }
}

class _BarsPreview extends StatelessWidget {
  const _BarsPreview();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 60,
      child: Center(child: BarsClock(barHeight: 50, barWidth: 14)),
    );
  }
}

class _DotMatrixPreview extends StatelessWidget {
  const _DotMatrixPreview();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 60,
      child: Center(child: DotMatrixClock(dotSize: 5)),
    );
  }
}

class _SplitFlapPreview extends StatelessWidget {
  const _SplitFlapPreview();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 60,
      child: Center(
        child: SplitFlapClock(digitWidth: 24, digitHeight: 34, fontSize: 20),
      ),
    );
  }
}

class _OrbitPreview extends StatelessWidget {
  const _OrbitPreview();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 60,
      child: Center(child: OrbitClock(size: 58)),
    );
  }
}

class _VerticalPreview extends StatelessWidget {
  const _VerticalPreview();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 60,
      child: Center(child: VerticalClock(fontSize: 18)),
    );
  }
}
