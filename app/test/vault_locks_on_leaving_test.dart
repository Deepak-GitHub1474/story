import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/features/vault/models/vault_models.dart';
import 'package:story_app/features/vault/providers/vault_providers.dart';
import 'package:story_app/features/vault/screens/vault_screen.dart';
import 'package:story_app/theme/app_theme.dart';

class _AlreadyOpen extends VaultSessionNotifier {
  @override
  VaultSession build() => VaultSession(
    state: VaultLockState.unlocked,
    umk: Uint8List(32),
    passcodeId: 'pcd_1',
    label: 'Main vault',
    keySource: 'master',
  );
}

final _overview = VaultOverview(
  itemCount: 0,
  usedBytes: 0,
  limitBytes: 1024,
  orphanedCount: 0,
  passcodes: [
    VaultPasscode.fromJson(const {
      'passcode_id': 'pcd_1',
      'label': 'Main vault',
      'salt_pc': 'c2FsdA==',
      'kdf': <String, dynamic>{},
    }),
  ],
);

Future<ProviderContainer> openVault(WidgetTester tester) async {
  tester.view.physicalSize = const Size(440, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      vaultSessionProvider.overrideWith(_AlreadyOpen.new),
      vaultOverviewProvider.overrideWith((ref) async => _overview),
      vaultItemsProvider.overrideWith((ref) async => <VaultItem>[]),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/vault'),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(path: '/vault', builder: (context, state) => const VaultScreen()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: midnightTheme,
        routerConfig: router,
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  expect(container.read(vaultSessionProvider).isUnlocked, isTrue);
  return container;
}

void main() {
  testWidgets('leaving by the back gesture locks the vault', (tester) async {
    final container = await openVault(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      container.read(vaultSessionProvider).isUnlocked,
      isFalse,
      reason: 'a system back must lock, exactly as the arrow does',
    );
  });

  testWidgets('leaving by the arrow locks the vault', (tester) async {
    final container = await openVault(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(container.read(vaultSessionProvider).isUnlocked, isFalse);
  });

  testWidgets('sending the app to the background locks the vault', (
    tester,
  ) async {
    final container = await openVault(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(
      container.read(vaultSessionProvider).isUnlocked,
      isFalse,
      reason: 'the vault must not stay open behind another app',
    );
  });

  testWidgets('the vault stays open while the app is merely inactive', (
    tester,
  ) async {
    final container = await openVault(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(container.read(vaultSessionProvider).isUnlocked, isTrue);
  });
}
