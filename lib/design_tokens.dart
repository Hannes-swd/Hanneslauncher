import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The launcher's look, as a handful of numbers instead of values typed into
/// widgets.
///
/// Everything the app's own chrome draws - the pull-down panel, its cards,
/// every settings screen, every dialog - reads its colors, corner radii,
/// shadows, gaps and text sizes from here. Nothing picks a color or a radius
/// of its own any more, which is what makes "change one slider, the whole app
/// follows" possible at all.
///
/// What this deliberately does *not* own: the home screen. The clock's
/// colors, the app list's font and color and the wallpaper are settings of
/// their own, because they sit on top of whatever picture the user chose -
/// a theme that reaches them would fight the wallpaper instead of the
/// launcher. The boundary is "does it have a background the app drew
/// itself".
///
/// The shape of it:
///
///   [DesignSettings]  what the user actually adjusts - a preset, optional
///                     per-color overrides, and six scalars.
///   [DesignTokens]    what widgets read - concrete colors, three tiers of
///                     surface, a type scale. Derived, never stored.
///   [buildAppTheme]   the same tokens poured into a Material [ThemeData],
///                     so every stock widget follows without being touched.

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

/// The colors a theme is made of. Each one can be overridden on its own, so
/// this enum is also the list of rows the design settings shows.
enum DesignColorRole {
  background,
  surface,
  textPrimary,
  textSecondary,
  accent,
  border,
}

/// Ready-made color sets. A preset is a starting point, not a cage: picking
/// one clears the per-color overrides, and every color can then be changed
/// again individually on top of it.
enum DesignThemePreset { grey, rose, green, blue, dark }

/// How a text field is drawn.
///
/// [line] carries a single line under the text and nothing else - the
/// quietest of the three, and the default, because a settings page is mostly
/// fields and a box around each of them turns it into a grid of boxes.
/// [box] draws the full outline, for when the edges of a field should be
/// unmistakable. [plain] drops the outline and tints the field instead, which
/// reads as one soft shape rather than as a frame.
enum InputFieldStyle { line, box, plain }

/// The colors each preset stands for. Kept complete rather than "just the
/// ones that differ": a half-filled preset would have to inherit the rest
/// from somewhere, and that somewhere is exactly where a rose theme ends up
/// with a grey border nobody chose.
///
/// Three rules hold across all five, and between them they are what stops a
/// preset looking like a color picker went off:
///
///   The grounds are near-grey. Everything a preset fills large areas with -
///   background, surface, border - stays under about a tenth of full
///   saturation, so the tint is something you notice only next to another
///   preset. A theme whose ground is a pastel wash reads as a form to fill
///   in, and it leaves the accent nothing to be the colored thing against;
///   these carry the hue in the ink and the accent instead, where a small
///   amount of it goes a long way.
///
///   The accents are deep, not bright. Each one clears 4.5:1 against its own
///   card, which is the same bar its text has to clear - so an accent is a
///   color a link can be *set in*, not just a color a switch can be filled
///   with. It also rules out the whole top-right corner of the color wheel,
///   which is where a saturated accent at full brightness lives and where
///   every stock palette puts its blue.
///
///   The accent belongs to its neutrals. The near-greys are pulled a step
///   towards the accent's own hue - warm paper under a copper, cool paper
///   under the slate blue. Neutrals at flat zero saturation under a
///   saturated accent is the arrangement that makes the accent look stuck
///   on rather than chosen, whatever the accent is.
///
/// [test/design_test.dart] holds the first two to those numbers, because
/// they are the ones a later edit would break without anything looking wrong
/// until the app is on a phone.
const Map<DesignThemePreset, Map<DesignColorRole, Color>> _presetColors = {
  DesignThemePreset.grey: {
    DesignColorRole.background: Color(0xFFF4F3F0),
    DesignColorRole.surface: Color(0xFFFFFFFF),
    DesignColorRole.textPrimary: Color(0xFF1B1A17),
    DesignColorRole.textSecondary: Color(0xFF6C6860),
    DesignColorRole.accent: Color(0xFFA15B2D),
    DesignColorRole.border: Color(0xFFE4E1DA),
  },
  DesignThemePreset.rose: {
    DesignColorRole.background: Color(0xFFF7F1F1),
    DesignColorRole.surface: Color(0xFFFFFBFB),
    DesignColorRole.textPrimary: Color(0xFF20191A),
    DesignColorRole.textSecondary: Color(0xFF756264),
    DesignColorRole.accent: Color(0xFFA63D5C),
    DesignColorRole.border: Color(0xFFEBDDDF),
  },
  DesignThemePreset.green: {
    DesignColorRole.background: Color(0xFFF0F3EF),
    DesignColorRole.surface: Color(0xFFFBFDFA),
    DesignColorRole.textPrimary: Color(0xFF181C18),
    DesignColorRole.textSecondary: Color(0xFF5F6B5F),
    DesignColorRole.accent: Color(0xFF3F7A52),
    DesignColorRole.border: Color(0xFFDCE3D9),
  },
  DesignThemePreset.blue: {
    DesignColorRole.background: Color(0xFFEFF2F5),
    DesignColorRole.surface: Color(0xFFFAFCFD),
    DesignColorRole.textPrimary: Color(0xFF171B1F),
    DesignColorRole.textSecondary: Color(0xFF5C6874),
    DesignColorRole.accent: Color(0xFF2E6C8E),
    DesignColorRole.border: Color(0xFFDCE3E9),
  },
  DesignThemePreset.dark: {
    DesignColorRole.background: Color(0xFF121211),
    DesignColorRole.surface: Color(0xFF1D1C1A),
    DesignColorRole.textPrimary: Color(0xFFF2F0EC),
    DesignColorRole.textSecondary: Color(0xFFA09C94),
    DesignColorRole.accent: Color(0xFFD98A4A),
    DesignColorRole.border: Color(0xFF33322E),
  },
};

