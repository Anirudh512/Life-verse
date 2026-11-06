import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/capsule_delivery_service.dart';
import '../services/user_state.dart';
import '../theme/lifeverse_theme.dart';
import '../widgets/lifeverse_components.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with WidgetsBindingObserver {
  String _userId = '';
  Future<Map<String, dynamic>>? _summary;
  bool _visitRequestRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _activateVisit());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.read<UserState>().userId;
    if (id != _userId) {
      _userId = id;
      _summary = id.isEmpty
          ? null
          : ApiService.getProgressAnalytics(id, days: 7);
    }
  }

  Future<void> _activateVisit() async {
    if (!mounted || _userId.isEmpty || _visitRequestRunning) return;
    _visitRequestRunning = true;
    try {
      final result = await ApiService.recordAppVisit();
      if (result['success'] != true) {
        debugPrint(
          'LifeVerse visit could not be recorded: ${result['message'] ?? 'server unavailable'}',
        );
      }
    } catch (error) {
      debugPrint('LifeVerse visit could not be recorded: $error');
    } finally {
      _visitRequestRunning = false;
    }
    await _refreshSummary();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _userId.isNotEmpty) {
      unawaited(_activateVisit());
      unawaited(
        CapsuleDeliveryService.checkAndShowDeliveries(context, _userId),
      );
    }
  }

  Future<void> _refreshSummary() async {
    if (_userId.isEmpty) return;
    final next = ApiService.getProgressAnalytics(_userId, days: 7);
    if (mounted) setState(() => _summary = next);
    try {
      await next;
    } catch (error) {
      debugPrint('LifeVerse home summary could not load: $error');
    }
  }

  Future<void> _refresh() => _refreshSummary();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserState>();
    final name = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()
        : user.username.trim();
    final guideDismissed = user.appState['homeGuideDismissed'] == true;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: LifeVerseColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  LvPageHeader(
                    title: name.isEmpty ? 'LifeVerse' : 'Welcome back, $name',
                    subtitle: DateFormat.yMMMMEEEEd().format(DateTime.now()),
                    trailing: CircleAvatar(
                      backgroundColor: LifeVerseColors.raised,
                      child: Text(
                        name.isEmpty ? 'L' : name[0].toUpperCase(),
                        style: const TextStyle(
                          color: LifeVerseColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (!guideDismissed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _WelcomeGuide(
                        onExplore: () =>
                            Navigator.pushNamed(context, '/hde_dashboard'),
                        onDismiss: () =>
                            user.updateAppState({'homeGuideDismissed': true}),
                      ),
                    ),
                  if (!guideDismissed) const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _summary == null
                        ? const _InlineNotice(
                            title: 'Sign in to see your saved activity',
                            message:
                                'Your LifeVerse records are private to your account.',
                          )
                        : FutureBuilder<Map<String, dynamic>>(
                            future: _summary,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const _SummaryLoading();
                              }
                              final data = snapshot.data;
                              if (snapshot.hasError ||
                                  data?['success'] != true) {
                                return _InlineNotice(
                                  title: 'Your activity could not load',
                                  message: _friendlyError(data),
                                  onRetry: _refresh,
                                );
                              }
                              return _HomeSummary(
                                data: Map<String, dynamic>.from(data!),
                              );
                            },
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
}

class _WelcomeGuide extends StatelessWidget {
  final VoidCallback onExplore;
  final VoidCallback onDismiss;
  const _WelcomeGuide({required this.onExplore, required this.onDismiss});

  @override
  Widget build(BuildContext context) => LvSurface(
    tint: LifeVerseColors.panel,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.waving_hand_outlined,
              color: LifeVerseColors.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to LifeVerse',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Choose an area, try one small activity, then see what you have recorded in Progress.',
                    style: TextStyle(color: LifeVerseColors.muted, height: 1.4),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss welcome guide',
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onExplore,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Choose an area'),
            ),
            TextButton(onPressed: onDismiss, child: const Text('Skip for now')),
          ],
        ),
      ],
    ),
  );
}

