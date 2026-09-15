import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'color_swatch_picker.dart';
import 'design_controller.dart';
import 'design_tokens.dart';
import 'design_widgets.dart';
import 'locale_controller.dart';

/// Where the look is changed: a theme, the six colors it is made of, and the
/// handful of scalars that decide shape, depth, spacing and size.
///
/// The screen is drawn in the very design it is setting, so every change
/// shows up on the page it was made on - no preview pane that could disagree
/// with the real thing, and nothing to apply or reload. The strip at the top
/// exists only because the three surface tiers can't all be seen in a list of
/// rows otherwise.
class DesignSettingsScreen extends StatelessWidget {
  const DesignSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<DesignSettings>(
          valueListenable: DesignController.instance,
          builder: (context, settings, child) {
            final design = context.design;
            return Scaffold(
              appBar: AppBar(title: Text(s.design)),
              body: ListView(
                padding: EdgeInsets.only(bottom: design.spaceXl),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      design.spaceMd,
                      design.spaceSm,
                      design.spaceMd,
                      0,
                    ),
                    child: Text(
                      s.designScopeHint,
                      style: design.textStyle(TypeRole.caption),
                    ),
                  ),

                  // Every group carries the thing it changes, rather than one
                  // preview at the top standing in for all of them. A slider
                  // with its effect two screens away is a slider you adjust
                  // by guessing.
                  SettingsHeading(s.designPreview),
                  _Preview(s: s),

                  SettingsHeading(s.designThemeLabel),
                  _ThemeGrid(settings: settings, s: s),

                  SettingsHeading(s.designColors),
                  _ColorRows(settings: settings, s: s),

                  SettingsHeading(s.designTypography),
                  _TypeSection(settings: settings, s: s),

                  SettingsHeading(s.designFieldStyle),
                  _FieldStyleChoice(settings: settings, s: s),

                  SettingsHeading(s.designDepth),
                  _DepthSection(settings: settings, s: s),

                  SettingsHeading(s.designSpaceGroup),
                  _SpaceSection(settings: settings, s: s),

                  SettingsHeading(s.designMotionLabel),
                  _MotionSection(settings: settings, s: s),

                  SizedBox(height: design.spaceSm),
                  ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: Text(s.designReset),
                    onTap: DesignController.instance.reset,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// The three tiers side by side. Reading a slider's effect off the settings
/// page alone is hard - most of it is rows, and rows only show one tier - so
/// this shows all three at once, in the real sizes, shadows and radii.
class _Preview extends StatelessWidget {
  const _Preview({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Padding(
      padding: design.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PreviewCard(
            level: SurfaceLevel.hero,
            title: s.designPreviewHero,
            body: s.designPreviewBody,
          ),
          SizedBox(height: design.space(SurfaceLevel.hero) * 0.5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PreviewCard(
                  level: SurfaceLevel.normal,
                  title: s.designPreviewNormal,
                ),
              ),
              SizedBox(width: design.spaceSm),
              Expanded(
                child: _PreviewCard(
                  level: SurfaceLevel.compact,
                  title: s.designPreviewCompact,
                  // One card wears the active ring, because that state is
                  // the other half of the design worth seeing before it is
                  // met somewhere real.
                  active: true,
                  subtitle: s.designPreviewSelected,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.level,
    required this.title,
    this.body,
    this.subtitle,
    this.active = false,
  });

  final SurfaceLevel level;
  final String title;
  final String? body;
  final String? subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final style = design.surfaceStyle(level);
    return Container(
      padding: style.insets,
      constraints: BoxConstraints(minHeight: style.minHeight * 0.45),
      decoration: design.cardDecoration(level, active: active),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: style.titleSize,
              fontWeight: DesignTokens.weightBold,
              color: design.textPrimary,
            ),
          ),
          if (body != null) ...[
            SizedBox(height: design.spaceXs),
            Text(
              body!,
              style: TextStyle(
                fontSize: design.typeBody,
                color: design.textSecondary,
              ),
            ),
          ],
          if (subtitle != null) ...[
            SizedBox(height: design.spaceXs),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: design.typeCaption,
                color: design.accent,
                fontWeight: DesignTokens.weightBold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The five presets, each shown as the colors it stands for rather than as
/// its name alone - which is the only way to pick one by how it looks.
class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({required this.settings, required this.s});

  final DesignSettings settings;
  final AppStrings s;

  String _label(DesignThemePreset preset) => switch (preset) {
    DesignThemePreset.grey => s.designThemeGrey,
    DesignThemePreset.rose => s.designThemeRose,
    DesignThemePreset.green => s.designThemeGreen,
    DesignThemePreset.blue => s.designThemeBlue,
    DesignThemePreset.dark => s.designThemeDark,
  };

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: design.pagePadding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: design.spaceSm,
        crossAxisSpacing: design.spaceSm,
        mainAxisExtent: design.surfaceStyle(SurfaceLevel.compact).minHeight,
      ),
      children: [
        for (final preset in DesignThemePreset.values)
          OptionTile(
            title: _label(preset),
            // Only when nothing has been changed by hand: with an override
            // in place the screen is no longer showing that preset, and a
            // tick saying otherwise would be a lie about what is on screen.
            selected:
                settings.preset == preset && settings.overrides.isEmpty,
            level: SurfaceLevel.compact,
            preview: _PresetSwatch(preset: preset),
            onTap: () => DesignController.instance.update(
              settings.withPreset(preset),
            ),
          ),
      ],
    );
  }
}

/// A preset boiled down to what it looks like: its ground, a card on it, and
/// the accent.
class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({required this.preset});

  final DesignThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final radius = BorderRadius.circular(design.radiusSmall);
    return Container(
      width: 56,
      height: 34,
      decoration: BoxDecoration(
        color: presetColor(preset, DesignColorRole.background),
        borderRadius: radius,
        border: Border.all(
          color: presetColor(preset, DesignColorRole.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 18,
            height: 14,
            decoration: BoxDecoration(
              color: presetColor(preset, DesignColorRole.surface),
              borderRadius: BorderRadius.circular(design.radiusSmall * 0.6),
              border: Border.all(
                color: presetColor(preset, DesignColorRole.border),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: presetColor(preset, DesignColorRole.accent),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row per color role. A row is showing either what the preset says or
/// what was picked instead; the second case gets a way back, so a change is
/// never a one-way door.
class _ColorRows extends StatelessWidget {
  const _ColorRows({required this.settings, required this.s});

  final DesignSettings settings;
  final AppStrings s;

  String _label(DesignColorRole role) => switch (role) {
    DesignColorRole.background => s.designRoleBackground,
    DesignColorRole.surface => s.designRoleSurface,
    DesignColorRole.textPrimary => s.designRoleTextPrimary,
    DesignColorRole.textSecondary => s.designRoleTextSecondary,
    DesignColorRole.accent => s.designRoleAccent,
    DesignColorRole.border => s.designRoleBorder,
  };

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            design.spaceMd,
            0,
            design.spaceMd,
            design.spaceSm * 0.5,
          ),
          child: Text(
            s.designColorsHint,
            style: TextStyle(
              fontSize: design.typeLabel,
              color: design.textSecondary,
            ),
          ),
        ),
        for (final role in DesignColorRole.values)
          ListTile(
            leading: ColorDot(color: settings.color(role), size: 32),
            title: Text(_label(role)),
            trailing: settings.overrides.containsKey(role)
                ? IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: s.designResetColors,
                    onPressed: () => DesignController.instance.update(
                      settings.withColor(role, null),
                    ),
                  )
                : null,
            onTap: () async {
              final picked = await showColorPickerDialog(
                context,
                s,
                title: _label(role),
                initial: settings.color(role),
                // The two colors the app paints its solid grounds with get no
                // opacity slider: a see-through ground is a hole rather than
                // a color, and how much of the wallpaper shows through the
                // panel is its own setting further down this page.
                allowAlpha:
                    role != DesignColorRole.background &&
                    role != DesignColorRole.surface,
              );
              if (picked == null) return;
              await DesignController.instance.update(
                settings.withColor(role, picked),
              );
            },
          ),
        if (settings.overrides.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.format_color_reset_outlined),
            title: Text(s.designResetColors),
            onTap: () => DesignController.instance.update(
              settings.withPreset(settings.preset),
            ),
          ),
      ],
    );
  }
}

/// Everything the font slider touches, shown as the ramp rather than as one
/// line: the sizes only mean something next to each other.
class _TypeSection extends StatelessWidget {
  const _TypeSection({required this.settings, required this.s});

  final DesignSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return _Panel(
      children: [
        // Four roles at once, so what is on show is the relation between
        // them - the tracking pulling tight as the size grows, the weight
        // going the other way - and not just "text, bigger".
        Text(s.designTypography.toUpperCase(),
            style: design.textStyle(TypeRole.overline)),
        SizedBox(height: design.spaceXs),
        Text(s.design, style: design.textStyle(TypeRole.display)),
        Text(s.designTypeSample, style: design.textStyle(TypeRole.heading)),
        SizedBox(height: design.spaceXs),
        Text(s.designTypeSample, style: design.textStyle(TypeRole.body)),
        Text(s.designTypeSample, style: design.textStyle(TypeRole.caption)),
        SizedBox(height: design.spaceSm),
        FieldLabel(s.designFontSize((settings.font * 100).round())),
        _Slider(
          range: fontRange,
          value: settings.font,
          divisions: 9,
          onChanged: (v) =>
              DesignController.instance.update(settings.copyWith(font: v)),
        ),
      ],
    );
  }
}

/// Rounding and shadow. Both are read off the preview at the top of the page,
/// which is why they sit together and why neither gets a preview of its own.
class _DepthSection extends StatelessWidget {
  const _DepthSection({required this.settings, required this.s});

