import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.obscureText = false,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final bool obscureText;
  final bool autofocus;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: AppTypeScale.label,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          obscureText: obscureText,
          autofocus: autofocus,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: !obscureText,
          style: TextStyle(color: colors.textPrimary, fontSize: AppTypeScale.body),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.textMuted),
            filled: true,
            fillColor: colors.surface,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            enabledBorder: _border(hasError ? colors.danger : colors.border),
            focusedBorder: _border(hasError ? colors.danger : colors.accent, width: 1.6),
            border: _border(colors.border),
          ),
        ),
        if (hasError || (helperText != null && helperText!.isNotEmpty)) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasError ? errorText! : helperText!,
            style: TextStyle(
              color: hasError ? colors.danger : colors.textMuted,
              fontSize: AppTypeScale.caption,
            ),
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide(color: color, width: width),
  );
}
