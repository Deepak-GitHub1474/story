import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/double_back_to_exit.dart';
import 'package:story_app/theme/app_theme.dart';

Widget host({bool Function()? onBack}) => MaterialApp(
  theme: midnightTheme,
  home: DoubleBackToExit(
    onBack: onBack,
    child: const Scaffold(body: Center(child: Text('home'))),
  ),
);

Future<void> pressBack(WidgetTester tester) async {
  final state = tester.state<NavigatorState>(find.byType(Navigator));
  await state.maybePop();
  await tester.pump();
}

void main() {
  testWidgets('the first back press warns instead of leaving', (tester) async {
    await tester.pumpWidget(host());
    await pressBack(tester);

    expect(find.text('Press back again to leave.'), findsOneWidget);
  });

  testWidgets('a single back press never closes the app', (tester) async {
    await tester.pumpWidget(host());
    await pressBack(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the warning window expires so a later press warns again', (tester) async {
    await tester.pumpWidget(host());
    await pressBack(tester);
    await tester.pump(DoubleBackToExit.window + const Duration(seconds: 1));

    await pressBack(tester);
    expect(find.text('Press back again to leave.'), findsWidgets);
  });

  testWidgets('a handled back does not warn', (tester) async {
    var handled = 0;
    await tester.pumpWidget(host(onBack: () {
      handled++;
      return true;
    }));

    await pressBack(tester);

    expect(handled, 1);
    expect(find.text('Press back again to leave.'), findsNothing);
  });

  testWidgets('a handled back resets the exit window', (tester) async {
    var shouldHandle = true;
    await tester.pumpWidget(host(onBack: () => shouldHandle));

    await pressBack(tester);
    shouldHandle = false;
    await pressBack(tester);

    expect(find.text('Press back again to leave.'), findsOneWidget);
  });

  testWidgets('an unhandled back falls through to the warning', (tester) async {
    await tester.pumpWidget(host(onBack: () => false));
    await pressBack(tester);

    expect(find.text('Press back again to leave.'), findsOneWidget);
  });
}
