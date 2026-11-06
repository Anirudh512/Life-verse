import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/capsule_theme.dart';
import '../screens/capsule_open_screen.dart';
import '../services/api_service.dart';
import '../services/capsule_delivery_service.dart';
import '../services/user_state.dart';
import '../theme/lifeverse_theme.dart';
import '../widgets/lifeverse_components.dart';

class TimeCapsuleDashboard extends StatefulWidget {
  const TimeCapsuleDashboard({super.key});

  @override
  State<TimeCapsuleDashboard> createState() => _TimeCapsuleDashboardState();
}

class _TimeCapsuleDashboardState extends State<TimeCapsuleDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _sent = [];
  List<dynamic> _received = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final userId = Provider.of<UserState>(context, listen: false).userId;
    if (userId.isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError = 'Sign in to load your saved capsules.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await CapsuleDeliveryService.checkAndShowDeliveries(context, userId);
      if (!mounted) return;

      final data = await ApiService.getAllCapsules(userId);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() {
          _sent = data['sent'] ?? data['capsules'] ?? [];
          _received = data['received'] ?? [];
        });
      } else {
        setState(() => _loadError = data['message']?.toString() ?? 'Your capsules could not be loaded.');
      }
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Check your connection, then try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCreate() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final seen = userState.appState['capsuleTutorialSeen'] == true;
    if (!seen) {
      await Navigator.pushNamed(context, '/capsule_how_it_works');
    } else {
      await Navigator.pushNamed(context, '/create_capsule');
    }
    if (!mounted) return;
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeVerseColors.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: LifeVerseColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Time Capsule', style: TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3D2C00), Color(0xFF0A0A0A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.mail_lock_rounded, size: 56, color: Color(0xFFFFB300)),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: LifeVerseColors.primary,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              tabs: [
                Tab(text: 'Sent (${_sent.length})'),
                Tab(text: 'Received (${_received.length})'),
              ],
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_loadError != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: LvMessage(title: 'Capsules unavailable', message: _loadError!, icon: Icons.cloud_off_outlined, onRetry: _load)),
              ),
            )
          else
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _CapsuleList(capsules: _sent, emptyMessage: 'No capsules sent yet.\nSeal your first memory.', onRefresh: _load),
                  _CapsuleList(capsules: _received, emptyMessage: 'No capsules received yet.\nSomeone may send you one soon.', onRefresh: _load),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startCreate,
        backgroundColor: LifeVerseColors.primary,
        foregroundColor: LifeVerseColors.canvas,
        icon: const Icon(Icons.add),
        label: const Text('New Capsule', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _CapsuleList extends StatelessWidget {
  final List<dynamic> capsules;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  const _CapsuleList({required this.capsules, required this.emptyMessage, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (capsules.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Padding(
              padding: const EdgeInsets.all(28),
              child: LvMessage(title: 'No capsules here yet', message: emptyMessage.replaceAll('\n', ' '), icon: Icons.inventory_2_outlined),
            ),
          ],
        ),
      );
    }

    final userId = Provider.of<UserState>(context, listen: false).userId;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: LifeVerseColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: capsules.length,
        itemBuilder: (_, i) {
          final c = capsules[i] as Map<String, dynamic>;
          return _CapsuleCard(capsule: c, userId: userId);
        },
      ),
    );
  }
}

class _CapsuleCard extends StatelessWidget {
  final Map<String, dynamic> capsule;
  final String userId;

  const _CapsuleCard({required this.capsule, required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = CapsuleThemes.byId(capsule['themeStyle'] as String? ?? 'amber_gold');
    final isReady = capsule['isReady'] == true;
    final timeRemaining = capsule['timeRemaining'] as String? ?? '';
    final title = capsule['title'] as String? ?? 'A Memory Preserved';
    final mediaCount = capsule['mediaCount'] as int? ?? 0;
    final isIncoming = capsule['isIncoming'] == true;
    final otherUser = isIncoming
        ? capsule['senderUsername'] as String? ?? '?'
        : capsule['recipientUsername'] as String?;

    return GestureDetector(
      onTap: isReady
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CapsuleOpenScreen(
                    capsuleId: capsule['id'] as String,
                    userId: userId,
                    previewCapsule: capsule,
                  ),
                ),
              )
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: theme.gradient),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isReady ? theme.accent : Colors.white12,
            width: isReady ? 2 : 1,
          ),
          boxShadow: isReady
              ? [BoxShadow(color: theme.accent.withValues(alpha: 0.25), blurRadius: 16)]
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Icon(
            isReady ? Icons.lock_open_rounded : Icons.lock_clock_rounded,
            color: theme.accent,
            size: 36,
          ),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                isReady ? 'Ready to open!' : timeRemaining,
                style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (otherUser != null)
                Text(
                  isIncoming ? 'From @$otherUser' : 'To @$otherUser',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              if (capsule['latitude'] != null)
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: theme.accent),
                    const SizedBox(width: 4),
                    const Text('Location check on open', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              if (mediaCount > 0)
                Text('$mediaCount file${mediaCount == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          trailing: isReady
              ? Icon(Icons.arrow_forward_ios, color: theme.accent, size: 16)
              : null,
        ),
      ),
    );
  }
}
