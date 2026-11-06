import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/capsule_theme.dart';
import '../screens/capsule_open_screen.dart';

Future<void> showCapsuleDeliveryOverlay(
  BuildContext context, {
  required Map<String, dynamic> capsule,
  required String userId,
}) {
  final theme = CapsuleThemes.byId(capsule['themeStyle'] as String? ?? 'amber_gold');
  final sender = capsule['senderUsername'] as String? ?? 'someone special';

  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, _, __) {
      final scale = CurvedAnimation(parent: animation, curve: Curves.elasticOut);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(scale),
          child: _DeliveryCard(
            theme: theme,
            sender: sender,
            title: capsule['title'] as String? ?? 'A Memory Preserved',
            mediaCount: capsule['mediaCount'] as int? ?? 0,
            onOpen: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CapsuleOpenScreen(
                    capsuleId: capsule['id'] as String,
                    userId: userId,
                    previewCapsule: capsule,
                  ),
                ),
              );
            },
            onLater: () => Navigator.of(context).pop(),
          ),
        ),
      );
    },
  );
}

class _DeliveryCard extends StatefulWidget {
  final CapsuleThemeStyle theme;
  final String sender;
  final String title;
  final int mediaCount;
  final VoidCallback onOpen;
  final VoidCallback onLater;

  const _DeliveryCard({
    required this.theme,
    required this.sender,
    required this.title,
    required this.mediaCount,
    required this.onOpen,
    required this.onLater,
  });

  @override
  State<_DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<_DeliveryCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.theme.gradient,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: widget.theme.accent.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.theme.accent.withValues(alpha: 0.35),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) {
                    final glow = 0.6 + (_pulse.value * 0.4);
                    return Transform.rotate(
                      angle: math.sin(_pulse.value * math.pi * 2) * 0.05,
                      child: Icon(
                        Icons.mail_lock_rounded,
                        size: 72,
                        color: widget.theme.accent.withValues(alpha: glow),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'A Time Capsule Has Arrived',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.theme.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '@${widget.sender} sealed "${widget.title}" for you.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
                if (widget.mediaCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${widget.mediaCount} memory file${widget.mediaCount == 1 ? '' : 's'} inside',
                    style: TextStyle(color: widget.theme.accent.withValues(alpha: 0.8), fontSize: 13),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onOpen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.theme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Open Capsule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: widget.onLater,
                  child: const Text('Save for later', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
