import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/capsule_delivery_service.dart';
import '../services/user_state.dart';
import '../theme/lifeverse_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 800), () async {
        if (!mounted) return;
        final userId = Provider.of<UserState>(context, listen: false).userId;
        Navigator.pushReplacementNamed(context, '/home');
        if (userId.isNotEmpty && mounted) {
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) {
            await CapsuleDeliveryService.checkAndShowDeliveries(context, userId);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeVerseColors.canvas,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Replace with actual logo image later
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  color: LifeVerseColors.surface,
                  border: Border.all(color: LifeVerseColors.primary, width: 2),
                  ),
                child: const Icon(Icons.all_inclusive, color: LifeVerseColors.primary, size: 50),
                ),
                const SizedBox(height: 20),
                const Text(
                  "LifeVerse",
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 3),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Connecting to your legacy...",
                  style: TextStyle(color: LifeVerseColors.muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
