import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class AppTextField extends StatefulWidget {
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
    this.prefixIcon,
    this.helperIcon,
    this.maxLines = 1,
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
  final IconData? prefixIcon;
  final IconData? helperIcon;
  final int maxLines;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _isRevealed = false;

  Widget _revealButton(BuildContext context) {
    final colors = context.colors;

    return IconButton(
      icon: Icon(
        _isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: colors.textMuted,
        size: 20,
      ),
      tooltip: _isRevealed ? 'Hide' : 'Show',
      onPressed: () => setState(() => _isRevealed = !_isRevealed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final suffix =
        widget.suffix ?? (widget.obscureText ? _revealButton(context) : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: AppTypeScale.label,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: widget.controller,
          obscureText: widget.obscureText && !_isRevealed,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          autofocus: widget.autofocus,
          textInputAction: widget.textInputAction,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          autocorrect: false,
          enableSuggestions: !widget.obscureText,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: AppTypeScale.body,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.lg,
                      right: AppSpacing.md,
                    ),
                    child: Icon(
                      widget.prefixIcon,
                      size: AppSizes.iconMd,
                      color: colors.textMuted,
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            hintStyle: TextStyle(color: colors.textMuted),
            filled: true,
            fillColor: colors.surface,
            suffixIcon: suffix,
            contentPadding: EdgeInsets.only(
              left: widget.prefixIcon == null ? AppSpacing.lg : 0,
              right: AppSpacing.lg,
              top: 14,
              bottom: 14,
            ),
            enabledBorder: _border(hasError ? colors.danger : colors.border),
            focusedBorder: _border(
              hasError ? colors.danger : colors.accent,
              width: 1.6,
            ),
            border: _border(colors.border),
          ),
        ),
        if (hasError ||
            (widget.helperText != null && widget.helperText!.isNotEmpty)) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.helperIcon != null && !hasError) ...[
                Icon(
                  widget.helperIcon,
                  size: AppSizes.iconSm,
                  color: colors.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  hasError ? widget.errorText! : widget.helperText!,
                  style: TextStyle(
                    color: hasError ? colors.danger : colors.textMuted,
                    fontSize: AppTypeScale.caption,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = AppSizes.hairline}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );
}
