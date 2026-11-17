import 'package:flutter/material.dart';

import '../theme/lifeverse_theme.dart';
import '../widgets/ai_data_notice.dart';
import '../widgets/lifeverse_components.dart';

class HDEDashboard extends StatelessWidget {
  final bool showBackButton;
  const HDEDashboard({super.key, this.showBackButton = true});

  static const _areas = [
    _GrowthArea(
      title: 'Physical',
      subtitle: 'Movement, energy, and everyday health.',
      icon: Icons.directions_run,
      color: LifeVerseColors.warning,
    ),
    _GrowthArea(
      title: 'Cognitive',
      subtitle: 'Focus, learning, and clear thinking.',
      icon: Icons.psychology_alt_outlined,
      color: LifeVerseColors.primary,
    ),
    _GrowthArea(
      title: 'Psychosocial',
      subtitle: 'Communication, empathy, and connection.',
      icon: Icons.people_outline,
      color: Color(0xFFF0A7C9),
    ),
    _GrowthArea(
      title: 'Moral',
      subtitle: 'Values, choices, and the habits that matter to you.',
      icon: Icons.balance_outlined,
      color: LifeVerseColors.secondary,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Evolution Matrix'),
      leading: showBackButton
          ? IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                'Choose one area to focus on',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick an area, choose a task, and mark it complete. LifeVerse saves completed activities to your account.',
                style: TextStyle(color: LifeVerseColors.muted, height: 1.45),
              ),
              const SizedBox(height: 16),
              const _HowItWorksCard(),
              const SizedBox(height: 14),
              const AiDataNotice(),
              const SizedBox(height: 22),
              const LvSectionTitle('Your four growth areas'),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 680 ? 2 : 1;
                  final gap = 12.0;
                  final width =
                      (constraints.maxWidth - (columns - 1) * gap) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: _areas
                        .map(
                          (area) => SizedBox(
                            width: width,
                            child: _GrowthAreaCard(area: area),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/growth_goals'),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('View growth goals'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) => LvSurface(
    tint: LifeVerseColors.panel,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Wrap(
      spacing: 18,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: const [
        _StepHint(number: '1', text: 'Choose an area'),
        _StepHint(number: '2', text: 'Pick a task'),
        _StepHint(number: '3', text: 'Record it when done'),
      ],
    ),
  );
}

class _StepHint extends StatelessWidget {
  final String number;
  final String text;
  const _StepHint({required this.number, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 12,
        backgroundColor: LifeVerseColors.raised,
        child: Text(
          number,
          style: const TextStyle(
            color: LifeVerseColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _GrowthArea {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _GrowthArea({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _GrowthAreaCard extends StatelessWidget {
  final _GrowthArea area;
  const _GrowthAreaCard({required this.area});

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.pushNamed(
        context,
        '/hde_category_tasks',
        arguments: area.title,
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: area.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(area.icon, color: area.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    area.subtitle,
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
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: area.color.withValues(alpha: .8),
              size: 16,
            ),
          ],
        ),
      ),
    ),
  );
}