class _HomeSummary extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HomeSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final summary = _map(data['summary']);
    final availability = _map(data['availability']);
    final rawGoals = data['goals'];
    final goalsAvailable = availability['goals'] != false;
    final goals = rawGoals is List
        ? rawGoals
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where((goal) => goal['isComplete'] != true)
              .toList()
        : <Map<String, dynamic>>[];
    final rawRecent = data['recentActivity'];
    final recent = rawRecent is List
        ? rawRecent
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final visitsAvailable =
        availability['visits'] != false && summary['visitDays'] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SuggestedStep(
          goal: goals.isEmpty ? null : goals.first,
          goalsAvailable: goalsAvailable,
        ),
        const SizedBox(height: 18),
        LvSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your recorded week',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              const Text(
                'A quick look at activity saved in LifeVerse.',
                style: TextStyle(color: LifeVerseColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 440 ? 2 : 3;
                  final gap = 10.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  final stats = [
                    _QuickStat(
                      label: 'Visit days',
                      value: visitsAvailable
                          ? '${_int(summary['visitDays'])}'
                          : '—',
                      icon: Icons.event_available_outlined,
                      detail: visitsAvailable ? 'App opened' : 'Unavailable',
                    ),
                    _QuickStat(
                      label: 'Growth days',
                      value: '${_int(summary['growthDays'])}',
                      icon: Icons.auto_awesome_outlined,
                      detail: 'Task or review',
                    ),
                    _QuickStat(
                      label: 'Tasks',
                      value: '${_int(summary['tasksCompleted'])}',
                      icon: Icons.check_circle_outline,
                      detail: 'Completed',
                    ),
                  ];
                  return Wrap(
                    spacing: gap,
                    runSpacing: 10,
                    children: stats.asMap().entries.map((entry) {
                      final fillRow =
                          columns == 2 && entry.key == stats.length - 1;
                      return SizedBox(
                        width: fillRow ? constraints.maxWidth : width,
                        child: entry.value,
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Visit tracking begins when enabled. Earlier visits are unavailable.',
                style: TextStyle(
                  color: LifeVerseColors.muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const LvSectionTitle('Recent activity'),
        if (recent.isEmpty)
          const _InlineNotice(
            title: 'Your timeline is ready',
            message:
                'Completed tasks, reviews, and milestones will appear here when saved.',
          )
        else
          LvSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < recent.length && index < 3;
                  index++
                ) ...[
                  _RecentRecord(item: recent[index]),
                  if (index < recent.length - 1 && index < 2)
                    const Divider(height: 1, indent: 56),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _SuggestedStep extends StatelessWidget {
  final Map<String, dynamic>? goal;
  final bool goalsAvailable;
  const _SuggestedStep({required this.goal, required this.goalsAvailable});

  @override
  Widget build(BuildContext context) {
    final hasGoal = goal != null;
    final available = goalsAvailable;
    final title = !available
        ? 'Choose an activity that feels useful today'
        : hasGoal
        ? 'Continue your goal: ${goal!['title']?.toString() ?? 'Growth goal'}'
        : 'Start with one small activity';
    final action = !available
        ? 'Open Evolution Matrix'
        : hasGoal
        ? 'Review goal'
        : 'Choose an area';
    final route = !available || !hasGoal ? '/hde_dashboard' : '/growth_goals';

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A small step for today',
              style: TextStyle(color: LifeVerseColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        );
        final button = FilledButton(
          onPressed: () => Navigator.pushNamed(context, route),
          child: Text(action),
        );
        return LvSurface(
          tint: LifeVerseColors.panel,
          child: constraints.maxWidth < 520
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: LifeVerseColors.raised,
                          child: Icon(
                            Icons.wb_sunny_outlined,
                            color: LifeVerseColors.primary,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(child: titleBlock),
                      ],
                    ),
                    const SizedBox(height: 12),
                    button,
                  ],
                )
              : Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: LifeVerseColors.raised,
                      child: Icon(
                        Icons.wb_sunny_outlined,
                        color: LifeVerseColors.primary,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(child: titleBlock),
                    const SizedBox(width: 8),
                    button,
                  ],
                ),
        );
      },
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  const _QuickStat({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: LifeVerseColors.raised,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: LifeVerseColors.primary, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                detail,
                style: const TextStyle(
                  color: LifeVerseColors.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InlineNotice extends StatelessWidget {
  final String title;
  final String message;
  final Future<void> Function()? onRetry;
  const _InlineNotice({
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: LifeVerseColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: LifeVerseColors.line),
    ),
    child: Row(
      children: [
        Icon(
          onRetry == null ? Icons.info_outline : Icons.cloud_off_outlined,
          color: LifeVerseColors.primary,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
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
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _SummaryLoading extends StatelessWidget {
  const _SummaryLoading();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          'Loading your saved activity…',
          style: TextStyle(color: LifeVerseColors.muted),
        ),
      ],
    ),
  );
}

class _RecentRecord extends StatelessWidget {
  final Map<String, dynamic> item;
  const _RecentRecord({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = item['actionType']?.toString() ?? '';
    final label = switch (type) {
      'TASK_COMPLETED' => 'Growth task completed',
      'SURVEY_SUBMITTED' => 'Daily review completed',
      'TIME_CAPSULE_CREATED' => 'Time capsule created',
      'TIME_CAPSULE_OPENED' => 'Time capsule opened',
      'LEGACY_EVENT_ADDED' => 'Life Atlas milestone added',
      _ => type.replaceAll('_', ' ').toLowerCase(),
    };
    final rawDate = item['createdAt']?.toString();
    final parsedDate = rawDate == null
        ? null
        : DateTime.tryParse(rawDate)?.toUtc();
    final dateLabel = parsedDate == null
        ? null
        : DateFormat.MMMd().format(parsedDate);
    return ListTile(
      dense: true,
      leading: const CircleAvatar(
        backgroundColor: LifeVerseColors.raised,
        child: Icon(Icons.check, color: LifeVerseColors.secondary, size: 17),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          if (item['dimension']?.toString().isNotEmpty == true)
            _capitalize(item['dimension'].toString()),
          ?dateLabel,
        ].join(' · '),
        style: const TextStyle(color: LifeVerseColors.muted, fontSize: 11),
      ),
    );
  }
}

String _friendlyError(Map<String, dynamic>? response) {
  if (response?['networkError'] == true) {
    return 'LifeVerse could not reach the server. Check that the backend is running, then retry.';
  }
  if (response?['httpStatus'] == 401) {
    return 'Your session may have expired. Sign in again to load your saved activity.';
  }
  return 'Your saved activity could not load right now. Your records have not been changed.';
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
