import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/lifeverse_theme.dart';
import '../widgets/lifeverse_components.dart';

typedef WeeklyReviewLoader = Future<Map<String, dynamic>> Function(String userId);

class WeeklyReviewScreen extends StatefulWidget {
  final WeeklyReviewLoader? reviewLoader;
  const WeeklyReviewScreen({super.key, this.reviewLoader});

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  String _userId = '';
  Future<Map<String, dynamic>>? _future;

  Future<Map<String, dynamic>> _load() =>
      widget.reviewLoader?.call(_userId) ??
      ApiService.getProgressAnalytics(_userId, days: 7);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.read<UserState>().userId;
    if (id != _userId) {
      _userId = id;
      _future = id.isEmpty ? null : _load();
    }
  }

  Future<void> _refresh() async {
    if (_userId.isEmpty) return;
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: LifeVerseColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            LvPageHeader(
              title: 'Weekly review',
              subtitle: 'Look back at recorded activity and choose a grounded next step.',
              trailing: IconButton(
                tooltip: 'Refresh weekly review',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ),
            if (_future == null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: LvMessage(
                  title: 'Sign in to review your week',
                  message: 'Weekly activity is private to your LifeVerse account.',
                ),
              )
            else
              FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final data = snapshot.data;
                  if (snapshot.hasError || data?['success'] != true) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: LvMessage(
                        title: 'Your review could not load',
                        message: data?['message']?.toString() ??
                            'Check your connection and try again. Your saved records are unchanged.',
                        icon: Icons.cloud_off_outlined,
                        onRetry: _refresh,
                      ),
                    );
                  }
                  return _WeeklyReviewContent(
                    data: Map<String, dynamic>.from(data!),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _WeeklyReviewContent extends StatelessWidget {
  final Map<String, dynamic> data;
  const _WeeklyReviewContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final summary = _map(data['summary']);
    final dimensions = _map(data['dimensions']);
    final goalsValue = data['goals'];
    final goals = goalsValue is List
        ? goalsValue.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    final activitiesValue = data['recentActivity'];
    final activities = activitiesValue is List
        ? activitiesValue.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    final activeGoals = goals.where((goal) => goal['isComplete'] != true).toList();
    final focus = dimensions.entries.toList()
      ..sort((a, b) => _activityCount(b.value).compareTo(_activityCount(a.value)));
    final hasGrowthActivity = _int(summary['tasksCompleted']) + _int(summary['reviewsCompleted']) > 0;
    final window = _map(data['window']);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LvSurface(
                tint: LifeVerseColors.panel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your recorded week', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(
                      '${_date(window['startDate'])} – ${_date(window['endDate'])} UTC',
                      style: const TextStyle(color: LifeVerseColors.muted),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(builder: (context, constraints) {
                      final width = (constraints.maxWidth - 12) / 2;
                      return Wrap(spacing: 12, runSpacing: 12, children: [
                        SizedBox(width: width, child: LvMetricTile(label: 'Visit days', value: '${_int(summary['visitDays'])}', icon: Icons.event_available_outlined, detail: 'Days the app was opened')),
                        SizedBox(width: width, child: LvMetricTile(label: 'Growth days', value: '${_int(summary['growthDays'])}', icon: Icons.auto_awesome_outlined, color: LifeVerseColors.secondary, detail: 'Days with a task or review')),
                        SizedBox(width: width, child: LvMetricTile(label: 'Tasks completed', value: '${_int(summary['tasksCompleted'])}', icon: Icons.check_circle_outline, color: LifeVerseColors.success)),
                        SizedBox(width: width, child: LvMetricTile(label: 'Reviews completed', value: '${_int(summary['reviewsCompleted'])}', icon: Icons.rate_review_outlined, color: LifeVerseColors.secondary)),
                        SizedBox(width: width, child: LvMetricTile(label: 'XP recorded', value: '${_int(summary['periodXp'])}', icon: Icons.bolt_outlined, color: LifeVerseColors.warning)),
                      ]);
                    }),
                    const SizedBox(height: 12),
                    const Text(
                      'Visits are not growth activity. Counts reflect saved LifeVerse records; no time-on-app estimate or unrecorded history is included.',
                      style: TextStyle(color: LifeVerseColors.muted, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const LvSectionTitle('Across your four dimensions'),
              LvSurface(child: Column(children: [
                for (final dimension in const [
                  ('Physical', 'physical'),
                  ('Cognitive', 'cognitive'),
                  ('Psychosocial', 'psychosocial'),
                  ('Moral', 'moral'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Expanded(child: Text(dimension.$1)),
                      Text(
                        '${_int(_map(dimensions[dimension.$2])['tasksCompleted'])} tasks · ${_int(_map(dimensions[dimension.$2])['reviewsCompleted'])} reviews',
                        style: const TextStyle(color: LifeVerseColors.muted, fontSize: 12),
                      ),
                    ]),
                  ),
              ])),
              const SizedBox(height: 22),
              const LvSectionTitle('What stands out'),
              if (!hasGrowthActivity || focus.isEmpty)
                const LvMessage(
                  title: 'No completed growth activity recorded this week',
                  message: 'Opening LifeVerse is recorded separately. Start with one task or a daily review when you are ready.',
                  icon: Icons.lightbulb_outline,
                )
              else
                LvSurface(child: Text(
                  '${_capitalize(focus.first.key)} has the most recorded task and review activity this week (${_activityCount(focus.first.value)} actions). This describes your records, not a measure of personal worth or improvement.',
                  style: const TextStyle(height: 1.5),
                )),
              const SizedBox(height: 22),
              LvSectionTitle('Goal progress', actionLabel: 'Manage goals', onAction: () => Navigator.pushNamed(context, '/growth_goals')),
              if (activeGoals.isEmpty)
                const LvMessage(title: 'No active goals', message: 'You can create a goal for tasks or active days in any growth dimension.', icon: Icons.flag_outlined)
              else
                ...activeGoals.take(5).map((goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WeeklyGoalCard(goal: goal),
                )),
              const SizedBox(height: 14),
              LvSurface(tint: LifeVerseColors.panel, child: Row(children: [
                const Icon(Icons.arrow_forward_rounded, color: LifeVerseColors.secondary),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  activeGoals.isEmpty ? 'Choose a small next step in Evolution.' : 'Continue your saved goal: ${activeGoals.first['title'] ?? 'Growth goal'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, activeGoals.isEmpty ? '/hde_dashboard' : '/growth_goals'),
                  child: Text(activeGoals.isEmpty ? 'Open Evolution' : 'Open goals'),
                ),
              ])),
              const SizedBox(height: 22),
              const LvSectionTitle('Optional reflection prompts'),
              LvSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('What action would you like to carry into next week?', style: TextStyle(height: 1.4)),
                const SizedBox(height: 6),
                const Text('Which growth area would benefit from your attention?', style: TextStyle(color: LifeVerseColors.muted, height: 1.4)),
                const SizedBox(height: 10),
                const Text('These prompts are not saved here. Use the Evolution daily review to record a reflection in your account.', style: TextStyle(color: LifeVerseColors.muted, fontSize: 11, height: 1.4)),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, '/hde_dashboard'), icon: const Icon(Icons.rate_review_outlined), label: const Text('Open daily review'))),
              ])),
              const SizedBox(height: 22),
              const LvSectionTitle('Recent records from this week'),
              if (activities.isEmpty)
                const LvMessage(title: 'No recent records', message: 'Completed tasks, reviews, and saved LifeVerse milestones appear here when recorded.')
              else
                LvSurface(padding: EdgeInsets.zero, child: Column(children: [
                  for (var index = 0; index < activities.length && index < 8; index++) ...[
                    _WeeklyActivityRow(item: activities[index]),
                    if (index < activities.length - 1 && index < 7) const Divider(height: 1, indent: 56),
                  ],
                ])),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  const _WeeklyGoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final target = _int(goal['targetTasks']);
    final current = _int(goal['progressValue']);
    final value = (target <= 0 ? 0.0 : current / target).clamp(0, 1).toDouble();
    final metric = goal['progressMetric'] == 'active_days' ? 'active days' : 'tasks';
    final dueDate = DateTime.tryParse(goal['dueDate']?.toString() ?? '');
    final now = DateTime.now().toUtc();
    final daysUntilDue = dueDate == null ? null : DateTime.utc(dueDate.year, dueDate.month, dueDate.day).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    final attention = goal['isOverdue'] == true ? 'Overdue' : daysUntilDue != null && daysUntilDue >= 0 && daysUntilDue <= 7 ? 'Due soon' : null;
    return LvSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(goal['title']?.toString() ?? 'Growth goal', style: const TextStyle(fontWeight: FontWeight.w700))), Text('${(value * 100).round()}%', style: const TextStyle(color: LifeVerseColors.primary, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: value, color: LifeVerseColors.primary, backgroundColor: LifeVerseColors.raised, minHeight: 6)),
      const SizedBox(height: 7),
      Text('$current of $target $metric · ${_capitalize(goal['dimension']?.toString() ?? 'Growth')}${dueDate == null ? '' : ' · Due ${DateFormat.MMMd().format(DateTime.utc(dueDate.year, dueDate.month, dueDate.day))}'}${attention == null ? '' : ' · $attention'}', style: TextStyle(color: goal['isOverdue'] == true ? LifeVerseColors.danger : attention != null ? LifeVerseColors.warning : LifeVerseColors.muted, fontSize: 12)),
    ]));
  }
}

