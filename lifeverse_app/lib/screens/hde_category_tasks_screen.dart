import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/user_state.dart';
import '../services/api_service.dart';
import '../widgets/flashcard_widget.dart';
import '../widgets/daily_review_survey.dart';
import '../widgets/lifeverse_components.dart';
import '../theme/lifeverse_theme.dart';
import '../utils/app_snackbar.dart';

class HDECategoryTasksScreen extends StatefulWidget {
  const HDECategoryTasksScreen({super.key});

  @override
  State<HDECategoryTasksScreen> createState() => _HDECategoryTasksScreenState();
}

class _HDECategoryTasksScreenState extends State<HDECategoryTasksScreen> {
  List<dynamic> _tasks = [];
  List<dynamic> _flashcards = [];
  List<String> _surveyQuestions = [];
  bool _isLoading = true;
  bool _isLocked = false;
  bool _showSurvey = false;
  bool _surveySubmitting = false;
  String? _loadError;
  final Set<int> _pendingTaskIndices = <int>{};
  String _dimension = '';
  String _lockedMessage = '';
  Timer? _countdownTimer;
  String _timeUntilMidnight = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dimension.isEmpty) {
      _dimension =
          ModalRoute.of(context)!.settings.arguments as String? ?? 'General';
      _generateTasks();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startMidnightCountdown() {
    _updateTimer();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimer();
    });
  }

  void _updateTimer() {
    final now = DateTime.now().toUtc();
    final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);

    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

    if (mounted) {
      setState(() {
        _timeUntilMidnight = "$hours:$minutes:$seconds";
      });
    }
  }

  Future<void> _generateTasks() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final userId = Provider.of<UserState>(context, listen: false).userId;
      final response = await ApiService.generateHDETasks(userId, _dimension);

      setState(() {
        final data = response['data'] ?? {};
        final rawTasks = data['tasks'] as List<dynamic>? ?? [];
        _flashcards = data['flashcards'] ?? [];
        _surveyQuestions = List<String>.from(data['surveyQuestions'] ?? []);

        // Preserve all tasks (including completed), never drop completed tasks from UI
        _tasks = rawTasks
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();

        final allDone =
            _tasks.isNotEmpty && _tasks.every((t) => t['completed'] == true);
        _isLocked = (response['isLocked'] == true) || allDone;
        final surveySubmitted = response['surveySubmitted'] == true;
        _showSurvey = allDone && !surveySubmitted;

        if (_isLocked) {
          final msg = surveySubmitted
              ? 'All tasks and review completed! See you tomorrow.'
              : response['message']?.toString();
          _lockedMessage = (msg != null && msg.isNotEmpty)
              ? msg
              : "Training complete for today. Amazing work!";
          _startMidnightCountdown();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _loadError =
              'Today’s activities could not load. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeTask(dynamic task, int index) async {
    if (_pendingTaskIndices.contains(index) ||
        _tasks[index]['completed'] == true) {
      return;
    }
    final userId = Provider.of<UserState>(context, listen: false).userId;
    _pendingTaskIndices.add(index);

    setState(() {
      if (_tasks[index] is Map) {
        _tasks[index]['completed'] = true;
      }
    });

    try {
      final response = await ApiService.completeDailyTask(
        userId,
        _dimension,
        task['title'],
      );
      final allCompleted = response['allCompleted'] ?? false;

      if (mounted) {
        final xpGained = response['xpGained'] ?? 0;
        AppSnackBar.show(
          context,
          response['alreadyCompleted'] == true
              ? 'This quest was already completed and its XP is already in your profile.'
              : 'Quest saved. +$xpGained XP added to your profile.',
          isSuccess: true,
        );
      }

      if (allCompleted && mounted) {
        setState(() {
          _isLocked = true;
          _lockedMessage = "All tasks completed! Complete your daily review.";
          _showSurvey = true;
          _startMidnightCountdown();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tasks[index]['completed'] = false;
        });
        AppSnackBar.show(
          context,
          'Could not save the task. Try again.',
          isError: true,
        );
      }
    } finally {
      _pendingTaskIndices.remove(index);
    }
  }

  Future<void> _onSurveyComplete(List<Map<String, String>> answers) async {
    if (_surveySubmitting) return;
    _surveySubmitting = true;
    final userId = Provider.of<UserState>(context, listen: false).userId;
    try {
      await ApiService.submitDailySurvey(userId, _dimension, answers);
    } catch (e) {
      _surveySubmitting = false;
      if (mounted) {
        AppSnackBar.show(
          context,
          'Review was not saved. Tap Finish to retry.',
          isError: true,
        );
      }
      return;
    }

    _surveySubmitting = false;
    if (!mounted) return;
    setState(() {
      _showSurvey = false;
      _isLocked = true;
      _lockedMessage = "All tasks and review completed! See you tomorrow.";
      _startMidnightCountdown();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeVerseColors.canvas,
      appBar: AppBar(
        title: const Text('Evolution Matrix'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: LifeVerseColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Preparing your $_dimension activities…',
                    style: const TextStyle(color: LifeVerseColors.muted),
                  ),
                ],
              ),
            )
          else
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loadError != null) ...[
                        LvMessage(
                          title: 'Activities are temporarily unavailable',
                          message: _loadError!,
                          icon: Icons.cloud_off_outlined,
                          onRetry: _generateTasks,
                        ),
                      ] else if (_tasks.isEmpty && !_isLocked) ...[
                        const LvMessage(
                          title: 'No activities are available yet',
                          message:
                              'Try again in a moment, or choose another growth area in Evolution Matrix.',
                          icon: Icons.lightbulb_outline,
                          onRetry: null,
                        ),
                      ] else if (_tasks.isNotEmpty) ...[
                        Text(
                          _dimension,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _isLocked
                              ? 'Today’s activities'
                              : 'Complete a quest when you finish to add its XP to your profile. Each quest rewards XP once.',
                          style: const TextStyle(
                            color: LifeVerseColors.muted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ..._tasks.asMap().entries.map(
                          (entry) => _buildTaskCard(entry.value, entry.key),
                        ),
                      ],

                      if (_isLocked) ...[
                        const SizedBox(height: 15),
                        _buildLockedState(),
                      ],

                      if (_flashcards.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        const Text(
                          "Motivation & Care",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),
                        ..._flashcards.map(
                          (fc) => FlashcardWidget(
                            frontText: fc['frontText'] ?? '',
                            backText: fc['backText'] ?? '',
                            themeColor: _getThemeColor(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          if (_showSurvey)
            Positioned.fill(
              child: DailyReviewSurvey(
                questions: _surveyQuestions,
                onComplete: _onSurveyComplete,
              ),
            ),
        ],
      ),
    );
  }

  Color _getThemeColor() {
    switch (_dimension.toLowerCase()) {
      case 'physical':
        return LifeVerseColors.warning;
      case 'cognitive':
        return LifeVerseColors.primary;
      case 'psychosocial':
        return const Color(0xFFF0A7C9);
      case 'moral':
        return LifeVerseColors.secondary;
      default:
        return LifeVerseColors.primary;
    }
  }

  Widget _buildLockedState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: LifeVerseColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LifeVerseColors.line),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.lock_clock_outlined,
              color: LifeVerseColors.primary,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              _lockedMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              "Resets at 00:00 UTC in",
              style: TextStyle(color: LifeVerseColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 5),
            Text(
              _timeUntilMidnight,
              style: const TextStyle(
                color: LifeVerseColors.primary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(dynamic task, int index) {
    final title = task['title'] ?? 'Unknown Task';
    final desc = task['description'] ?? '';
    final exp = task['expReward'] ?? 25;
    final isDone = task['completed'] == true;
    final color = _getThemeColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isDone
            ? LifeVerseColors.success.withValues(alpha: .08)
            : LifeVerseColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone
              ? LifeVerseColors.success.withValues(alpha: .32)
              : LifeVerseColors.line,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isDone ? LifeVerseColors.success : color).withValues(
              alpha: .12,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDone ? Icons.check : Icons.star,
            color: isDone ? LifeVerseColors.success : color,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDone ? LifeVerseColors.muted : Colors.white,
            fontWeight: FontWeight.bold,
            decoration: isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              desc,
              style: TextStyle(
                color: LifeVerseColors.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isDone ? "Completed (+${exp} XP)" : "+$exp XP",
              style: TextStyle(
              color: isDone ? LifeVerseColors.success : LifeVerseColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: isDone
            ? const Icon(
                Icons.check_circle,
                color: LifeVerseColors.success,
                size: 28,
              )
            : IconButton(
                tooltip: 'Complete quest and claim $exp XP',
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: LifeVerseColors.primary,
                ),
                onPressed: () => _completeTask(task, index),
              ),
      ),
    );
  }
}
