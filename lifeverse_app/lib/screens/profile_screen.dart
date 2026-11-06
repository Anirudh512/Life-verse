import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/user_state.dart';
import '../services/api_service.dart';
import '../services/session_token_cache.dart';
import '../utils/app_snackbar.dart';
import '../theme/lifeverse_theme.dart';
import '../widgets/ai_data_notice.dart';
import '../widgets/lifeverse_components.dart';
import 'friend_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;
  final int refreshToken;
  const ProfileScreen({
    super.key,
    this.showBackButton = true,
    this.refreshToken = 0,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

Map<String, dynamic> _profileMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int _profileInt(dynamic value, {int fallback = 0}) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _friends = [];
  List<dynamic> _requests = [];
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _progress = {};
  List<Map<String, dynamic>> _goals = [];
  bool _profileAvailable = false;
  bool _progressAvailable = false;
  bool _goalsAvailable = false;
  bool _connectionsAvailable = false;
  bool _isLoading = true;
  bool _showQr = false;
  final TextEditingController _addFriendController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addFriendController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = Provider.of<UserState>(context, listen: false).userId;
      if (userId.isEmpty) return;
      Future<Map<String, dynamic>> safe(
        Future<Map<String, dynamic>> request,
      ) async {
        try {
          return await request;
        } catch (_) {
          return <String, dynamic>{};
        }
      }

      final results = await Future.wait([
        safe(ApiService.getFriendsList(userId)),
        safe(ApiService.getUserProfile(userId)),
        safe(ApiService.getProgressAnalytics(userId, days: 30)),
        safe(ApiService.getGrowthGoals(userId)),
      ]);
      final friendsData = results[0];
      final profileData = results[1];
      final progressData = results[2];
      final goalsData = results[3];
      if (!mounted) return;
      setState(() {
        _friends = friendsData['friends'] ?? [];
        _requests = friendsData['pendingRequests'] ?? [];
        _profile = Map<String, dynamic>.from(profileData['profile'] ?? {});
        _progress = progressData['success'] == true
            ? Map<String, dynamic>.from(progressData)
            : {};
        _profileAvailable = profileData['success'] == true;
        _progressAvailable = progressData['success'] == true;
        _goalsAvailable = goalsData['success'] == true;
        _connectionsAvailable = friendsData['success'] == true;
        final rawGoals = goalsData['goals'];
        _goals = rawGoals is List
            ? rawGoals
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : [];
      });
    } catch (e) {
      print('Profile error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRequest(String username) async {
    if (username.isEmpty) return;
    try {
      final userId = Provider.of<UserState>(context, listen: false).userId;
      final data = await ApiService.sendFriendRequest(userId, username);
      if (!mounted) return;

      if (data['success'] == true) {
        AppSnackBar.show(
          context,
          'Connection request sent to @$username.',
          isSuccess: true,
        );
        _addFriendController.clear();
      } else {
        AppSnackBar.show(
          context,
          data['message'] ?? 'Failed to send request',
          isError: true,
        );
      }
    } catch (e) {
      AppSnackBar.show(context, 'Error: $e', isError: true);
    }
  }

  Future<void> _previewConnection(String rawUsername) async {
    final username = rawUsername.trim().replaceFirst(RegExp(r'^@'), '');
    if (username.isEmpty || username.length > 100) {
      AppSnackBar.show(
        context,
        'Enter a valid LifeVerse username.',
        isError: true,
      );
      return;
    }

    final lookup = await ApiService.lookupCapsuleFriend(username);
    if (!mounted) return;
    final person = lookup['user'];
    if (lookup['success'] != true || person is! Map) {
      AppSnackBar.show(
        context,
        lookup['message']?.toString() ??
            'Could not find that LifeVerse account.',
        isError: true,
      );
      return;
    }

    final userState = Provider.of<UserState>(context, listen: false);
    if (person['id']?.toString() == userState.userId) {
      AppSnackBar.show(context, 'That is your own account.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add this connection?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              person['fullName']?.toString() ?? 'LifeVerse member',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '@${person['username'] ?? username}',
              style: const TextStyle(color: LifeVerseColors.muted),
            ),
            const SizedBox(height: 14),
            const Text(
              'After the request is accepted, you can both view each other’s XP and growth summary. Reflections, goals, and Twin Mind conversations stay private. Capsule contents are visible only to recipients and contributors.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _sendRequest(person['username']?.toString() ?? username);
    }
  }

  String? _usernameFromConnectionQr(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'lifeverse' || uri.host != 'addfriend') {
      return null;
    }
    final username = uri.queryParameters['username']?.trim();
    if (username == null || username.isEmpty || username.length > 100) {
      return null;
    }
    return username;
  }

  void _acceptRequest(String senderId) async {
    try {
      final userId = Provider.of<UserState>(context, listen: false).userId;
      final data = await ApiService.acceptFriendRequest(senderId, userId);
      if (!mounted) return;

      if (data['success'] == true) {
        AppSnackBar.show(context, 'Trusted connection added.', isSuccess: true);
        _loadData();
      } else {
        AppSnackBar.show(
          context,
          data['message'] ?? 'Failed to accept',
          isError: true,
        );
      }
    } catch (e) {
      AppSnackBar.show(context, 'Error: $e', isError: true);
    }
  }

  void _openScanner() {
    var handledScan = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: LifeVerseColors.surface,
      isScrollControlled: true,
      builder: (scannerContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                "Scan a LifeVerse connection QR",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: MobileScanner(
                    onDetect: (capture) {
                      if (handledScan) return;
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final username = _usernameFromConnectionQr(
                          barcode.rawValue,
                        );
                        if (username == null) continue;
                        handledScan = true;
                        Navigator.pop(scannerContext);
                        _previewConnection(username);
                        break;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Align QR code within frame",
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: LifeVerseColors.surface,
        title: const Text(
          'Delete account permanently?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This deletes your profile, activity, trusted connections, and capsules you created, including capsules shared with other people. Your access to capsules created by others will be removed. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final passwordController = TextEditingController();
    String? password;
    try {
      password = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: LifeVerseColors.surface,
          title: const Text(
            'Confirm with your password',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Current password'),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, passwordController.text),
              child: const Text(
                'Delete account',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
    } finally {
      passwordController.dispose();
    }
    if (!mounted || password == null || password.isEmpty) return;

    final userId = Provider.of<UserState>(context, listen: false).userId;
    final result = await ApiService.deleteAccount(userId, password);
    if (!mounted) return;
    if (result['success'] == true) {
      if (result['mediaCleanupComplete'] == false) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Account deleted'),
            content: const Text(
              'Your account is deleted, but some capsule files could not be removed automatically. Contact the LifeVerse administrator to finish file cleanup.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (!mounted) return;
      }
      await SessionTokenCache.clear();
      if (!mounted) return;
      Provider.of<UserState>(context, listen: false).clearSession();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } else {
      AppSnackBar.show(
        context,
        result['message'] ?? 'Account deletion failed.',
        isError: true,
      );
    }
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(
      text: _profile['fullName']?.toString() ?? '',
    );
    final usernameController = TextEditingController(
      text: _profile['username']?.toString() ?? '',
    );
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usernameController,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixText: '@',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'fullName': nameController.text.trim(),
              'username': usernameController.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    usernameController.dispose();
    if (!mounted || values == null) return;
    final result = await ApiService.updateUserProfile(
      Provider.of<UserState>(context, listen: false).userId,
      fullName: values['fullName'] ?? '',
      username: values['username'] ?? '',
    );
    if (!mounted) return;
    if (result['success'] != true) {
      AppSnackBar.show(
        context,
        result['message']?.toString() ?? 'Profile could not be saved.',
        isError: true,
      );
      return;
    }
    final saved = Map<String, dynamic>.from(result['profile'] ?? values);
    setState(() => _profile = {..._profile, ...saved});
    Provider.of<UserState>(context, listen: false).updateIdentity(
      username: saved['username']?.toString() ?? '',
      fullName: saved['fullName']?.toString() ?? '',
    );
    AppSnackBar.show(context, 'Profile updated.', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeVerseColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Connections'),
                Tab(text: 'Privacy & account'),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildIdentityTab(),
                        _buildConnectionsTab(),
                        _buildPrivacyTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final userState = context.watch<UserState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Row(
        children: [
          if (widget.showBackButton)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(context),
            ),
          Expanded(
            child: Text(
              'Profile',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '@${userState.username}',
            style: const TextStyle(color: LifeVerseColors.muted, fontSize: 12),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.logout();
              await SessionTokenCache.clear();
              if (!mounted) return;
              Provider.of<UserState>(context, listen: false).clearSession();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityTab() {
    final userState = context.watch<UserState>();
    final summary = _profileMap(_progress['summary']);
    final availability = _profileMap(_progress['availability']);
    final hde = _profileMap(_progress['hdeStats']);
    final dimensions = _profileMap(hde['dimensions']);
    final activityDimensions = _profileMap(_progress['dimensions']);
    final joined = DateTime.tryParse(_profile['createdAt']?.toString() ?? '');
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LvSurface(
              tint: LifeVerseColors.panel,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 33,
                    backgroundColor: LifeVerseColors.raised,
                    child: Text(
                      userState.fullName.isEmpty
                          ? 'L'
                          : userState.fullName[0].toUpperCase(),
                      style: const TextStyle(
                        color: LifeVerseColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userState.fullName.isEmpty
                              ? 'LifeVerse member'
                              : userState.fullName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${userState.username}',
                          style: const TextStyle(
                            color: LifeVerseColors.primary,
                          ),
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
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: _editProfile,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const LvSectionTitle('Account information'),
            LvSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.alternate_email,
                      color: LifeVerseColors.primary,
                    ),
                    title: const Text('Email'),
                    subtitle: Text(
                      _profileAvailable
                          ? (_profile['email']?.toString() ?? 'Unavailable')
                          : 'Account details unavailable',
                    ),
                    trailing: const Text(
                      'Not editable',
                      style: TextStyle(
                        color: LifeVerseColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.badge_outlined,
                      color: LifeVerseColors.primary,
                    ),
                    title: const Text('Display name'),
                    subtitle: Text(userState.fullName),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            LvSectionTitle(
              'Growth snapshot · last 30 days',
              actionLabel: 'View progress',
              onAction: () => Navigator.pushNamed(context, '/progress'),
            ),
            if (!_progressAvailable)
              LvMessage(
                title: 'Growth summary unavailable',
                message: 'Reconnect and try again to load your saved activity.',
                onRetry: _loadData,
              )
            else
              LvSurface(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: LvSummaryMetric(
                            label: 'Visit days',
                            value:
                                availability['visits'] == false ||
                                    summary['visitDays'] == null
                                ? '—'
                                : '${_profileInt(summary['visitDays'])}',
                          ),
                        ),
                        const LvMetricDivider(),
                        Expanded(
                          child: LvSummaryMetric(
                            label: 'Growth days',
                            value: '${_profileInt(summary['growthDays'])}',
                            color: LifeVerseColors.secondary,
                          ),
                        ),
                        const LvMetricDivider(),
                        Expanded(
                          child: LvSummaryMetric(
                            label: 'Tasks',
                            value: '${_profileInt(summary['tasksCompleted'])}',
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
                          label: 'reviews',
                          value: '${_profileInt(summary['reviewsCompleted'])}',
                        ),
                        LvCompactFact(
                          label: 'streak',
                          value: availability['hdeStats'] == false ||
                                  _progress['hdeStats'] is! Map
                              ? '—'
                              : '${_profileInt(hde['currentStreak'])} days',
                        ),
                        LvCompactFact(
                          label: 'lifetime XP',
                          value: availability['totalXp'] == false ||
                                  summary['totalXp'] == null
                              ? '—'
                              : '${_profileInt(summary['totalXp'])}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const LvSectionTitle('Your four dimensions'),
            LvSurface(
              child: Column(
                children: [
                  for (final item in const [
                    ('Physical', 'physical'),
                    ('Cognitive', 'cognitive'),
                    ('Psychosocial', 'psychosocial'),
                    ('Moral', 'moral'),
                  ]) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.$1)),
                          Text(
                            availability['hdeStats'] == false ||
                                    _progress['hdeStats'] is! Map
                                ? 'Level unavailable'
                                : 'Level ${_profileInt(_profileMap(dimensions[item.$2])['level'], fallback: 1)}',
                            style: const TextStyle(
                              color: LifeVerseColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(
                        '${_profileInt(_profileMap(activityDimensions[item.$2])['tasksCompleted'])} tasks recorded in the last 30 days',
                        style: const TextStyle(
                          color: LifeVerseColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            LvSectionTitle(
              'Active goals',
              actionLabel: 'Manage',
              onAction: () => Navigator.pushNamed(context, '/growth_goals'),
            ),
            if (!_goalsAvailable)
              LvMessage(
                title: 'Goals unavailable',
                message: 'Your saved goals could not be loaded.',
                onRetry: _loadData,
              )
            else if (_goals.isEmpty)
              const LvMessage(
                title: 'No goals saved yet',
                message: 'Create a goal to make your next growth step visible.',
              )
            else if (_goals.every((goal) => goal['isComplete'] == true))
              const LvMessage(
                title: 'All saved goals complete',
                message:
                    'Review your completed goals or create a new one to keep building.',
              )
            else
              ..._goals.where((g) => g['isComplete'] != true).take(3).map((
                goal,
              ) {
                final target = _profileInt(goal['targetTasks']);
                final current = _profileInt(goal['progressValue']);
                final fraction = (target <= 0 ? 0.0 : current / target)
                    .clamp(0, 1)
                    .toDouble();
                final metric = goal['progressMetric'] == 'active_days'
                    ? 'active days'
                    : 'tasks';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LvSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal['title']?.toString() ?? 'Growth goal',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${(fraction * 100).round()}%',
                              style: const TextStyle(
                                color: LifeVerseColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 6,
                            backgroundColor: LifeVerseColors.raised,
                            color: LifeVerseColors.primary,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '$current of $target $metric · ${goal['dimension'] ?? 'Growth'}',
                          style: const TextStyle(
                            color: LifeVerseColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showQr = !_showQr),
              icon: const Icon(Icons.qr_code_2),
              label: Text(
                _showQr ? 'Hide connection QR' : 'Show connection QR',
              ),
            ),
            if (_showQr) ...[
              const SizedBox(height: 12),
              LvSurface(
                child: Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        data: Uri(
                          scheme: 'lifeverse',
                          host: 'addfriend',
                          queryParameters: {'username': userState.username},
                        ).toString(),
                        version: QrVersions.auto,
                        size: 180,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'This QR shares your username. Growth activity and reflections remain private.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: LifeVerseColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyTab() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Your growth records, reflections, and Twin Mind conversations are private to your account. Trusted connections are used for time-capsule sharing.',
            style: TextStyle(color: LifeVerseColors.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          const AiDataNotice(),
          const SizedBox(height: 18),
          LvSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.forum_outlined,
                    color: LifeVerseColors.primary,
                  ),
                  title: const Text('Twin Mind history and memories'),
                  subtitle: const Text(
                    'Review or clear saved conversations and facts.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/digital_twin'),
                ),
                const Divider(height: 1, indent: 56),
                const ListTile(
                  leading: Icon(
                    Icons.privacy_tip_outlined,
                    color: LifeVerseColors.secondary,
                  ),
                  title: Text('Activity data'),
                  subtitle: Text(
                    'Progress uses recorded visits and completed actions. Activity summaries do not display reflection answers or Twin Mind conversation text.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          LvSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Permanent account deletion',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This removes your account and associated LifeVerse records after you confirm with your current password.',
                  style: TextStyle(color: LifeVerseColors.muted, height: 1.4),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _confirmDeleteAccount,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: LifeVerseColors.danger,
                  ),
                  label: const Text(
                    'Delete account and data',
                    style: TextStyle(color: LifeVerseColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildConnectionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_connectionsAvailable)
            LvMessage(
              title: 'Connections unavailable',
              message: 'Check your connection and try again.',
              onRetry: _loadData,
            ),
          const Text(
            'Trusted connections',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Accepted connections can view your XP, 30-day quest totals, and dimension levels. Reflections, goals, and Twin Mind conversations stay private. Capsule contents are visible only to their recipients and contributors.',
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 18),
          // Add a connection by username or QR.
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addFriendController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Add by @username",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: LifeVerseColors.raised,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                backgroundColor: LifeVerseColors.primary,
                radius: 25,
                child: IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  onPressed: () =>
                      _previewConnection(_addFriendController.text),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                backgroundColor: LifeVerseColors.raised,
                radius: 25,
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  onPressed: _openScanner,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Pending Requests
          if (_requests.isNotEmpty) ...[
            const Text(
              "Connection requests",
              style: TextStyle(
                color: LifeVerseColors.warning,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ..._requests.map((r) => _buildRequestTile(r)).toList(),
            const SizedBox(height: 20),
          ],

          // Accepted connections are used for capsule recipients.
          const Text(
            "Your connections",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (_friends.isEmpty)
            const Text(
              "No trusted connections yet. Add someone when you want to send them a time capsule.",
              style: TextStyle(
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ..._friends.map((f) => _buildFriendTile(f)).toList(),
        ],
      ),
    );
  }

  Widget _buildRequestTile(dynamic req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: LifeVerseColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: LifeVerseColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: LifeVerseColors.raised,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req['full_name'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "@${req['username']}",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: LifeVerseColors.success),
            onPressed: () => _acceptRequest(req['id']),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(dynamic friend) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FriendProfileScreen(
            friendId: friend['id']?.toString() ?? '',
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: LifeVerseColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: LifeVerseColors.line),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: LifeVerseColors.primary,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend['full_name'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "@${friend['username']}",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: LifeVerseColors.primary),
          ],
        ),
      ),
    );
  }
}
