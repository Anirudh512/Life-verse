import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../services/user_state.dart';
import '../services/api_service.dart';
import '../utils/app_snackbar.dart';
import '../widgets/ai_data_notice.dart';
import '../theme/lifeverse_theme.dart';

class DigitalTwinScreen extends StatefulWidget {
  final bool openButterflyEffect;
  const DigitalTwinScreen({super.key, this.openButterflyEffect = false});

  @override
  State<DigitalTwinScreen> createState() => _DigitalTwinScreenState();
}

class _DigitalTwinScreenState extends State<DigitalTwinScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  bool _isLoadingOlderMessages = false;
  bool _hasOlderMessages = false;
  bool _isClearingHistory = false;
  bool _includeLifeVerseContext = false;
  String? _retryDraft;
  String? _historyError;
  String? _historyCursor;
  String _persona = 'Mentor';

  // Voice Link
  late stt.SpeechToText _speech;
  bool _isListening = false;
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;

  final List<String> _personas = ['Best Friend', 'Mentor', 'Parent'];

  @override
  void initState() {
    super.initState();
    final savedPersona = Provider.of<UserState>(
      context,
      listen: false,
    ).appState['twinPersona'];
    if (_personas.contains(savedPersona)) _persona = savedPersona as String;
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();
    _loadConversationHistory();
    if (widget.openButterflyEffect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showButterflyEffect();
      });
    }
  }

  void _initTts() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (error) {
      debugPrint('Twin Mind voice setup is unavailable: $error');
    }

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversationHistory() async {
    final requestedPersona = _persona;
    if (mounted) setState(() => _isLoadingHistory = true);
    final userId = Provider.of<UserState>(context, listen: false).userId;
    if (userId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          _historyError = 'Sign in to load your saved Twin Mind history.';
        });
      }
      return;
    }
    final result = await ApiService.getTwinConversationHistory(
      userId,
      requestedPersona,
    );
    if (!mounted || requestedPersona != _persona) return;
    if (result['success'] == true && result['messages'] is List) {
      final messages = (result['messages'] as List)
          .whereType<Map>()
          .where((message) => message['persona'] == _persona)
          .map(
            (message) => {
              'sender': message['role'] == 'user' ? 'user' : 'ai',
              'text': message['content']?.toString() ?? '',
            },
          )
          .where((message) => message['text']!.isNotEmpty)
          .toList();
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _historyError = null;
        _isLoadingHistory = false;
        _isLoadingOlderMessages = false;
        _hasOlderMessages = result['hasMore'] == true;
        _historyCursor = result['nextBeforeId']?.toString();
      });
      _scrollToLatest();
    } else {
      setState(() {
        _historyError =
            result['message']?.toString() ??
            'Could not load saved conversation.';
        _isLoadingHistory = false;
        _isLoadingOlderMessages = false;
      });
    }
  }

  Future<void> _loadOlderConversationHistory() async {
    final cursor = _historyCursor;
    if (!_hasOlderMessages || _isLoadingOlderMessages || cursor == null) return;

    final requestedPersona = _persona;
    final userId = Provider.of<UserState>(context, listen: false).userId;
    if (userId.isEmpty) return;
    setState(() => _isLoadingOlderMessages = true);

    final result = await ApiService.getTwinConversationHistory(
      userId,
      requestedPersona,
      beforeId: cursor,
    );
    if (!mounted || requestedPersona != _persona) return;

    if (result['success'] == true && result['messages'] is List) {
      final olderMessages = (result['messages'] as List)
          .whereType<Map>()
          .where((message) => message['persona'] == requestedPersona)
          .map(
            (message) => <String, String>{
              'sender': message['role'] == 'user' ? 'user' : 'ai',
              'text': message['content']?.toString() ?? '',
            },
          )
          .where((message) => message['text']!.isNotEmpty)
          .toList();

      setState(() {
        _messages.insertAll(0, olderMessages);
        _hasOlderMessages = result['hasMore'] == true;
        _historyCursor = result['nextBeforeId']?.toString();
        _isLoadingOlderMessages = false;
      });
    } else {
      setState(() => _isLoadingOlderMessages = false);
      AppSnackBar.show(
        context,
        result['message']?.toString() ?? 'Could not load older messages.',
        isError: true,
      );
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Twin Mind data?'),
        content: const Text(
          'This permanently deletes saved Twin Mind conversations and facts you asked it to remember from your LifeVerse account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _isClearingHistory) return;

    setState(() => _isClearingHistory = true);
    final userId = Provider.of<UserState>(context, listen: false).userId;
    final result = await ApiService.clearTwinConversationHistory(userId);
    if (!mounted) return;
    setState(() {
      _isClearingHistory = false;
      if (result['success'] == true) {
        _messages.clear();
        _historyError = null;
        _hasOlderMessages = false;
        _historyCursor = null;
      }
    });
    AppSnackBar.show(
      context,
      result['success'] == true
          ? 'Twin Mind conversations and saved facts cleared.'
          : result['message']?.toString() ?? 'Could not clear Twin Mind data.',
      isError: result['success'] != true,
    );
  }

  Future<void> _showSavedMemories() async {
    final userId = Provider.of<UserState>(context, listen: false).userId;
    if (userId.isEmpty) {
      AppSnackBar.show(
        context,
        'Sign in to review saved facts.',
        isError: true,
      );
      return;
    }

    var memoriesFuture = ApiService.getTwinMemories(userId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LifeVerseColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved facts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'These are facts you explicitly asked Twin Mind to remember. Remove a saved fact here; chat history is managed separately.',
                    style: TextStyle(color: LifeVerseColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: memoriesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError ||
                            snapshot.data?['success'] != true) {
                          return Center(
                            child: Text(
                              snapshot.data?['message']?.toString() ??
                                  'Could not load saved facts.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: LifeVerseColors.muted,
                              ),
                            ),
                          );
                        }
                        final memories =
                            (snapshot.data?['memories'] as List? ?? [])
                                .whereType<Map>()
                                .map(
                                  (memory) => Map<String, dynamic>.from(memory),
                                )
                                .toList();
                        if (memories.isEmpty) {
                          return const Center(
                            child: Text(
                              'You have not asked Twin Mind to save any facts yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: LifeVerseColors.muted),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: memories.length,
                          separatorBuilder: (_, _) =>
                              const Divider(color: Colors.white12),
                          itemBuilder: (context, index) {
                            final memory = memories[index];
                            final memoryId = int.tryParse(
                              memory['id'].toString(),
                            );
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                memory['content']?.toString() ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.35,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  memory['tag']?.toString() ?? 'Saved fact',
                                  style: const TextStyle(
                                    color: LifeVerseColors.muted,
                                  ),
                                ),
                              ),
                              trailing: IconButton(
                                tooltip: 'Delete saved fact',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: memoryId == null
                                    ? null
                                    : () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) => AlertDialog(
                                            title: const Text(
                                              'Delete this saved fact?',
                                            ),
                                            content: const Text(
                                              'This removes the saved-memory entry. If the same detail appears in recent chats, Twin Mind may still see it there. Clear Twin Mind history to remove those conversations too.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  dialogContext,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(
                                                  dialogContext,
                                                  true,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed != true) return;
                                        final result =
                                            await ApiService.deleteTwinMemory(
                                              userId,
                                              memoryId,
                                            );
                                        if (!context.mounted) return;
                                        if (result['success'] == true) {
                                          setSheetState(() {
                                            memoriesFuture =
                                                ApiService.getTwinMemories(
                                                  userId,
                                                );
                                          });
                                        } else {
                                          AppSnackBar.show(
                                            sheetContext,
                                            result['message']?.toString() ??
                                                'Could not delete saved fact.',
                                            isError: true,
                                          );
                                        }
                                      },
                              ),
                            );
                          },
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

  void _listen() async {
    if (_isLoading || _isLoadingHistory) return;
    if (!_isListening) {
      try {
        final available = await _speech.initialize(
          onStatus: (val) {
            if (val == 'done' && mounted) {
              setState(() => _isListening = false);
              if (_msgController.text.isNotEmpty) {
                _sendMessage();
              }
            }
          },
          onError: (val) {
            if (mounted) setState(() => _isListening = false);
          },
        );
        if (!mounted) return;
        if (available) {
          setState(() => _isListening = true);
          await _speech.listen(
            onResult: (val) {
              if (mounted) {
                setState(() => _msgController.text = val.recognizedWords);
              }
            },
          );
        } else {
          AppSnackBar.show(
            context,
            'Microphone permission is unavailable.',
            isError: true,
          );
        }
      } catch (error) {
        if (mounted)
          AppSnackBar.show(
            context,
            'Voice input is unavailable on this device.',
            isError: true,
          );
        debugPrint('Twin Mind speech input failed: $error');
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _speak(String text) async {
    try {
      if (_persona == 'Mentor') {
        await _flutterTts.setPitch(0.9);
      } else if (_persona == 'Parent') {
        await _flutterTts.setPitch(0.95);
      } else {
        await _flutterTts.setPitch(1.0);
      }
      await _flutterTts.speak(text);
    } catch (error) {
      if (mounted)
        AppSnackBar.show(
          context,
          'Voice playback is unavailable.',
          isError: true,
        );
      debugPrint('Twin Mind speech output failed: $error');
    }
  }

  void _showButterflyEffect() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final userId = Provider.of<UserState>(context, listen: false).userId;
    final res = await ApiService.getButterflyAnalysis(userId);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      _speak(res['analysis'] ?? '');
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: LifeVerseColors.surface,
          title: const Row(
            children: [
              Icon(Icons.all_inclusive, color: LifeVerseColors.primary),
              SizedBox(width: 10),
              Text('Possible patterns', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This is an exploratory interpretation, not proof that a choice caused an outcome.',
                  style: TextStyle(color: LifeVerseColors.warning, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  res['analysis'] ?? '',
                  style: const TextStyle(
                    color: LifeVerseColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _flutterTts.stop();
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      AppSnackBar.show(
        context,
        res['message']?.toString() ?? 'Could not load possible patterns.',
        isError: true,
      );
    }
  }

  Future<void> _logMicroDecision() async {
    final TextEditingController decisionController = TextEditingController();
    final TextEditingController tagsController = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: LifeVerseColors.surface,
          title: const Text(
            'Log a Choice',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: decisionController,
                maxLength: 1000,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "e.g. Took a different route home today...",
                  hintStyle: const TextStyle(color: LifeVerseColors.muted),
                  filled: true,
                  fillColor: LifeVerseColors.raised,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: LifeVerseColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: LifeVerseColors.primary,
                    ),
                  ),
                  labelText: 'What choice did you make?',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tagsController,
                maxLength: 500,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Optional labels',
                  hintText: 'e.g. family, patience, learning',
                  helperText: 'Separate up to 10 labels with commas.',
                  hintStyle: const TextStyle(color: LifeVerseColors.muted),
                  filled: true,
                  fillColor: LifeVerseColors.raised,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: LifeVerseColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: LifeVerseColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text(
                'Cancel',
                style: TextStyle(color: LifeVerseColors.muted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LifeVerseColors.primary,
                foregroundColor: LifeVerseColors.onPrimary,
              ),
              onPressed: () async {
                if (decisionController.text.trim().isEmpty) return;
                Navigator.pop(c);
                final userId = Provider.of<UserState>(
                  context,
                  listen: false,
                ).userId;
                final tags = tagsController.text
                    .split(',')
                    .map((tag) => tag.trim())
                    .where((tag) => tag.isNotEmpty)
                    .toSet()
                    .take(10)
                    .toList();
                final res = await ApiService.logMicroDecision(
                  userId,
                  decisionController.text.trim(),
                  tags: tags,
                );
                if (!mounted) return;
                if (res['success'] == true) {
                  AppSnackBar.show(
                    context,
                    'Choice added to your private Butterfly Effect records.',
                    isSuccess: true,
                  );
                } else {
                  AppSnackBar.show(
                    context,
                    res['message']?.toString() ??
                        'Your choice could not be saved.',
                    isError: true,
                  );
                }
              },
              child: const Text('Log'),
            ),
          ],
        ),
      );
    } finally {
      decisionController.dispose();
      tagsController.dispose();
    }
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || text.length > 2000 || _isLoading || _isLoadingHistory)
      return;

    final isRetry =
        _retryDraft == text &&
        _messages.isNotEmpty &&
        _messages.last['sender'] == 'user' &&
        _messages.last['text'] == text;
    setState(() {
      if (!isRetry) _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
    });
    _msgController.clear();

    try {
      final userId = Provider.of<UserState>(context, listen: false).userId;
      final data = await ApiService.chatWithTwin(
        userId,
        text,
        _persona,
        includeLifeVerseContext: _includeLifeVerseContext,
      );

      if (data['success'] == true && mounted) {
        setState(() {
          _retryDraft = null;
          _messages.add({
            'sender': 'ai',
            'text': data['reply']?.toString() ?? 'I could not prepare a reply.',
          });
        });
        if (data['memorySaved'] == true) {
          AppSnackBar.show(
            context,
            'Saved to Twin Mind memory at your request.',
            isSuccess: true,
          );
        } else if (data['memoryDeclined'] == true) {
          AppSnackBar.show(
            context,
            'Twin Mind saves only non-sensitive preferences, goals, interests, hobbies, routines, and values.',
          );
        }
        _scrollToLatest();
      } else if (mounted) {
        setState(() {
          _retryDraft = text;
          _msgController.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        });
        AppSnackBar.show(
          context,
          data['networkError'] == true
              ? 'LifeVerse could not confirm the save. Your draft is restored; check chat history before retrying to avoid a duplicate.'
              : '${data['message']?.toString() ?? 'Twin Mind could not respond.'} Your draft is restored.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _retryDraft = text;
          _msgController.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        });
        AppSnackBar.show(
          context,
          'Twin Mind is unavailable. Your draft is restored; check chat history before retrying if the connection dropped.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getPersonaColor() {
    return LifeVerseColors.primary;
  }

  String _personaLabel(String persona) =>
      persona == 'Best Friend' ? 'Supportive Companion' : persona;

  @override
  Widget build(BuildContext context) {
    final activeColor = _getPersonaColor();

    return Scaffold(
      backgroundColor: LifeVerseColors.canvas,
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _persona,
            dropdownColor: LifeVerseColors.surface,
            icon: Icon(Icons.keyboard_arrow_down, color: activeColor),
            style: TextStyle(
              color: activeColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            onChanged: (String? newValue) {
              if (newValue != null &&
                  newValue != _persona &&
                  !_isLoading &&
                  !_isLoadingHistory) {
                setState(() {
                  _persona = newValue;
                  _messages.clear();
                  _retryDraft = null;
                  _historyError = null;
                  _historyCursor = null;
                  _hasOlderMessages = false;
                  _isLoadingOlderMessages = false;
                });
                Provider.of<UserState>(
                  context,
                  listen: false,
                ).updateAppState({'twinPersona': newValue});
                _loadConversationHistory();
              }
            },
            items: _personas.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(_personaLabel(value)),
              );
            }).toList(),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Twin Mind data options',
            onSelected: (value) {
              if (value == 'clear') _confirmClearHistory();
              if (value == 'memories') _showSavedMemories();
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'memories',
                child: Text('Review saved facts'),
              ),
              PopupMenuItem<String>(
                value: 'clear',
                enabled: !_isClearingHistory,
                child: Text(
                  _isClearingHistory
                      ? 'Clearing…'
                      : 'Clear chat and saved facts',
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_task, color: Colors.white),
            tooltip: 'Log Micro-Decision',
            onPressed: _logMicroDecision,
          ),
          IconButton(
            icon: const Icon(
              Icons.all_inclusive,
              color: LifeVerseColors.primary,
            ),
            tooltip: 'Butterfly Effect',
            onPressed: _showButterflyEffect,
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AiDataNotice(),
          ),
          SwitchListTile.adaptive(
            value: _includeLifeVerseContext,
            activeColor: LifeVerseColors.primary,
            tileColor: LifeVerseColors.surface,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Use saved LifeVerse context'),
            subtitle: Text(
              _includeLifeVerseContext
                  ? 'Includes saved facts, activity summaries, and choices. Daily reviews are never included.'
                  : 'Off. Only this persona chat and your current message are used.',
              style: const TextStyle(
                color: LifeVerseColors.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
            onChanged: (value) =>
                setState(() => _includeLifeVerseContext = value),
          ),
          if (_isSpeaking)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.volume_up_outlined,
                    size: 16,
                    color: LifeVerseColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Reading the response aloud',
                    style: TextStyle(
                      color: LifeVerseColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _historyError != null && _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _historyError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: LifeVerseColors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _loadConversationHistory,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Start with what is on your mind. Enable saved context above if you want relevant facts, activity summaries, and choices included for a reply.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: LifeVerseColors.muted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length + (_hasOlderMessages ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_hasOlderMessages && index == 0) {
                        return Center(
                          child: _isLoadingOlderMessages
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : TextButton.icon(
                                  onPressed: _loadOlderConversationHistory,
                                  icon: const Icon(Icons.expand_less),
                                  label: const Text('Load older messages'),
                                ),
                        );
                      }
                      final messageIndex = index - (_hasOlderMessages ? 1 : 0);
                      final msg = _messages[messageIndex];
                      final isUser = msg['sender'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(15),
                          constraints: BoxConstraints(
                            maxWidth: math.min(
                              640.0,
                              MediaQuery.of(context).size.width * 0.75,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? LifeVerseColors.primary.withValues(alpha: .18)
                                : LifeVerseColors.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: isUser
                                  ? const Radius.circular(20)
                                  : Radius.zero,
                              bottomRight: isUser
                                  ? Radius.zero
                                  : const Radius.circular(20),
                            ),
                            border: Border.all(
                              color: isUser
                                  ? LifeVerseColors.primary.withValues(
                                      alpha: .35,
                                    )
                                  : LifeVerseColors.line,
                            ),
                          ),
                          child: Text(
                            msg['text'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.45,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: LinearProgressIndicator(
                color: activeColor,
                backgroundColor: LifeVerseColors.line,
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: LifeVerseColors.surface,
              border: Border(top: BorderSide(color: LifeVerseColors.line)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _isListening
                      ? LifeVerseColors.danger
                      : LifeVerseColors.raised,
                  radius: 22,
                  child: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
                    onPressed: _listen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? "Listening..."
                          : "Chat with your Twin...",
                      hintStyle: const TextStyle(color: LifeVerseColors.muted),
                      filled: true,
                      fillColor: LifeVerseColors.raised,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: LifeVerseColors.line,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: LifeVerseColors.line,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: LifeVerseColors.primary,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      counterText: '',
                    ),
                    maxLength: 2000,
                    onChanged: (value) => setState(() {
                      if (_retryDraft != null && value.trim() != _retryDraft) {
                        _retryDraft = null;
                      }
                    }),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: LifeVerseColors.primary,
                  radius: 22,
                  child: IconButton(
                    tooltip: 'Send message',
                    icon: const Icon(
                      Icons.send,
                      color: LifeVerseColors.onPrimary,
                    ),
                    onPressed:
                        _isLoading ||
                            _isLoadingHistory ||
                            _msgController.text.trim().isEmpty
                        ? null
                        : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
