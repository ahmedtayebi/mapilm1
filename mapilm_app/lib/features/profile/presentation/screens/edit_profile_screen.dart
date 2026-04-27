import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.currentUser});
  final Map<String, dynamic> currentUser;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  String? _pickedImagePath;
  bool _isSaving = false;

  bool get _hasChanges {
    final origName = widget.currentUser['name'] as String? ?? '';
    final origBio = widget.currentUser['bio'] as String? ?? '';
    return _nameCtrl.text != origName ||
        _bioCtrl.text != origBio ||
        _pickedImagePath != null;
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.currentUser['name'] as String? ?? '');
    _bioCtrl =
        TextEditingController(text: widget.currentUser['bio'] as String? ?? '');
    _nameCtrl.addListener(() => setState(() {}));
    _bioCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    return ConfirmationDialog.show(
      context,
      title: 'تجاهل التغييرات؟',
      message: 'لديك تغييرات غير محفوظة. هل تريد تجاهلها؟',
      confirmLabel: 'تجاهل',
      isDestructive: true,
      icon: Icons.warning_amber_rounded,
    );
  }

  void _pickImage() {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'تغيير الصورة الشخصية',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey900,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _PickerOption(
              icon: Icons.camera_alt_rounded,
              label: 'الكاميرا',
              onTap: () async {
                Navigator.pop(context);
                final img = await picker.pickImage(
                    source: ImageSource.camera, imageQuality: 85);
                if (img != null) setState(() => _pickedImagePath = img.path);
              },
            ),
            _PickerOption(
              icon: Icons.photo_library_rounded,
              label: 'معرض الصور',
              onTap: () async {
                Navigator.pop(context);
                final img = await picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 85);
                if (img != null) setState(() => _pickedImagePath = img.path);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_hasChanges || _isSaving) return;
    setState(() => _isSaving = true);
    final ok = await ref.read(meProvider.notifier).updateProfile(
          name: _nameCtrl.text.trim(),
          bio: _bioCtrl.text.trim(),
          avatarPath: _pickedImagePath,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('فشل الحفظ، حاول مجدداً'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final should = await _onWillPop();
        if (should && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.white,
          title: const Text(
            'تعديل الملف الشخصي',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.grey900,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.grey700),
            onPressed: () async {
              final should = await _onWillPop();
              if (should && context.mounted) Navigator.pop(context);
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      )
                    : TextButton(
                        onPressed: _hasChanges ? _save : null,
                        style: TextButton.styleFrom(
                          backgroundColor: _hasChanges
                              ? AppColors.primary
                              : AppColors.grey100,
                          foregroundColor: _hasChanges
                              ? Colors.white
                              : AppColors.grey400,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          minimumSize: const Size(70, 36),
                        ),
                        child: const Text(
                          'حفظ',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            children: [
              // Avatar section
              _AvatarSection(
                currentUrl: widget.currentUser['avatar_url'] as String?,
                name: widget.currentUser['name'] as String?,
                pickedPath: _pickedImagePath,
                onTap: _pickImage,
              ).animate().scale(
                    begin: const Offset(0.88, 0.88),
                    duration: 450.ms,
                    curve: Curves.easeOutBack,
                  ).fadeIn(),

              const SizedBox(height: 36),

              // Name field
              _PremiumInputField(
                controller: _nameCtrl,
                label: 'الاسم الكامل',
                hint: 'أدخل اسمك الكامل',
                icon: Icons.person_outline_rounded,
                maxLength: 50,
              ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.12),

              const SizedBox(height: 14),

              // Bio / Status field
              _PremiumInputField(
                controller: _bioCtrl,
                label: 'الحالة',
                hint: 'اكتب حالتك...',
                icon: Icons.mood_rounded,
                maxLength: 120,
                maxLines: 3,
              ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.12),

              const SizedBox(height: 44),

              // Save button
              _GradientSaveButton(
                onTap: _isSaving ? null : _save,
                isLoading: _isSaving,
                isEnabled: _hasChanges,
              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Avatar Section ─────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    this.currentUrl,
    this.name,
    this.pickedPath,
    required this.onTap,
  });
  final String? currentUrl;
  final String? name;
  final String? pickedPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (pickedPath != null) {
      imageProvider = FileImage(File(pickedPath!));
    } else if (currentUrl != null && currentUrl!.isNotEmpty) {
      imageProvider = NetworkImage(currentUrl!);
    }

    final initials = (name?.trim().isNotEmpty == true) ? name![0] : '?';

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing gradient ring
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2038F5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.38),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .custom(
                    duration: 2000.ms,
                    builder: (_, value, child) => Transform.scale(
                      scale: 1.0 + value * 0.04,
                      child: child,
                    ),
                  ),
              // Avatar circle
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.grey300,
                  image: imageProvider != null
                      ? DecorationImage(
                          image: imageProvider, fit: BoxFit.cover)
                      : null,
                ),
                child: imageProvider == null
                    ? Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
              // Camera overlay badge
              Positioned(
                bottom: 4,
                right: 4,
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
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'تغيير الصورة الشخصية',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Premium Input Field ────────────────────────────────────────────────────

class _PremiumInputField extends StatefulWidget {
  const _PremiumInputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.maxLength,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLength;
  final int maxLines;

  @override
  State<_PremiumInputField> createState() => _PremiumInputFieldState();
}

class _PremiumInputFieldState extends State<_PremiumInputField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final charCount = widget.controller.text.length;
    final nearLimit = charCount > widget.maxLength * 0.85;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? AppColors.primary : AppColors.border,
          width: _focused ? 2 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                EdgeInsets.only(top: widget.maxLines > 1 ? 3 : 0),
            child: Icon(
              widget.icon,
              size: 20,
              color: _focused ? AppColors.primary : AppColors.grey400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _focused ? AppColors.primary : AppColors.grey400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  maxLines: widget.maxLines,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey900,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: const TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.grey400,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          // Counter
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$charCount/${widget.maxLength}',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: nearLimit ? AppColors.warning : AppColors.grey400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gradient Save Button ───────────────────────────────────────────────────

class _GradientSaveButton extends StatefulWidget {
  const _GradientSaveButton({
    this.onTap,
    this.isLoading = false,
    this.isEnabled = true,
  });
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isEnabled;

  @override
  State<_GradientSaveButton> createState() => _GradientSaveButtonState();
}

class _GradientSaveButtonState extends State<_GradientSaveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1.0,
        child: Container(
          width: double.infinity,
          height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: widget.isEnabled
              ? const LinearGradient(
                  colors: [Color(0xFF2038F5), Color(0xFF1429C8)],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                )
              : LinearGradient(
                  colors: [AppColors.grey200, AppColors.grey300],
                ),
          boxShadow: widget.isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  'حفظ التغييرات',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: widget.isEnabled ? Colors.white : AppColors.grey400,
                  ),
                ),
        ),
      ),     // Container
    ),       // AnimatedScale
    );
  }
}

// ── Picker Option Row ──────────────────────────────────────────────────────

class _PickerOption extends StatelessWidget {
  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primaryLighter,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: AppColors.grey800,
        ),
      ),
      onTap: onTap,
    );
  }
}
