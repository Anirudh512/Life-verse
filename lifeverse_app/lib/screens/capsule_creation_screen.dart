import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/capsule_theme.dart';
import '../services/api_service.dart';
import '../services/user_state.dart';
import '../utils/app_snackbar.dart';
import '../theme/lifeverse_theme.dart';
import '../services/notification_service.dart';
import 'capsule_opening_cinematic.dart';
import 'package:geolocator/geolocator.dart';

class CapsuleMediaItem {
  final PlatformFile file;
  String customName;
  CapsuleMediaItem(this.file) : customName = file.name;
}

class CapsuleCreationScreen extends StatefulWidget {
  const CapsuleCreationScreen({super.key});

  @override
  State<CapsuleCreationScreen> createState() => _CapsuleCreationScreenState();
}

class _CapsuleCreationScreenState extends State<CapsuleCreationScreen> {
  static final math.Random _requestKeyRandom = math.Random.secure();

  final _titleController = TextEditingController(text: 'A Memory Preserved');
  final _messageController = TextEditingController();
  final _predictionController = TextEditingController();
  final _friendController = TextEditingController();

  CapsuleThemeStyle _theme = CapsuleThemes.all.first;
  bool _sendToFriend = false;
  bool _isSubmitting = false;
  bool _isGeoLocked = false;
  Position? _currentPosition;
  final List<String> _contributors = [];
  int _unlockDays = 1;
  List<CapsuleMediaItem> _mediaFiles = [];
  List<dynamic> _friendsList = [];
  bool _isLoadingFriends = false;
  String? _friendsLoadError;
  String _idempotencyKey = _newIdempotencyKey();
  static const _maxBytes = 200 * 1024 * 1024;
  static const _maxFileBytes = 50 * 1024 * 1024;
  static const _maxFileCount = 20;

  static String _newIdempotencyKey() => List.generate(
    32,
    (_) => _requestKeyRandom.nextInt(16).toRadixString(16),
  ).join();

  void _resetIdempotencyKey() {
    _idempotencyKey = _newIdempotencyKey();
  }

