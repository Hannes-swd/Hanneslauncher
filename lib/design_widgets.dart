import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// The shapes the settings screens are built out of, in one place so they are
/// drawn from the design tokens once instead of retyped with their sizes and
/// greys at every screen that needs them.
///
/// These existed already - as a private `_heading` here and a private
/// `_Label` there, each with its own 14, its own `Colors.black54` and its own
/// padding, which is exactly how two screens end up a pixel apart. What is
/// new is that they are no longer only text and boxes: a row knows it is part
/// of a group, a tile knows how to become the chosen one, and both move when
/// they change rather than jumping.

/// The little heading above a group of settings ("Position", "Stil").
///
/// Set in the overline role: the smallest size in the ramp, capitalised, and
/// spaced right out. A heading does not need to be big to be a heading - at
/// this size and this tracking it reads as a label on a drawer rather than as
/// a sentence, which is what lets the things under it be the loud part.
class SettingsHeading extends StatelessWidget {
  const SettingsHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        design.spaceMd,
        design.spaceLg,
        design.spaceMd,
        design.spaceSm,
      ),
      child: Text(
        text.toUpperCase(),
        style: design.textStyle(TypeRole.overline),
      ),
    );
  }
}

/// The label sitting directly above a single control - a colour row, a
/// slider. Quieter than [SettingsHeading], which groups several of these.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Padding(
      padding: EdgeInsets.only(bottom: design.space2xs),
      child: Text(
        text,
        style: design.textStyle(TypeRole.label, color: design.textPrimary),
      ),
    );
  }
}

/// Anything tappable that should answer the finger.
///
/// A ripple says a tap landed; it does not say the thing under the finger is
/// an object. Taking the whole row down a fraction of a percent does, and it
/// is the difference between a list of text and a surface being pressed. The
/// scale is deliberately almost too small to notice - noticing it is the
/// failure mode.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down && !design.motionless ? 0.985 : 1,
        duration: design.motionFast,
        curve: design.motionCurve,
        child: AnimatedContainer(
          duration: design.motionFast,
          curve: design.motionCurve,
          color: _down ? design.fillSubtle : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

/// One tile in a grid you pick something from by looking at it: a clock
/// style, a theme. Shows [preview] as big as it will go and [title]
/// underneath.
///
/// Becoming the chosen one is a movement, not a redraw. The ring, the wash
/// and the glow all arrive over [DesignTokens.motionFast], so the eye follows
/// the choice from where it was to where it went instead of having to find it
/// again.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.preview,
    required this.onTap,
    this.level = SurfaceLevel.normal,
    this.color,
  });

  final String title;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;
  final SurfaceLevel level;

  /// Set only where the preview needs a ground of its own - the offline mode
  /// tiles, which have to show the clock on black to say anything at all.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final style = design.surfaceStyle(level);
    return _Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: design.motionFast,
        curve: design.motionCurve,
        padding: EdgeInsets.fromLTRB(
          style.padding * 0.7,
          style.padding * 0.7,
          style.padding * 0.7,
          style.padding * 0.5,
        ),
        decoration: design.cardDecoration(
          level,
          active: selected,
          color: color ?? design.surface,
          sheen: color == null,
        ),
        child: Column(
          children: [
            Expanded(child: Center(child: preview)),
            SizedBox(height: design.spaceXs),
            AnimatedDefaultTextStyle(
              duration: design.motionFast,
              curve: design.motionCurve,
              style: design.textStyle(
                TypeRole.label,
                color: selected ? design.accent : design.textPrimary,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Takes no width when unselected, so the title does not
                  // shuffle sideways as tiles are picked.
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: design.motionFast,
                    curve: design.motionCurve,
                    child: Padding(
                      padding: EdgeInsets.only(right: design.spaceXs),
                      child: Icon(
                        Icons.check_circle,
                        size: design.typeLabel,
                        color: design.accent,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
