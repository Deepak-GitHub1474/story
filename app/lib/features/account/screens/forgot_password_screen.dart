import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_text_field.dart';
import '../../../components/app_toast.dart';
import '../../../components/otp_field.dart';
import '../../../core/utils/otp_wait.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/widgets/password_strength_bar.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/account_repository.dart';

enum _Step { username, code, password }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _username = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();

  _Step _step = _Step.username;
  bool _isBusy = false;
  bool _acknowledged = false;
  String? _resetToken;
  String? _error;

  Timer? _tick;
  DateTime? _codeDies;
  DateTime? _canAskAgain;
  DateTime? _lockedUntil;

  Duration get _codeLife => _leftUntil(_codeDies);

  Duration get _resendIn => _leftUntil(_canAskAgain);

  Duration get _lockedFor => _leftUntil(_lockedUntil);

  Duration _leftUntil(DateTime? moment) {
    if (moment == null) return Duration.zero;
    final left = moment.difference(DateTime.now());
    return left > Duration.zero ? left : Duration.zero;
  }

  @override
  void dispose() {
    _tick?.cancel();
    _username.dispose();
    _otp.dispose();
    _password.dispose();
    super.dispose();
  }

  void _keepTicking() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (_codeLife <= Duration.zero &&
          _resendIn <= Duration.zero &&
          _lockedFor <= Duration.zero) {
        timer.cancel();
      }
    });
  }

  void _startClocks(ResetAsk ask) {
    final now = DateTime.now();
    setState(() {
      _codeDies = now.add(ask.expiresIn);
      _canAskAgain = now.add(ask.resendAfter);
      _lockedUntil = null;
    });
    _keepTicking();
  }

  void _lockOut(Duration wait) {
    setState(() {
      _lockedUntil = DateTime.now().add(wait);
      _codeDies = null;
      _canAskAgain = null;
      _error = null;
      _otp.clear();
    });
    _keepTicking();
  }

  Future<void> _request() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await ref
        .read(accountRepositoryProvider)
        .requestReset(_username.text.trim().toLowerCase());

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _step = _Step.code;
    });

    final ask = result.valueOrNull;
    if (ask != null) _startClocks(ask);
  }

  Future<void> _resend() async {
    if (_resendIn > Duration.zero || _lockedFor > Duration.zero || _isBusy) {
      return;
    }

    setState(() => _isBusy = true);
    final result = await ref
        .read(accountRepositoryProvider)
        .requestReset(_username.text.trim().toLowerCase());

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _error = null;
      _otp.clear();
    });

    final ask = result.valueOrNull;
    if (ask != null) _startClocks(ask);
    if (!mounted) return;
    AppToast.show(context, 'A new code is on its way.');
  }

  Future<void> _verify(String otp) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await ref.read(accountRepositoryProvider).verifyReset(
      username: _username.text.trim().toLowerCase(),
      otp: otp,
    );

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result.isSuccess) {
      _tick?.cancel();
      setState(() {
        _resetToken = result.valueOrNull;
        _step = _Step.password;
      });
    } else {
      final failure = result.failureOrNull!;
      final wait = lockedWait(failure);
      if (wait != null) {
        _lockOut(wait);
      } else {
        setState(() {
          _error = otpTrouble(failure);
          _otp.clear();
        });
      }
    }
  }

  Future<void> _complete() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await ref.read(accountRepositoryProvider).completeReset(
      resetToken: _resetToken!,
      newPassword: _password.text,
    );

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result.isSuccess) {
      AppToast.show(context, 'Password reset. Sign in.', kind: AppToastKind.success);
      context.go(Routes.signin);
    } else {
      setState(() => _error = result.failureOrNull!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppScaffold(
      title: 'Forgot password',
      leading: BackButton(onPressed: () => context.pop()),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_step == _Step.username) ...[
              Text(
                'If an email is on your account, we will send a code to it.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: AppTypeScale.body,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _username,
                label: 'Username',
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Send code',
                isLoading: _isBusy,
                onPressed: _username.text.trim().isEmpty ? null : _request,
              ),
            ] else if (_step == _Step.code) ...[
              Text(
                'Enter the code we sent. If no email is on the account, no code '
                'was sent and nothing here will work.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: AppTypeScale.body,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              OtpField(
                controller: _otp,
                hasError: _error != null,
                enabled: _lockedFor <= Duration.zero,
                onCompleted: _verify,
              ),
              if (_lockedFor > Duration.zero) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  lockedLabel(_lockedFor),
                  style: TextStyle(
                    color: colors.danger,
                    fontSize: AppTypeScale.caption,
                  ),
                ),
              ] else ...[
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: colors.danger,
                      fontSize: AppTypeScale.caption,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      expiryLabel(_codeLife) ?? '',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: AppTypeScale.caption,
                      ),
                    ),
                    GestureDetector(
                      onTap: _resend,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        resendLabel(_resendIn),
                        style: TextStyle(
                          color: _resendIn > Duration.zero
                              ? colors.textMuted
                              : colors.accent,
                          fontSize: AppTypeScale.caption,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.danger),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: colors.danger),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Read this before continuing',
                          style: TextStyle(
                            color: colors.danger,
                            fontSize: AppTypeScale.body,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'A reset gives you back your account. Your chats were sealed '
                      'with the password you forgot, so nothing can open them again '
                      'and they are cleared from here. Whoever you were talking to '
                      'keeps their own copy.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: AppTypeScale.label,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Your vault is opened by its own passcode, so it is unaffected '
                      'and stays exactly as it was.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: AppTypeScale.label,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              InkWell(
                onTap: () => setState(() => _acknowledged = !_acknowledged),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _acknowledged ? colors.danger : Colors.transparent,
                        border: Border.all(
                          color: _acknowledged ? colors.danger : colors.border,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _acknowledged
                          ? Icon(Icons.check, size: 16, color: colors.bg)
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'I understand my chats will be cleared and this signs me '
                        'out everywhere.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: AppTypeScale.label,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _password,
                label: 'New password',
                obscureText: true,
                errorText: _error,
                helperText: 'At least 10 characters.',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              PasswordStrengthBar(password: _password.text),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Reset password',
                isLoading: _isBusy,
                onPressed: _acknowledged && _password.text.length >= 10
                    ? _complete
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