Color presetColor(DesignThemePreset preset, DesignColorRole role) =>
    _presetColors[preset]![role]!;

// ---------------------------------------------------------------------------
// The scale
// ---------------------------------------------------------------------------

/// The golden ratio, and the step the whole design is measured in.
///
/// Every size in this file is one of these two numbers raised to a whole
/// power of something else in it, rather than a number that looked about
/// right. Sizes picked one at a time drift a pixel or two out of relation and
/// the eye reads the result as approximate, even when it cannot say why.
const phi = 1.618033988749895;

/// The square root of [phi]: one step of the type ramp. A full golden ratio
/// between adjacent text sizes is a jump - fine between a headline and body
/// text, far too much between body text and a caption - so the ramp climbs in
/// half-steps and reaches [phi] every two of them.
final typeStep = math.sqrt(phi);

/// The type ramp, in steps away from body text.
///
/// Six sizes, not ten. A system with a size for every occasion ends up with
/// several that differ by a point, which reads as sloppy rather than as
/// precise; the work of telling two pieces of text apart is done by weight
/// and letter-spacing instead, where it costs no space at all.
double typeAt(double step) => 15 * math.pow(typeStep, step).toDouble();

/// The spacing ramp: 4, 8, 12, 20, 32, 52.
///
/// Each one is the sum of the two before it, so the ratio between neighbours
/// closes on [phi] as they grow - the same rhythm as the type, in whole
/// pixels that land on the screen's own grid.
const spaceRamp = [4.0, 8.0, 12.0, 20.0, 32.0, 52.0];

// ---------------------------------------------------------------------------
// The adjustable settings
// ---------------------------------------------------------------------------

/// The scalars, with the range each one may take and what it starts at.
///
/// The bounds are the whole reason no combination can look broken: a radius
/// can't reach zero on one tier and stay round on another, text can't shrink
/// until rows collapse, shadows can't grow into smears. They are checked in
/// [DesignSettings], not at the sliders, so a value arriving from a backup
/// file is held to the same limits as one dragged by hand.
class DesignRange {
  const DesignRange(this.min, this.max, this.initial);

  final double min;
  final double max;
  final double initial;

  double clamp(double value) => value.clamp(min, max).toDouble();
}

/// Corner radius of the largest tier, in logical pixels. The two smaller
/// tiers follow from it (see [DesignTokens.radius]).
const radiusRange = DesignRange(4, 32, 24);

/// 0 removes every shadow, 0.5 is the designed default, 1 doubles it.
const shadowRange = DesignRange(0, 1, 0.5);

/// Multiplies every gap and every bit of padding.
const spacingRange = DesignRange(0.8, 1.5, 1);

/// Multiplies the height cards ask for.
const cardSizeRange = DesignRange(0.8, 1.4, 1);

/// Multiplies the whole type scale.
const fontRange = DesignRange(0.85, 1.3, 1);

/// How solid the panel and its cards are over the wallpaper. 1 hides the
/// wallpaper behind the panel completely.
const opacityRange = DesignRange(0.4, 1, 0.85);

/// How long things take to move. 0 switches animation off outright - which
/// some people want and some phones need - and 1.6 draws every transition out
/// to where it can be watched.
const motionRange = DesignRange(0, 1.6, 1);

/// Everything the user has set about the look, and nothing derived from it.
/// This is what gets persisted and what goes into a backup.
@immutable
class DesignSettings {
  DesignSettings({
    this.preset = DesignThemePreset.grey,
    this.fieldStyle = InputFieldStyle.line,
    Map<DesignColorRole, Color> overrides = const {},
    double? radius,
    double? shadow,
    double? spacing,
    double? cardSize,
    double? font,
    double? opacity,
    double? motion,
  }) : overrides = Map.unmodifiable(overrides),
       motion = motionRange.clamp(motion ?? motionRange.initial),
       radius = radiusRange.clamp(radius ?? radiusRange.initial),
       shadow = shadowRange.clamp(shadow ?? shadowRange.initial),
       spacing = spacingRange.clamp(spacing ?? spacingRange.initial),
       cardSize = cardSizeRange.clamp(cardSize ?? cardSizeRange.initial),
       font = fontRange.clamp(font ?? fontRange.initial),
       opacity = opacityRange.clamp(opacity ?? opacityRange.initial);

  final DesignThemePreset preset;

  /// How every text field in the app is framed.
  final InputFieldStyle fieldStyle;

  /// Colors changed by hand, on top of [preset]. Only the ones actually
  /// touched are in here - the rest follow the preset, so switching presets
  /// moves them without anything having to be rewritten.
  final Map<DesignColorRole, Color> overrides;

  final double radius;
  final double shadow;
  final double spacing;
  final double cardSize;
  final double font;
  final double opacity;

  /// Multiplies every animation's length. See [DesignTokens.duration].
  final double motion;

  Color color(DesignColorRole role) =>
      overrides[role] ?? presetColor(preset, role);

