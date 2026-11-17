import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/user_state.dart';
import '../services/api_service.dart';
import '../widgets/ai_data_notice.dart';
import '../theme/lifeverse_theme.dart';

class FutureSimulationScreen extends StatefulWidget {
  const FutureSimulationScreen({super.key});

  @override
  State<FutureSimulationScreen> createState() => _FutureSimulationScreenState();
}

class _FutureSimulationScreenState extends State<FutureSimulationScreen> {
  final TextEditingController _decisionController = TextEditingController();
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _simulation;
  String? _simulationId;
  bool? _simulationHelpful;
  String? _statusLoadError;
  bool _isLoading = true;
  bool _isSimulating = false;
  bool _isSavingFeedback = false;
  final Set<String> _committedTimelines = {};
  bool _isCommitting = false;

  Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _decisionController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    if (mounted)
      setState(() {
        _isLoading = true;
        _statusLoadError = null;
      });
    try {
      final userId = Provider.of<UserState>(context, listen: false).userId;
      if (userId.isEmpty)
        throw StateError('Sign in to load your Vision Engine.');
      final results = await Future.wait([
        ApiService.getFutureUnlockStatus(userId),
        ApiService.getLatestSimulation(userId),
      ]);
      final statusData = results[0];
      final simData = results[1];

      if (statusData['success'] == true &&
          statusData['status'] is Map &&
          mounted) {
        setState(
          () =>
              _status = Map<String, dynamic>.from(statusData['status'] as Map),
        );
      } else {
        throw StateError(
          statusData['message']?.toString() ?? 'Could not load growth data.',
        );
      }
      if (simData['success'] == true &&
          simData['simulation'] is Map &&
          mounted) {
        setState(() {
          _simulation = Map<String, dynamic>.from(simData['simulation'] as Map);
          _simulationId = simData['simulationId']?.toString();
          _simulationHelpful = simData['feedbackHelpful'] is bool
              ? simData['feedbackHelpful'] as bool
              : null;
          final decision = simData['decisionQuestion']?.toString();
          if (decision != null &&
              decision.isNotEmpty &&
              _decisionController.text.isEmpty) {
            _decisionController.text = decision;
          }
        });
      } else if (simData['success'] != true) {
        debugPrint(
          'Latest Vision Engine scenario unavailable: ${simData['message'] ?? 'unknown error'}',
        );
      }
    } catch (e) {
      if (mounted)
        setState(
          () => _statusLoadError = e.toString().replaceFirst('Bad state: ', ''),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _commitRecommendation(Map<String, dynamic> timeline) async {
    final title = timeline['title']?.toString() ?? 'Timeline Focus';
    final desc = timeline['description']?.toString() ?? '';
    final userId = Provider.of<UserState>(context, listen: false).userId;
    if (userId.isEmpty || _isCommitting) return;

    final dimension = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose a growth area'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Where should this recommendation appear in your Evolution Matrix?',
            ),
            for (final item in const [
              ('physical', 'Physical'),
              ('cognitive', 'Cognitive'),
              ('psychosocial', 'Psychosocial'),
              ('moral', 'Moral'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.$2),
                onTap: () => Navigator.pop(dialogContext, item.$1),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (dimension == null || !mounted) return;

    setState(() => _isCommitting = true);
    try {
      final res = await ApiService.commitSimulationRecommendation(
        userId,
        title: title,
        description: desc,
        dimension: dimension,
      );
      if (res['success'] == true && mounted) {
        setState(() {
          _committedTimelines.add(title);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Committed to Evolution Matrix!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to commit recommendation'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCommitting = false);
    }
  }

  Future<void> _runSimulation({String? decision}) async {
    final cleanedDecision = decision?.trim();
    if (cleanedDecision != null && cleanedDecision.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a decision to explore two scenarios.'),
        ),
      );
      return;
    }
    if (_isSimulating || _status?['unlocked'] != true) return;
    setState(() => _isSimulating = true);
    try {
      final userId = Provider.of<UserState>(context, listen: false).userId;
      final data = await ApiService.simulateFuture(
        userId,
        decisionQuestion: cleanedDecision,
      );
      if (data['success'] == true && mounted) {
        final simulation = data['simulation'];
        if (simulation is Map) {
          setState(() {
            _simulation = Map<String, dynamic>.from(simulation);
            _simulationId = data['simulationId']?.toString();
            _simulationHelpful = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The scenario response was incomplete. Please try again.',
              ),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['error']?.toString() ??
                  data['message']?.toString() ??
                  'Simulation unavailable',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  Future<void> _saveSimulationFeedback(bool helpful) async {
    final simulationId = _simulationId;
    final userId = Provider.of<UserState>(context, listen: false).userId;
    if (_isSavingFeedback || simulationId == null || userId.isEmpty) return;

    setState(() => _isSavingFeedback = true);
    final result = await ApiService.saveSimulationFeedback(
      userId,
      simulationId: simulationId,
      helpful: helpful,
    );
    if (!mounted) return;
    setState(() {
      _isSavingFeedback = false;
      if (result['success'] == true) _simulationHelpful = helpful;
    });
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not save feedback.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _status?['unlocked'] == true;
    final progress = (_status?['progress'] as num?)?.toInt() ?? 0;
    final currentData = (_status?['currentData'] as num?)?.toInt() ?? 0;
    final requiredData = (_status?['requiredData'] as num?)?.toInt() ?? 100;

    return Scaffold(
      backgroundColor: LifeVerseColors.canvas,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: LifeVerseColors.primary,
                          ),
                        )
                      : _statusLoadError != null && _status == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_off,
                                  color: Colors.white54,
                                  size: 42,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _statusLoadError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _loadStatus,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              Text(
                                "The Oracle",
                                style: TextStyle(
                                  color: LifeVerseColors.primary,
                                  fontSize: 14,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                "Vision Engine",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const AiDataNotice(),
                              const SizedBox(height: 24),

                              _buildStatusCard(
                                unlocked,
                                progress,
                                currentData,
                                requiredData,
                              ),

                              if (unlocked) ...[
                                const SizedBox(height: 40),
                                const Text(
                                  "Simulation Protocol",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                _buildDecisionSimulator(),
                                const SizedBox(height: 40),
                                const Text(
                                  "Neural Projection",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                _buildProjectionCard(),
                                if (_simulation != null) ...[
                                  const SizedBox(height: 25),
                                  _buildFeedbackCard(),
                                  const SizedBox(height: 12),
                                  _buildDisclaimerCard(),
                                ],
                              ],
                              const SizedBox(height: 50),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: LifeVerseColors.muted),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh your growth record',
            icon: const Icon(Icons.refresh, color: LifeVerseColors.muted),
            onPressed: _isLoading ? null : _loadStatus,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    bool unlocked,
    int progress,
    int currentData,
    int requiredData,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: LifeVerseColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: unlocked ? LifeVerseColors.primary : LifeVerseColors.line,
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: LifeVerseColors.primary.withValues(alpha: .12),
                      blurRadius: 20,
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                    unlocked ? Icons.visibility : Icons.visibility_off,
                    color: unlocked ? LifeVerseColors.primary : LifeVerseColors.muted,
                    size: 60,
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(end: 1.05, duration: 2.seconds),
              const SizedBox(height: 20),
              Text(
                unlocked
                    ? "Scenario Reflections Available"
                    : "Building Your Growth Record",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                unlocked
                    ? "Your recorded growth gives the Vision Engine enough context to explore possible paths. Scenarios remain uncertain and are yours to judge."
                    : "Complete and reflect on Evolution Matrix activities to build a useful record for grounded scenarios.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: unlocked ? Colors.white70 : Colors.white54,
                  fontSize: 14,
                ),
              ),
              if (!unlocked) ...[
                const SizedBox(height: 25),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 8,
                    backgroundColor: LifeVerseColors.line,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      LifeVerseColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "$currentData / $requiredData Data Points",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1);
  }

  Widget _buildDecisionSimulator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LifeVerseColors.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LifeVerseColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Crossroads Simulator",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Explore two plausible paths using your recorded growth, saved reflections, and choices. This is a thinking aid, not a prediction.",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _decisionController,
            style: const TextStyle(color: Colors.white),
            enabled: !_isSimulating,
            decoration: InputDecoration(
              hintText: "What if I...",
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: LifeVerseColors.raised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: _isSimulating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: LifeVerseColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.psychology,
                        color: LifeVerseColors.primary,
                      ),
                onPressed:
                    !_isSimulating && _decisionController.text.trim().isNotEmpty
                    ? () => _runSimulation(
                        decision: _decisionController.text.trim(),
                      )
                    : null,
              ),
            ),
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            onSubmitted: (value) => _runSimulation(decision: value),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionCard() {
    if (_simulation == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _isSimulating ? null : () => _runSimulation(),
          icon: _isSimulating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.flash_on, color: Colors.white),
          label: Text(
            _isSimulating
                ? 'Calculating Trajectories...'
                : 'Run General 1-Year Simulation',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: LifeVerseColors.primary,
            foregroundColor: LifeVerseColors.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      );
    }

    if (_simulation!.containsKey('timelineA')) {
      final timelineA = _asStringMap(_simulation!['timelineA']);
      final timelineB = _asStringMap(_simulation!['timelineB']);
      if (timelineA == null || timelineB == null) {
        return const Text(
          'This saved scenario is incomplete. Run a new reflection to replace it.',
          style: TextStyle(color: Colors.white70),
        );
      }
      return Column(
        children: [
          _buildEvidenceCard(),
          const SizedBox(height: 14),
          _buildTimelineCard(timelineA, LifeVerseColors.primary),
          const SizedBox(height: 20),
          _buildTimelineCard(timelineB, LifeVerseColors.secondary),
        ],
      ).animate().fadeIn(duration: 1.seconds);
    }

    final projection = _simulation!['projection']?.toString() ?? '';
    final milestones =
        (_simulation!['milestones'] as List?)?.whereType<String>().toList() ??
        [];
    final risks =
        (_simulation!['risks'] as List?)?.whereType<String>().toList() ?? [];

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: LifeVerseColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LifeVerseColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEvidenceCard(),
          const SizedBox(height: 16),
          Text(
            projection,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 25),
          if (milestones.isNotEmpty) ...[
            const Text(
              "Possible milestones",
              style: TextStyle(
                color: LifeVerseColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...milestones.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: LifeVerseColors.secondary,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        m,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (risks.isNotEmpty) ...[
            const Text(
              "Things to consider",
              style: TextStyle(
                color: LifeVerseColors.warning,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...risks.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: LifeVerseColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if ((_simulation!['nextStep']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'A small next step',
              style: TextStyle(
                color: LifeVerseColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _simulation!['nextStep'].toString(),
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 1.seconds);
  }

  Widget _buildEvidenceCard() {
    final basis = _asStringMap(_simulation?['basis']);
    if (basis == null) return const SizedBox.shrink();

    final metrics = <(String, String)>[
      (
        'Tasks',
        '${basis['completedTasks'] ?? 0}/${basis['taskRecords'] ?? 0} completed',
      ),
      (
        'Activity',
        '${basis['activeDays'] ?? 0} days, ${basis['activityRecords'] ?? 0} records',
      ),
      ('Reflections', '${basis['reflections'] ?? 0}'),
      ('Choices', '${basis['loggedChoices'] ?? 0}'),
      ('Saved facts', '${basis['savedFacts'] ?? 0}'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LifeVerseColors.raised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LifeVerseColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Records used for this reflection',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metrics
                .map(
                  (metric) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: LifeVerseColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${metric.$1}: ${metric.$2}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            basis['coverageNote']?.toString() ??
                'Counts describe available records, not prediction accuracy.',
            style: const TextStyle(
              color: LifeVerseColors.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic>? timeline, Color color) {
    if (timeline == null) return const SizedBox.shrink();
    final title = timeline['title']?.toString() ?? 'Timeline';
    final isCommitted = _committedTimelines.contains(title);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LifeVerseColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LifeVerseColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            timeline['description']?.toString() ?? '',
            style: const TextStyle(color: Colors.white, height: 1.5),
          ),
          if ((timeline['nextStep']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Next step: ${timeline['nextStep']}',
              style: TextStyle(color: color, height: 1.4),
            ),
          ],
          if (timeline['risk'] != null) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LifeVerseColors.raised,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Risk: ${timeline['risk']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 15),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isCommitted || _isCommitting
                  ? null
                  : () => _commitRecommendation(timeline),
              icon: Icon(
                isCommitted ? Icons.check : Icons.add_task,
                color: isCommitted ? LifeVerseColors.success : color,
                size: 16,
              ),
              label: Text(
                isCommitted ? 'Committed to Matrix' : 'Commit as Quest',
                style: TextStyle(
                  color: isCommitted ? LifeVerseColors.success : color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: color.withValues(alpha: .12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    final disclaimer =
        _simulation?['disclaimer']?.toString() ??
        'Advisory: Future simulations are AI-generated speculative possibilities based on habit trajectories, not guaranteed predictions.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: LifeVerseColors.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LifeVerseColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: LifeVerseColors.muted, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              disclaimer,
              style: const TextStyle(
                color: LifeVerseColors.muted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard() {
    if (_simulationId == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: LifeVerseColors.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LifeVerseColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Was this reflection useful?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _simulationHelpful == null
                      ? 'Your rating helps tune future guidance.'
                      : 'Thanks. You can update your rating anytime.',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'This was useful',
            onPressed: _isSavingFeedback
                ? null
                : () => _saveSimulationFeedback(true),
            icon: Icon(
              Icons.thumb_up_alt_outlined,
              color: _simulationHelpful == true
                  ? LifeVerseColors.success
                  : LifeVerseColors.muted,
            ),
          ),
          IconButton(
            tooltip: 'This was not useful',
            onPressed: _isSavingFeedback
                ? null
                : () => _saveSimulationFeedback(false),
            icon: Icon(
              Icons.thumb_down_alt_outlined,
              color: _simulationHelpful == false
                  ? LifeVerseColors.warning
                  : LifeVerseColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
