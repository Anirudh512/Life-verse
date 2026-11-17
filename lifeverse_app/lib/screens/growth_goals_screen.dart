import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/user_state.dart';
import '../theme/lifeverse_theme.dart';

typedef GrowthGoalsLoader = Future<Map<String, dynamic>> Function(String userId);
typedef GrowthGoalCreator = Future<Map<String, dynamic>> Function({
  required String userId,
  required String title,
  required String dimension,
  required int targetTasks,
  required String dueDate,
  required bool reminderEnabled,
  required String progressMetric,
});
typedef GrowthGoalUpdater = Future<Map<String, dynamic>> Function({
  required String userId,
  required String goalId,
  required String title,
  required String dimension,
  required int targetTasks,
  required String dueDate,
  required bool reminderEnabled,
  required String progressMetric,
});
typedef GrowthGoalDeleter = Future<Map<String, dynamic>> Function(
  String userId,
  String goalId,
);

class GrowthGoalsScreen extends StatefulWidget {
  final GrowthGoalsLoader? goalsLoader;
  final GrowthGoalCreator? goalCreator;
  final GrowthGoalUpdater? goalUpdater;
  final GrowthGoalDeleter? goalDeleter;

  const GrowthGoalsScreen({
    super.key,
    this.goalsLoader,
    this.goalCreator,
    this.goalUpdater,
    this.goalDeleter,
  });

  @override
  State<GrowthGoalsScreen> createState() => _GrowthGoalsScreenState();
}

class _GrowthGoalsScreenState extends State<GrowthGoalsScreen> {
  Future<List<Map<String, dynamic>>>? _goalsFuture;
  String _userId = '';
  bool _saving = false;

