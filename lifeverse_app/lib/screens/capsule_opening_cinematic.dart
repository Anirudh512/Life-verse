import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/lifeverse_theme.dart';

class CapsuleOpeningCinematic extends StatefulWidget {
  final String title;
  final String message;
  
  const CapsuleOpeningCinematic({super.key, required this.title, required this.message});

  @override
  State<CapsuleOpeningCinematic> createState() => _CapsuleOpeningCinematicState();
}

class _CapsuleOpeningCinematicState extends State<CapsuleOpeningCinematic> {
  bool _isOpen = false;

  void _openCapsule() {
    setState(() => _isOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeVerseColors.canvas,
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(seconds: 2),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: _isOpen
                      ? [
                          LifeVerseColors.primary.withValues(alpha: .24),
                          LifeVerseColors.canvas,
                        ]
                      : [
                          LifeVerseColors.secondary.withValues(alpha: .12),
                          LifeVerseColors.canvas,
                        ],
                  radius: _isOpen ? 1.5 : 0.8,
                ),
              ),
            ),
          ),
          
          Center(
            child: !_isOpen 
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                          Icons.lock_clock,
                          size: 80,
                          color: LifeVerseColors.secondary,
                        )
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .scaleXY(end: 1.1, duration: 1000.ms),
                    const SizedBox(height: 30),
                    const Text(
                      "A Memory Awaits",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.5),
                    const SizedBox(height: 50),
                    ElevatedButton(
                      onPressed: _openCapsule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LifeVerseColors.primary,
                        foregroundColor: LifeVerseColors.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text("Break the Seal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ).animate().fadeIn(delay: 500.ms),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                          Icons.auto_awesome,
                          size: 60,
                          color: LifeVerseColors.primary,
                        )
                        .animate()
                        .scaleXY(begin: 0.0, end: 1.0, curve: Curves.easeOutBack, duration: 800.ms)
                        .then()
                        .shimmer(duration: 1000.ms),
                    const SizedBox(height: 30),
                    Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),
                    const SizedBox(height: 20),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: LifeVerseColors.surface,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: LifeVerseColors.line),
                      ),
                      child: Text(
                        widget.message,
                        style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().fadeIn(delay: 1000.ms).scaleXY(begin: 0.9),
                    const SizedBox(height: 40),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close", style: TextStyle(color: Colors.white54)),
                    ).animate().fadeIn(delay: 2000.ms),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}