  final DesignSettings settings;
  final AppStrings s;

  String _shadowWord(double value) {
    if (value <= 0.01) return s.designShadowOff;
    if (value < 0.38) return s.designShadowSubtle;
    if (value < 0.72) return s.designShadowNormal;
    return s.designShadowStrong;
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return _Panel(
      children: [
        FieldLabel(s.designRounding(settings.radius.round())),
        _Slider(
          range: radiusRange,
          value: settings.radius,
          divisions: 28,
          onChanged: (v) =>
              DesignController.instance.update(settings.copyWith(radius: v)),
        ),
        Text(s.designRoundingHint, style: design.textStyle(TypeRole.caption)),
        SizedBox(height: design.spaceSm),
        FieldLabel(s.designShadow(_shadowWord(settings.shadow))),
        _Slider(
          range: shadowRange,
          value: settings.shadow,
          divisions: 20,
          onChanged: (v) =>
              DesignController.instance.update(settings.copyWith(shadow: v)),
        ),
      ],
    );
  }
}

/// How much room things take, and how much of the wallpaper the panel lets
/// through.
class _SpaceSection extends StatelessWidget {
  const _SpaceSection({required this.settings, required this.s});

  final DesignSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    int percent(double value) => (value * 100).round();
    return _Panel(
      children: [
        FieldLabel(s.designSpacing(percent(settings.spacing))),
        _Slider(
          range: spacingRange,
          value: settings.spacing,
          divisions: 14,
          onChanged: (v) =>
              DesignController.instance.update(settings.copyWith(spacing: v)),
        ),
        SizedBox(height: design.spaceSm),
        FieldLabel(s.designCardSize(percent(settings.cardSize))),
        _Slider(
          range: cardSizeRange,
          value: settings.cardSize,
          divisions: 12,
          onChanged: (v) =>
              DesignController.instance.update(settings.copyWith(cardSize: v)),
        ),
        SizedBox(height: design.spaceSm),
        FieldLabel(s.designPanelOpacity(percent(settings.opacity))),
        _Slider(
          range: opacityRange,
          value: settings.opacity,
          divisions: 12,
          onChanged: (v) =>
              DesignController.instance.update(settings.copyWith(opacity: v)),
        ),
        Text(
          s.designPanelOpacityHint,
          style: design.textStyle(TypeRole.caption),
        ),
      ],
    );
  }
}

