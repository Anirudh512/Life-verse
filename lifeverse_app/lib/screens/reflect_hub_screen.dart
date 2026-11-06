import 'package:flutter/material.dart';

import '../theme/lifeverse_theme.dart';
import '../widgets/lifeverse_components.dart';

class ReflectHubScreen extends StatelessWidget {
  const ReflectHubScreen({super.key});

  static const _groups = [
    _ReflectGroup(
      title: 'Talk it through',
      description:
          'Think about what is happening now and what you might do next.',
      features: [
        _ReflectFeature(
          title: 'Twin Mind',
          description:
              'Talk through a thought with your AI companion. Sharing saved LifeVerse context is optional.',
          icon: Icons.forum_outlined,
          route: '/digital_twin',
          color: LifeVerseColors.primary,
        ),
        _ReflectFeature(
          title: 'Vision Engine',
          description:
              'Explore possible paths for a goal and choose a next step that feels right to you.',
          icon: Icons.alt_route_outlined,
          route: '/future_simulation',
          color: LifeVerseColors.secondary,
        ),
      ],
    ),
    _ReflectGroup(
      title: 'Explore your choices',
      description:
          'Look at a decision from a few angles. The results are possibilities, not predictions.',
      features: [
        _ReflectFeature(
          title: 'Butterfly Effect',
          description:
              'Record a choice and explore possible patterns. This cannot prove that a choice caused an outcome.',
          icon: Icons.change_circle_outlined,
          route: '/digital_twin',
          routeArgument: 'butterfly',
          color: Color(0xFFF0A7C9),
        ),
      ],
    ),
    _ReflectGroup(
      title: 'Save and revisit',
      description: 'Keep meaningful moments and return to them later.',
      features: [
        _ReflectFeature(
          title: 'Life Atlas',
          description:
              'Save milestones and build a personal timeline you can revisit.',
          icon: Icons.auto_stories_outlined,
          route: '/legacy_timeline',
          color: LifeVerseColors.warning,
        ),
        _ReflectFeature(
          title: 'Time Capsules',
          description:
              'Save a message, memory, or attachment to open in the future, or share with someone you trust.',
          icon: Icons.lock_clock_outlined,
          route: '/time_capsules',
          color: Color(0xFF9CBFFF),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const LvPageHeader(
                title: 'Reflect',
                subtitle:
                    'Choose what you would like to think about, plan, or remember.',
              ),
              for (final group in _groups) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LvSectionTitle(group.title),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          group.description,
                          style: const TextStyle(
                            color: LifeVerseColors.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 700 ? 2 : 1;
                          final gap = 12.0;
                          final width =
                              (constraints.maxWidth - (columns - 1) * gap) /
                              columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: group.features
                                .map(
                                  (feature) => SizedBox(
                                    width: width,
                                    child: _FeatureCard(feature: feature),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReflectGroup {
  final String title;
  final String description;
  final List<_ReflectFeature> features;
  const _ReflectGroup({
    required this.title,
    required this.description,
    required this.features,
  });
}

class _ReflectFeature {
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final Object? routeArgument;
  final Color color;
  const _ReflectFeature({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    this.routeArgument,
    required this.color,
  });
}

class _FeatureCard extends StatelessWidget {
  final _ReflectFeature feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.pushNamed(
        context,
        feature.route,
        arguments: feature.routeArgument,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: feature.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(feature.icon, color: feature.color, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    feature.description,
                    style: const TextStyle(
                      color: LifeVerseColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: LifeVerseColors.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
