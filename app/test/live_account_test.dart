@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/api/api_client.dart';
import 'package:story_app/core/storage/secure_store.dart';
import 'package:story_app/features/account/data/account_repository.dart';
import 'package:story_app/features/auth/data/auth_repository.dart';

String uniqueUsername() =>
    'a${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

Future<(AccountRepository, AuthRepository, String)> signedIn() async {
  final store = SecureStore(InMemoryStore());
  final client = ApiClient(store: store);
  final username = uniqueUsername();

  final session = (await AuthRepository(client).signup(
    username: username,
    password: 'a-long-enough-password',
    tncAccepted: true,
  )).valueOrNull!;

  await store.saveTokens(
    accessToken: session.tokens.accessToken,
    refreshToken: session.tokens.refreshToken,
  );
  return (AccountRepository(client), AuthRepository(client), username);
}

void main() {
  test('adding an email returns a masked address and never the plaintext', () async {
    final (account, _, username) = await signedIn();
    final result = await account.addEmail('$username@example.com');

    final state = result.valueOrNull!;
    expect(state.verified, isFalse);
    expect(state.masked, isNotNull);
    expect(state.masked, isNot(contains(username)));
  });

  test('a bad otp is rejected with a usable message', () async {
    final (account, _, username) = await signedIn();
    await account.addEmail('$username@example.com');

    final result = await account.verifyEmail('000000');
    expect(result.failureOrNull!.code, 'OTP_INVALID');
  });

  test('resending too soon is refused', () async {
    final (account, _, username) = await signedIn();
    await account.addEmail('$username@example.com');

    final result = await account.resendOtp();
    expect(result.failureOrNull!.code, 'OTP_COOLDOWN');
  });

  test('a reset request never reveals whether the account exists', () async {
    final (account, _, _) = await signedIn();
    final known = await account.requestReset('someone_real_enough');
    final unknown = await account.requestReset('not_a_real_user');
    expect(known.isSuccess, unknown.isSuccess);
  });

  test('deactivating requires the right password', () async {
    final (account, _, _) = await signedIn();
    final result = await account.deactivate('not-my-password');
    expect(result.failureOrNull!.code, 'INVALID_CREDENTIALS');
  });

  test('deactivating then signing in restores the account', () async {
    final (account, auth, username) = await signedIn();
    expect((await account.deactivate('a-long-enough-password')).isSuccess, isTrue);

    final signin = await auth.signin(
      username: username,
      password: 'a-long-enough-password',
    );
    expect(signin.isSuccess, isTrue);
  });

  test('deletion is scheduled and blocks sign in', () async {
    final (account, auth, username) = await signedIn();
    final result = await account.requestDeletion('a-long-enough-password');
    expect(result.valueOrNull, isNotNull);

    final signin = await auth.signin(
      username: username,
      password: 'a-long-enough-password',
    );
    expect(signin.failureOrNull!.code, 'ACCOUNT_DEACTIVATED');
  });

  test('a scheduled deletion can be cancelled', () async {
    final (account, auth, username) = await signedIn();
    await account.requestDeletion('a-long-enough-password');

    final cancelled = await account.cancelDeletion(
      username: username,
      password: 'a-long-enough-password',
    );
    expect(cancelled.isSuccess, isTrue);

    final signin = await auth.signin(
      username: username,
      password: 'a-long-enough-password',
    );
    expect(signin.isSuccess, isTrue);
  });
}
