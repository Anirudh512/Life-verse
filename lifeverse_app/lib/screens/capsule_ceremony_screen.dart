import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/capsule_theme.dart';

class CapsuleCeremonyScreen extends StatefulWidget {
  const CapsuleCeremonyScreen({super.key});

  @override
  State<CapsuleCeremonyScreen> createState() => _CapsuleCeremonyScreenState();
}

class _CapsuleCeremonyScreenState extends State<CapsuleCeremonyScreen> with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _glowController;
  CapsuleThemeStyle _theme = CapsuleThemes.all.first;
  String _title = 'A Memory Preserved';
  String _dateLabel = '';
  String? _recipient;
  int _mediaCount = 0;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _theme = CapsuleThemes.byId(args['themeStyle'] as String? ?? 'amber_gold');
        _title = args['title'] as String? ?? _title;
        _recipient = args['recipient'] as String?;
        _mediaCount = args['mediaCount'] as int? ?? 0;
        final openDate = DateTime.tryParse(args['openDate'] as String? ?? '');
        if (openDate != null) {
          _dateLabel = DateFormat('EEEE, MMMM d, yyyy').format(openDate);
        }
        setState(() {});
      } else {
        _theme = CapsuleThemes.all.first;
      }
      _startSequence();
    });
  }

  void _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    for (int i = 1; i <= 4; i++) {
      await Future.delayed(Duration(milliseconds: i == 4 ? 3500 : 2500));
      if (mounted) setState(() => _currentStep = i);
    }
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pushReplacementNamed(context, '/time_capsules');
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 1),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.gradient,
          ),
        ),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _glowController,
              builder: (_, __) {
                return Center(
                  child: Container(
                    width: 200 + (_glowController.value * 40),
                    height: 200 + (_glowController.value * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.15 + _glowController.value * 0.2),
                          blurRadius: 60,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: _buildStep(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(CapsuleThemeStyle theme) {
    switch (_currentStep) {
      case 0:
        return Icon(Icons.hourglass_empty, key: const ValueKey(0), size: 64, color: theme.accent.withValues(alpha: 0.5));
      case 1:
        return _textStep(
          key: const ValueKey(1),
          theme: theme,
          icon: Icons.lock_rounded,
          text: 'Your memories are now sealed inside "$_title".',
        );
      case 2:
        return _textStep(
          key: const ValueKey(2),
          theme: theme,
          icon: Icons.favorite_rounded,
          text: _recipient != null
              ? 'Traveling through time to @$_recipient...'
              : 'Traveling through time to your future self...',
        );
      case 3:
        return _textStep(
          key: const ValueKey(3),
          theme: theme,
          icon: Icons.schedule_rounded,
          text: 'We will meet again on\n$_dateLabel',
          subtitle: _mediaCount > 0 ? '$_mediaCount memory files preserved' : 'Safely traveling through time...',
        );
      default:
        return Column(
          key: const ValueKey(4),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 72, color: theme.accent),
            const SizedBox(height: 16),
            Text('Capsule Launched', style: TextStyle(color: theme.accent, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        );
    }
  }

  Widget _textStep({
    required Key key,
    required CapsuleThemeStyle theme,
    required IconData icon,
    required String text,
    String? subtitle,
  }) {
    return Column(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 72, color: theme.accent),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.4, fontWeight: FontWeight.w300),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(subtitle, style: TextStyle(color: theme.accent.withValues(alpha: 0.8), fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }
}
