@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/api/api_client.dart';
import 'package:story_app/core/storage/secure_store.dart';
import 'package:story_app/features/auth/data/auth_repository.dart';

String uniqueUsername() =>
    'live_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

void main() {
  late SecureStore store;
  late AuthRepository repository;

  setUp(() {
    store = SecureStore(InMemoryStore());
    repository = AuthRepository(ApiClient(store: store));
  });

  test('signup creates an account on the live backend', () async {
    final username = uniqueUsername();
    final result = await repository.signup(
      username: username,
      password: 'a-long-enough-password',
      tncAccepted: true,
    );

    final session = result.valueOrNull;
    expect(result.failureOrNull?.message, isNull);
    expect(session, isNotNull);
    expect(session!.user.username, username);
    expect(session.user.referralCode.length, 6);
    expect(session.user.role, 'user');
    expect(session.user.blocked, isFalse);
    expect(session.tokens.accessToken, isNotEmpty);
  });

  test('username availability flips after signup', () async {
    final username = uniqueUsername();
    expect((await repository.isUsernameAvailable(username)).valueOrNull, isTrue);

    await repository.signup(
      username: username,
      password: 'a-long-enough-password',
      tncAccepted: true,
    );

    expect((await repository.isUsernameAvailable(username)).valueOrNull, isFalse);
  });

  test('duplicate signup returns USERNAME_TAKEN on the username field', () async {
    final username = uniqueUsername();
    await repository.signup(
      username: username,
      password: 'a-long-enough-password',
      tncAccepted: true,
    );

    final failure = (await repository.signup(
      username: username,
      password: 'a-long-enough-password',
      tncAccepted: true,
    )).failureOrNull;

    expect(failure!.code, 'USERNAME_TAKEN');
    expect(failure.field, 'username');
  });

  test('an unknown referral code is rejected', () async {
    final failure = (await repository.signup(
      username: uniqueUsername(),
      password: 'a-long-enough-password',
      tncAccepted: true,
      referralCode: 'ZZZZZZ',
    )).failureOrNull;

    expect(failure!.code, 'REFERRAL_CODE_INVALID');
  });

  test('a valid referral code is recorded', () async {
    final referrer = (await repository.signup(
      username: uniqueUsername(),
      password: 'a-long-enough-password',
      tncAccepted: true,
    )).valueOrNull!;

    final referred = (await repository.signup(
      username: uniqueUsername(),
      password: 'a-long-enough-password',
      tncAccepted: true,
      referralCode: referrer.user.referralCode,
    )).valueOrNull!;

    expect(referred.user.referredBy, referrer.user.referralCode);
  });

  test('signin returns a session and records login info', () async {
    final username = uniqueUsername();
    await repository.signup(
      username: username,
      password: 'a-long-enough-password',
      tncAccepted: true,
    );

    final session = (await repository.signin(
      username: username,
      password: 'a-long-enough-password',
    )).valueOrNull;

    expect(session, isNotNull);
    expect(session!.user.username, username);
  });

  test('signin with a wrong password returns INVALID_CREDENTIALS', () async {
    final username = uniqueUsername();
    await repository.signup(
      username: username,
      password: 'a-long-enough-password',
      tncAccepted: true,
    );

    final failure = (await repository.signin(
      username: username,
      password: 'definitely-not-it',
    )).failureOrNull;

    expect(failure!.code, 'INVALID_CREDENTIALS');
  });

  test('me returns the signed-in user using the stored token', () async {
    final username = uniqueUsername();
    final session = (await repository.signup(
      username: username,
      password: 'a-long-enough-password',
      tncAccepted: true,
    )).valueOrNull!;

    await store.saveTokens(
      accessToken: session.tokens.accessToken,
      refreshToken: session.tokens.refreshToken,
    );

    final user = (await repository.me()).valueOrNull;
    expect(user!.username, username);
  });

  test('me without a token returns SESSION_REQUIRED', () async {
    final failure = (await repository.me()).failureOrNull;
    expect(failure!.code, 'SESSION_REQUIRED');
  });

  test('signout invalidates the session', () async {
    final session = (await repository.signup(
      username: uniqueUsername(),
      password: 'a-long-enough-password',
      tncAccepted: true,
    )).valueOrNull!;

    await store.saveTokens(
      accessToken: session.tokens.accessToken,
      refreshToken: session.tokens.refreshToken,
    );

    expect((await repository.signout()).isSuccess, isTrue);
    expect((await repository.me()).failureOrNull!.code, 'TOKEN_REVOKED');
  });
}