  DesignSettings copyWith({
    DesignThemePreset? preset,
    InputFieldStyle? fieldStyle,
    Map<DesignColorRole, Color>? overrides,
    double? radius,
    double? shadow,
    double? spacing,
    double? cardSize,
    double? font,
    double? opacity,
    double? motion,
  }) {
    return DesignSettings(
      preset: preset ?? this.preset,
      fieldStyle: fieldStyle ?? this.fieldStyle,
      overrides: overrides ?? this.overrides,
      motion: motion ?? this.motion,
      radius: radius ?? this.radius,
      shadow: shadow ?? this.shadow,
      spacing: spacing ?? this.spacing,
      cardSize: cardSize ?? this.cardSize,
      font: font ?? this.font,
      opacity: opacity ?? this.opacity,
    );
  }

  /// Picking a preset drops every hand-picked color with it. Keeping them
  /// would mean "rose" arrives with the old accent still on it, which is
  /// not what choosing a theme looks like from the outside - and the way
  /// back (change that one color again) is one tap away either way.
  DesignSettings withPreset(DesignThemePreset value) => DesignSettings(
    preset: value,
    fieldStyle: fieldStyle,
    radius: radius,
    shadow: shadow,
    spacing: spacing,
    cardSize: cardSize,
    font: font,
    opacity: opacity,
    motion: motion,
  );

  DesignSettings withColor(DesignColorRole role, Color? value) {
    final next = {...overrides};
    if (value == null) {
      next.remove(role);
    } else {
      next[role] = value;
    }
    return copyWith(overrides: next);
  }

  @override
  bool operator ==(Object other) =>
      other is DesignSettings &&
      other.preset == preset &&
      other.fieldStyle == fieldStyle &&
      other.radius == radius &&
      other.shadow == shadow &&
      other.spacing == spacing &&
      other.cardSize == cardSize &&
      other.font == font &&
      other.opacity == opacity &&
      other.motion == motion &&
      _sameOverrides(other.overrides);

