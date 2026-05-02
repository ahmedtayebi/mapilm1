import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_notifier.dart';
import '../widgets/premium_button_widget.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});
  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  static const int _kDigits = 6;

  final List<TextEditingController> _controllers =
      List.generate(_kDigits, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_kDigits, (_) => FocusNode());

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;

  int _secondsLeft = 60;
  Timer? _countdownTimer;
  bool _isError = false;
  bool _isVerifying = false;

  // Captured at first build / on every fresh OtpSent so a wrong OTP (which
  // transitions the notifier to AuthError) doesn't lose the verificationId.
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    // Pull the verificationId from the OtpSent state we navigated under.
    final state = ref.read(authNotifierProvider);
    if (state is OtpSent) {
      _verificationId = state.verificationId;
    }

    _startCountdown();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _shakeController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0) {
        if (mounted) setState(() => _secondsLeft--);
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  String get _currentOtp =>
      _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    setState(() {}); // trigger rebuild so box colors update
    if (value.isNotEmpty) {
      if (index < _kDigits - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_currentOtp.length == _kDigits && !_isVerifying) {
      Future.microtask(_verify);
    }
  }

  void _verify() {
    if (_currentOtp.length < _kDigits) return;
    final id = _verificationId;
    if (id == null) {
      // No verificationId in flight (rare — direct deep-link or hot-restart).
      _showErrorSnack('انتهت الجلسة، اطلب رمزاً جديداً.');
      return;
    }
    setState(() => _isVerifying = true);
    ref.read(authNotifierProvider.notifier).confirmOtp(
          verificationId: id,
          otp: _currentOtp,
        );
  }

  void _clearFields() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() => _isVerifying = false);
  }

  void _triggerErrorAnimation() {
    setState(() => _isError = true);
    _shakeController.forward(from: 0).then((_) {
      if (mounted) setState(() => _isError = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;

    ref.listen<AuthState>(authNotifierProvider, (_, state) {
      if (state is OtpSent) {
        // Resend produced a fresh verificationId — capture it so subsequent
        // verifies use the new code.
        _verificationId = state.verificationId;
      }
      if (state is AuthSuccess) {
        if (state.user.isProfileComplete) {
          context.go(AppRoutes.home);
        } else {
          context.go(AppRoutes.setupProfile);
        }
      }
      if (state is AuthError) {
        _triggerErrorAnimation();
        _clearFields();
        _showErrorSnack(state.message);
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 48),
                    _buildOtpBoxes(isLoading),
                    const SizedBox(height: 32),
                    _buildResendSection(),
                    const SizedBox(height: 48),
                    PremiumButtonWidget(
                      text: 'تحقق',
                      onPressed: _verify,
                      isLoading: isLoading,
                      triggerError: _isError,
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Back button
          Material(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => context.pop(),
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.grey700,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Step indicator
          _StepIndicator(current: 2, total: 3),
          const Spacer(),
          const SizedBox(width: 42), // balance
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'رمز التحقق',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.grey900,
          ),
        ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.grey500,
              height: 1.6,
            ),
            children: [
              const TextSpan(text: 'أدخل الرمز المرسل إلى\n'),
              TextSpan(
                text: widget.phone,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          textDirection: TextDirection.rtl,
        ).animate().fadeIn(delay: 180.ms),
      ],
    );
  }

  Widget _buildOtpBoxes(bool isLoading) {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeAnim.value, 0),
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          _kDigits,
          (i) => _buildOtpBox(i, isLoading),
        ),
      ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15),
    );
  }

  Widget _buildOtpBox(int index, bool isLoading) {
    final filled = _controllers[index].text.isNotEmpty;
    return _OtpBox(
      controller: _controllers[index],
      focusNode: _focusNodes[index],
      isError: _isError,
      isFilled: filled,
      isLoading: isLoading,
      index: index,
      onChanged: (v) => _onDigitChanged(index, v),
    );
  }

  Widget _buildResendSection() {
    return Center(
      child: _secondsLeft > 0
          ? _CountdownTimer(
              secondsLeft: _secondsLeft,
              total: 60,
            )
          : GestureDetector(
              onTap: () {
                ref
                    .read(authNotifierProvider.notifier)
                    .requestOtp(widget.phone);
                _startCountdown();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'إعادة إرسال الرمز',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).scale(
                begin: const Offset(0.9, 0.9),
                curve: Curves.easeOutBack,
              ),
    );
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Tajawal'),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ── OTP Box ────────────────────────────────────────────────────────────────

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.isError,
    required this.isFilled,
    required this.isLoading,
    required this.index,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isError;
  final bool isFilled;
  final bool isLoading;
  final int index;
  final ValueChanged<String> onChanged;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut),
    );
    widget.focusNode.addListener(_onFocus);
  }

  void _onFocus() {
    final focused = widget.focusNode.hasFocus;
    setState(() => _isFocused = focused);
    if (focused) {
      _scaleCtrl.forward();
    } else {
      _scaleCtrl.reverse();
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_OtpBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFilled && !oldWidget.isFilled) {
      _scaleCtrl.forward().then((_) => _scaleCtrl.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 58,
        decoration: BoxDecoration(
          color: widget.isError
              ? AppColors.errorLight
              : widget.isFilled
                  ? AppColors.primary
                  : _isFocused
                      ? AppColors.primaryLighter
                      : AppColors.grey100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isError
                ? AppColors.error
                : _isFocused
                    ? AppColors.primary
                    : widget.isFilled
                        ? AppColors.primary
                        : AppColors.border,
            width: _isFocused ? 2.0 : 1.5,
          ),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          enabled: !widget.isLoading,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textDirection: TextDirection.ltr,
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: widget.isFilled ? Colors.white : AppColors.onSurface,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            filled: false,
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

// ── Countdown timer ────────────────────────────────────────────────────────

class _CountdownTimer extends StatelessWidget {
  const _CountdownTimer({required this.secondsLeft, required this.total});
  final int secondsLeft;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = secondsLeft / total;
    final minutes = secondsLeft ~/ 60;
    final seconds = secondsLeft % 60;
    final label =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3.5,
                  backgroundColor: AppColors.grey200,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'إعادة الإرسال بعد $label',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.grey500,
          ),
        ),
      ],
    );
  }
}

// ── Step indicator ─────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLighter,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(total, (i) {
          final isActive = i + 1 == current;
          final isDone = i + 1 < current;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isActive ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isDone || isActive
                      ? AppColors.primary
                      : AppColors.grey300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (i < total - 1) const SizedBox(width: 4),
            ],
          );
        }),
      ),
    );
  }
}
