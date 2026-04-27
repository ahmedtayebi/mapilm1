import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../providers/conversations_provider.dart';

// Demo contacts for UI purposes (production: load from contacts provider)
final _demoContacts = <UserEntity>[
  const UserEntity(id: '1', phone: '+213500000001', name: 'أحمد محمد'),
  const UserEntity(id: '2', phone: '+213500000002', name: 'فاطمة علي'),
  const UserEntity(id: '3', phone: '+213500000003', name: 'محمد الأمين'),
  const UserEntity(id: '4', phone: '+213500000004', name: 'سارة بوعلام'),
  const UserEntity(id: '5', phone: '+213500000005', name: 'يوسف بن علي'),
];

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen>
    with TickerProviderStateMixin {
  late final PageController _pageCtrl;
  late final AnimationController _stepAnim;

  int _step = 0;
  final Set<String> _selectedIds = {};
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Step 2 fields
  final _nameController = TextEditingController();
  File? _avatarFile;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _stepAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _stepAnim.dispose();
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _goToStep2() {
    if (_selectedIds.isEmpty) return;
    _pageCtrl.animateToPage(
      1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _step = 1);
    _stepAnim.forward();
  }

  void _goBack() {
    if (_step == 0) {
      context.pop();
    } else {
      _pageCtrl.animateToPage(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _step = 0);
      _stepAnim.reverse();
    }
  }

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isCreating = true);
    try {
      await ref.read(conversationsProvider.notifier).createGroup(
            name: _nameController.text.trim(),
            participantIds: _selectedIds.toList(),
            avatarPath: _avatarFile?.path,
          );
      if (mounted) context.go(AppRoutes.home);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.somethingWrong),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<void> _pickAvatar() async {
    final xFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (xFile != null) {
      setState(() => _avatarFile = File(xFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredContacts = _searchQuery.isEmpty
        ? _demoContacts
        : _demoContacts.where((c) {
            final q = _searchQuery.toLowerCase();
            return (c.name?.toLowerCase().contains(q) ?? false) ||
                c.phone.contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Custom AppBar
          _CreateGroupAppBar(
            step: _step,
            onBack: _goBack,
            onNext: _step == 0 ? (_selectedIds.isNotEmpty ? _goToStep2 : null) : null,
            onCreate: _step == 1 ? (_nameController.text.trim().isNotEmpty ? _create : null) : null,
            isCreating: _isCreating,
          ),
          // Step indicator
          _StepIndicator(current: _step),
          // Selected members chips (step 1)
          if (_selectedIds.isNotEmpty)
            _SelectedChips(
              selected: _demoContacts
                  .where((c) => _selectedIds.contains(c.id))
                  .toList(),
              onRemove: (id) => setState(() => _selectedIds.remove(id)),
            ),
          // Page content
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Step 1: Select members
                _Step1SelectMembers(
                  contacts: filteredContacts,
                  selectedIds: _selectedIds,
                  searchController: _searchController,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  onToggle: (id) => setState(() {
                    if (_selectedIds.contains(id)) {
                      _selectedIds.remove(id);
                    } else {
                      _selectedIds.add(id);
                    }
                  }),
                ),
                // Step 2: Group details
                _Step2GroupDetails(
                  nameController: _nameController,
                  avatarFile: _avatarFile,
                  selectedMembers: _demoContacts
                      .where((c) => _selectedIds.contains(c.id))
                      .toList(),
                  onPickAvatar: _pickAvatar,
                  onNameChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          // Bottom button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _BottomButton(
                step: _step,
                selectedCount: _selectedIds.length,
                nameValid: _nameController.text.trim().length >= 2,
                isCreating: _isCreating,
                onNext: _goToStep2,
                onCreate: _create,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App Bar ────────────────────────────────────────────────────────────────

class _CreateGroupAppBar extends StatelessWidget {
  const _CreateGroupAppBar({
    required this.step,
    required this.onBack,
    this.onNext,
    this.onCreate,
    required this.isCreating,
  });
  final int step;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final VoidCallback? onCreate;
  final bool isCreating;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPad),
      color: Colors.white,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(10),
                child: const SizedBox(
                  width: 48,
                  height: 56,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: AppColors.grey700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                AppStrings.createGroup,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

// ── Step Indicator ─────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          _Step(index: 0, current: current, label: 'اختر الأعضاء'),
          Expanded(
            child: Container(
              height: 2,
              color: current > 0 ? AppColors.primary : AppColors.grey200,
            ),
          ),
          _Step(index: 1, current: current, label: 'تفاصيل المجموعة'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.current,
    required this.label,
  });
  final int index;
  final int current;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isActive = current == index;
    final isDone = current > index;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDone || isActive ? AppColors.primary : AppColors.grey200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 14)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: isActive ? Colors.white : AppColors.grey400,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isActive ? AppColors.primary : AppColors.grey400,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Selected Chips ─────────────────────────────────────────────────────────

class _SelectedChips extends StatelessWidget {
  const _SelectedChips({
    required this.selected,
    required this.onRemove,
  });
  final List<UserEntity> selected;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        itemCount: selected.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final member = selected[i];
          return _MemberChip(
            member: member,
            onRemove: () => onRemove(member.id),
          ).animate().scale(
                begin: const Offset(0.8, 0.8),
                curve: Curves.easeOutBack,
                duration: 250.ms,
              );
        },
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.member, required this.onRemove});
  final UserEntity member;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLighter,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(
            name: member.name,
            imageUrl: member.avatarUrl,
            radius: 14,
          ),
          const SizedBox(width: 6),
          Text(
            (member.name ?? member.phone).split(' ').first,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1 ─────────────────────────────────────────────────────────────────

class _Step1SelectMembers extends StatelessWidget {
  const _Step1SelectMembers({
    required this.contacts,
    required this.selectedIds,
    required this.searchController,
    required this.onSearchChanged,
    required this.onToggle,
  });

  final List<UserEntity> contacts;
  final Set<String> selectedIds;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(22),
            ),
            child: TextField(
              controller: searchController,
              style: AppTypography.bodyMedium,
              cursorColor: AppColors.primary,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'ابحث عن جهة اتصال...',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.grey400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppColors.grey400,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
              ),
            ),
          ),
        ),
        // Contacts list
        Expanded(
          child: contacts.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد نتائج',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.grey400),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: contacts.length,
                  itemBuilder: (_, i) {
                    final contact = contacts[i];
                    final isSelected = selectedIds.contains(contact.id);
                    return _ContactSelectTile(
                      contact: contact,
                      isSelected: isSelected,
                      onTap: () => onToggle(contact.id),
                    ).animate().fadeIn(
                          delay: Duration(milliseconds: i * 30),
                          duration: 250.ms,
                        );
                  },
                ),
        ),
      ],
    );
  }
}

