@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/api/api_client.dart';
import 'package:story_app/core/storage/secure_store.dart';
import 'package:story_app/features/auth/data/auth_repository.dart';
import 'package:story_app/features/vault/data/recovery_repository.dart';

String uniqueUsername() =>
    'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

Future<RecoveryRepository> signedIn() async {
  final store = SecureStore(InMemoryStore());
  final client = ApiClient(store: store);
  final auth = AuthRepository(client);

  final session = (await auth.signup(
    username: uniqueUsername(),
    password: 'a-long-enough-password',
    tncAccepted: true,
  )).valueOrNull!;

  await store.saveTokens(
    accessToken: session.tokens.accessToken,
    refreshToken: session.tokens.refreshToken,
  );
  return RecoveryRepository(client);
}

void main() {
  test('opening a passcode release request returns a submitted ticket', () async {
    final recovery = await signedIn();

    final ticket = (await recovery.open(
      type: 'passcode_release',
      reason: 'I cannot remember the passcode for my vault.',
    )).valueOrNull;

    expect(ticket, isNotNull);
    expect(ticket!.type, 'passcode_release');
    expect(ticket.state, 'submitted');
    expect(ticket.requiredRole, 'super_admin');
  });

  test('a second request of the same type is refused', () async {
    final recovery = await signedIn();
    const reason = 'I cannot remember the passcode for my vault.';

    await recovery.open(type: 'passcode_release', reason: reason);
    final second = await recovery.open(type: 'passcode_release', reason: reason);

    expect(second.isFailure, isTrue);
    expect(second.failureOrNull!.code, 'TICKET_ALREADY_OPEN');
  });

  test('my requests list what I opened', () async {
    final recovery = await signedIn();
    await recovery.open(
      type: 'passcode_release',
      reason: 'Locked out of the vault after changing my phone.',
    );

    final mine = (await recovery.tickets()).valueOrNull;

    expect(mine, isNotNull);
    expect(mine!.length, 1);
    expect(mine.first.reason, contains('Locked out'));
  });

  test('security activity is empty until staff touch the account', () async {
    final recovery = await signedIn();

    final activity = (await recovery.securityActivity()).valueOrNull;

    expect(activity, isNotNull);
    expect(activity, isEmpty);
  });

  test('a request cannot be opened without a reason', () async {
    final recovery = await signedIn();

    final result = await recovery.open(type: 'passcode_release', reason: 'no');

    expect(result.isFailure, isTrue);
  });
}
