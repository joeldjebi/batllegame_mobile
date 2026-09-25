import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/tokens.dart';

/// Labelled text field: visible label above, error under the field (never only a placeholder).
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.error,
    this.helper,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscure = false,
    this.inputFormatters,
    this.onSubmitted,
    this.onChanged,
    this.prefix,
    this.autofocus = false,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.style,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? error;
  final String? helper;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscure;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? prefix;
  final bool autofocus;
  final int? maxLength;
  final TextAlign textAlign;
  final TextStyle? style;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: context.text.labelMedium?.copyWith(color: c.textMuted)),
        const SizedBox(height: Space.sm),
        TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          obscureText: _hidden,
          inputFormatters: widget.inputFormatters,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          autofocus: widget.autofocus,
          maxLength: widget.maxLength,
          textAlign: widget.textAlign,
          style: widget.style ?? context.text.bodyLarge,
          cursorColor: c.primary,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.error,
            counterText: '',
            prefixIcon: widget.prefix,
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                    icon: Icon(_hidden ? AppIcons.show : AppIcons.hide, size: 20, color: c.textMuted),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
        if (widget.helper != null && widget.error == null) ...[
          const SizedBox(height: Space.xs),
          Text(widget.helper!, style: context.text.bodySmall),
        ],
      ],
    );
  }
}
