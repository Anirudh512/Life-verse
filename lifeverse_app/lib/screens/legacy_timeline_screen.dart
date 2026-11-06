import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/lifeverse_theme.dart';
import '../widgets/ai_data_notice.dart';
import '../widgets/lifeverse_components.dart';

class LegacyTimelineScreen extends StatefulWidget {
  const LegacyTimelineScreen({super.key});

  @override
  State<LegacyTimelineScreen> createState() => _LegacyTimelineScreenState();
}

class _LegacyTimelineScreenState extends State<LegacyTimelineScreen> {
  final _biographyController = TextEditingController();
  List<dynamic> _timeline = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isSavingBiography = false;
  bool _isBiographyDraft = false;
  bool _includeDailyReviews = true;
  String? _biography;
  String? _loadError;
  Map<String, dynamic>? _draftSources;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  @override
  void dispose() {
    _biographyController.dispose();
    super.dispose();
  }

  Future<void> _loadTimeline() async {
    final userId = Provider.of<UserState>(context, listen: false).userId;
    if (userId.isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError = 'Sign in to load your saved milestones.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final data = await ApiService.getLegacyTimeline(userId);
      if (!mounted) return;
      if (data['success'] == true) {
        final biography = data['biography']?.toString();
        setState(() {
          _timeline = data['timeline'] is List ? data['timeline'] as List : [];
          _biography = biography;
          if (!_isBiographyDraft) _biographyController.text = biography ?? '';
        });
      } else {
        setState(
          () => _loadError =
              data['message']?.toString() ??
              'Your Life Atlas could not be loaded.',
        );
      }
    } catch (_) {
      if (mounted)
        setState(() => _loadError = 'Check your connection, then try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAutobiography() async {
    final userId = Provider.of<UserState>(context, listen: false).userId;
    if (userId.isEmpty) return;
    setState(() => _isGenerating = true);
    try {
      final data = await ApiService.generateAIBiography(
        userId,
        save: false,
        includeReflections: _includeDailyReviews,
      );
      if (!mounted) return;
      if (data['success'] == true && data['biography'] is String) {
        if (data['hasSources'] == false) {
          _showMessage(data['biography'] as String);
          return;
        }
        setState(() {
          _biographyController.text = data['biography'] as String;
          _isBiographyDraft = true;
          _draftSources = data['sources'] is Map
              ? Map<String, dynamic>.from(data['sources'] as Map)
              : null;
        });
      } else {
        _showMessage(
          data['message']?.toString() ??
              'The biography draft could not be created.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted)
        _showMessage(
          'The biography draft could not be created. Try again.',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _saveBiography() async {
    final userId = Provider.of<UserState>(context, listen: false).userId;
    final text = _biographyController.text.trim();
    if (userId.isEmpty || text.isEmpty) {
      _showMessage('Add some text before saving your story.', isError: true);
      return;
    }
    setState(() => _isSavingBiography = true);
    try {
      final data = await ApiService.saveAIBiography(userId, text);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() {
          _biography = data['biography']?.toString() ?? text;
          _biographyController.text = _biography!;
          _isBiographyDraft = false;
          _draftSources = null;
        });
        _showMessage('Your story was saved.');
      } else {
        _showMessage(
          data['message']?.toString() ?? 'Your story was not saved. Try again.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted)
        _showMessage(
          'Your story was not saved. Check your connection and try again.',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isSavingBiography = false);
    }
  }

  void _discardBiographyDraft() {
    setState(() {
      _biographyController.text = _biography ?? '';
      _isBiographyDraft = false;
      _draftSources = null;
    });
  }

  int _draftSourceCount(String key) =>
      (_draftSources?[key] as num?)?.toInt() ?? 0;

  Widget _dailyReviewContextOption() => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    value: _includeDailyReviews,
    onChanged: _isGenerating
        ? null
        : (value) => setState(() => _includeDailyReviews = value ?? false),
    title: const Text('Use my saved daily review answers'),
    subtitle: const Text(
      'Recent answers can add your own reflections to this draft. They are sent to Google Gemini only when you create it.',
      style: TextStyle(color: LifeVerseColors.muted, fontSize: 12, height: 1.4),
    ),
  );

  Future<void> _addMilestone() async {
    final userId = Provider.of<UserState>(context, listen: false).userId;
    if (userId.isEmpty) return;
    final titleController = TextEditingController();
    final detailController = TextEditingController();
    final chapterController = TextEditingController(text: 'Personal');
    final coreValuesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a milestone'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Milestone'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Add a title.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: detailController,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'What happened?',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: chapterController,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Chapter'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: coreValuesController,
                  maxLength: 400,
                  decoration: const InputDecoration(
                    labelText: 'Values this milestone reflects',
                    hintText: 'e.g. patience, courage, learning',
                    helperText:
                        'Optional. Separate up to 8 values with commas.',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate())
                Navigator.pop(dialogContext, true);
            },
            child: const Text('Save milestone'),
          ),
        ],
      ),
    );

    try {
      if (confirmed == true && mounted) {
        final result = await ApiService.addLegacyEvent(
          userId,
          title: titleController.text.trim(),
          description: detailController.text.trim(),
          chapter: chapterController.text.trim().isEmpty
              ? 'Personal'
              : chapterController.text.trim(),
          coreValues: coreValuesController.text
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .take(8)
              .map(
                (value) => value.length > 80 ? value.substring(0, 80) : value,
              )
              .toList(),
        );
        if (!mounted) return;
        if (result['success'] == true) {
          _showMessage('Milestone added to your Life Atlas.');
          await _loadTimeline();
        } else {
          _showMessage(
            result['message']?.toString() ??
                result['error']?.toString() ??
                'Milestone could not be saved.',
            isError: true,
          );
        }
      }
    } finally {
      titleController.dispose();
      detailController.dispose();
      chapterController.dispose();
      coreValuesController.dispose();
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? LifeVerseColors.danger
            : LifeVerseColors.raised,
      ),
    );
  }

