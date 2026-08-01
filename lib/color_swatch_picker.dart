import 'package:flutter/material.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;
import 'app_strings.dart';
import 'custom_colors_controller.dart';

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
                child: Container(
                  width: swatchSize,
                  height: swatchSize,
                  decoration: BoxDecoration(
                    color: palette[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i == selectedIndex
                          ? Colors.black
                          : Colors.black26,
                      width: i == selectedIndex ? 3 : 1,
                    ),
                  ),
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
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border(
                    top: BorderSide(color: Colors.black45),
                    bottom: BorderSide(color: Colors.black45),
                    left: BorderSide(color: Colors.black45),
                    right: BorderSide(color: Colors.black45),
                  ),
                ),
                child: const Icon(Icons.add, color: Colors.black45, size: 18),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A full RGB picker (sliders plus a hex field) rather than a handful of
/// presets - "the complete palette" the user can reach any color from.
Future<Color?> showAddColorDialog(BuildContext context, AppStrings s) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _AddColorDialog(s: s),
  );
}

class _AddColorDialog extends StatefulWidget {
  const _AddColorDialog({required this.s});

  final AppStrings s;

  @override
  State<_AddColorDialog> createState() => _AddColorDialogState();
}

class _AddColorDialogState extends State<_AddColorDialog> {
  int _r = 120;
  int _g = 120;
  int _b = 120;
  late final TextEditingController _hex = TextEditingController(
    text: _hexOf(_current),
  );

  Color get _current => Color.fromARGB(255, _r, _g, _b);

  static String _hexOf(Color color) =>
      color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  void _setFromHex(String value) {
    final cleaned = value.replaceAll('#', '').trim();
    if (cleaned.length != 6) return;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return;
    setState(() {
      _r = (parsed >> 16) & 0xFF;
      _g = (parsed >> 8) & 0xFF;
      _b = parsed & 0xFF;
    });
  }

  void _setChannel({int? r, int? g, int? b}) {
    setState(() {
      _r = r ?? _r;
      _g = g ?? _g;
      _b = b ?? _b;
      // Only the sliders drive this - the hex field's own onChanged already
      // handles the other direction, so updating it here too would fight
      // whatever the user is mid-typing.
      _hex.text = _hexOf(_current);
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
    return AlertDialog(
      title: Text(s.addColor),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _current,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ChannelSlider(
              label: 'R',
              value: _r,
              onChanged: (v) => _setChannel(r: v),
            ),
            _ChannelSlider(
              label: 'G',
              value: _g,
              onChanged: (v) => _setChannel(g: v),
            ),
            _ChannelSlider(
              label: 'B',
              value: _b,
              onChanged: (v) => _setChannel(b: v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hex,
              maxLength: 6,
              decoration: const InputDecoration(
                prefixText: '#',
                labelText: 'Hex',
                counterText: '',
              ),
              onChanged: _setFromHex,
            ),
          ],
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

class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 16, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text('$value', textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