  Future<List<Map<String, dynamic>>> _loadGoals(String userId) async {
    final response = await (widget.goalsLoader?.call(userId) ??
        ApiService.getGrowthGoals(userId));
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Could not load your goals.');
    }
    final rawGoals = response['goals'];
    if (rawGoals is! List) return [];
    final goals = rawGoals
        .whereType<Map>()
        .map((goal) => Map<String, dynamic>.from(goal))
        .toList();
    try {
      final supportedPlatform = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      final remindersAllowed = supportedPlatform
          ? (await Permission.notification.status).isGranted
          : false;
      await NotificationService.syncGrowthGoalReminders(
        remindersAllowed ? goals : const <Map<String, dynamic>>[],
      );
    } catch (error) {
      debugPrint('Growth goal reminders could not be synchronized: $error');
    }
    return goals;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<UserState>().userId;
    if (userId != _userId) {
      _userId = userId;
      _goalsFuture = userId.isEmpty ? null : _loadGoals(userId);
    }
  }

  Future<void> _refresh() async {
    if (_userId.isEmpty) return;
    final future = _loadGoals(_userId);
    setState(() => _goalsFuture = future);
    try {
      await future;
    } catch (_) {
      // The FutureBuilder below shows the error and offers a retry action.
    }
  }

  Future<void> _addGoal() => _saveGoal();

  Future<void> _editGoal(Map<String, dynamic> goal) => _saveGoal(goal);

  Future<void> _saveGoal([Map<String, dynamic>? existingGoal]) async {
    final draft = await _showGoalDialog(context, existingGoal: existingGoal);
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      var reminderEnabled = draft.reminderEnabled;
      var reminderPermissionMissing = false;
      final supportedPlatform = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (reminderEnabled && !supportedPlatform) {
        if (existingGoal == null) {
          reminderEnabled = false;
          reminderPermissionMissing = true;
        }
      } else if (reminderEnabled) {
        try {
          reminderEnabled = (await Permission.notification.request()).isGranted;
          reminderPermissionMissing = !reminderEnabled;
        } catch (_) {
          reminderEnabled = false;
          reminderPermissionMissing = true;
        }
      }

      final response = existingGoal == null
          ? await (widget.goalCreator?.call(
                  userId: _userId,
                  title: draft.title,
                  dimension: draft.dimension,
                  targetTasks: draft.targetTasks,
                  dueDate: draft.dueDate,
                  reminderEnabled: reminderEnabled,
                  progressMetric: draft.progressMetric,
                ) ??
              ApiService.createGrowthGoal(
                userId: _userId,
                title: draft.title,
                dimension: draft.dimension,
                targetTasks: draft.targetTasks,
                dueDate: draft.dueDate,
                reminderEnabled: reminderEnabled,
                progressMetric: draft.progressMetric,
              ))
          : await (widget.goalUpdater?.call(
                  userId: _userId,
                  goalId: '${existingGoal['id']}',
                  title: draft.title,
                  dimension: draft.dimension,
                  targetTasks: draft.targetTasks,
                  dueDate: draft.dueDate,
                  reminderEnabled: reminderEnabled,
                  progressMetric: draft.progressMetric,
                ) ??
              ApiService.updateGrowthGoal(
                userId: _userId,
                goalId: '${existingGoal['id']}',
                title: draft.title,
                dimension: draft.dimension,
                targetTasks: draft.targetTasks,
                dueDate: draft.dueDate,
                reminderEnabled: reminderEnabled,
                progressMetric: draft.progressMetric,
              ));
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Could not save this goal.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reminderPermissionMissing
                ? 'Goal saved. Notifications are disabled, so no reminder was scheduled.'
                : existingGoal == null
                    ? 'Growth goal saved.'
                    : 'Growth goal updated.',
          ),
        ),
      );
      await _refresh();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteGoal(Map<String, dynamic> goal) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this goal?'),
        content: Text('“${goal['title'] ?? 'Growth goal'}” will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    try {
      final response = await (widget.goalDeleter?.call(
            _userId,
            '${goal['id'] ?? ''}',
          ) ??
          ApiService.deleteGrowthGoal(_userId, '${goal['id'] ?? ''}'));
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Could not delete this goal.');
      }
      try {
        await NotificationService.cancelGrowthGoalReminder(
          '${goal['id'] ?? ''}',
        );
      } catch (error) {
        debugPrint('Growth goal reminder could not be cancelled: $error');
      }
      await _refresh();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeVerseColors.canvas,
      appBar: AppBar(
        title: const Text('Growth goals'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            const Text(
              'Turn a personal intention into steady progress.',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose task totals or active days. Progress uses all activity in the selected HDE dimension.',
              style: TextStyle(color: LifeVerseColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            if (_saving) const LinearProgressIndicator(minHeight: 2),
            if (_userId.isEmpty)
              const _GoalMessage(
                icon: Icons.account_circle_outlined,
                title: 'Sign in to save goals',
                body: 'Your personal goals are stored with your LifeVerse account.',
              )
            else if (_goalsFuture == null)
              const _GoalMessage(
                icon: Icons.flag_outlined,
                title: 'Your goals will appear here',
                body: 'Create a goal to track task progress in an HDE dimension.',
              )
            else
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _goalsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _GoalMessage(
                      icon: Icons.cloud_off_outlined,
                      title: 'Goals could not be loaded',
                      body: snapshot.error.toString().replaceFirst('Exception: ', ''),
                      action: TextButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    );
                  }
                  final goals = snapshot.data ?? [];
                  final canAddGoal = goals.length < 10;
                  if (goals.isEmpty) {
                    return _GoalMessage(
                      icon: Icons.flag_outlined,
                      title: 'No goals yet',
                      body: '0 of 10 saved. Set a progress measure and due date to make your next step measurable.',
                      action: FilledButton.icon(
                        onPressed: _saving ? null : _addGoal,
                        icon: const Icon(Icons.add),
                        label: const Text('Create a goal'),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final goal in goals)
                        _GrowthGoalCard(
                          goal: goal,
                          onEdit: () => _editGoal(goal),
                          onDelete: () => _deleteGoal(goal),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${goals.length} of 10 saved goals',
                          style: const TextStyle(
                            color: LifeVerseColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (canAddGoal)
                        TextButton.icon(
                          onPressed: _saving ? null : _addGoal,
                          icon: const Icon(Icons.add),
                          label: const Text('Add another goal'),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'You have reached the 10-goal limit. Delete a goal to add another.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: LifeVerseColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

Future<_GoalDraft?> _showGoalDialog(
  BuildContext context, {
  Map<String, dynamic>? existingGoal,
}) async {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController(
    text: existingGoal?['title']?.toString() ?? '',
  );
  final targetController = TextEditingController(
    text: existingGoal?['targetTasks']?.toString() ?? '10',
  );
  var dimension = existingGoal?['dimension']?.toString().toLowerCase() ??
      'physical';
  const validDimensions = {'physical', 'cognitive', 'psychosocial', 'moral'};
  if (!validDimensions.contains(dimension)) {
    dimension = 'physical';
  }
  var progressMetric =
      existingGoal?['progressMetric']?.toString() == 'active_days'
          ? 'active_days'
          : 'tasks';
  var dueDate = DateTime.tryParse('${existingGoal?['dueDate'] ?? ''}') ??
      DateTime.now().add(const Duration(days: 30));
  var reminderEnabled = existingGoal?['reminderEnabled'] == true ||
      existingGoal?['reminderEnabled'] == 1 ||
      existingGoal?['reminderEnabled'] == '1';
  final remindersSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final today = DateUtils.dateOnly(DateTime.now());
  final latestDay = today.add(const Duration(days: 365));

  final draft = await showDialog<_GoalDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(
          existingGoal == null ? 'Create a growth goal' : 'Edit growth goal',
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Goal',
                    hintText: 'e.g. Build a consistent exercise habit',
                  ),
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    return length < 3 ? 'Enter at least 3 characters.' : null;
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 2, bottom: 4),
                    child: Text(
                      progressMetric == 'active_days'
                          ? 'Progress counts distinct days with at least one completed task in this HDE dimension.'
                          : 'Progress counts all completed tasks in this HDE dimension.',
                      style: const TextStyle(
                        color: LifeVerseColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: dimension,
                  decoration: const InputDecoration(labelText: 'HDE dimension'),
                  items: const [
                    DropdownMenuItem(value: 'physical', child: Text('Physical')),
                    DropdownMenuItem(value: 'cognitive', child: Text('Cognitive')),
                    DropdownMenuItem(value: 'psychosocial', child: Text('Psychosocial')),
                    DropdownMenuItem(value: 'moral', child: Text('Moral')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => dimension = value);
                  },
                ),
                DropdownButtonFormField<String>(
                  value: progressMetric,
                  decoration: const InputDecoration(labelText: 'Measure progress by'),
                  items: const [
                    DropdownMenuItem(
                      value: 'tasks',
                      child: Text('Completed tasks'),
                    ),
                    DropdownMenuItem(
                      value: 'active_days',
                      child: Text('Active days'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => progressMetric = value);
                    }
                  },
                ),
                TextFormField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: progressMetric == 'active_days'
                        ? 'Active days to reach'
                        : 'Completed tasks to reach',
                    helperText: 'Choose a target from 1 to 100.',
                  ),
                  validator: (value) {
                    final target = int.tryParse(value ?? '');
                    return target == null || target < 1 || target > 100
                        ? 'Enter a whole number from 1 to 100.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: dueDate.isBefore(today) ? today : dueDate,
                        firstDate: today,
                        lastDate: latestDay,
                      );
                      if (selected != null) {
                        setDialogState(() => dueDate = selected);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Due ${DateFormat.yMMMd().format(dueDate)}'),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: reminderEnabled,
                  onChanged: remindersSupported
                      ? (value) => setDialogState(
                          () => reminderEnabled = value,
                        )
                      : null,
                  title: const Text('Remind me before the due date'),
                  subtitle: Text(
                    remindersSupported
                        ? 'Around 9:00 a.m. the day before, or on the due date if set later. Android may delay delivery.'
                        : 'Local goal reminders are available on Android and iOS.',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                _GoalDraft(
                  title: titleController.text.trim(),
                  dimension: dimension,
                  targetTasks: int.parse(targetController.text.trim()),
                  dueDate: DateFormat('yyyy-MM-dd').format(dueDate),
                  reminderEnabled: reminderEnabled,
                  progressMetric: progressMetric,
                ),
              );
            },
            child: Text(existingGoal == null ? 'Save goal' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
  titleController.dispose();
  targetController.dispose();
  return draft;
}

class _GoalDraft {
  final String title;
  final String dimension;
  final int targetTasks;
  final String dueDate;
  final bool reminderEnabled;
  final String progressMetric;

  const _GoalDraft({
    required this.title,
    required this.dimension,
    required this.targetTasks,
    required this.dueDate,
    required this.reminderEnabled,
    required this.progressMetric,
  });
}

class _GrowthGoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GrowthGoalCard({
    required this.goal,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const dimensions = {
      'physical': ('Physical', LifeVerseColors.warning),
      'cognitive': ('Cognitive', LifeVerseColors.primary),
      'psychosocial': ('Psychosocial', Color(0xFFF0A7C9)),
      'moral': ('Moral', LifeVerseColors.secondary),
    };
    final dimension = dimensions[goal['dimension']?.toString().toLowerCase()] ??
        ('Growth', LifeVerseColors.primary);
    final target = _goalInt(
      goal['targetTasks'],
      fallback: 1,
    ).clamp(1, 100).toInt();
    final progressValue = _goalInt(
      goal['progressValue'] ?? goal['completedTasks'],
    );
    final progress = (progressValue / target).clamp(0.0, 1.0).toDouble();
    final isActiveDayGoal = goal['progressMetric'] == 'active_days';
    final progressUnit = isActiveDayGoal ? 'days' : 'tasks';
    final isComplete = goal['isComplete'] == true || progressValue >= target;
    final isOverdue = goal['isOverdue'] == true && !isComplete;
    final dueDate = DateTime.tryParse('${goal['dueDate'] ?? ''}');
    final status = isComplete ? 'Complete' : isOverdue ? 'Overdue' : 'In progress';
    final statusColor = isComplete
        ? LifeVerseColors.success
        : isOverdue
            ? LifeVerseColors.danger
            : LifeVerseColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LifeVerseColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LifeVerseColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${goal['title'] ?? 'Growth goal'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit goal',
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: LifeVerseColors.muted),
              ),
              IconButton(
                tooltip: 'Delete goal',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: LifeVerseColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                dimension.$1,
                style: TextStyle(color: dimension.$2, fontSize: 12),
              ),
              const Spacer(),
              Text(
                status,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: LifeVerseColors.line,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$progressValue of $target $progressUnit',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const Spacer(),
              Text(
                dueDate == null
                    ? 'Due date unavailable'
                    : 'Due ${DateFormat.yMMMd().format(dueDate)}',
                style: const TextStyle(color: LifeVerseColors.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const _GoalMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: LifeVerseColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: LifeVerseColors.line),
        ),
        child: Column(
          children: [
            Icon(icon, color: LifeVerseColors.primary, size: 30),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: LifeVerseColors.muted, height: 1.4)),
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      );
}

int _goalInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
