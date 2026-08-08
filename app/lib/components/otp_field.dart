import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.hasError = false,
    this.length = 6,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final bool hasError;
  final int length;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = widget.controller.text;

    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var index = 0; index < widget.length; index++)
              AnimatedContainer(
                duration: AppMotion.fast,
                width: 46,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(
                    color: widget.hasError
                        ? colors.danger
                        : index == value.length
                        ? colors.accent
                        : colors.border,
                    width: index == value.length ? 1.6 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  index < value.length ? value[index] : '',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.title,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (text) {
                setState(() {});
                if (text.length == widget.length) widget.onCompleted(text);
              },
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
        ),
      ],
    );
  }
}