class _WeeklyActivityRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _WeeklyActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = item['actionType']?.toString() ?? '';
    final title = switch (type) {
      'TASK_COMPLETED' => 'Growth task completed',
      'SURVEY_SUBMITTED' => 'Daily review completed',
      'TIME_CAPSULE_CREATED' => 'Time capsule created',
      'TIME_CAPSULE_OPENED' => 'Time capsule opened',
      'LEGACY_EVENT_ADDED' => 'Life Atlas milestone added',
      _ => type.replaceAll('_', ' ').toLowerCase(),
    };
    final rawDate = item['createdAt']?.toString();
    final parsedDate = rawDate == null ? null : DateTime.tryParse(rawDate)?.toUtc();
    final dimension = item['dimension']?.toString();
    return ListTile(
      leading: const CircleAvatar(backgroundColor: LifeVerseColors.raised, child: Icon(Icons.check, color: LifeVerseColors.secondary, size: 18)),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text([
        if (dimension != null && dimension.isNotEmpty) _capitalize(dimension),
        if (parsedDate != null) '${DateFormat.MMMd().add_jm().format(parsedDate)} UTC',
      ].join(' · '), style: const TextStyle(color: LifeVerseColors.muted, fontSize: 12)),
      trailing: _int(item['xp']) > 0 ? Text('+${_int(item['xp'])} XP', style: const TextStyle(color: LifeVerseColors.warning, fontSize: 11)) : null,
    );
  }
}

Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int _int(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
int _activityCount(dynamic value) => _int(_map(value)['tasksCompleted']) + _int(_map(value)['reviewsCompleted']);
String _capitalize(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
String _date(dynamic value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value?.toString() ?? '');
  if (match == null) return '—';
  final date = DateTime.utc(int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
  return DateFormat.MMMd().format(date);
}
