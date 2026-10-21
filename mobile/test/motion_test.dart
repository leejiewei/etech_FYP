import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etech_mobile/theme.dart';
import 'package:etech_mobile/widgets/motion.dart';

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find.descendant(
        of: find.byType(Entrance), matching: find.byType(FadeTransition)))
    .opacity
    .value;

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
      theme: AppTheme.theme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('a card fades in over durSlow', (tester) async {
    await tester.pumpWidget(_app(const Entrance(index: 0, child: Text('card'))));
    expect(_opacity(tester), 0);
    await tester.pump(AppTheme.durSlow);
    expect(_opacity(tester), 1);
  });

  testWidgets('later cards in the first screenful wait their turn', (tester) async {
    await tester.pumpWidget(_app(const Entrance(index: 4, child: Text('card'))));
    await tester.pump(AppTheme.durFast * (3 / 4));
    expect(_opacity(tester), 0);
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
  });

  testWidgets('with animations removed a card is simply there', (tester) async {
    await tester.pumpWidget(
        _app(const Entrance(index: 3, child: Text('card')), reduced: true));
    expect(_opacity(tester), 1);
  });

  testWidgets('a card gives a little under the finger and lets go', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(PressScale(
      child: GestureDetector(onTap: () => taps++, child: const Text('card')),
    )));
    double scale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    final gesture = await tester.startGesture(tester.getCenter(find.text('card')));
    await tester.pump();
    expect(scale(), AppTheme.pressScale);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(), 1);
    expect(taps, 1, reason: 'the press-in must not swallow the tap');
  });

  testWidgets('pages open with the rise transition at durSlow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const Text('next page'))),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(AppTheme.durSlow ~/ 2);
    final fade = tester.widget<FadeTransition>(find
        .ancestor(of: find.text('next page'), matching: find.byType(FadeTransition))
        .first);
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(find.text('next page'), findsOneWidget);
  });
}
