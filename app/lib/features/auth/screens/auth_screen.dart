import 'package:flutter/material.dart';

import '../../../components/app_scaffold.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../widgets/signin_form.dart';
import '../widgets/signup_form.dart';

enum AuthTab { login, signup }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialTab = AuthTab.login});

  final AuthTab initialTab;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppScaffold(
      padding: EdgeInsets.zero,
      alignment: Alignment.topCenter,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/bloom.png',
                width: 151,
                height: 226,
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _tab.index,
                  sizing: StackFit.expand,
                  children: [
                    SigninForm(
                      header: _header(colors, isLogin: true),
                      onSwitch: () => setState(() => _tab = AuthTab.signup),
                    ),
                    SignupForm(
                      header: _header(colors, isLogin: false),
                      onSwitch: () => setState(() => _tab = AuthTab.login),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(AppColors colors, {required bool isLogin}) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.xxl + AppSpacing.md,
      AppSpacing.xl,
      AppSpacing.lg,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 184),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'STORY',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: AppTypeScale.heading,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: 200,
                child: Text(
                  isLogin ? 'Welcome back' : 'Create account',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: 215,
                child: Text(
                  isLogin
                      ? 'Your space. Your story. Always private.'
                      : 'Pick a name nobody can trace back to you.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: AppTypeScale.body,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