  int get _totalBytes => _mediaFiles.fold(0, (sum, f) => sum + (f.file.size));

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_resetIdempotencyKey);
    _messageController.addListener(_resetIdempotencyKey);
    _predictionController.addListener(_resetIdempotencyKey);
    _friendController.addListener(_resetIdempotencyKey);
  }

  @override
  void dispose() {
    _titleController.removeListener(_resetIdempotencyKey);
    _messageController.removeListener(_resetIdempotencyKey);
    _predictionController.removeListener(_resetIdempotencyKey);
    _friendController.removeListener(_resetIdempotencyKey);
    _titleController.dispose();
    _messageController.dispose();
    _predictionController.dispose();
    _friendController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );
      if (result == null || !mounted) return;

      final newItems = result.files.map((f) => CapsuleMediaItem(f)).toList();
      final combined = [..._mediaFiles, ...newItems];
      final inaccessible = newItems.any((item) => item.file.bytes == null && item.file.path == null);
      if (inaccessible) {
        AppSnackBar.show(context, 'One or more selected files could not be read.', isError: true);
        return;
      }
      final oversized = newItems.where((item) => item.file.size > _maxFileBytes).toList();
      if (oversized.isNotEmpty) {
        AppSnackBar.show(context, 'Each attachment must be 50MB or smaller.', isError: true);
        return;
      }
      if (combined.length > _maxFileCount) {
        AppSnackBar.show(context, 'A capsule can contain up to 20 attachments.', isError: true);
        return;
      }
      final total = combined.fold<int>(0, (sum, item) => sum + item.file.size);
      if (total > _maxBytes) {
        AppSnackBar.show(context, 'Total media must stay under 200MB.', isError: true);
        return;
      }
      setState(() {
        _mediaFiles = combined;
        _resetIdempotencyKey();
      });
    } catch (_) {
      if (mounted) AppSnackBar.show(context, 'Files could not be selected. Try again.', isError: true);
    }
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;
    setState(() {
      _isLoadingFriends = true;
      _friendsLoadError = null;
    });
    try {
      final userId = Provider.of<UserState>(context, listen: false).userId;
      if (userId.isEmpty) return;

      final data = await ApiService.getFriendsList(userId);
      if (mounted && data['success'] == true) {
        setState(() => _friendsList = data['friends'] ?? []);
      } else if (mounted) {
        setState(() => _friendsLoadError = data['message']?.toString() ?? 'Connections could not be loaded.');
      }
    } catch (_) {
      if (mounted) setState(() => _friendsLoadError = 'Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _toggleGeoLock(bool enable) async {
    if (!enable) {
      setState(() {
        _isGeoLocked = false;
        _currentPosition = null;
        _resetIdempotencyKey();
      });
      return;
    }

    setState(() => _isSubmitting = true); // use to show loading state
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      Position position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      setState(() {
        _isGeoLocked = true;
        _currentPosition = position;
        _resetIdempotencyKey();
      });
      if (mounted)
        AppSnackBar.show(
          context,
          'Locked to your current coordinates.',
          isError: false,
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGeoLocked = false);
      if (mounted) AppSnackBar.show(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sealCapsule() async {
    if (_messageController.text.trim().isEmpty) {
      AppSnackBar.show(
        context,
        'Write a message for your capsule',
        isError: true,
      );
      return;
    }
    if (_sendToFriend && _friendController.text.trim().isEmpty) {
      AppSnackBar.show(
        context,
        'Choose a trusted LifeVerse connection.',
        isError: true,
      );
      return;
    }

    final userId = Provider.of<UserState>(context, listen: false).userId;
    if (userId.isEmpty) return;

    final unlockDate = DateTime.now().add(Duration(days: _unlockDays));

    setState(() => _isSubmitting = true);
    final response = await ApiService.createCapsuleWithMedia(
      userId: userId,
      idempotencyKey: _idempotencyKey,
      title: _titleController.text.trim(),
      message: _messageController.text.trim(),
      openDate: unlockDate.toIso8601String(),
      prediction: _predictionController.text.trim(),
      themeStyle: _theme.id,
      capsuleType: _sendToFriend ? 'friend' : 'self',
      recipientUsername: _sendToFriend ? _friendController.text.trim() : null,
      capsuleData: {
        if (_isGeoLocked && _currentPosition != null)
          'latitude': _currentPosition!.latitude,
        if (_isGeoLocked && _currentPosition != null)
          'longitude': _currentPosition!.longitude,
        if (_contributors.isNotEmpty) 'contributors': _contributors,
      },
      mediaFiles: _mediaFiles,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response['success'] == true) {
      if (mounted) {
        // Schedule a notification for when the capsule unlocks
        try {
          await NotificationService.scheduleNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: 'Time Capsule Unlocked!',
            body:
                'Your capsule "${_titleController.text.trim()}" is now ready to be opened.',
            scheduledTime: unlockDate,
          );
        } catch (_) {
          // ignore notification scheduling errors if permissions denied
        }

        Navigator.pushReplacementNamed(
          context,
          '/capsule_ceremony',
          arguments: {
            'title': _titleController.text.trim(),
            'openDate': unlockDate.toIso8601String(),
            'recipient': _sendToFriend ? _friendController.text.trim() : null,
            'themeStyle': _theme.id,
            'mediaCount': _mediaFiles.length,
          },
        );
      }
    } else {
      AppSnackBar.show(
        context,
        response['error'] ?? response['message'] ?? 'Failed to seal capsule',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.gradient.last,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Seal a Time Capsule',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CapsuleOpeningCinematic(
                    title: 'Demo Capsule',
                    message:
                        'This is how your friends will see the memories you send them!',
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: _theme.accent),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Try a Demo',
                style: TextStyle(color: _theme.accent, fontSize: 12),
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/capsule_how_it_works'),
            child: Text('Info', style: TextStyle(color: _theme.accent)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewCard(theme: _theme, title: _titleController.text),
            const SizedBox(height: 24),
            const Text('Choose Theme', style: _labelStyle),
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: CapsuleThemes.all.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final t = CapsuleThemes.all[i];
                  final selected = t.id == _theme.id;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _theme = t;
                      _resetIdempotencyKey();
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: t.gradient),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? t.accent : LifeVerseColors.line,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(t.icon, color: t.accent),
                          const SizedBox(height: 6),
                          Text(
                            t.name,
                            style: TextStyle(color: t.accent, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text('Capsule Title', style: _labelStyle),
            const SizedBox(height: 8),
            _field(_titleController, hint: 'Give this moment a name'),
            const SizedBox(height: 20),
            const Text('Your Message', style: _labelStyle),
            const SizedBox(height: 8),
            _field(
              _messageController,
              hint: 'Words for the future...',
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            const Text('Future Prediction (optional)', style: _labelStyle),
            const SizedBox(height: 8),
            _field(
              _predictionController,
              hint: 'I think I will be...',
              icon: Icons.psychology,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Location check (uses device-reported location)',
                    style: TextStyle(
                      color: _theme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: _isGeoLocked,
                  activeColor: _theme.accent,
                  onChanged: _toggleGeoLock,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Send to a trusted connection',
                    style: TextStyle(
                      color: _theme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: _sendToFriend,
                  activeColor: _theme.accent,
                  onChanged: (v) {
                    setState(() {
                      _sendToFriend = v;
                      _resetIdempotencyKey();
                    });
                    if (v && _friendsList.isEmpty) {
                      _loadFriends();
                    }
                  },
                ),
              ],
            ),
            if (_sendToFriend) ...[
              if (_isLoadingFriends)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                )
              else if (_friendsLoadError != null)
                Row(children: [
                  Expanded(child: Text(_friendsLoadError!, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                  TextButton(onPressed: _loadFriends, child: const Text('Retry')),
                ])
              else if (_friendsList.isEmpty)
                Text(
                  'No trusted connections yet. Add one in your Profile.',
                  style: TextStyle(
                    color: _theme.accent.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: LifeVerseColors.raised,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: LifeVerseColors.surface,
                      hint: const Text(
                        'Select a connection',
                        style: TextStyle(color: Colors.white38),
                      ),
                      value: _friendController.text.isEmpty
                          ? null
                          : _friendController.text,
                      items: _friendsList.map((f) {
                        return DropdownMenuItem<String>(
                          value: f['username'],
                          child: Text(
                            '@${f['username']} (${f['full_name']})',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _friendController.text = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            // Add Contributors (Co-Op Vaults) UI
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Invite Contributors (Co-Op Vault)',
                    style: TextStyle(
                      color: _theme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.group_add, color: _theme.accent),
                  onPressed: () async {
                    if (_friendsList.isEmpty) {
                      await _loadFriends();
                    }
                    if (!mounted) return;

                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: LifeVerseColors.surface,
                        title: const Text(
                          'Add Contributors',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: _friendsList.isEmpty
                              ? const Text(
                                  'No trusted connections available.',
                                  style: TextStyle(color: Colors.white54),
                                )
                              : StatefulBuilder(
                                  builder: (context, setDialogState) {
                                    return ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _friendsList.length,
                                      itemBuilder: (c, i) {
                                        final f = _friendsList[i];
                                        final un = f['username'] as String;
                                        final isSelected = _contributors
                                            .contains(un);
                                        return CheckboxListTile(
                                          title: Text(
                                            '@$un',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          value: isSelected,
                                          activeColor: _theme.accent,
                                          checkColor: Colors.black,
                                          onChanged: (val) {
                                            setDialogState(() {
                                              if (val == true) {
                                                _contributors.add(un);
                                              } else {
                                                _contributors.remove(un);
                                              }
                                            });
                                            setState(() {
                                              _resetIdempotencyKey();
                                            });
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: Text(
                              'Done',
                              style: TextStyle(color: _theme.accent),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            if (_contributors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Wrap(
                  spacing: 8,
                  children: _contributors
                      .map(
                        (c) => Chip(
                          label: Text(
                            '@$c',
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: _theme.accent.withValues(alpha: 0.2),
                          deleteIconColor: Colors.white54,
                          onDeleted: () => setState(() {
                            _contributors.remove(c);
                            _resetIdempotencyKey();
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
            const Text('Attach files (up to 50MB each, 200MB total)', style: _labelStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: Icon(
                    Icons.add_photo_alternate,
                    color: _theme.accent,
                    size: 18,
                  ),
                  label: const Text('Photos / Videos / Files'),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  onPressed: _pickMedia,
                ),
                if (_mediaFiles.isNotEmpty)
                  Text(
                    '${_mediaFiles.length} files · ${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
              ],
            ),
            if (_mediaFiles.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._mediaFiles.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, color: _theme.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: f.customName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                          ),
                          onChanged: (val) {
                            f.customName = val;
                            _resetIdempotencyKey();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white38,
                        ),
                        onPressed: () => setState(() {
                          _mediaFiles.remove(f);
                          _resetIdempotencyKey();
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text('Unlock After (min 1 day)', style: _labelStyle),
            Slider(
              value: _unlockDays.toDouble(),
              min: 1,
              max: 365,
              divisions: 364,
              activeColor: _theme.accent,
              label: '$_unlockDays day${_unlockDays == 1 ? '' : 's'}',
              onChanged: (v) => setState(() {
                _unlockDays = v.round();
                _resetIdempotencyKey();
              }),
            ),
            Center(
              child: Text(
                'Opens on ${DateFormat('MMM d, yyyy · h:mm a').format(DateTime.now().add(Duration(days: _unlockDays)))}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _sealCapsule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _theme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Seal Capsule',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _labelStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  Widget _field(
    TextEditingController c, {
    required String hint,
    int maxLines = 1,
    IconData? icon,
  }) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: icon != null ? Icon(icon, color: _theme.accent) : null,
        filled: true,
        fillColor: LifeVerseColors.raised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final CapsuleThemeStyle theme;
  final String title;

  const _PreviewCard({required this.theme, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: theme.gradient),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: theme.accent.withValues(alpha: 0.2), blurRadius: 24),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_rounded, size: 48, color: theme.accent),
          const SizedBox(height: 12),
          Text(
            title.isEmpty ? 'Your Capsule' : title,
            style: TextStyle(
              color: theme.accent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Live preview',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
