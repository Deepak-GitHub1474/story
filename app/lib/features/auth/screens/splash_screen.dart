import 'package:flutter/material.dart';

import '../../../components/app_scaffold.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'STORY',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: AppTypeScale.title,
                fontWeight: FontWeight.w500,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
              width: AppSizes.iconMd,
              height: AppSizes.iconMd,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
