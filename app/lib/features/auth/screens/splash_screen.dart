import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/splash.png',
              width: 220,
              height: 220,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: AppSizes.iconMd,
              height: AppSizes.iconMd,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.midnight.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
