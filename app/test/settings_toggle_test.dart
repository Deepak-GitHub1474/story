import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_app/core/prefs/prefs_store.dart';
import 'package:story_app/core/result.dart';
import 'package:story_app/features/auth/data/profile_repository.dart';
import 'package:story_app/features/auth/models/auth_models.dart';
import 'package:story_app/features/auth/providers/auth_provider.dart';
import 'package:story_app/features/settings/providers/settings_provider.dart';
import 'package:story_app/features/settings/providers/theme_provider.dart';
import 'package:story_app/features/settings/screens/settings_screen.dart';
import 'package:story_app/theme/app_theme.dart';

AppUser reader({bool inApp = true}) => AppUser.fromJson({
  'user_id': 'us_1',
  'username': 'deepak',
  'display_name': 'Deepak',
  'avatar_seed': 'seed',
  'role': 'user',
  'status': 'active',
  'prefs': {'notify_in_app': inApp, 'notify_push': false},
});

class FakeAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.signedIn, user: reader());
}

class SlowProfile implements ProfileRepository {
  SlowProfile({this.succeeds = true});

  final bool succeeds;
  final answered = Completer<void>();
  int calls = 0;

  @override
  Future<Result<AppUser>> updateProfile({
    String? displayName,
    String? bio,
    String? avatarSeed,
    List<String>? interests,
    Map<String, dynamic>? prefs,
  }) async {
    calls += 1;
    await answered.future;
    if (!succeeds) {
      return const Failure(code: 'OFFLINE', message: 'Not now.');
    }
    return Success(reader(inApp: prefs?['notify_in_app'] as bool? ?? true));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> openSettings(WidgetTester tester, SlowProfile profile) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
        authProvider.overrideWith(FakeAuth.new),
        profileRepositoryProvider.overrideWithValue(profile),
      ],
      child: MaterialApp(theme: midnightTheme, home: const SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder inAppSwitch() => find.ancestor(
  of: find.text('In-app notifications'),
  matching: find.byType(Row),
).first;

bool switchIsOn(WidgetTester tester) =>
    tester.widget<Switch>(find.byType(Switch).first).value;

void main() {
  testWidgets('the switch moves before the server has answered', (tester) async {
    final profile = SlowProfile();
    await openSettings(tester, profile);

    expect(switchIsOn(tester), isTrue);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(
      switchIsOn(tester),
      isFalse,
      reason: 'waiting on the network to move a switch feels broken',
    );
    expect(profile.calls, 1);

    profile.answered.complete();
    await tester.pumpAndSettle();
    expect(switchIsOn(tester), isFalse);
  });

  testWidgets('a save that fails snaps the switch back', (tester) async {
    final profile = SlowProfile(succeeds: false);
    await openSettings(tester, profile);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(switchIsOn(tester), isFalse);

    profile.answered.complete();
    await tester.pumpAndSettle();

    expect(
      switchIsOn(tester),
      isTrue,
      reason: 'an optimistic switch that keeps a lost change is lying',
    );
  });

  testWidgets('saving a pref costs one call, not two', (tester) async {
    final profile = SlowProfile();
    await openSettings(tester, profile);

    await tester.tap(find.byType(Switch).first);
    profile.answered.complete();
    await tester.pumpAndSettle();

    expect(
      profile.calls,
      1,
      reason: 'updateProfile already returns the user, so re-fetching /me is waste',
    );
  });
}
