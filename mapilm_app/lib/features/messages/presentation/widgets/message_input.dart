import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/message_entity.dart';

class MessageInput extends StatefulWidget {
  const MessageInput({
    super.key,
    this.replyTo,
    required this.onSendText,
    required this.onSendImage,
    required this.onTypingChanged,
    this.onCancelReply,
  });

  final MessageEntity? replyTo;
  final void Function(String text) onSendText;
  final void Function(String path, ImageSource source) onSendImage;
  final void Function(bool) onTypingChanged;
  final VoidCallback? onCancelReply;

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  Timer? _typingTimer;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String value) {
    final hadText = _hasText;
    setState(() => _hasText = value.trim().isNotEmpty);
    if (_hasText && !hadText) widget.onTypingChanged(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      widget.onTypingChanged(false);
    });
  }

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.onSendText(text);
    _controller.clear();
    setState(() => _hasText = false);
    widget.onTypingChanged(false);
    _typingTimer?.cancel();
  }

  void _showAttachmentSheet() {
    _focusNode.unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (_) => _AttachmentSheet(
        onCamera: () async {
          Navigator.pop(context);
          final xFile = await ImagePicker().pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
          );
          if (xFile != null) {
            widget.onSendImage(xFile.path, ImageSource.camera);
          }
        },
        onGallery: () async {
          Navigator.pop(context);
          final xFile = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 80,
          );
          if (xFile != null) {
            widget.onSendImage(xFile.path, ImageSource.gallery);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyTo != null) _ReplyBar(
              reply: widget.replyTo!,
              onCancel: widget.onCancelReply,
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.85),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withOpacity(0.10),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _RoundIconBtn(
                        icon: Icons.add_rounded,
                        onTap: _showAttachmentSheet,
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: _buildTextField()),
                      const SizedBox(width: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInBack,
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: FadeTransition(
                            opacity: anim,
                            child: child,
                          ),
                        ),
                        child: _hasText
                            ? _SendOrb(
                                key: const ValueKey('send'),
                                onTap: _sendText,
                              )
                            : const _MicOrb(key: ValueKey('mic')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 140),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        textInputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
          height: 1.4,
        ),
        cursorColor: AppColors.primary,
        cursorWidth: 2,
        onChanged: _onTextChanged,
        decoration: InputDecoration(
          hintText: AppStrings.typeMessage,
          hintStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

// ── Reply Bar ─────────────────────────────────────────────────────────────

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.reply, required this.onCancel});
  final MessageEntity reply;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.auroraStops,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.reply_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reply.senderName != null)
                  Text(
                    reply.senderName!,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.2,
                    ),
                  ),
                Text(
                  reply.content ?? '...',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.inkMuted,
            ),
            onPressed: onCancel,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Action buttons ────────────────────────────────────────────────────────

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.ink.withOpacity(0.045),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.inkSoft, size: 22),
      ),
    );
  }
}

class _SendOrb extends StatelessWidget {
  const _SendOrb({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.auroraStops,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.40),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_upward_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _MicOrb extends StatelessWidget {
  const _MicOrb({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.auroraStops,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.40),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.mic_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

// ── Attachment Sheet ───────────────────────────────────────────────────────

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet({required this.onCamera, required this.onGallery});
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 28),
      decoration: BoxDecoration(
        color: AppColors.pearl,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(0.18),
            blurRadius: 40,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'إرسال محتوى',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: _AttachOption(
                    icon: Icons.photo_camera_rounded,
                    label: 'الكاميرا',
                    colors: const [AppColors.primary, AppColors.violet],
                    onTap: onCamera,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AttachOption(
                    icon: Icons.photo_library_rounded,
                    label: 'المعرض',
                    colors: const [AppColors.violet, AppColors.rose],
                    onTap: onGallery,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AttachOption(
                    icon: Icons.description_rounded,
                    label: 'مستند',
                    colors: const [AppColors.peach, AppColors.amber],
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    )
        .animate()
        .slideY(
          begin: 0.3,
          end: 0,
          curve: Curves.easeOutCubic,
          duration: 280.ms,
        )
        .fadeIn(duration: 200.ms);
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withOpacity(0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
