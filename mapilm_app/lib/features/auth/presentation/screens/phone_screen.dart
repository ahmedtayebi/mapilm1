import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_notifier.dart';
import '../widgets/auth_card_widget.dart';
import '../widgets/auth_header_widget.dart';
import '../widgets/premium_button_widget.dart';
import '../widgets/premium_input_widget.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();

  _CountryEntry _country = _countries.firstWhere((c) => c.code == '+213');
  bool _hasError = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;

    ref.listen<AuthState>(authNotifierProvider, (_, state) {
      if (state is OtpSent) {
        context.push(
          AppRoutes.otp,
          extra: '${_country.code}${_phoneController.text.trim()}',
        );
      }
      if (state is AuthSuccess) {
        // Android instant-verify: skip OTP screen entirely.
        if (state.user.isProfileComplete) {
          context.go(AppRoutes.home);
        } else {
          context.go(AppRoutes.setupProfile);
        }
      }
      if (state is AuthError) {
        setState(() => _hasError = true);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _hasError = false);
        });
        _showError(state.message);
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Gradient header with wave + phone icon
            AuthHeaderWidget(
              gradientHeight: MediaQuery.of(context).size.height * 0.36,
              icon: const Icon(
                Icons.phone_android_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: -0.1, end: 0, duration: 500.ms),
            // Scrollable form area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Card floats over icon bottom
                    const SizedBox(height: 12),
                    AuthCardWidget(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCardHeader(),
                            const SizedBox(height: 24),
                            _buildCountryPicker(),
                            const SizedBox(height: 16),
                            _buildPhoneInput(),
                            const SizedBox(height: 10),
                            _buildHint(),
                            const SizedBox(height: 28),
                            PremiumButtonWidget(
                              text: AppStrings.sendOtp,
                              onPressed: _submit,
                              isLoading: isLoading,
                              triggerError: _hasError,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أدخل رقم هاتفك',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: AppColors.grey900,
          ),
        ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.1),
        const SizedBox(height: 6),
        Text(
          'سنرسل لك رمز التحقق',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.grey500,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildCountryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الدولة',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.grey600,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        _PremiumCountryPicker(
          selected: _country,
          onChanged: (c) => setState(() => _country = c),
        ),
      ],
    ).animate().fadeIn(delay: 440.ms).slideY(begin: 0.1);
  }

  Widget _buildPhoneInput() {
    return PremiumInputWidget(
      label: 'رقم الهاتف',
      controller: _phoneController,
      focusNode: _phoneFocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      textDirection: TextDirection.ltr,
      hintText: '05XX XXX XXXX',
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onFieldSubmitted: (_) => _submit(),
      validator: (v) {
        if (v == null || v.isEmpty) return 'أدخل رقم الهاتف';
        if (v.length < 9) return 'رقم الهاتف قصير جداً';
        return null;
      },
      prefixWidget: Text(
        _country.code,
        style: AppTypography.bodyLarge.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          fontSize: 16,
        ),
        textDirection: TextDirection.ltr,
      ),
    ).animate().fadeIn(delay: 470.ms).slideY(begin: 0.1);
  }

  Widget _buildHint() {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 14,
          color: AppColors.grey400,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            AppStrings.phoneSubtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.grey400,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final phone = '${_country.code}${_phoneController.text.trim()}';
      ref.read(authNotifierProvider.notifier).requestOtp(phone);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontFamily: 'Tajawal'))),
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

// ── Country entry model ────────────────────────────────────────────────────

class _CountryEntry {
  const _CountryEntry({
    required this.name,
    required this.code,
    required this.flag,
  });
  final String name;
  final String code;
  final String flag;
}

const _countries = <_CountryEntry>[
  _CountryEntry(name: 'الجزائر', code: '+213', flag: '🇩🇿'),
  _CountryEntry(name: 'المملكة العربية السعودية', code: '+966', flag: '🇸🇦'),
  _CountryEntry(name: 'الإمارات', code: '+971', flag: '🇦🇪'),
  _CountryEntry(name: 'مصر', code: '+20', flag: '🇪🇬'),
  _CountryEntry(name: 'الكويت', code: '+965', flag: '🇰🇼'),
  _CountryEntry(name: 'البحرين', code: '+973', flag: '🇧🇭'),
  _CountryEntry(name: 'عُمان', code: '+968', flag: '🇴🇲'),
  _CountryEntry(name: 'قطر', code: '+974', flag: '🇶🇦'),
  _CountryEntry(name: 'المغرب', code: '+212', flag: '🇲🇦'),
  _CountryEntry(name: 'تونس', code: '+216', flag: '🇹🇳'),
];

// ── Premium country picker ─────────────────────────────────────────────────

class _PremiumCountryPicker extends StatelessWidget {
  const _PremiumCountryPicker({
    required this.selected,
    required this.onChanged,
  });
  final _CountryEntry selected;
  final ValueChanged<_CountryEntry> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CountryEntry>(
      initialValue: selected,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      color: Colors.white,
      itemBuilder: (_) => _countries.map((c) {
        return PopupMenuItem<_CountryEntry>(
          value: c,
          child: Row(
            children: [
              Text(c.flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Text(
                c.name,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                c.code,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Text(selected.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              selected.name,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${selected.code})',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.ltr,
            ),
            const Spacer(),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.grey400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
