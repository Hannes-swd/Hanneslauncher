import 'package:flutter/material.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;
import 'app_strings.dart';
import 'custom_colors_controller.dart';
import 'design_tokens.dart';

/// Every selectable color (the fixed palette plus whatever the user has
/// added), as tappable circles, with a trailing "+" that opens a full color
/// picker. A color picked there is added to the palette and selected right
/// away, so it shows up on every other color picker in the app from then on.
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.s,
    this.swatchSize = 36,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final AppStrings s;
  final double swatchSize;

  @override
  Widget build(BuildContext context) {
    // Rebuilds whenever a color is added anywhere in the app, not just from
    // this row's own "+".
    return ListenableBuilder(
      listenable: CustomColorsController.instance,
      builder: (context, child) {
        final palette = appListColorPalette;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < palette.length; i++)
              GestureDetector(
                onTap: () => onSelected(i),
                child: ColorDot(
                  color: palette[i],
                  size: swatchSize,
                  selected: i == selectedIndex,
                ),
              ),
            GestureDetector(
              onTap: () async {
                final picked = await showAddColorDialog(context, s);
                if (picked == null) return;
                await CustomColorsController.instance.add(picked);
                onSelected(appListColorPalette.indexOf(picked));
              },
              child: Container(
                width: swatchSize,
                height: swatchSize,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.design.textMuted),
                ),
                child: Icon(
                  Icons.add,
                  color: context.design.textMuted,
                  size: 18,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One color as a circle, on the chequerboard every image editor uses for
/// "nothing behind this".
///
/// The board is the whole reason this isn't a plain [Container]: a color that
/// is half see-through and one that is solid look identical on a white sheet,
/// and telling them apart is exactly what somebody who just moved the opacity
/// slider is trying to do.
class ColorDot extends StatelessWidget {
  const ColorDot({
    super.key,
    required this.color,
    this.size = 36,
    this.selected = false,
  });

  final Color color;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? design.accent : design.border,
          width: selected ? 3 : 1,
        ),
      ),
      child: ClipOval(
        child: CustomPaint(
          painter: _CheckerPainter(design.border),
          child: ColoredBox(color: color, child: const SizedBox.expand()),
        ),
      ),
    );
  }
}

/// The colour picker: a hue-and-saturation field with brightness and opacity
/// underneath it, which is the arrangement every paint program uses.
///
/// It replaced three sliders labelled R, G and B. Those could reach the same
/// colours, but only by arithmetic - "a bit warmer" or "the same blue, a
/// little paler" are not moves you can make on them. On the field they are
/// one drag sideways and one drag down.
///
/// [allowAlpha] hides the opacity slider where a see-through colour would be
/// a hole rather than a colour - the two the design paints its solid grounds
/// with. Everywhere else the colour is laid over something, and letting what
/// is underneath show through is a real choice.
Future<Color?> showColorPickerDialog(
  BuildContext context,
  AppStrings s, {
  Color? initial,
  String? title,
  bool allowAlpha = true,
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorPickerDialog(
      s: s,
      initial: initial,
      title: title,
      allowAlpha: allowAlpha,
    ),
  );
}

