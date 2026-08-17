import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/otp_field.dart';
import 'package:story_app/core/result.dart';
import 'package:story_app/features/account/data/account_repository.dart';
import 'package:story_app/features/settings/providers/settings_provider.dart';
import 'package:story_app/features/auth/models/auth_models.dart';
import 'package:story_app/features/auth/providers/auth_provider.dart';
import 'package:story_app/features/account/screens/email_screen.dart';
import 'package:story_app/theme/app_theme.dart';

AppUser someone({String? emailMasked}) => AppUser.fromJson({
  'user_id': 'us_1',
  'username': 'deepak',
  'display_name': 'Deepak',
  'avatar_seed': 'seed',
  'role': 'user',
  'status': 'active',
  'email_masked': ?emailMasked,
});

class FakeAuth extends AuthNotifier {
  FakeAuth(this._user);

  final AppUser _user;

  @override
  AuthState build() => AuthState(status: AuthStatus.signedIn, user: _user);
}

class SendingRepository implements AccountRepository {
  @override
  Future<Result<EmailState>> addEmail(String email) async => const Success(
    EmailState(masked: 'd••••k@gmail.com', verified: false),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> showEmail(WidgetTester tester, {String? emailMasked}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => FakeAuth(someone(emailMasked: emailMasked))),
        accountRepositoryProvider.overrideWithValue(SendingRepository()),
      ],
      child: MaterialApp(theme: midnightTheme, home: const EmailScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with no email yet it asks for one', (tester) async {
    await showEmail(tester);

    expect(find.text('Email address'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('with an email on file it shows that instead of the form', (
    tester,
  ) async {
    await showEmail(tester, emailMasked: 'd••••k@gmail.com');

    expect(find.textContaining('d••••k@gmail.com'), findsWidgets);
  });

  testWidgets('the screen builds without a single drawn glyph', (tester) async {
    await showEmail(tester);

    expect(
      tester.takeException(),
      isNull,
      reason: 'removing the doodles must not have left a dangling widget',
    );
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('the code field is still what it was', (tester) async {
    await showEmail(tester);

    expect(
      find.byType(OtpField),
      findsNothing,
      reason: 'no code is asked for until an email has been sent one',
    );
  });

  testWidgets('sending a code still opens the code step', (tester) async {
    await showEmail(tester);

    await tester.enterText(find.byType(TextField).first, 'd@gmail.com');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(
      find.byType(OtpField),
      findsOneWidget,
      reason: 'this is the branch the keyhole doodle was removed from',
    );
    expect(find.text('Enter the 6-digit code we sent.'), findsOneWidget);
    expect(find.textContaining('Send again in'), findsWidgets);

    await tester.pumpAndSettle(const Duration(minutes: 11));
  });

  testWidgets('nothing on this screen needs scrolling to reach', (
    tester,
  ) async {
    await showEmail(tester);

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;

    expect(position.maxScrollExtent, 0);
  });
}
