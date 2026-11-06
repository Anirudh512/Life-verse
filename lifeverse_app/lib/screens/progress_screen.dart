import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/lifeverse_theme.dart';
import '../widgets/lifeverse_components.dart';

typedef ProgressAnalyticsLoader =
    Future<Map<String, dynamic>> Function(String userId, int days);

class ProgressScreen extends StatefulWidget {
  final ProgressAnalyticsLoader? analyticsLoader;
  const ProgressScreen({super.key, this.analyticsLoader});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _range = 7;
  String _userId = '';
  Future<Map<String, dynamic>>? _future;

  Future<Map<String, dynamic>> _load() =>
      widget.analyticsLoader?.call(_userId, _range) ??
      ApiService.getProgressAnalytics(_userId, days: _range);

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

  void _selectRange(int value) {
    if (_range == value) return;
    setState(() {
      _range = value;
      _future = _load();
    });
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
              title: 'Progress',
              subtitle:
                  'A clear view of the activity you have recorded in LifeVerse.',
              trailing: IconButton(
                tooltip: 'Refresh progress',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 days')),
                  ButtonSegment(value: 30, label: Text('30 days')),
                  ButtonSegment(value: 90, label: Text('90 days')),
                ],
                selected: {_range},
                onSelectionChanged: (values) => _selectRange(values.first),
                showSelectedIcon: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/weekly-review'),
                  icon: const Icon(Icons.calendar_view_week_outlined),
                  label: const Text('Open weekly review'),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_future == null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: LvMessage(
                  title: 'Sign in to see your progress',
                  message:
                      'Your activity summaries are private to your LifeVerse account.',
                ),
              )
            else
              FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _ProgressLoading(),
                    );
                  }
                  final data = snapshot.data;
                  if (snapshot.hasError || data?['success'] != true) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _ProgressLoadNotice(
                        response: data,
                        onRetry: _refresh,
                      ),
                    );
                  }
                  return _ProgressContent(
                    data: Map<String, dynamic>.from(data!),
                    days: _range,
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _ProgressLoading extends StatelessWidget {
  const _ProgressLoading();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: LifeVerseColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: LifeVerseColors.line),
    ),
    child: const Row(
      children: [
        SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Text(
          'Loading your saved progress…',
          style: TextStyle(color: LifeVerseColors.muted),
        ),
      ],
    ),
  );
}

