import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import '../../../core/storage/secure_store.dart';
import '../data/auth_repository.dart';
import '../models/auth_models.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  const AuthState({required this.status, this.user, this.isBusy = false});

  final AuthStatus status;
  final AppUser? user;
  final bool isBusy;

  AuthState copyWith({AuthStatus? status, AppUser? user, bool? isBusy, bool clearUser = false}) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : (user ?? this.user),
        isBusy: isBusy ?? this.isBusy,
      );
}

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(secureStoreProvider);
  return ApiClient(
    store: store,
    onSessionExpired: () async {
      await store.clear();
      ref.read(authProvider.notifier).markSignedOut();
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unknown);

  SecureStore get _store => ref.read(secureStoreProvider);

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> restoreSession() async {
    final token = await _store.readAccessToken();
    if (token == null) {
      state = const AuthState(status: AuthStatus.signedOut);
      return;
    }

    final result = await _repository.me();
    state = result.fold(
      onSuccess: (success) => AuthState(status: AuthStatus.signedIn, user: success.value),
      onFailure: (_) => const AuthState(status: AuthStatus.signedOut),
    );
  }

  Future<Failure<AuthSession>?> signup({
    required String username,
    required String password,
    required bool tncAccepted,
    String? referralCode,
  }) async {
    state = state.copyWith(isBusy: true);
    final result = await _repository.signup(
      username: username,
      password: password,
      tncAccepted: tncAccepted,
      referralCode: referralCode,
    );
    return _completeSession(result);
  }

  Future<Failure<AuthSession>?> signin({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isBusy: true);
    final result = await _repository.signin(username: username, password: password);
    return _completeSession(result);
  }

  Future<Failure<AuthSession>?> _completeSession(Result<AuthSession> result) async {
    final failure = result.failureOrNull;
    if (failure != null) {
      state = state.copyWith(isBusy: false);
      return failure;
    }

    final session = result.valueOrNull!;
    await _store.saveTokens(
      accessToken: session.tokens.accessToken,
      refreshToken: session.tokens.refreshToken,
    );
    state = AuthState(status: AuthStatus.signedIn, user: session.user);
    return null;
  }

  Future<void> refreshUser() async {
    final result = await _repository.me();
    final user = result.valueOrNull;
    if (user != null) {
      state = state.copyWith(status: AuthStatus.signedIn, user: user);
    }
  }

  Future<void> signout() async {
    state = state.copyWith(isBusy: true);
    await _repository.signout();
    await _store.clear();
    state = const AuthState(status: AuthStatus.signedOut);
  }

  void markSignedOut() {
    state = const AuthState(status: AuthStatus.signedOut);
  }
}
