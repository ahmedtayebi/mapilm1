import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

class PremiumInputWidget extends StatefulWidget {
  const PremiumInputWidget({
    super.key,
    required this.label,
    required this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.maxLength,
    this.showCounter = false,
    this.prefixWidget,
    this.suffixWidget,
    this.textDirection,
    this.hintText,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool showCounter;
  final Widget? prefixWidget;
  final Widget? suffixWidget;
  final TextDirection? textDirection;
  final String? hintText;
  final int maxLines;
  final bool enabled;
  final bool autofocus;

  @override
  State<PremiumInputWidget> createState() => _PremiumInputWidgetState();
}

class _PremiumInputWidgetState extends State<PremiumInputWidget>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode;
  late final AnimationController _borderAnim;
  late final Animation<double> _progress;

  bool _isFocused = false;
  bool _isDirty = false;
  String? _errorText;
  bool _isOwningFocusNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _isOwningFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }
    _borderAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _progress = CurvedAnimation(parent: _borderAnim, curve: Curves.easeOut);
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    if (hasFocus != _isFocused) {
      setState(() => _isFocused = hasFocus);
      if (hasFocus) {
        _borderAnim.forward();
      } else {
        _isDirty = true;
        _borderAnim.reverse();
        _validate();
      }
    }
  }

  void _onTextChanged() {
    if (_isDirty) _validate();
  }

  void _validate() {
    if (widget.validator == null) return;
    final err = widget.validator!(widget.controller.text);
    if (err != _errorText) {
      setState(() => _errorText = err);
    }
  }

  bool get _hasError => _errorText != null && _isDirty;

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    if (_isOwningFocusNode) _focusNode.dispose();
    _borderAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: AppTypography.labelLarge.copyWith(
            color: _hasError
                ? AppColors.error
                : _isFocused
                    ? AppColors.primary
                    : AppColors.grey600,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          child: Text(widget.label),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _progress,
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _hasError
                  ? AppColors.errorLight.withOpacity(0.4)
                  : _isFocused
                      ? AppColors.primaryLighter.withOpacity(0.25)
                      : AppColors.grey50,
              border: Border.all(
                color: _hasError
                    ? AppColors.error.withOpacity(0.7)
                    : Color.lerp(
                        AppColors.border,
                        AppColors.primary,
                        _progress.value,
                      )!,
                width: _hasError
                    ? 1.5
                    : 1.5 + (_progress.value * 0.5),
              ),
              boxShadow: _isFocused && !_hasError
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            // Real validator for Form.validate() integration
            validator: widget.validator,
            onFieldSubmitted: widget.onFieldSubmitted,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            maxLines: widget.maxLines,
            enabled: widget.enabled,
            textDirection: widget.textDirection,
            autofocus: widget.autofocus,
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: AppTypography.bodyLarge.copyWith(
                color: AppColors.grey400,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: widget.prefixWidget != null
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 14,
                        end: 8,
                      ),
                      child: widget.prefixWidget,
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(minHeight: 24),
              suffixIcon: widget.suffixWidget != null
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 8,
                        end: 14,
                      ),
                      child: widget.suffixWidget,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minHeight: 24),
              // Hide the built-in error text — we show it below the container
              errorStyle: const TextStyle(
                height: 0,
                fontSize: 0,
                color: Colors.transparent,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              counterText: widget.showCounter ? null : '',
              filled: false,
            ),
          ),
        ),
        // Error message rendered below the border container
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 13,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _errorText!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