class _ProgressLoadNotice extends StatelessWidget {
  final Map<String, dynamic>? response;
  final Future<void> Function() onRetry;
  const _ProgressLoadNotice({required this.response, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = response?['networkError'] == true
        ? 'LifeVerse could not reach the server. Check that the backend is running, then retry.'
        : response?['httpStatus'] == 401
        ? 'Your session may have expired. Sign in again to load your saved progress.'
        : 'Your saved progress could not load. Your records have not been changed.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LifeVerseColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LifeVerseColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: LifeVerseColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progress is temporarily unavailable',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: LifeVerseColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ProgressContent extends StatelessWidget {
  final Map<String, dynamic> data;
  final int days;
  const _ProgressContent({required this.data, required this.days});

  @override
  Widget build(BuildContext context) {
    final summary = _map(data['summary']);
    final availability = _map(data['availability']);
    final rawDaily = data['daily'];
    final daily = rawDaily is List
        ? rawDaily
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
    final dimensions = _map(data['dimensions']);
    final hdeStats = _map(data['hdeStats']);
    final levelDimensions = _map(hdeStats['dimensions']);
    final goalsRaw = data['goals'];
    final goals = goalsRaw is List
        ? goalsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
    final recentRaw = data['recentActivity'];
    final recent = recentRaw is List
        ? recentRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
    final visitsAvailable =
        availability['visits'] != false && summary['visitDays'] != null;
    final totalXpAvailable =
        availability['totalXp'] != false && summary['totalXp'] != null;
    final hdeStatsAvailable =
        availability['hdeStats'] != false && data['hdeStats'] is Map;
    final goalsAvailable = availability['goals'] != false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LvSurface(
            tint: LifeVerseColors.panel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your activity',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${totalXpAvailable ? _int(summary['totalXp']) : '—'} XP all time',
                      style: const TextStyle(
                        color: LifeVerseColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Recorded for the last $days days',
                  style: const TextStyle(
                    color: LifeVerseColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: LvSummaryMetric(
                        label: 'Visit days',
                        value: visitsAvailable
                            ? '${_int(summary['visitDays'])}'
                            : '—',
                        color: LifeVerseColors.primary,
                      ),
                    ),
                    const LvMetricDivider(),
                    Expanded(
                      child: LvSummaryMetric(
                        label: 'Growth days',
                        value: '${_int(summary['growthDays'])}',
                        color: LifeVerseColors.secondary,
                      ),
                    ),
                    const LvMetricDivider(),
                    Expanded(
                      child: LvSummaryMetric(
                        label: 'Tasks',
                        value: '${_int(summary['tasksCompleted'])}',
                        color: LifeVerseColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 7,
                  children: [
                    LvCompactFact(
                      label: 'Reviews',
                      value: '${_int(summary['reviewsCompleted'])}',
                    ),
                    LvCompactFact(
                      label: 'XP this period',
                      value: '${_int(summary['periodXp'])}',
                    ),
                    if (hdeStatsAvailable)
                      LvCompactFact(
                        label: 'Streak',
                        value: '${_int(hdeStats['currentStreak'])} days',
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Visit history starts when tracking was enabled. Earlier visits are unavailable. Dates use UTC.',
                  style: TextStyle(
                    color: LifeVerseColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const LvSectionTitle('Activity calendar'),
          LvSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${visitsAvailable ? _int(summary['visitDays']) : '—'} visit days · ${_int(summary['growthDays'])} growth days',
                  style: const TextStyle(color: LifeVerseColors.muted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: daily
                      .map((day) => _ActivityCell(day: day))
                      .toList(),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _Legend(
                      color: LifeVerseColors.raised,
                      label: 'No activity',
                    ),
                    _Legend(
                      color: LifeVerseColors.primary.withValues(alpha: .52),
                      label: 'Visit',
                    ),
                    _Legend(
                      color: LifeVerseColors.secondary,
                      label: 'Growth activity',
                    ),
                    _Legend(
                      color: LifeVerseColors.primary,
                      label: 'Both recorded',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const LvSectionTitle('Growth dimensions'),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 12) / 2;
              const specs = [
                (
                  'Physical',
                  'physical',
                  Icons.directions_run,
                  Color(0xFFF0C982),
                ),
                (
                  'Cognitive',
                  'cognitive',
                  Icons.psychology_alt_outlined,
                  Color(0xFF9CBFFF),
                ),
                (
                  'Psychosocial',
                  'psychosocial',
                  Icons.people_outline,
                  Color(0xFFF0A7C9),
                ),
                ('Moral', 'moral', Icons.balance_outlined, Color(0xFF8EDBD2)),
              ];
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: specs.map((spec) {
                  final item = _map(dimensions[spec.$2]);
                  final level = _map(levelDimensions[spec.$2]);
                  return SizedBox(
                    width: width,
                    child: _DimensionCard(
                      title: spec.$1,
                      data: item,
                      level: hdeStatsAvailable
                          ? _int(level['level'], fallback: 1)
                          : null,
                      icon: spec.$3,
                      color: spec.$4,
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'XP and activity counts describe LifeVerse records; they do not measure personal worth or prove improvement.',
            style: TextStyle(
              color: LifeVerseColors.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          LvSectionTitle(
            'Growth goals',
            actionLabel: 'Manage',
            onAction: () => Navigator.pushNamed(context, '/growth_goals'),
          ),
          if (!goalsAvailable)
            const LvMessage(
              title: 'Saved goals are unavailable',
              message:
                  'Your other progress records are still shown. Try again when the connection is restored.',
              icon: Icons.cloud_off_outlined,
            )
          else if (goals.isEmpty)
            const LvMessage(
              title: 'No goals yet',
              message:
                  'Create a goal to track tasks or active days in a growth dimension.',
              icon: Icons.flag_outlined,
            )
          else
            ...goals
                .take(5)
                .map(
                  (goal) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GoalCard(goal: goal),
                  ),
                ),
          const SizedBox(height: 24),
          const LvSectionTitle('Recent activity'),
          if (recent.isEmpty)
            const LvMessage(
              title: 'Your activity will appear here',
              message:
                  'Complete a growth task or save a meaningful LifeVerse record to begin your timeline.',
            )
          else
            LvSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < math.min(12, recent.length); i++) ...[
                    _ActivityRow(item: recent[i]),
                    if (i < math.min(12, recent.length) - 1)
                      const Divider(height: 1, indent: 56),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityCell extends StatelessWidget {
  final Map<String, dynamic> day;
  const _ActivityCell({required this.day});

  @override
  Widget build(BuildContext context) {
    final visitStatusKnown = day['visited'] is bool;
    final visited = day['visited'] == true;
    final growth = day['growthActivity'] == true;
    final date = day['date']?.toString() ?? '';
    final label = !visitStatusKnown
        ? growth
              ? 'Growth activity; visit tracking unavailable'
              : 'Visit tracking unavailable'
        : visited && growth
        ? 'Visit and growth activity'
        : visited
        ? 'Visit'
        : growth
        ? 'Growth activity'
        : 'No recorded activity';
    final color = visited && growth
        ? LifeVerseColors.primary
        : visited
        ? LifeVerseColors.primary.withValues(alpha: .52)
        : growth
        ? LifeVerseColors.secondary
        : LifeVerseColors.raised;
    return Semantics(
      label: '$date: $label',
      child: Tooltip(
        message: '$date · $label',
        child: Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: LifeVerseColors.line),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(color: LifeVerseColors.muted, fontSize: 11),
      ),
    ],
  );
}

class _DimensionCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  final int? level;
  final IconData icon;
  final Color color;
  const _DimensionCard({
    required this.title,
    required this.data,
    required this.level,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => LvSurface(
    padding: const EdgeInsets.all(15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              level == null ? '—' : 'Lv $level',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '${_int(data['tasksCompleted'])} tasks',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          '${_int(data['activeDays'])} active days · ${_int(data['xp'])} XP',
          style: const TextStyle(color: LifeVerseColors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  const _GoalCard({required this.goal});
  @override
  Widget build(BuildContext context) {
    final target = _int(goal['targetTasks']);
    final current = _int(goal['progressValue']);
    final progress = (target == 0 ? 0.0 : current / target)
        .clamp(0, 1)
        .toDouble();
    final metric = goal['progressMetric'] == 'active_days'
        ? 'active days'
        : 'tasks';
    final due = DateTime.tryParse(goal['dueDate']?.toString() ?? '');
    final nowUtc = DateTime.now().toUtc();
    final daysUntilDue = due == null
        ? null
        : DateTime.utc(due.year, due.month, due.day)
              .difference(DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day))
              .inDays;
    final deadlineLabel = goal['isOverdue'] == true
        ? 'Overdue'
        : daysUntilDue != null && daysUntilDue >= 0 && daysUntilDue <= 7
        ? 'Due soon'
        : null;
    return LvSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal['title']?.toString() ?? 'Growth goal',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: LifeVerseColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: LifeVerseColors.raised,
              color: LifeVerseColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$current of $target $metric${due == null ? '' : ' · Due ${DateFormat.MMMd().format(due)}'}${deadlineLabel == null ? '' : ' · $deadlineLabel'}',
            style: TextStyle(
              color: goal['isOverdue'] == true
                  ? LifeVerseColors.danger
                  : deadlineLabel != null
                  ? LifeVerseColors.warning
                  : LifeVerseColors.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ActivityRow({required this.item});
  @override
  Widget build(BuildContext context) {
    final type = item['actionType']?.toString() ?? 'Activity';
    final title = switch (type) {
      'TASK_COMPLETED' => 'Growth task completed',
      'SURVEY_SUBMITTED' => 'Daily review completed',
      'TIME_CAPSULE_CREATED' => 'Time capsule created',
      'TIME_CAPSULE_OPENED' => 'Time capsule opened',
      'LEGACY_EVENT_ADDED' => 'Life Atlas milestone added',
      _ => type.replaceAll('_', ' ').toLowerCase(),
    };
    final rawDate = item['createdAt']?.toString();
    final parsedDate = rawDate == null ? null : DateTime.tryParse(rawDate);
    final date = parsedDate?.toUtc();
    final dimension = item['dimension']?.toString();
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: LifeVerseColors.raised,
        child: Icon(Icons.check, color: LifeVerseColors.secondary, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          if (dimension != null && dimension.isNotEmpty) _capitalize(dimension),
          if (date != null) '${DateFormat.MMMd().add_jm().format(date)} UTC',
        ].join(' · '),
        style: const TextStyle(color: LifeVerseColors.muted, fontSize: 12),
      ),
      trailing: _int(item['xp']) > 0
          ? Text(
              '+${_int(item['xp'])} XP',
              style: const TextStyle(
                color: LifeVerseColors.warning,
                fontSize: 11,
              ),
            )
          : null,
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int _int(dynamic value, {int fallback = 0}) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
