import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Reusable text field based on the search UI rule:
/// input is a supporting element, so it uses a pale surface, 1px border,
/// and never uses the brand color unless focused.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.minHeight = 46,
    this.semanticLabel,
    this.focusedBorderColor,
    this.validator,
    this.autovalidateMode,
    this.errorText,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final double minHeight;
  final String? semanticLabel;
  final Color? focusedBorderColor;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final String? errorText;

  static const Color _fieldFill = Color(0xFFFAFAFB);
  static const Color _fieldBorder = Color(0xFFD4D4DA);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    final normalBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: _fieldBorder, width: 1),
    );

    final field = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        onTap: onTap,
        readOnly: readOnly,
        enabled: enabled,
        autofocus: autofocus,
        obscureText: obscureText,
        maxLines: maxLines,
        maxLength: maxLength,
        buildCounter: maxLength != null
            ? (_, {required currentLength, required isFocused, maxLength}) =>
                null
            : null,
        validator: validator,
        autovalidateMode: autovalidateMode,
        style: AppTextStyles.bodyMedium.copyWith(
          color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
          height: 1.25,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: enabled
              ? _fieldFill
              : Color.alphaBlend(
                  AppColors.surfaceVariant.withValues(alpha: 0.76),
                  AppColors.surface,
                ),
          labelText: labelText,
          hintText: hintText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          labelStyle: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textTertiary,
            height: 1.25,
          ),
          errorText: errorText,
          errorStyle: AppTextStyles.caption.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
          border: normalBorder,
          enabledBorder: normalBorder,
          disabledBorder: normalBorder,
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(
              color: focusedBorderColor ?? AppColors.accentPrimary,
              width: 1.2,
            ),
          ),
        ),
      ),
    );

    if (semanticLabel == null || semanticLabel!.trim().isEmpty) {
      return field;
    }

    return Semantics(label: semanticLabel, textField: true, child: field);
  }
}
