import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/app_close_button.dart';
import 'package:story_app/theme/app_theme.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: midnightTheme, home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('every close is the same mark', (tester) async {
    await tester.pumpWidget(_host(AppCloseButton(onPressed: () {})));

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.close_rounded);
  });

  testWidgets('it answers a tap', (tester) async {
    var closed = 0;
    await tester.pumpWidget(_host(AppCloseButton(onPressed: () => closed += 1)));

    await tester.tap(find.byType(AppCloseButton));
    await tester.pump();

    expect(closed, 1);
  });

  testWidgets('the small one is smaller but the same mark', (tester) async {
    await tester.pumpWidget(
      _host(AppCloseButton(size: AppCloseSize.small, onPressed: () {})),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.close_rounded);
    expect(icon.size, 18);
  });

  testWidgets('on a picture it turns white so it stays visible', (tester) async {
    await tester.pumpWidget(
      _host(AppCloseButton(isOnImage: true, onPressed: () {})),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, Colors.white);
  });

  testWidgets('the tap target is big enough for a thumb', (tester) async {
    await tester.pumpWidget(_host(AppCloseButton(onPressed: () {})));

    final box = tester.getSize(find.byType(SizedBox).first);
    expect(box.width, greaterThanOrEqualTo(40));
    expect(box.height, greaterThanOrEqualTo(40));
  });
}