/// The one setting that cannot be shown standing still, so it comes with
/// something to tap.
class _MotionSection extends StatelessWidget {
  const _MotionSection({required this.settings, required this.s});

  final DesignSettings settings;
  final AppStrings s;

  String _word(double value) {
    if (value <= 0.01) return s.designMotionOff;
    if (value < 0.85) return s.designMotionBrisk;
    if (value < 1.2) return s.designMotionNormal;
    return s.designMotionCalm;
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return _Panel(
      children: [
        const _MotionDemo(),
        SizedBox(height: design.spaceSm),
        FieldLabel(s.designMotion(_word(settings.motion))),
        _Slider(
          range: motionRange,
          value: settings.motion,
          divisions: 16,
          onChanged: (v) =>
              DesignController.instance.update(settings.copyWith(motion: v)),
        ),
        Text(s.designMotionHint, style: design.textStyle(TypeRole.caption)),
      ],
    );
  }
}

/// A card that moves when tapped, at exactly the speed the slider is set to.
///
/// A duration in milliseconds is a number nobody can picture. Two seconds of
/// tapping this says more than the label ever could, and it is the same
/// duration and the same curve the rest of the app uses, not an imitation.
class _MotionDemo extends StatefulWidget {
  const _MotionDemo();

  @override
  State<_MotionDemo> createState() => _MotionDemoState();
}

