import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'capsule_open_screen.dart';
import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/lifeverse_theme.dart';
import '../utils/app_snackbar.dart';
import '../widgets/lifeverse_components.dart';

class FriendProfileScreen extends StatefulWidget {
  final String friendId;

  const FriendProfileScreen({super.key, required this.friendId});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _progress = {};
  Map<String, dynamic> _dimensions = {};
  List<Map<String, dynamic>> _capsules = [];
  bool _loading = true;
  bool _available = false;
  final Set<String> _openingCapsules = <String>{};

  int _number(dynamic value, {int fallback = 0}) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? fallback;

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final response = await ApiService.getFriendProfile(widget.friendId);
      if (!mounted) return;
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Friend profile unavailable.');
      }
      final rawCapsules = response['capsules'];
      setState(() {
        _profile = _map(response['profile']);
        _progress = _map(response['progress']);
        _dimensions = _map(response['dimensions']);
        _capsules = rawCapsules is List
            ? rawCapsules
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : [];
        _available = true;
      });
    } catch (_) {
      if (mounted) setState(() => _available = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCapsule(Map<String, dynamic> summary) async {
    final capsuleId = summary['id']?.toString() ?? '';
    if (capsuleId.isEmpty || summary['isReady'] != true ||
        _openingCapsules.contains(capsuleId)) {
      return;
    }

    final userId = Provider.of<UserState>(context, listen: false).userId;
    setState(() => _openingCapsules.add(capsuleId));
    try {
      // Load the authorized capsule detail before opening so geo-lock checks
      // receive the same capsule metadata as the regular Capsules screen.
      final response = await ApiService.getCapsuleDetail(capsuleId, userId);
      if (response['success'] != true || response['capsule'] is! Map) {
        throw Exception(response['message'] ?? 'Capsule could not be opened.');
      }
      final capsule = Map<String, dynamic>.from(response['capsule'] as Map);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CapsuleOpenScreen(
            capsuleId: capsuleId,
            userId: userId,
            previewCapsule: capsule,
          ),
        ),
      );
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        AppSnackBar.show(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _openingCapsules.remove(capsuleId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeVerseColors.canvas,
      appBar: AppBar(title: const Text('Friend profile')),
      body: _loading && !_available
          ? const Center(
              child: CircularProgressIndicator(color: LifeVerseColors.primary),
            )
          : !_available
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LvMessage(
                  title: 'Friend profile unavailable',
                  message:
                      'Check your connection, or confirm that this person is still in your connections.',
                  icon: Icons.cloud_off_outlined,
                  onRetry: _load,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIdentity(),
                          const SizedBox(height: 18),
                          _buildProgressCard(),
                          const SizedBox(height: 22),
                          const LvSectionTitle('Growth areas'),
                          _buildDimensions(),
                          const SizedBox(height: 22),
                          const LvSectionTitle('Capsules shared with you'),
                          _buildCapsules(),
                          const SizedBox(height: 18),
                          const LvMessage(
                            title: 'Private areas stay private',
                            message:
                                'Connections can see this progress summary. Reflections, goals, and Twin Mind conversations remain private. Capsule contents are available only to their recipients and contributors.',
                            icon: Icons.lock_outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildIdentity() {
    final name = _profile['fullName']?.toString().trim();
    final username = _profile['username']?.toString() ?? '';
    final joined = DateTime.tryParse(_profile['createdAt']?.toString() ?? '');
    final initialSource = name != null && name.isNotEmpty ? name : username;
    final initial = initialSource.isEmpty ? null : initialSource.substring(0, 1);

    return LvSurface(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: LifeVerseColors.primary.withValues(alpha: .18),
            child: Text(
              (initial ?? 'L').toUpperCase(),
              style: const TextStyle(
                color: LifeVerseColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (name == null || name.isEmpty) ? 'LifeVerse member' : name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '@$username',
                  style: const TextStyle(color: LifeVerseColors.primary),
                ),
                if (joined != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Member since ${DateFormat.yMMMM().format(joined.toLocal())}',
                    style: const TextStyle(
                      color: LifeVerseColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.verified_user_outlined, color: LifeVerseColors.secondary),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return LvSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress · last 30 days',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: LvSummaryMetric(
                  label: 'Lifetime XP',
                  value: NumberFormat.decimalPattern().format(
                    _number(_progress['totalXp']),
                  ),
                  color: LifeVerseColors.primary,
                ),
              ),
              const LvMetricDivider(),
              Expanded(
                child: LvSummaryMetric(
                  label: 'Tasks',
                  value: '${_number(_progress['tasksCompleted'])}',
                  color: LifeVerseColors.success,
                ),
              ),
              const LvMetricDivider(),
              Expanded(
                child: LvSummaryMetric(
                  label: 'Growth days',
                  value: '${_number(_progress['growthDays'])}',
                  color: LifeVerseColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              LvCompactFact(
                label: 'reviews',
                value: '${_number(_progress['reviewsCompleted'])}',
              ),
              LvCompactFact(
                label: 'current streak',
                value: '${_number(_progress['currentStreak'])} days',
              ),
              LvCompactFact(
                label: 'XP this month',
                value: '${_number(_progress['periodXp'])}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDimensions() {
    const areas = [
      ('Physical', 'physical', Icons.directions_run, LifeVerseColors.warning),
      ('Cognitive', 'cognitive', Icons.psychology_alt_outlined, LifeVerseColors.primary),
      ('Psychosocial', 'psychosocial', Icons.people_outline, Color(0xFFF0A7C9)),
      ('Moral', 'moral', Icons.balance_outlined, LifeVerseColors.secondary),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 2 : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: areas.map((area) {
            final stats = _map(_dimensions[area.$2]);
            return SizedBox(
              width: width,
              child: LvSurface(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(area.$3, color: area.$4),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(area.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            '${_number(stats['xp'])} XP',
                            style: const TextStyle(color: LifeVerseColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Lv ${_number(stats['level'], fallback: 1)}',
                      style: TextStyle(color: area.$4, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCapsules() {
    if (_capsules.isEmpty) {
      return const LvMessage(
        title: 'No capsules shared yet',
        message: 'Capsules this friend sends or shares with you will appear here.',
        icon: Icons.inventory_2_outlined,
      );
    }

    return Column(
      children: _capsules.map((capsule) {
        final ready = capsule['isReady'] == true;
        final openDate = DateTime.tryParse(capsule['openDate']?.toString() ?? '');
        final status = ready
            ? (capsule['status']?.toString().toUpperCase() == 'OPENED'
                ? 'Already opened · tap to revisit'
                : 'Ready to open')
            : openDate == null
            ? 'Locked'
            : 'Opens ${DateFormat.yMMMd().format(openDate.toLocal())}';
        final id = capsule['id']?.toString() ?? '';
        final opening = _openingCapsules.contains(id);
        final mediaCount = _number(capsule['mediaCount']);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: LvSurface(
            padding: EdgeInsets.zero,
            child: ListTile(
              onTap: ready ? () => _openCapsule(capsule) : null,
              leading: Icon(
                ready ? Icons.lock_open_rounded : Icons.lock_clock_rounded,
                color: ready ? LifeVerseColors.warning : LifeVerseColors.muted,
                size: 30,
              ),
              title: Text(
                capsule['title']?.toString() ?? 'A Memory Preserved',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      status,
                      style: TextStyle(
                        color: ready ? LifeVerseColors.success : LifeVerseColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (mediaCount > 0)
                      Text(
                        '$mediaCount file${mediaCount == 1 ? '' : 's'}',
                        style: const TextStyle(color: LifeVerseColors.muted, fontSize: 12),
                      ),
                    if (capsule['isGeoLocked'] == true)
                      const Text(
                        'Location check',
                        style: TextStyle(color: LifeVerseColors.muted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              trailing: opening
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ready
                  ? const Icon(Icons.chevron_right, color: LifeVerseColors.primary)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
