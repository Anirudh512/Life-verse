import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/user_state.dart';

class CapsuleHowItWorksScreen extends StatefulWidget {
  const CapsuleHowItWorksScreen({super.key});

  @override
  State<CapsuleHowItWorksScreen> createState() =>
      _CapsuleHowItWorksScreenState();
}

class _CapsuleHowItWorksScreenState extends State<CapsuleHowItWorksScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  final _steps = const [
    _Step(
      icon: Icons.edit_note_rounded,
      title: 'Create Your Capsule',
      body:
          'Write a message and attach up to 20 files. Each file can be up to 50MB, with a 200MB total limit. Pick a theme that matches the moment.',
      color: Color(0xFFFFB300),
    ),
    _Step(
      icon: Icons.schedule_rounded,
      title: 'Seal for at Least 1 Day',
      body:
          'Every capsule needs at least 24 hours before it unlocks. Time makes the moment sacred.',
      color: Color(0xFFB388FF),
    ),
    _Step(
      icon: Icons.favorite_rounded,
      title: 'Send to Someone You Love',
      body:
          'Keep it for yourself or send it to a trusted LifeVerse connection. The recipient can open it when the time arrives.',
      color: Color(0xFFFF6090),
    ),
    _Step(
      icon: Icons.celebration_rounded,
      title: 'The Grand Opening',
      body:
          'When the date arrives, the capsule is ready in the app. The recipient sees it the next time they open LifeVerse; remote push delivery is not available yet.',
      color: Color(0xFF40C4FF),
    ),
  ];

  void _finish() {
    final userState = Provider.of<UserState>(context, listen: false);
    userState.updateAppState({'capsuleTutorialSeen': true});
    ApiService.saveAppState(userState.userId, userState.appState);
    Navigator.pushReplacementNamed(context, '/create_capsule');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    '${_page + 1}/${_steps.length}',
                    style: const TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _StepView(step: _steps[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i ? _steps[i].color : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_page == _steps.length - 1) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.privacy_tip_outlined, color: Colors.white70),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'LifeVerse asks for access only when you choose a feature that needs it, such as location lock. File selection uses your device picker.',
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_page < _steps.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );
                    } else {
                      _finish();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _steps[_page].color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _page < _steps.length - 1
                        ? 'Next'
                        : 'Create My First Capsule',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _Step({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
}

class _StepView extends StatelessWidget {
  final _Step step;

  const _StepView({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (_, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: step.color.withValues(alpha: 0.15),
                border: Border.all(
                  color: step.color.withValues(alpha: 0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: step.color.withValues(alpha: 0.3),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Icon(step.icon, size: 56, color: step.color),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            step.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