class _MotionDemoState extends State<_MotionDemo> {
  bool _moved = false;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final s = AppStrings(LocaleController.instance.value);
    final size = design.typeBody * 2.6;
    return GestureDetector(
      onTap: () => setState(() => _moved = !_moved),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: size + design.spaceSm * 2,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                s.designMotionDemo,
                style: design.textStyle(TypeRole.caption),
              ),
            ),
            AnimatedAlign(
              alignment: _moved
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              duration: design.motionNormal,
              curve: design.motionCurve,
              child: AnimatedContainer(
                duration: design.motionNormal,
                curve: design.motionCurve,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: design.accent,
                  borderRadius: BorderRadius.circular(
                    _moved ? size / 2 : design.radiusSmall,
                  ),
                  boxShadow: design.accentGlow(SurfaceLevel.compact),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The controls belonging to one heading, in the page's own margins.
///
/// Not a card: gathering settings onto surfaces was tried and it made the
/// app look like a form. The heading above is enough to say where a group
/// begins.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.design.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// A slider that takes its bounds from the [DesignRange] the setting is
/// defined by, so the track can never offer a value the setting would then
/// clamp away behind the user's back.
class _Slider extends StatelessWidget {
  const _Slider({
    required this.range,
    required this.value,
    required this.divisions,
    required this.onChanged,
  });

  final DesignRange range;
  final double value;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: range.clamp(value),
      min: range.min,
      max: range.max,
      divisions: divisions,
      onChanged: onChanged,
    );
  }
}

/// How text fields are framed, with a real field under it rather than a
/// drawing of one.
///
/// A live field is the only honest preview here: it is the same widget, in
/// the same theme, so what is shown is what every other field in the app will
/// look like - including in the dark, which is where the framing was hardest
/// to picture from a name alone.
class _FieldStyleChoice extends StatelessWidget {
  const _FieldStyleChoice({required this.settings, required this.s});

  final DesignSettings settings;
  final AppStrings s;

  String _label(InputFieldStyle style) => switch (style) {
    InputFieldStyle.line => s.designFieldLine,
    InputFieldStyle.box => s.designFieldBox,
    InputFieldStyle.plain => s.designFieldPlain,
  };

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Padding(
      padding: design.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: design.spaceSm * 0.6,
            children: [
              for (final style in InputFieldStyle.values)
                ChoiceChip(
                  label: Text(_label(style)),
                  selected: settings.fieldStyle == style,
                  onSelected: (_) => DesignController.instance.update(
                    settings.copyWith(fieldStyle: style),
                  ),
                ),
            ],
          ),
          SizedBox(height: design.spaceSm),
          TextField(
            decoration: InputDecoration(
              isDense: true,
              labelText: s.designFieldSample,
              suffixIcon: const Icon(Icons.edit_outlined),
            ),
          ),
          SizedBox(height: design.spaceXs),
          Text(
            s.designFieldHint,
            style: TextStyle(
              fontSize: design.typeCaption,
              color: design.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
