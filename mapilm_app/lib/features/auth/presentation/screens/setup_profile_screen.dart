import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_notifier.dart';
import '../widgets/auth_card_widget.dart';
import '../widgets/auth_header_widget.dart';
import '../widgets/premium_button_widget.dart';
import '../widgets/premium_input_widget.dart';

class SetupProfileScreen extends ConsumerStatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  ConsumerState<SetupProfileScreen> createState() =>
      _SetupProfileScreenState();
}

class _SetupProfileScreenState extends ConsumerState<SetupProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _statusController = TextEditingController();
  final _nameFocus = FocusNode();
  final _statusFocus = FocusNode();

  late final AnimationController _ringController;
  late final Animation<double> _ringAnim;

  File? _avatarFile;
  bool _isUploadingAvatar = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _ringAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ringController.dispose();
    _nameController.dispose();
    _statusController.dispose();
    _nameFocus.dispose();
    _statusFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;

    ref.listen<AuthState>(authNotifierProvider, (_, state) {
      if (state is AuthSuccess) context.go(AppRoutes.home);
      if (state is AuthError) {
        setState(() => _hasError = true);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _hasError = false);
        });
        _showErrorSnack(state.message);
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Gradient header with camera/person icon
            AuthHeaderWidget(
              gradientHeight: MediaQuery.of(context).size.height * 0.34,
              icon: const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: -0.08, end: 0, duration: 500.ms),
            // Scrollable form
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    AuthCardWidget(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCardHeader(),
                            const SizedBox(height: 28),
                            _buildAvatarPicker(),
                            const SizedBox(height: 32),
                            _buildNameField(),
                            const SizedBox(height: 18),
                            _buildStatusField(),
                            const SizedBox(height: 32),
                            PremiumButtonWidget(
                              text: 'ابدأ المحادثة',
                              onPressed: _submit,
                              isLoading: isLoading,
                              triggerError: _hasError,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card Header ───────────────────────────────────────────────────────────

  Widget _buildCardHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أنشئ ملفك الشخصي',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: AppColors.grey900,
          ),
        ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.1),
        const SizedBox(height: 6),
        Text(
          'أخبرنا من أنت',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.grey500,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  // ── Avatar Picker ─────────────────────────────────────────────────────────

  Widget _buildAvatarPicker() {
    return Center(
      child: GestureDetector(
        onTap: _showAvatarOptions,
        child: AnimatedBuilder(
          animation: _ringAnim,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Animated outer ring
                Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(
                        0.3 + _ringAnim.value * 0.4,
                      ),
                      width: 2.5,
                    ),
                  ),
                ),
                // Inner ring (dashed look via opacity pulse)
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(
                        0.15 + _ringAnim.value * 0.15,
                      ),
                      width: 1.5,
                    ),
                  ),
                ),
                // Avatar circle
                child!,
              ],
            );
          },
          child: _buildAvatarCircle(),
        ),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.8, 0.8),
          delay: 380.ms,
          duration: 600.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(delay: 380.ms);
  }

  Widget _buildAvatarCircle() {
    return Stack(
      children: [
        // Main avatar
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _avatarFile == null
                ? const LinearGradient(
                    colors: [AppColors.primaryLighter, Color(0xFFDDE3FE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 2,
            ),
            image: _avatarFile != null
                ? DecorationImage(
                    image: FileImage(_avatarFile!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _avatarFile == null
              ? const Icon(
                  Icons.person_rounded,
                  size: 52,
                  color: AppColors.primary,
                )
              : null,
        ),
        // Upload progress overlay
        if (_isUploadingAvatar)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.4),
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
          ),
        // Camera button
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 17,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // ── Form fields ───────────────────────────────────────────────────────────

  Widget _buildNameField() {
    return PremiumInputWidget(
      label: AppStrings.yourName,
      controller: _nameController,
      focusNode: _nameFocus,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      hintText: 'أدخل اسمك الكامل',
      maxLength: 50,
      showCounter: true,
      onFieldSubmitted: (_) => _statusFocus.requestFocus(),
      inputFormatters: [LengthLimitingTextInputFormatter(50)],
      prefixWidget: const Icon(
        Icons.person_outline_rounded,
        size: 20,
        color: AppColors.grey400,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'الاسم مطلوب';
        if (v.trim().length < 2) return 'الاسم قصير جداً (٢ أحرف على الأقل)';
        return null;
      },
    ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1);
  }

  Widget _buildStatusField() {
    return PremiumInputWidget(
      label: 'ماذا تفعل الآن؟ (اختياري)',
      controller: _statusController,
      focusNode: _statusFocus,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      hintText: 'أضف حالتك...',
      maxLength: 100,
      showCounter: true,
      inputFormatters: [LengthLimitingTextInputFormatter(100)],
      prefixWidget: const Icon(
        Icons.mood_rounded,
        size: 20,
        color: AppColors.grey400,
      ),
    ).animate().fadeIn(delay: 490.ms).slideY(begin: 0.1);
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _showAvatarOptions() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (ctx) => _AvatarBottomSheet(
        onCamera: () {
          Navigator.pop(ctx);
          _pickImage(ImageSource.camera);
        },
        onGallery: () {
          Navigator.pop(ctx);
          _pickImage(ImageSource.gallery);
        },
        hasImage: _avatarFile != null,
        onRemove: _avatarFile != null
            ? () {
                Navigator.pop(ctx);
                setState(() => _avatarFile = null);
              }
            : null,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (xFile != null && mounted) {
        setState(() => _avatarFile = File(xFile.path));
      }
    } catch (_) {
      // permission denied or cancelled
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ref.read(authNotifierProvider.notifier).setupProfile(
            name: _nameController.text.trim(),
            bio: _statusController.text.trim().isEmpty
                ? null
                : _statusController.text.trim(),
            avatarPath: _avatarFile?.path,
          );
    }
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

// ── Avatar Bottom Sheet ────────────────────────────────────────────────────

class _AvatarBottomSheet extends StatelessWidget {
  const _AvatarBottomSheet({
    required this.onCamera,
    required this.onGallery,
    required this.hasImage,
    this.onRemove,
  });

  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final bool hasImage;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'اختر صورة الملف الشخصي',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.grey900,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SheetOption(
            icon: Icons.camera_alt_rounded,
            label: 'التقاط صورة',
            color: AppColors.primary,
            onTap: onCamera,
          ),
          _SheetOption(
            icon: Icons.photo_library_rounded,
            label: 'اختيار من المعرض',
            color: const Color(0xFF7C3AED),
            onTap: onGallery,
          ),
          if (onRemove != null)
            _SheetOption(
              icon: Icons.delete_outline_rounded,
              label: 'إزالة الصورة',
              color: AppColors.error,
              onTap: onRemove!,
            ),
          const SizedBox(height: 8),
        ],
      ),
    )
        .animate()
        .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic, duration: 300.ms)
        .fadeIn(duration: 250.ms);
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey800,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.grey400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