class _ContactSelectTile extends StatelessWidget {
  const _ContactSelectTile({
    required this.contact,
    required this.isSelected,
    required this.onTap,
  });
  final UserEntity contact;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primaryLighter : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              AppAvatar(
                name: contact.name,
                imageUrl: contact.avatarUrl,
                radius: 23,
                showOnlineIndicator: true,
                isOnline: contact.isOnline,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name ?? contact.phone,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey900,
                      ),
                    ),
                    Text(
                      contact.phone,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.grey300,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 2 ─────────────────────────────────────────────────────────────────

class _Step2GroupDetails extends StatelessWidget {
  const _Step2GroupDetails({
    required this.nameController,
    required this.avatarFile,
    required this.selectedMembers,
    required this.onPickAvatar,
    required this.onNameChanged,
  });

  final TextEditingController nameController;
  final File? avatarFile;
  final List<UserEntity> selectedMembers;
  final VoidCallback onPickAvatar;
  final ValueChanged<String> onNameChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar picker
          Center(
            child: GestureDetector(
              onTap: onPickAvatar,
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryLighter,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 2,
                      ),
                      image: avatarFile != null
                          ? DecorationImage(
                              image: FileImage(avatarFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: avatarFile == null
                        ? const Icon(
                            Icons.group_rounded,
                            size: 48,
                            color: AppColors.primary,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().scale(
                  begin: const Offset(0.8, 0.8),
                  curve: Curves.easeOutBack,
                  duration: 400.ms,
                ),
          ),
          const SizedBox(height: 28),
          // Group name
          Text(
            AppStrings.groupName,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.grey600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: nameController,
              onChanged: onNameChanged,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLength: 50,
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: AppStrings.groupNamePlaceholder,
                hintStyle: AppTypography.bodyLarge.copyWith(
                  color: AppColors.grey400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                counterText: '',
                filled: false,
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Selected members preview
          Text(
            '${AppStrings.participants} (${selectedMembers.length})',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.grey600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedMembers.map((m) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppAvatar(
                    name: m.name,
                    imageUrl: m.avatarUrl,
                    radius: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    (m.name ?? m.phone).split(' ').first,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.grey700,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Button ──────────────────────────────────────────────────────────

class _BottomButton extends StatelessWidget {
  const _BottomButton({
    required this.step,
    required this.selectedCount,
    required this.nameValid,
    required this.isCreating,
    required this.onNext,
    required this.onCreate,
  });

  final int step;
  final int selectedCount;
  final bool nameValid;
  final bool isCreating;
  final VoidCallback onNext;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final isEnabled = step == 0 ? selectedCount >= 2 : nameValid;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? const LinearGradient(
                colors: [AppColors.primary, Color(0xFF4B6EF5)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              )
            : null,
        color: isEnabled ? null : AppColors.grey200,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isEnabled && !isCreating
              ? (step == 0 ? onNext : onCreate)
              : null,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.15),
          child: Center(
            child: isCreating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    step == 0
                        ? selectedCount >= 2
                            ? 'التالي ($selectedCount)'
                            : 'اختر عضوين على الأقل'
                        : 'إنشاء المجموعة',
                    style: AppTypography.labelLarge.copyWith(
                      color: isEnabled ? Colors.white : AppColors.grey400,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
