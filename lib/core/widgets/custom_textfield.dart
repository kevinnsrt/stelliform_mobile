import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stelliform_mobile/app/config/app_colors.dart';

/// Standardized labeled text field for forms across Dobrak Mandiri ERP.
class CustomTextField extends StatelessWidget {
  /// Creates a [CustomTextField].
  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.enabled = true,
    this.readOnly = false,
  });

  /// Controller managing the field text.
  final TextEditingController? controller;

  /// Optional label displayed above the field.
  final String? label;

  /// Placeholder hint inside the input box.
  final String? hintText;

  /// Optional leading icon inside the input decoration.
  final IconData? prefixIcon;

  /// Optional trailing widget (e.g., password visibility toggle).
  final Widget? suffixIcon;

  /// Whether input characters are masked.
  final bool obscureText;

  /// Keyboard layout hint.
  final TextInputType? keyboardType;

  /// Soft keyboard action button.
  final TextInputAction? textInputAction;

  /// Maximum visible text lines.
  final int maxLines;

  /// Form validation callback.
  final String? Function(String?)? validator;

  /// Change listener callback.
  final ValueChanged<String>? onChanged;

  /// Submit action callback.
  final ValueChanged<String>? onFieldSubmitted;

  /// Optional text input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Whether the input accepts user interaction.
  final bool enabled;

  /// Whether the input is read-only.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          inputFormatters: inputFormatters,
          enabled: enabled,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 19, color: palette.textSecondary)
                : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
