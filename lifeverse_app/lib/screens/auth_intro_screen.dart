import 'package:flutter/material.dart';

import '../theme/lifeverse_theme.dart';
import '../widgets/lifeverse_components.dart';

class AuthIntroScreen extends StatelessWidget {
  const AuthIntroScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: LifeVerseColors.surface,
                  child: Icon(
                    Icons.all_inclusive,
                    color: LifeVerseColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Welcome to LifeVerse',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A space to work on what matters to you, reflect on your choices, and keep the moments you want to remember.',
                  style: TextStyle(
                    color: LifeVerseColors.muted,
                    fontSize: 16,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                const LvSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IntroStep(
                        icon: Icons.explore_outlined,
                        text: 'Choose a growth area in Evolution Matrix.',
                      ),
                      SizedBox(height: 14),
                      _IntroStep(
                        icon: Icons.check_circle_outline,
                        text: 'Try one activity and record it when you finish.',
                      ),
                      SizedBox(height: 14),
                      _IntroStep(
                        icon: Icons.insights_outlined,
                        text: 'See your saved activity in Progress.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    icon: const Icon(Icons.login),
                    label: const Text('Log in'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Create an account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _IntroStep extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IntroStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: LifeVerseColors.primary, size: 20),
      const SizedBox(width: 11),
      Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
    ],
  );
}
