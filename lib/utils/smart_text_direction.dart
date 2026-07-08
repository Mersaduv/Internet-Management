import 'package:flutter/material.dart';

/// Detects RTL when text contains Arabic / Persian / Hebrew script.
TextDirection detectInputTextDirection(String text) {
  if (text.trim().isEmpty) {
    return TextDirection.ltr;
  }

  const rtlPattern =
      r'[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]';
  if (RegExp(rtlPattern).hasMatch(text)) {
    return TextDirection.rtl;
  }

  return TextDirection.ltr;
}

TextAlign textAlignForDirection(TextDirection direction) {
  return direction == TextDirection.rtl ? TextAlign.right : TextAlign.left;
}

/// TextField with LTR for Latin and RTL for Persian/Arabic content.
class SmartDirectionTextField extends StatefulWidget {
  const SmartDirectionTextField({
    super.key,
    required this.controller,
    this.decoration,
    this.obscureText = false,
    this.enabled = true,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.style,
  });

  final TextEditingController controller;
  final InputDecoration? decoration;
  final bool obscureText;
  final bool enabled;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? style;

  @override
  State<SmartDirectionTextField> createState() => _SmartDirectionTextFieldState();
}

class _SmartDirectionTextFieldState extends State<SmartDirectionTextField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant SmartDirectionTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final direction = detectInputTextDirection(widget.controller.text);

    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: widget.style,
      textDirection: direction,
      textAlign: textAlignForDirection(direction),
      decoration: widget.decoration,
    );
  }
}

/// TextFormField with smart text direction for mixed Persian/English input.
class SmartDirectionTextFormField extends StatefulWidget {
  const SmartDirectionTextFormField({
    super.key,
    required this.controller,
    this.decoration,
    this.validator,
    this.obscureText = false,
    this.enabled = true,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onFieldSubmitted,
    this.style,
  });

  final TextEditingController controller;
  final InputDecoration? decoration;
  final String? Function(String?)? validator;
  final bool obscureText;
  final bool enabled;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextStyle? style;

  @override
  State<SmartDirectionTextFormField> createState() =>
      _SmartDirectionTextFormFieldState();
}

class _SmartDirectionTextFormFieldState extends State<SmartDirectionTextFormField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant SmartDirectionTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final direction = detectInputTextDirection(widget.controller.text);

    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      style: widget.style,
      textDirection: direction,
      textAlign: textAlignForDirection(direction),
      decoration: widget.decoration,
    );
  }
}