  int get _chapterCount => _timeline
      .map(
        (event) =>
            (event is Map ? event['chapter']?.toString().trim() : null) ?? '',
      )
      .where((chapter) => chapter.isNotEmpty)
      .toSet()
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Atlas'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Add milestone',
            onPressed: _addMilestone,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTimeline,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            const LvPageHeader(
              title: 'Your story, in chapters',
              subtitle:
                  'A private record of milestones you choose to keep and the growth you want to remember.',
            ),
            const AiDataNotice(),
            const SizedBox(height: 16),
            if (_loadError != null)
              LvMessage(
                title: 'Life Atlas unavailable',
                message: _loadError!,
                icon: Icons.cloud_off_outlined,
                onRetry: _loadTimeline,
              )
            else if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: LvMetricTile(
                      label: 'Milestones',
                      value: '${_timeline.length}',
                      icon: Icons.flag_outlined,
                      color: LifeVerseColors.secondary,
                      detail: 'Saved by you',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LvMetricTile(
                      label: 'Chapters',
                      value: '$_chapterCount',
                      icon: Icons.menu_book_outlined,
                      detail: 'From your milestones',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LvSectionTitle(
                'The Book of You',
                actionLabel: _biography == null && !_isBiographyDraft
                    ? null
                    : (_isBiographyDraft ? null : 'Edit'),
                onAction: _biography == null
                    ? null
                    : () => setState(() => _isBiographyDraft = true),
              ),
              if (_isBiographyDraft)
                LvSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Draft — review and edit before saving',
                        style: TextStyle(
                          color: LifeVerseColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_draftSources != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Sources: ${_draftSourceCount('milestones')} milestones · ${_draftSourceCount('dailyReviews')} daily reviews (${_draftSourceCount('reviewAnswers')} answers) · ${_draftSourceCount('twinMemories')} saved Twin Mind memories.',
                          style: const TextStyle(
                            color: LifeVerseColors.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _biographyController,
                        minLines: 7,
                        maxLines: 18,
                        maxLength: 20000,
                        decoration: const InputDecoration(
                          alignLabelWithHint: true,
                          labelText: 'Your story',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _isSavingBiography
                                ? null
                                : _saveBiography,
                            icon: _isSavingBiography
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('Save story'),
                          ),
                          TextButton(
                            onPressed: _isSavingBiography
                                ? null
                                : _discardBiographyDraft,
                            child: const Text('Discard draft'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else if (_biography != null && _biography!.trim().isNotEmpty)
                LvSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_biography!, style: const TextStyle(height: 1.7)),
                      const SizedBox(height: 10),
                      const Text(
                        'Saved to your Life Atlas',
                        style: TextStyle(
                          color: LifeVerseColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _dailyReviewContextOption(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _isGenerating
                              ? null
                              : _generateAutobiography,
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(
                            _isGenerating
                                ? 'Creating draft…'
                                : 'Create an updated draft',
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                LvSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create an editable biography draft from your saved milestones, Twin Mind memories, and optionally your daily review answers. Nothing is saved until you review and choose Save story.',
                        style: TextStyle(
                          color: LifeVerseColors.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _dailyReviewContextOption(),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isGenerating
                            ? null
                            : _generateAutobiography,
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(
                          _isGenerating
                              ? 'Creating draft…'
                              : 'Create biography draft',
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              LvSectionTitle(
                'Milestones',
                actionLabel: 'Add',
                onAction: _addMilestone,
              ),
              if (_timeline.isEmpty)
                const LvMessage(
                  title: 'Your timeline is ready',
                  message:
                      'Add a milestone when you want to remember a meaningful moment.',
                  icon: Icons.bookmark_add_outlined,
                )
              else
                ..._timeline.map(_buildMilestone),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMilestone(dynamic event) {
    final data = event is Map ? event : const <String, dynamic>{};
    final dateText = data['date'] == null
        ? null
        : data['date'].toString().split('T').first;
    final chapter = data['chapter']?.toString();
    final coreValues = data['coreValues'] is List
        ? (data['coreValues'] as List)
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .take(8)
              .toList()
        : <String>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LvSurface(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.flag_outlined, color: LifeVerseColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title']?.toString() ?? 'Milestone',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (chapter != null && chapter.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      chapter,
                      style: const TextStyle(
                        color: LifeVerseColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if ((data['description']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      data['description'].toString(),
                      style: const TextStyle(
                        color: LifeVerseColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (coreValues.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: coreValues
                          .map((value) => Chip(label: Text(value)))
                          .toList(),
                    ),
                  ],
                  if (dateText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      dateText,
                      style: const TextStyle(
                        color: LifeVerseColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
