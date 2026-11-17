import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/lifeverse_theme.dart';

class FirstLaunchScreen extends StatefulWidget {
  const FirstLaunchScreen({super.key});

  @override
  State<FirstLaunchScreen> createState() => _FirstLaunchScreenState();
}

class _FirstLaunchScreenState extends State<FirstLaunchScreen> with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  
  final List<String> _messages = [
    "",
    "Every life tells a story.",
    "The question is... will you remember yours?",
    "Welcome to LifeVerse.",
    "This isn't a productivity app.\nIt isn't a diary.\nIt isn't a game.",
    "It's a place where your past, present, and future come together."
  ];

  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  void _startSequence() async {
    for (int i = 1; i < _messages.length; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _currentStep = i;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background - Deep space color
          Container(color: LifeVerseColors.canvas),
          
          // Subtle Star particles could go here (using a CustomPainter or package in the future)
          
          // Center Text Animation
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(seconds: 2),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                _messages[_currentStep],
                key: ValueKey<int>(_currentStep),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.2,
                  height: 1.5,
                ),
              ),
            ),
          ),

          // Begin Button (Appears at the very end)
          if (_currentStep == _messages.length - 1)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: child,
                    );
                  },
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/dashboard');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LifeVerseColors.primary,
                      side: const BorderSide(color: LifeVerseColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Begin My Journey",
                      style: TextStyle(fontSize: 18, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
