import 'package:flutter/material.dart';
import '../responsive_helper.dart';
import 'transitions.dart';

/// Responsive Form Field
class ResponsiveTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final EdgeInsets? padding;
  final double? borderRadius;
  final bool autofocus;

  const ResponsiveTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.padding,
    this.borderRadius,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final responsivePadding = padding ??
        ResponsiveHelper.getResponsivePadding(
          context,
          vertical: 8,
        );
    final responsiveRadius = borderRadius ??
        ResponsiveHelper.getResponsiveRadius(context, 8);

    return Padding(
      padding: responsivePadding,
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        enabled: enabled,
        autofocus: autofocus,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(responsiveRadius),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(responsiveRadius),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(responsiveRadius),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(responsiveRadius),
            borderSide: const BorderSide(color: Colors.red),
          ),
          contentPadding: ResponsiveHelper.getResponsivePadding(
            context,
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: TextStyle(
          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
        ),
      ),
    );
  }
}

/// Responsive Form - Adaptive form layout
class ResponsiveForm extends StatelessWidget {
  final GlobalKey<FormState>? formKey;
  final List<Widget> fields;
  final List<Widget>? actions;
  final EdgeInsets? padding;
  final bool autoValidate;
  final VoidCallback? onSubmit;
  final Widget? submitButton;

  const ResponsiveForm({
    super.key,
    this.formKey,
    required this.fields,
    this.actions,
    this.padding,
    this.autoValidate = false,
    this.onSubmit,
    this.submitButton,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = ResponsiveHelper.isSmallDevice(context);
    final responsivePadding = padding ??
        ResponsiveHelper.getResponsivePadding(context, all: 16);

    return Form(
      key: formKey,
      autovalidateMode: autoValidate
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Padding(
        padding: responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fields - stack on small, can be side-by-side on larger
            if (isSmall)
              ...fields
            else
              Wrap(
                spacing: ResponsiveHelper.getResponsiveWidth(context, 16),
                runSpacing: ResponsiveHelper.getResponsiveHeight(context, 16),
                children: fields.map((field) {
                  return SizedBox(
                    width: ResponsiveHelper.getResponsiveWidth(context, 300),
                    child: field,
                  );
                }).toList(),
              ),
            if (submitButton != null || actions != null) ...[
              ResponsiveHelper.getResponsiveSpacing(context, 24),
              if (submitButton != null)
                FadeTransitionWidget(
                  child: submitButton!,
                ),
              if (actions != null)
                Wrap(
                  spacing: ResponsiveHelper.getResponsiveWidth(context, 12),
                  children: actions!,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
