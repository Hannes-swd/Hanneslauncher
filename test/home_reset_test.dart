import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/home_reset.dart';

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ),
    );
  }

  void push(Widget page) {
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  testWidgets('home closes every settings page on top of the home screen', (
    tester,
  ) async {
    await pumpHome(tester);
    push(const Scaffold(body: Text('settings')));
    push(const Scaffold(body: Text('app list settings')));
    await tester.pumpAndSettle();

    final closed = popToHome(navigatorKey.currentState!);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('settings'), findsNothing);
    expect(find.text('app list settings'), findsNothing);
  });

  testWidgets('dialogs go too', (tester) async {
    await pumpHome(tester);
    push(const Scaffold(body: Text('settings')));
    await tester.pumpAndSettle();
    showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (_) => const AlertDialog(content: Text('dialog')),
    );
    await tester.pumpAndSettle();

    popToHome(navigatorKey.currentState!);
    await tester.pumpAndSettle();

    expect(find.text('dialog'), findsNothing);
    expect(find.text('settings'), findsNothing);
  });

  testWidgets('already home, there is nothing to close', (tester) async {
    await pumpHome(tester);

    expect(popToHome(navigatorKey.currentState!), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a page that refuses back is asked, not thrown away', (
    tester,
  ) async {
    var asked = 0;
    await pumpHome(tester);
    push(const Scaffold(body: Text('settings')));
    push(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) asked++;
        },
        child: const Scaffold(body: Text('editor')),
      ),
    );
    push(const Scaffold(body: Text('above the editor')));
    await tester.pumpAndSettle();

    popToHome(navigatorKey.currentState!);
    await tester.pumpAndSettle();

    expect(find.text('above the editor'), findsNothing);
    expect(find.text('editor'), findsOneWidget);
    expect(asked, 1);
  });
}
