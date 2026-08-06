import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'color_swatch_picker.dart';
import 'note_document.dart';

/// The panel that slides in at the bottom of the note editor once the
/// "format" button is tapped. Everything in it acts on whatever is selected
/// in the note above - or, with nothing selected, on the line the cursor is
/// in.
class NoteFormatPanel extends StatelessWidget {
  const NoteFormatPanel({
    super.key,
    required this.s,
    required this.format,
    required this.style,
    required this.list,
    required this.align,
    required this.onInline,
    required this.onStyle,
    required this.onList,
    required this.onAlign,
    required this.onDeleteLine,
    required this.onClose,
  });

  final AppStrings s;

  /// What the selection currently looks like, so the toggles can show it.
  final NoteInlineFormat format;
  final NoteBlockStyle style;
  final NoteListKind list;
  final NoteAlign align;

  /// Applies a change to every selected character.
  final void Function(NoteInlineFormat Function(NoteInlineFormat)) onInline;
  final ValueChanged<NoteBlockStyle> onStyle;
  final ValueChanged<NoteListKind> onList;
  final ValueChanged<NoteAlign> onAlign;
  final VoidCallback onDeleteLine;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    s.formatLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.backspace_outlined, size: 20),
                    tooltip: s.deleteLine,
                    onPressed: onDeleteLine,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: s.closeFormat,
                    onPressed: onClose,
                  ),
                ],
              ),
              // What the selected part is: the note's own outline levels.
              _Scroller(
                child: Row(
                  children: [
                    for (final entry in {
                      NoteBlockStyle.title: s.styleTitle,
                      NoteBlockStyle.heading: s.styleHeading,
                      NoteBlockStyle.text: s.styleText,
                      NoteBlockStyle.note: s.styleNote,
                    }.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: style == entry.key,
                          onSelected: (_) => onStyle(entry.key),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 12),
              // Character formats, plus the two colors that belong to them.
              _Scroller(
                child: Row(
                  children: [
                    _Toggle(
                      icon: Icons.format_bold,
                      tooltip: s.boldLabel,
                      active: format.bold,
                      onTap: () => onInline(
                        (f) => f.copyWith(bold: !format.bold, clearWeight: true),
                      ),
                    ),
                    _Toggle(
                      icon: Icons.format_italic,
                      tooltip: s.italicLabel,
                      active: format.italic,
                      onTap: () =>
                          onInline((f) => f.copyWith(italic: !format.italic)),
                    ),
                    _Toggle(
                      icon: Icons.format_strikethrough,
                      tooltip: s.strikethroughLabel,
                      active: format.strikethrough,
                      onTap: () => onInline(
                        (f) => f.copyWith(strikethrough: !format.strikethrough),
                      ),
                    ),
                    const _Separator(),
                    _ColorButton(
                      s: s,
                      icon: Icons.format_color_fill,
                      tooltip: s.highlightColor,
                      colorIndex: format.highlightColorIndex,
                      onPicked: (index) => onInline(
                        (f) => index == null
                            ? f.copyWith(clearHighlight: true)
                            : f.copyWith(highlightColorIndex: index),
                      ),
                    ),
                    const _Separator(),
                    _Toggle(
                      icon: Icons.format_underlined,
                      tooltip: s.underlineLabel,
                      active: format.underline,
                      onTap: () => onInline(
                        (f) => f.copyWith(underline: !format.underline),
                      ),
                    ),
                    _ColorButton(
                      s: s,
                      icon: Icons.border_color_outlined,
                      tooltip: s.underlineColor,
                      colorIndex: format.underlineColorIndex,
                      // Picking a color is also how the underline is turned
                      // on - asking for a red underline and getting nothing
                      // because the toggle was still off would just be
                      // annoying.
                      onPicked: (index) => onInline(
                        (f) => index == null
                            ? f.copyWith(clearUnderlineColor: true)
                            : f.copyWith(
                                underlineColorIndex: index,
                                underline: true,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 12),
              // Lists and alignment - both act on whole lines.
              _Scroller(
                child: Row(
                  children: [
                    _Toggle(
                      icon: Icons.format_list_bulleted,
                      tooltip: s.bulletList,
                      active: list == NoteListKind.bullet,
                      onTap: () => onList(
                        list == NoteListKind.bullet
                            ? NoteListKind.none
                            : NoteListKind.bullet,
                      ),
                    ),
                    _Toggle(
                      icon: Icons.format_list_numbered,
                      tooltip: s.numberedList,
                      active: list == NoteListKind.numbered,
                      onTap: () => onList(
                        list == NoteListKind.numbered
                            ? NoteListKind.none
                            : NoteListKind.numbered,
                      ),
                    ),
                    _Toggle(
                      icon: Icons.checklist,
                      tooltip: s.checklist,
                      active: list == NoteListKind.checklist,
                      onTap: () => onList(
                        list == NoteListKind.checklist
                            ? NoteListKind.none
                            : NoteListKind.checklist,
                      ),
                    ),
                    const _Separator(),
                    _Toggle(
                      icon: Icons.format_align_left,
                      tooltip: s.alignLeft,
                      active: align == NoteAlign.left,
                      onTap: () => onAlign(NoteAlign.left),
                    ),
                    _Toggle(
                      icon: Icons.format_align_center,
                      tooltip: s.alignCenter,
                      active: align == NoteAlign.center,
                      onTap: () => onAlign(NoteAlign.center),
                    ),
                    _Toggle(
                      icon: Icons.format_align_right,
                      tooltip: s.alignRight,
                      active: align == NoteAlign.right,
                      onTap: () => onAlign(NoteAlign.right),
                    ),
                  ],
                ),
              ),
              const Divider(height: 12),
              // Thickness, font, size - and the text color right next to
              // them, since it's read off the same three fields' preview.
              _Scroller(
                child: Row(
                  children: [
                    _Choice<int>(
                      hint: s.weightLabel,
                      value: format.weight,
                      // "Standard" means the line style decides, which is
                      // also what the bold toggle works on top of.
                      options: {
                        for (final weight in noteFontWeights) weight: '$weight',
                      },
                      onChanged: (weight) => onInline(
                        (f) => weight == null
                            ? f.copyWith(clearWeight: true)
                            : f.copyWith(weight: weight, bold: false),
                      ),
                      defaultLabel: s.fontStandard,
                    ),
                    const SizedBox(width: 8),
                    _Choice<String>(
                      hint: s.font,
                      value: format.fontFamily,
                      // Named the same way the app list's font picker names
                      // them, rather than showing the raw family name.
                      options: {
                        'serif': s.fontSerif,
                        'monospace': s.fontMonospace,
                      },
                      onChanged: (family) => onInline(
                        (f) => family == null
                            ? f.copyWith(clearFontFamily: true)
                            : f.copyWith(fontFamily: family),
                      ),
                      defaultLabel: s.fontStandard,
                    ),
                    const SizedBox(width: 8),
                    _Choice<double>(
                      hint: s.fontSizeLabel,
                      value: format.fontSize,
                      options: {
                        for (final size in noteFontSizes)
                          size: size.round().toString(),
                      },
                      onChanged: (size) => onInline(
                        (f) => size == null
                            ? f.copyWith(clearFontSize: true)
                            : f.copyWith(fontSize: size),
                      ),
                      defaultLabel: s.fontStandard,
                    ),
                    const _Separator(),
                    _ColorButton(
                      s: s,
                      icon: Icons.format_color_text,
                      tooltip: s.textColor,
                      colorIndex: format.colorIndex,
                      onPicked: (index) => onInline(
                        (f) => index == null
                            ? f.copyWith(clearColor: true)
                            : f.copyWith(colorIndex: index),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every row scrolls sideways on its own, so a narrow screen never drops a
/// button off the edge.
class _Scroller extends StatelessWidget {
  const _Scroller({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: child,
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.black12,
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active ? Colors.black12 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: active ? Colors.black : Colors.black54,
          ),
        ),
      ),
    );
  }
}

/// A swatch that opens the app's colour picker; the ring shows what's set,
/// a crossed-out circle that nothing is.
class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.s,
    required this.icon,
    required this.tooltip,
    required this.colorIndex,
    required this.onPicked,
  });

  final AppStrings s;
  final IconData icon;
  final String tooltip;
  final int? colorIndex;

  /// null means the user chose "no color".
  final ValueChanged<int?> onPicked;

  @override
  Widget build(BuildContext context) {
    final color = noteColorAt(colorIndex);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: () async {
          final picked = await showDialog<int>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(tooltip),
              content: SingleChildScrollView(
                child: ColorSwatchPicker(
                  s: s,
                  selectedIndex: colorIndex ?? -1,
                  onSelected: (index) => Navigator.of(context).pop(index),
                ),
              ),
              actions: [
                TextButton(
                  // -1 rather than null: null is what a dismissed dialog
                  // gives back, and "none" has to stay tellable from that.
                  onPressed: () => Navigator.of(context).pop(-1),
                  child: Text(s.noColor),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s.cancel),
                ),
              ],
            ),
          );
          if (picked == null) return;
          onPicked(picked < 0 ? null : picked);
        },
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.black54),
              const SizedBox(height: 3),
              Container(
                width: 20,
                height: 5,
                decoration: BoxDecoration(
                  color: color ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: color == null ? Colors.black26 : Colors.black12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dropdown whose first entry clears the override again.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.defaultLabel,
  });

  final String hint;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T?> onChanged;
  final String defaultLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          hint,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(width: 4),
        DropdownButton<T?>(
          value: options.containsKey(value) ? value : null,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: [
            DropdownMenuItem<T?>(child: Text(defaultLabel)),
            for (final entry in options.entries)
              DropdownMenuItem<T?>(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