  bool _sameOverrides(Map<DesignColorRole, Color> other) {
    if (other.length != overrides.length) return false;
    for (final entry in overrides.entries) {
      if (other[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    preset,
    fieldStyle,
    radius,
    shadow,
    spacing,
    cardSize,
    font,
    opacity,
    motion,
    Object.hashAllUnordered([
      for (final entry in overrides.entries)
        Object.hash(entry.key, entry.value),
    ]),
  );
}

// ---------------------------------------------------------------------------
// Surface tiers
// ---------------------------------------------------------------------------

/// How much weight a surface carries. Everything stays on screen either way -
/// this only decides how loudly each thing says "I am the point of this
/// screen".
///
/// [hero] is for the one or two things a screen exists for: the panel itself,
/// a widget card the user built. Roundest, deepest shadow, biggest type.
/// [normal] is the default and covers most cards and rows.
/// [compact] is for the supporting cast - chips, swatches, small previews:
/// squarer and flatter, so it reads as a detail even at a glance.
enum SurfaceLevel { hero, normal, compact }

/// The jobs text does here, rather than the sizes it comes in.
///
/// Two of them share a size: [caption] and [overline] are both the smallest
/// step, and what separates them is weight, letter-spacing and case. That is
/// the point of the ramp being short - the difference between a quiet note
/// and a section heading is carried by how the letters are set, not by
/// another size nobody could name.
enum TypeRole { display, title, heading, body, label, caption, overline }

/// Everything one tier decides, worked out once so a widget can ask for a
/// card's look in one line instead of assembling it from six tokens.
@immutable
class SurfaceStyle {
  const SurfaceStyle({
    required this.radius,
    required this.shadow,
    required this.padding,
    required this.gap,
    required this.minHeight,
    required this.titleSize,
  });

  final double radius;
  final List<BoxShadow> shadow;

  /// Inside the card, between its edge and its contents.
  final double padding;

  /// Outside it, between this card and the next.
  final double gap;

  /// What a card of this tier asks for when its contents don't ask for more.
  final double minHeight;

  /// The size a heading on this tier is set in.
  final double titleSize;

  BorderRadius get borderRadius => BorderRadius.circular(radius);

  EdgeInsets get insets => EdgeInsets.all(padding);
}

// ---------------------------------------------------------------------------
// The tokens themselves
// ---------------------------------------------------------------------------

/// The resolved look, as widgets read it. Lives on the [ThemeData] as an
/// extension, so `DesignTokens.of(context)` both finds it anywhere in the
/// tree and re-runs the widget that asked when it changes - which is what
/// makes the sliders in the design settings show their effect while they are
/// still being dragged.
@immutable
class DesignTokens extends ThemeExtension<DesignTokens> {
  const DesignTokens(this.settings);

  /// The defaults, for the handful of places that draw before a theme exists
  /// (tests, a widget built outside a [MaterialApp]).
  static final DesignTokens fallback = DesignTokens(DesignSettings());

  final DesignSettings settings;

  /// Never throws: a screen shown outside the app's own theme still draws,
  /// it just draws the defaults.
  static DesignTokens of(BuildContext context) =>
      Theme.of(context).extension<DesignTokens>() ?? fallback;

  // -- Colors ---------------------------------------------------------------

  Color get background => settings.color(DesignColorRole.background);

  /// The card color, held to the same side of the light/dark line as the
  /// ground.
  ///
  /// Six colors that can each be set on their own can be set to contradict
  /// each other, and one pair contradicts worse than the rest: a pale card on
  /// a dark ground (or the reverse) leaves no single text color that can be
  /// read on both. Rather than let the app half-work, a card that lands on
  /// the wrong side is carried back over the line, keeping its hue and the
  /// direction it stood off the ground in - a card asked to be lighter than
  /// its ground still is, just within the dark.
  Color get surface {
    final raw = settings.color(DesignColorRole.surface);
    if (_isDark(raw) == _isDark(background)) return raw;
    final card = HSVColor.fromColor(raw);
    final ground = HSVColor.fromColor(background);
    final value = _isDark(background)
        ? (ground.value + 0.1).clamp(0.0, 1.0)
        : (ground.value - 0.06).clamp(0.0, 1.0);
    return HSVColor.fromAHSV(
      card.alpha,
      card.hue,
      card.saturation,
      value,
    ).toColor();
  }

  /// The text colors, lifted until they can actually be read on the ground.
  ///
  /// Untouched for every preset - those already clear the bar by a wide
  /// margin - and for any pair a person picks that works. It only does
  /// something for the combination that is easy to walk into and hard to
  /// notice: darkening the ground and leaving the text where the light theme
  /// left it. The lift keeps the color's own hue rather than jumping to plain
  /// white, so a warm grey stays a warm grey.
  /// The bar is a little above the 4.5 that body text nominally needs,
  /// because the ground it is measured against is not always the last thing
  /// under the text: a tinted field lays a wash of this very color over the
  /// ground first, which closes the gap slightly. Aiming a step high means
  /// the text still clears the bar once it is on top of that wash.
  Color get textPrimary =>
      _legible(settings.color(DesignColorRole.textPrimary), background, 5.2);

  /// The quieter one is held to a lower bar on purpose: it is meant to
  /// recede, and forcing it to full body contrast would flatten the
  /// difference between the two.
  Color get textSecondary =>
      _legible(settings.color(DesignColorRole.textSecondary), background, 3.4);

  Color get accent => settings.color(DesignColorRole.accent);
  Color get border => settings.color(DesignColorRole.border);

  static bool _isDark(Color color) => color.computeLuminance() < 0.4;

  /// Contrast between two colors, the way accessibility guidance measures it.
  static double contrastBetween(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final high = la > lb ? la : lb;
    final low = la > lb ? lb : la;
    return (high + 0.05) / (low + 0.05);
  }

  static Color _legible(Color raw, Color ground, double target) {
    if (contrastBetween(raw, ground) >= target) return raw;
    final base = HSVColor.fromColor(raw);
    final lighten = _isDark(ground);
    for (var step = 1; step <= 20; step++) {
      final value = base.value + (lighten ? 1 : -1) * step * 0.05;
      if (value < 0 || value > 1) break;
      final candidate = base.withValue(value).toColor();
      if (contrastBetween(candidate, ground) >= target) return candidate;
    }
    // A deeply saturated color can run out of room before it gets there -
    // a pure blue is never going to read on black. Then the readable end it
    // has to be.
    return lighten ? Colors.white : Colors.black;
  }

  /// Icons and marks that sit next to secondary text without competing with
  /// it - the old `Colors.black45`.
  Color get textMuted => textSecondary.withValues(alpha: 0.72);

  /// Text on a filled accent button. Worked out from the accent rather than
  /// fixed, so a pale accent doesn't end up with white text on it.
  ///
  /// Measured rather than guessed at a brightness threshold. A threshold has
  /// to sit somewhere, and wherever it sits there is a band of mid-tone
  /// accents just under it - every amber, every mid green - that keep white
  /// text at barely 2.5:1, which is the "filled button you cannot read" every
  /// colored theme used to end up with. Asking which of the two actually
  /// contrasts more puts the line exactly where it belongs for the color in
  /// hand, and puts it there for a color the user picked as well as for one
  /// of ours.
  Color get onAccent => inkOn(accent);

  /// The same measurement for a ground the design doesn't hold: a
  /// notification badge painted in a color the user picked out of the
  /// palette. Stated once here so every such mark answers the question the
  /// same way instead of each one guessing at a brightness threshold.
  static Color inkOn(Color ground) =>
      contrastBetween(_ink, ground) > contrastBetween(Colors.white, ground)
      ? _ink
      : Colors.white;

  /// The near-black the theme uses where a true black would be a hole. Taken
  /// from the light presets rather than from [textPrimary], because this is
  /// the ink on *the accent*, which does not change when the theme goes dark.
  static const _ink = Color(0xFF1B1A17);

  /// A wash of the accent, for the background of something switched on.
  Color get accentWash => accent.withValues(alpha: 0.12);

  /// A barely-there fill for a pressed or active control - the old
  /// `Colors.black12`. Built from the text color so it stays visible on a
  /// dark theme, where a black veil would do nothing at all.
  ///
  /// It is also what a filled text field is tinted with, and deliberately not
  /// [surface]: a fixed card color can land on a page of the same color (a
  /// field in a dialog) or on a ground it has nothing to do with (a dark
  /// background with the cards left pale), and both were how a field ended up
  /// a strange block nobody chose. A wash of the text color can do neither -
  /// it is always a step away from whatever is behind it, and always a
  /// contrast to what is written on it.
  Color get fillSubtle => textPrimary.withValues(alpha: 0.08);

  /// Dimming behind a sheet or dialog.
  Color get scrim => const Color(0xFF000000).withValues(alpha: 0.45);

  /// The one color the user does not get to pick: something has gone wrong.
  ///
  /// Stated here rather than typed at each of the three places that need it
  /// (the [ColorScheme], a field's error text, a destructive row), which is
  /// how the app used to carry two different reds. Warm rather than the
  /// stock Material scarlet, so it belongs to the same family as the rest of
  /// the palette instead of arriving from another design.
  Color get danger =>
      isDark ? const Color(0xFFF08E7A) : const Color(0xFFAE3A2E);

  Color get onDanger => isDark ? const Color(0xFF1B1A17) : Colors.white;

  /// Whether this theme is a dark one. Read off the background rather than
  /// stored, so a hand-picked dark background gets light Material defaults
  /// without the preset having to be "Dark".
  Brightness get brightness =>
      background.computeLuminance() < 0.4 ? Brightness.dark : Brightness.light;

  bool get isDark => brightness == Brightness.dark;

  /// The panel over the wallpaper. Translucent on purpose - the picture
  /// showing faintly through is what stops the panel feeling like a separate
  /// app - and how translucent is the one thing the opacity slider changes.
  Color get panelSurface => background.withValues(alpha: settings.opacity);

  /// A card on the panel, one step more see-through than the panel it sits
  /// on, so the two never flatten into one slab.
  Color get cardSurface =>
      surface.withValues(alpha: (settings.opacity * 0.72).clamp(0.2, 1));

  // -- Radii ----------------------------------------------------------------

  /// The three tiers, each a golden step down from the one above, so the
  /// relation between them is the same relation the type and the spacing use.
  /// A floor keeps the smallest from collapsing to a hard square while the
  /// largest is still round.
  double radius(SurfaceLevel level) => switch (level) {
    SurfaceLevel.hero => settings.radius,
    SurfaceLevel.normal => (settings.radius / phi).clamp(3, 32).toDouble(),
    SurfaceLevel.compact => (settings.radius / (phi * phi))
        .clamp(2, 32)
        .toDouble(),
  };

  double get radiusLarge => radius(SurfaceLevel.hero);
  double get radiusMedium => radius(SurfaceLevel.normal);
  double get radiusSmall => radius(SurfaceLevel.compact);

  // -- Shadows --------------------------------------------------------------

  /// Three shadows per tier rather than one, because that is what a real
  /// one looks like.
  ///
  /// A single soft blur is the tell of a flat design pretending at depth: it
  /// is the same grey everywhere, so nothing has a near edge. Light falling
  /// on an object makes three separate marks, and they are separated here -
  ///
  ///   contact  a hairline directly under the edge, the darkest of the three,
  ///            which is what says the card is resting on something;
  ///   key      the short throw, offset downwards, the shadow you would
  ///            describe if asked;
  ///   ambient  a wide, almost invisible haze that lifts the whole card off
  ///            the page.
  ///
  /// Each tier gets the same three, scaled. At the default the hero tier
  /// throws `0 12 32`; 0 leaves nothing at all and 1 doubles them, and
  /// because all three tiers scale together the depth order holds wherever
  /// the slider sits.
  List<BoxShadow> shadow(SurfaceLevel level) {
    final strength = settings.shadow * 2;
    if (strength <= 0) return const [];
    final reach = switch (level) {
      SurfaceLevel.hero => 1.0,
      SurfaceLevel.normal => 1 / phi,
      SurfaceLevel.compact => 1 / (phi * phi),
    };
    // A dark theme needs heavier shadows to read at all: the same alpha over
    // a near-black background is a difference nobody sees.
    final depth = isDark ? 1.7 : 1.0;
    BoxShadow layer(double blur, double dy, double alpha) => BoxShadow(
      color: Colors.black.withValues(
        alpha: (alpha * strength * depth).clamp(0, 0.6),
      ),
      blurRadius: blur * reach * strength,
      offset: Offset(0, dy * reach * strength),
    );
    return [
      layer(32, 12, 0.055),
      layer(8, 3, 0.07),
      layer(1.5, 1, 0.08),
    ];
  }

  /// The same three layers, tinted with the accent, for something that is on
  /// rather than merely present.
  ///
  /// Colour carries weight here instead of just marking an edge: a selected
  /// tile does not only wear a ring, it casts light of its own onto the page
  /// around it, which is what makes the choice feel like it registered.
  List<BoxShadow> accentGlow(SurfaceLevel level) {
    final strength = (0.4 + settings.shadow).clamp(0.4, 1.4);
    final reach = switch (level) {
      SurfaceLevel.hero => 1.0,
      SurfaceLevel.normal => 1 / phi,
      SurfaceLevel.compact => 1 / (phi * phi),
    };
    return [
      // Wide and faint, thrown downwards: colored light pooling under the
      // card. The alpha is low on purpose - a saturated color at the
      // strength a grey shadow needs stops reading as light and starts
      // reading as a neon outline, which was the single loudest thing on
      // these screens.
      BoxShadow(
        color: accent.withValues(alpha: 0.16 * strength),
        blurRadius: 24 * reach * strength,
        offset: Offset(0, 8 * reach * strength),
      ),
      // The contact layer, still colored but tight enough to read as the
      // card meeting the page rather than as a halo around it.
      BoxShadow(
        color: accent.withValues(alpha: 0.10 * strength),
        blurRadius: 4 * reach * strength,
        offset: Offset(0, 1 * reach * strength),
      ),
    ];
  }

  // -- Spacing --------------------------------------------------------------

  /// The six rungs of [spaceRamp], scaled.
  double gap(int step) => spaceRamp[step.clamp(0, spaceRamp.length - 1)] *
      settings.spacing;

  double get spaceXs => gap(0);
  double get space2xs => gap(1);
  double get spaceSm => gap(2);
  double get spaceMd => gap(3);
  double get spaceLg => gap(4);
  double get spaceXl => gap(5);

  double space(SurfaceLevel level) => switch (level) {
    SurfaceLevel.hero => spaceLg,
    SurfaceLevel.normal => spaceMd,
    SurfaceLevel.compact => spaceSm,
  };

  /// The left/right margin a settings page keeps.
  EdgeInsets get pagePadding => EdgeInsets.symmetric(horizontal: spaceMd);

  // -- Type -----------------------------------------------------------------

  /// A chrome type scale, not a clock one: these size headings, rows and
  /// captions in the panel and the settings. The clock and the app list bring
  /// their own sizes, because those sit on the wallpaper rather than on
  /// anything this file draws.
  double size(TypeRole role) {
    final step = switch (role) {
      TypeRole.display => 3.0,
      TypeRole.title => 2.0,
      TypeRole.heading => 1.0,
      TypeRole.body => 0.0,
      TypeRole.label => -0.6,
      TypeRole.caption || TypeRole.overline => -1.0,
    };
    return typeAt(step) * settings.font;
  }

  double get typeDisplay => size(TypeRole.display);
  double get typeHero => size(TypeRole.title);
  double get typeTitle => size(TypeRole.heading);
  double get typeBody => size(TypeRole.body);
  double get typeLabel => size(TypeRole.label);
  double get typeCaption => size(TypeRole.caption);

  double typeFor(SurfaceLevel level) => switch (level) {
    SurfaceLevel.hero => typeHero,
    SurfaceLevel.normal => typeTitle,
    SurfaceLevel.compact => typeLabel,
  };

  static const weightLight = FontWeight.w300;
  static const weightNormal = FontWeight.w400;
  static const weightMedium = FontWeight.w500;
  static const weightBold = FontWeight.w600;

  /// A text style with its weight, letter-spacing and line height already on
  /// it, not just a size.
  ///
  /// The tracking is the part that does the work. Letters set at a headline
  /// size have too much air between them at the spacing drawn for body text,
  /// and letters set small have too little - so the ramp runs from tight at
  /// the top to open at the bottom, which is how type has been set on paper
  /// for a century and why a screen that does it reads as considered rather
  /// than as typed. The same trick separates [TypeRole.caption] from
  /// [TypeRole.overline], which are the same size: one is quiet, the other is
  /// spaced out and capitalised into a heading.
  ///
  /// Weight goes the other way. Large text is set *lighter*, because at that
  /// size the strokes already carry; small text is set heavier, because at
  /// that size they do not. Everything shouting in bold is what a default
  /// looks like.
  TextStyle textStyle(TypeRole role, {Color? color}) {
    final (FontWeight weight, double tracking, double height) = switch (role) {
      TypeRole.display => (weightLight, -0.9, 1.12),
      TypeRole.title => (weightBold, -0.45, 1.18),
      TypeRole.heading => (weightBold, -0.2, 1.28),
      TypeRole.body => (weightNormal, 0.0, 1.45),
      TypeRole.label => (weightMedium, 0.15, 1.35),
      TypeRole.caption => (weightNormal, 0.25, 1.35),
      TypeRole.overline => (weightBold, 1.1, 1.3),
    };
    final base = switch (role) {
      TypeRole.body || TypeRole.title || TypeRole.heading ||
      TypeRole.display => textPrimary,
      _ => textSecondary,
    };
    return TextStyle(
      fontSize: size(role),
      fontWeight: weight,
      // Scaled with the size so the spacing stays a proportion of the letter
      // rather than a fixed gap that grows wrong.
      letterSpacing: tracking * settings.font,
      height: height,
      color: color ?? base,
    );
  }

  // -- Motion ---------------------------------------------------------------

  /// How long a movement takes. Nothing in the app snaps any more: a theme
  /// crossfades, a card that becomes the chosen one grows into it, a page
  /// arrives rather than appearing. Below about 150ms a movement reads as a
  /// flicker instead of a movement, which is why [fast] starts there.
  Duration duration(double scale) =>
      Duration(milliseconds: (scale * settings.motion).round());

  Duration get motionFast => duration(160);
  Duration get motionNormal => duration(260);
  Duration get motionSlow => duration(420);

  /// Out fast, settling slow - the shape of something with weight coming to
  /// rest. A linear or symmetric curve is the other half of why an interface
  /// feels mechanical.
  Curve get motionCurve => Curves.easeOutCubic;

  /// Whether motion is switched off entirely, for the few places that have to
  /// take a different path rather than a shorter one.
  bool get motionless => settings.motion <= 0;

  // -- Surfaces -------------------------------------------------------------

  /// Everything one tier decides, in one object. The heights are a golden
  /// step apart, like everything else.
  SurfaceStyle surfaceStyle(SurfaceLevel level) {
    final height = switch (level) {
      SurfaceLevel.hero => 108 * phi * phi,
      SurfaceLevel.normal => 108 * phi,
      SurfaceLevel.compact => 108.0,
    };
    return SurfaceStyle(
      radius: radius(level),
      shadow: shadow(level),
      padding: space(level) * 0.75,
      gap: space(level) / phi,
      minHeight: height * settings.cardSize,
      titleSize: typeFor(level),
    );
  }

  /// The faint top-to-bottom shading that stops a card reading as a flat
  /// rectangle of colour.
  ///
  /// It stands in for a rim light. A real one would be a bright hairline
  /// along the top edge, which Flutter will not draw next to a rounded corner
  /// without a second layer; a gradient that starts a shade above the card's
  /// colour and ends a shade below reads the same way at a glance - light
  /// coming from above - and costs nothing. Roughly a percent either side: at
  /// the point where it can be named as a gradient it has gone too far.
  Gradient surfaceSheen(Color base) {
    final hsv = HSVColor.fromColor(base);
    final lift = isDark ? 0.035 : 0.012;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        hsv.withValue((hsv.value + lift).clamp(0.0, 1.0)).toColor(),
        hsv.withValue((hsv.value - lift * 0.6).clamp(0.0, 1.0)).toColor(),
      ],
    );
  }

  /// A card's whole decoration: the shading, the edge, the three shadows, and
  /// what changes when it is the chosen one.
  ///
  /// The active state is where the accent gets to carry weight. A ring alone
  /// marks a card; a ring over a wash of the same colour, with that colour
  /// thrown onto the page underneath, makes the card the thing the screen is
  /// about. It is still the same card in the same place - nothing grows, no
  /// neighbour moves - so the screen stays readable while one thing on it is
  /// unmistakable.
  BoxDecoration cardDecoration(
    SurfaceLevel level, {
    bool active = false,
    Color? color,
    bool bordered = true,
    bool sheen = true,
  }) {
    final style = surfaceStyle(level);
    final base = color ?? surface;
    final fill = active ? Color.alphaBlend(accentWash, base) : base;
    return BoxDecoration(
      // A translucent card keeps its flat colour: shading something you can
      // see the wallpaper through only muddies what is behind it.
      color: sheen && fill.a == 1 ? null : fill,
      gradient: sheen && fill.a == 1 ? surfaceSheen(fill) : null,
      borderRadius: style.borderRadius,
      border: active
          ? Border.all(color: accent, width: 1.5)
          : (bordered ? Border.all(color: border, width: 1) : null),
      boxShadow: active ? accentGlow(level) : style.shadow,
    );
  }

  // -- ThemeExtension -------------------------------------------------------

  @override
  DesignTokens copyWith({DesignSettings? settings}) =>
      DesignTokens(settings ?? this.settings);

  /// Interpolates, so that switching theme is a crossfade rather than a cut.
  ///
  /// Every colour is lerped as a resolved colour and handed back as an
  /// override, which is what lets a rose theme travel to a dark one through
  /// the colours in between instead of swapping at the halfway mark. The
  /// preset and the field style have no in-between, so those flip once, at
  /// the point the colours have already got closer to the destination than to
  /// where they started.
  @override
  DesignTokens lerp(ThemeExtension<DesignTokens>? other, double t) {
    if (other is! DesignTokens) return this;
    if (t <= 0) return this;
    if (t >= 1) return other;
    final a = settings;
    final b = other.settings;
    double mix(double x, double y) => x + (y - x) * t;
    return DesignTokens(
      DesignSettings(
        preset: t < 0.5 ? a.preset : b.preset,
        fieldStyle: t < 0.5 ? a.fieldStyle : b.fieldStyle,
        overrides: {
          for (final role in DesignColorRole.values)
            role: Color.lerp(a.color(role), b.color(role), t)!,
        },
        radius: mix(a.radius, b.radius),
        shadow: mix(a.shadow, b.shadow),
        spacing: mix(a.spacing, b.spacing),
        cardSize: mix(a.cardSize, b.cardSize),
        font: mix(a.font, b.font),
        opacity: mix(a.opacity, b.opacity),
        motion: mix(a.motion, b.motion),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DesignTokens && other.settings == settings;

  @override
  int get hashCode => settings.hashCode;
}

/// `context.design` instead of `DesignTokens.of(context)`, because a colour
/// lookup sits inside a `TextStyle(...)` where the longer form buries the
/// thing being read.
extension DesignTokensContext on BuildContext {
  DesignTokens get design => DesignTokens.of(this);
}

// ---------------------------------------------------------------------------
// The Material theme
// ---------------------------------------------------------------------------

/// The same tokens as a [ThemeData], so the stock widgets - list rows,
/// switches, sliders, chips, dialogs, text fields, the app bar - follow the
/// design without every screen having to dress them by hand. This is most of
/// what makes the default look designed rather than like whatever Material
/// ships with.
ThemeData buildAppTheme(DesignSettings settings) {
  final t = DesignTokens(settings);
  final dark = t.isDark;

  final scheme = ColorScheme(
    brightness: t.brightness,
    primary: t.accent,
    onPrimary: t.onAccent,
    primaryContainer: t.accentWash,
    onPrimaryContainer: t.textPrimary,
    secondary: t.accent,
    onSecondary: t.onAccent,
    surface: t.surface,
    onSurface: t.textPrimary,
    surfaceContainerHighest: t.background,
    onSurfaceVariant: t.textSecondary,
    outline: t.border,
    outlineVariant: t.border,
    error: t.danger,
    onError: t.onDanger,
  );

  TextStyle role(TypeRole r) => t.textStyle(r);

  return ThemeData(
    useMaterial3: true,
    brightness: t.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.background,
    canvasColor: t.background,
    dividerColor: t.border,
    hintColor: t.textSecondary,
    splashFactory: InkRipple.splashFactory,
    extensions: [t],
    // Every route arrives the same way, whatever Android's own default for
    // this phone happens to be - a page that slides in from the side on one
    // device and fades on another is the kind of inconsistency that reads as
    // unfinished.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: _DesignPageTransitions(t),
      },
    ),
    // Material's own slots, filled from the roles above, so a stock widget
    // that reaches for `titleMedium` gets the same tracking and weight as
    // anything written here.
    textTheme: TextTheme(
      displaySmall: role(TypeRole.display),
      headlineMedium: role(TypeRole.display),
      headlineSmall: role(TypeRole.title),
      titleLarge: role(TypeRole.title),
      titleMedium: role(TypeRole.heading),
      titleSmall: role(TypeRole.label).copyWith(color: t.textPrimary),
      bodyLarge: role(TypeRole.body),
      bodyMedium: role(TypeRole.body),
      bodySmall: role(TypeRole.label),
      labelLarge: role(TypeRole.label).copyWith(color: t.textPrimary),
      labelMedium: role(TypeRole.label),
      labelSmall: role(TypeRole.caption),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.background,
      foregroundColor: t.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: role(TypeRole.title),
    ),
    iconTheme: IconThemeData(color: t.textSecondary),
    dividerTheme: DividerThemeData(color: t.border, space: 1, thickness: 1),
    listTileTheme: ListTileThemeData(
      iconColor: t.textSecondary,
      textColor: t.textPrimary,
      titleTextStyle: role(TypeRole.body),
      subtitleTextStyle: role(TypeRole.label),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMedium),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: t.spaceMd,
        vertical: t.spaceXs * 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: t.spaceSm * 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMedium),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusLarge),
      ),
      titleTextStyle: role(TypeRole.heading),
      contentTextStyle: role(TypeRole.body),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(t.radiusLarge),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? t.surface : t.textPrimary,
      contentTextStyle: role(
        TypeRole.body,
      ).copyWith(color: dark ? t.textPrimary : t.background),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMedium),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: t.surface,
      selectedColor: t.accentWash,
      side: BorderSide(color: t.border),
      checkmarkColor: t.accent,
      labelStyle: role(TypeRole.label).copyWith(color: t.textPrimary),
      secondaryLabelStyle: role(TypeRole.label).copyWith(color: t.accent),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusSmall),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: t.accent,
      inactiveTrackColor: t.border,
      thumbColor: t.accent,
      overlayColor: t.accentWash,
      valueIndicatorColor: t.accent,
      valueIndicatorTextStyle: TextStyle(color: t.onAccent),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? t.onAccent
            : (dark ? t.textSecondary : t.surface),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? t.accent : t.fillSubtle,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? t.accent : t.border,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? t.accent
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(t.onAccent),
      side: BorderSide(color: t.border, width: 1.5),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? t.accent : t.textSecondary,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.accent,
      linearTrackColor: t.border,
      circularTrackColor: t.border,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.accent,
      selectionColor: t.accent.withValues(alpha: 0.28),
      selectionHandleColor: t.accent,
    ),
    inputDecorationTheme: _inputTheme(t),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.accent,
        textStyle: role(TypeRole.label).copyWith(color: t.accent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusSmall),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        textStyle: role(TypeRole.label).copyWith(color: t.onAccent),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusMedium),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.textPrimary,
        side: BorderSide(color: t.border),
        textStyle: role(TypeRole.label).copyWith(color: t.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusMedium),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.accent,
      foregroundColor: t.onAccent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMedium),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMedium),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? t.surface : t.textPrimary,
        borderRadius: BorderRadius.circular(t.radiusSmall),
      ),
      textStyle: role(
        TypeRole.caption,
      ).copyWith(color: dark ? t.textPrimary : t.background),
    ),
  );
}