/// The same picker, but what comes back is also appended to the shared
/// palette - which is what every `colorIndex` setting in the app indexes
/// into.
Future<Color?> showAddColorDialog(BuildContext context, AppStrings s) =>
    showColorPickerDialog(context, s, title: s.addColor);

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.s,
    required this.allowAlpha,
    this.initial,
    this.title,
  });

  final AppStrings s;
  final bool allowAlpha;
  final Color? initial;
  final String? title;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  // Held as hue/saturation/value rather than as red/green/blue, because that
  // is what the controls below actually move. Round-tripping through RGB
  // after every touch would lose the hue of a black or a white - both of
  // which are every hue at once - and the marker would jump to the left edge
  // the moment the brightness slider reached the bottom.
  late double _hue;
  late double _saturation;
  late double _value;
  late double _alpha;

  late final TextEditingController _hex = TextEditingController(text: _hexOf());

  @override
  void initState() {
    super.initState();
    final start = HSVColor.fromColor(widget.initial ?? const Color(0xFF787878));
    _hue = start.hue;
    _saturation = start.saturation;
    _value = start.value;
    _alpha = widget.allowAlpha ? (widget.initial?.a ?? 1) : 1;
  }

  Color get _current =>
      HSVColor.fromAHSV(_alpha, _hue, _saturation, _value).toColor();

  /// Eight digits only while the colour is see-through: `#1A1A1A` is what
  /// gets pasted in from anywhere else, and prefixing it with `FF` forever
  /// would make the common case the odd-looking one.
  String _hexOf() {
    final full = _current
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    return full.startsWith('FF') ? full.substring(2) : full;
  }

  void _syncHex() => _hex.text = _hexOf();

  void _setFromHex(String text) {
    final cleaned = text.replaceAll('#', '').trim();
    if (cleaned.length != 6 && cleaned.length != 8) return;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return;
    final argb = cleaned.length == 6 ? 0xFF000000 | parsed : parsed;
    final hsv = HSVColor.fromColor(Color(argb));
    setState(() {
      // A grey typed in has no hue of its own, so taking the zero that comes
      // back would swing the marker to red for no reason the user can see.
      if (hsv.saturation > 0) _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
      if (widget.allowAlpha) _alpha = ((argb >> 24) & 0xFF) / 255;
    });
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final design = context.design;
    // The colour as it would be at full brightness and no transparency: what
    // the two sliders below run towards, so each one shows where it is going.
    final pure = HSVColor.fromAHSV(1, _hue, _saturation, 1).toColor();

    return AlertDialog(
      title: Text(widget.title ?? s.pickColor),
      // The field wants width more than the default dialog gives it.
      insetPadding: EdgeInsets.symmetric(
        horizontal: design.spaceMd,
        vertical: design.spaceXl,
      ),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HueSaturationField(
                hue: _hue,
                saturation: _saturation,
                value: _value,
                onChanged: (hue, saturation) => setState(() {
                  _hue = hue;
                  _saturation = saturation;
                  _syncHex();
                }),
              ),
              SizedBox(height: design.spaceMd),

              Text(
                s.colorBrightness((_value * 100).round()),
                style: TextStyle(
                  fontSize: design.typeLabel,
                  color: design.textSecondary,
                ),
              ),
              _GradientSlider(
                value: _value,
                colors: [Colors.black, pure],
                onChanged: (v) => setState(() {
                  _value = v;
                  _syncHex();
                }),
              ),

              if (widget.allowAlpha) ...[
                Text(
                  s.colorOpacity((_alpha * 100).round()),
                  style: TextStyle(
                    fontSize: design.typeLabel,
                    color: design.textSecondary,
                  ),
                ),
                _GradientSlider(
                  value: _alpha,
                  // Over the chequerboard, so the left end reads as "gone"
                  // rather than as "white".
                  chequered: true,
                  colors: [
                    _current.withValues(alpha: 0),
                    _current.withValues(alpha: 1),
                  ],
                  onChanged: (v) => setState(() {
                    _alpha = v;
                    _syncHex();
                  }),
                ),
              ],

              SizedBox(height: design.spaceSm),
              Row(
                children: [
                  ColorDot(color: _current, size: 44),
                  SizedBox(width: design.spaceSm),
                  Expanded(
                    child: TextField(
                      controller: _hex,
                      maxLength: 8,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixText: '#',
                        labelText: 'Hex',
                        counterText: '',
                      ),
                      onChanged: _setFromHex,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_current),
          child: Text(s.save),
        ),
      ],
    );
  }
}

/// The square: hue left to right, saturation top to bottom, dimmed by the
/// brightness currently set so it shows the colours actually on offer rather
/// than a bright square that has nothing to do with the result.
class _HueSaturationField extends StatelessWidget {
  const _HueSaturationField({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final void Function(double hue, double saturation) onChanged;

  static const _hues = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final radius = BorderRadius.circular(design.radiusSmall);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 180.0;

        void report(Offset position) {
          onChanged(
            (position.dx / width).clamp(0, 1) * 360,
            1 - (position.dy / height).clamp(0, 1),
          );
        }

        return GestureDetector(
          // Down as well as pan: tapping a colour should pick it, without
          // having to drag a pixel first.
          onPanDown: (d) => report(d.localPosition),
          onPanUpdate: (d) => report(d.localPosition),
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              height: height,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: _hues),
                      ),
                    ),
                  ),
                  // White towards the bottom takes the saturation out.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Black over everything is the brightness slider's doing.
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 1 - value),
                    ),
                  ),
                  Positioned(
                    left: (hue / 360) * width - 9,
                    top: (1 - saturation) * height - 9,
                    child: const _FieldMarker(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Where the finger left off. A white ring inside a black one, so it is
/// visible on every colour the field can show.
class _FieldMarker extends StatelessWidget {
  const _FieldMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 2, spreadRadius: 0.5),
        ],
      ),
    );
  }
}

/// A slider whose track is the range it covers. "Brightness 40%" says very
/// little on a plain grey bar; a bar running from black to the colour says
/// what the next drag will do before it is made.
class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.value,
    required this.colors,
    required this.onChanged,
    this.chequered = false,
  });

  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;
  final bool chequered;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            // Lines the track up with the one the thumb travels, which the
            // slider insets by half a thumb at each end.
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                painter: chequered ? _CheckerPainter(design.border) : null,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    border: Border.all(color: design.border),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ),
          ),
          SliderTheme(
            // The track is the gradient behind, so the slider only brings the
            // thumb.
            data: SliderTheme.of(context).copyWith(
              trackHeight: 14,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              trackShape: const RectangularSliderTrackShape(),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 9,
                elevation: 2,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(value: value.clamp(0, 1), onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// The grey chessboard that means "see-through" everywhere pictures are
/// edited.
class _CheckerPainter extends CustomPainter {
  const _CheckerPainter(this.shade);

  final Color shade;

  static const _square = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = shade;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    for (var y = 0.0; y < size.height; y += _square) {
      for (var x = 0.0; x < size.width; x += _square) {
        final odd = ((x / _square).floor() + (y / _square).floor()).isOdd;
        if (!odd) continue;
        canvas.drawRect(Rect.fromLTWH(x, y, _square, _square), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) => oldDelegate.shade != shade;
}
