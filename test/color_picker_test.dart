import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_strings.dart';
import 'package:hanneslauncher/color_swatch_picker.dart';
import 'package:hanneslauncher/design_tokens.dart';
import 'package:hanneslauncher/locale_controller.dart';

const _s = AppStrings(AppLanguage.de);

/// Opens the picker and hands back whatever it was closed with.
Future<Color?> _open(
  WidgetTester tester, {
  Color? initial,
  bool allowAlpha = true,
}) async {
  Color? result;
  var opened = false;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(DesignSettings()),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                opened = true;
                result = await showColorPickerDialog(
                  context,
                  _s,
                  initial: initial,
                  allowAlpha: allowAlpha,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(opened, isTrue);
  return result;
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text(_s.save));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the colour it was opened with is the colour it gives back', (
    tester,
  ) async {
    // Nothing touched means nothing changed - otherwise opening the picker to
    // look at a colour would quietly shift it.
    const original = Color(0xFF6366F1);
    Color? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(DesignSettings()),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showColorPickerDialog(
                    context,
                    _s,
                    initial: original,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _save(tester);
    expect(picked, original);
  });

  testWidgets('the opacity slider is there, and only where it belongs', (
    tester,
  ) async {
    await _open(tester, initial: const Color(0xFF204080));
    // Brightness and opacity.
    expect(find.byType(Slider), findsNWidgets(2));
    expect(find.textContaining('Helligkeit'), findsOneWidget);
    expect(find.textContaining('Deckkraft'), findsOneWidget);

    await tester.tap(find.text(_s.cancel));
    await tester.pumpAndSettle();

    await _open(tester, initial: const Color(0xFF204080), allowAlpha: false);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.textContaining('Deckkraft'), findsNothing);
  });

  testWidgets('a hex typed in is the colour that comes back', (tester) async {
    Color? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(DesignSettings()),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showColorPickerDialog(context, _s);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'EC4899');
    await tester.pumpAndSettle();
    await _save(tester);
    expect(picked, const Color(0xFFEC4899));
  });

  testWidgets('eight digits carry the transparency with them', (tester) async {
    Color? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(DesignSettings()),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showColorPickerDialog(context, _s);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '8010B981');
    await tester.pumpAndSettle();
    await _save(tester);
    expect(picked?.toARGB32(), 0x8010B981);
  });

  testWidgets('with the opacity slider hidden, what comes back is solid', (
    tester,
  ) async {
    Color? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(DesignSettings()),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  // Even handed a see-through colour to start from: the two
                  // grounds the design paints have to come back opaque.
                  picked = await showColorPickerDialog(
                    context,
                    _s,
                    initial: const Color(0x40123456),
                    allowAlpha: false,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _save(tester);
    expect(picked?.a, 1.0);
  });

  testWidgets('dragging across the field changes the colour', (tester) async {
    Color? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(DesignSettings()),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showColorPickerDialog(
                    context,
                    _s,
                    initial: const Color(0xFFFF0000),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // A tap in the middle of the field is a different hue from the red it
    // opened on - which is the whole point of having a field. The field has
    // no type of its own to find, so it is located by the brightness slider
    // that sits directly under it.
    final brightness = tester.getRect(find.byType(Slider).first);
    await tester.tapAt(Offset(brightness.center.dx, brightness.top - 90));
    await tester.pumpAndSettle();
    await _save(tester);
    expect(picked, isNotNull);
    expect(picked, isNot(const Color(0xFFFF0000)));
  });
}