/// How text fields are framed, from [DesignSettings.fieldStyle].
///
/// Every style states all four borders rather than leaning on Material's
/// fallbacks: an unset `enabledBorder` quietly becomes the M3 default, which
/// is how a field ends up with a look nothing in this file asked for.
InputDecorationTheme _inputTheme(DesignTokens t) {
  final radius = BorderRadius.circular(t.radiusMedium);

  InputBorder border(Color color, double width) {
    final side = BorderSide(color: color, width: width);
    return switch (t.settings.fieldStyle) {
      InputFieldStyle.line => UnderlineInputBorder(borderSide: side),
      InputFieldStyle.box => OutlineInputBorder(
        borderRadius: radius,
        borderSide: side,
      ),
      // No edge at all: the tint is the field. Focus is shown by the tint
      // deepening instead, see fillColor below.
      InputFieldStyle.plain => OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
    };
  }

  final filled = t.settings.fieldStyle == InputFieldStyle.plain;

  return InputDecorationTheme(
    filled: filled,
    fillColor: filled
        ? WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? t.accentWash
                : t.fillSubtle,
          )
        : null,
    hintStyle: t.textStyle(TypeRole.body, color: t.textSecondary),
    labelStyle: t.textStyle(TypeRole.body, color: t.textSecondary),
    floatingLabelStyle: t.textStyle(TypeRole.label, color: t.accent),
    helperStyle: t.textStyle(TypeRole.caption),
    counterStyle: t.textStyle(TypeRole.caption),
    errorStyle: t.textStyle(TypeRole.caption, color: t.danger),
    // The little bits of text a field can carry alongside the input - the "#"
    // in front of a hex value, a unit behind a number. Left unset they take
    // Material's own color, which is the one color on the field the theme
    // would not be deciding.
    prefixStyle: t.textStyle(TypeRole.body),
    suffixStyle: t.textStyle(TypeRole.body, color: t.textSecondary),
    prefixIconColor: t.textSecondary,
    suffixIconColor: t.textSecondary,
    border: border(t.border, 1),
    enabledBorder: border(t.border, 1),
    disabledBorder: border(t.border.withValues(alpha: 0.4), 1),
    focusedBorder: border(t.accent, 2),
  );
}

/// One way in and one way out for every page: the arriving page fades up
/// while lifting a little, the leaving one drops back and dims.
///
/// Sliding a whole screen sideways is a phone convention, not a design
/// decision, and it fights the pull-down panel this launcher is built around.
/// A page that rises into place says the same thing more quietly.
class _DesignPageTransitions extends PageTransitionsBuilder {
  const _DesignPageTransitions(this.tokens);

  final DesignTokens tokens;

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget? child,
  ) {
    if (tokens.motionless) return child!;
    final curved = CurvedAnimation(
      parent: animation,
      curve: tokens.motionCurve,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
