import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/capsule_theme.dart';
import '../services/api_service.dart';
import '../utils/app_snackbar.dart';
import '../theme/lifeverse_theme.dart';
import 'package:geolocator/geolocator.dart';

class CapsuleOpenScreen extends StatefulWidget {
  final String capsuleId;
  final String userId;
  final Map<String, dynamic>? previewCapsule;

  const CapsuleOpenScreen({
    super.key,
    required this.capsuleId,
    required this.userId,
    this.previewCapsule,
  });

  @override
  State<CapsuleOpenScreen> createState() => _CapsuleOpenScreenState();
}

class _CapsuleOpenScreenState extends State<CapsuleOpenScreen>
    with TickerProviderStateMixin {
  late AnimationController _openController;
  late AnimationController _particleController;
  bool _ceremonyDone = false;
  bool _loading = true;
  Map<String, dynamic>? _capsule;

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _loadAndOpen();
  }

  Future<void> _loadAndOpen() async {
    final lat = widget.previewCapsule?['latitude'] as num?;
    final lng = widget.previewCapsule?['longitude'] as num?;
    double? clientLat;
    double? clientLng;

    if (lat != null && lng != null) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) throw 'Location services are disabled.';

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied)
            throw 'Location permissions are denied';
        }
        if (permission == LocationPermission.deniedForever)
          throw 'Location permissions are permanently denied.';

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        clientLat = position.latitude;
        clientLng = position.longitude;

        double distanceInMeters = Geolocator.distanceBetween(
          lat.toDouble(),
          lng.toDouble(),
          clientLat,
          clientLng,
        );

        if (distanceInMeters > 100) {
          // Require being within 100 meters
          if (mounted) {
            AppSnackBar.show(
              context,
              'You must be within 100 meters of the capsule to open it. (You are ${distanceInMeters.round()}m away)',
              isError: true,
            );
            Navigator.pop(context);
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.show(
            context,
            'Failed to verify location: $e',
            isError: true,
          );
          Navigator.pop(context);
        }
        return;
      }
    }

    await _openController.forward();
    if (!mounted) return;

    final result = await ApiService.openCapsule(
      widget.userId,
      widget.capsuleId,
      latitude: clientLat,
      longitude: clientLng,
    );
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _capsule = Map<String, dynamic>.from(result['capsule'] as Map);
        _loading = false;
        _ceremonyDone = true;
      });
    } else {
      AppSnackBar.show(
        context,
        result['error'] ?? result['message'] ?? 'Could not open capsule',
        isError: true,
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _openController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  CapsuleThemeStyle get _theme {
    final id =
        _capsule?['themeStyle'] as String? ??
        widget.previewCapsule?['themeStyle'] as String? ??
        'amber_gold';
    return CapsuleThemes.byId(id);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ceremonyDone || _loading) {
      return Scaffold(
        backgroundColor: LifeVerseColors.canvas,
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: _openController,
              builder: (_, __) {
                final t = _openController.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _theme.accent.withValues(alpha: 0.3 * t),
                        LifeVerseColors.canvas,
                      ],
                      radius: 0.5 + t,
                    ),
                  ),
                );
              },
            ),
            ...List.generate(
              12,
              (i) => _Particle(
                i: i,
                controller: _particleController,
                color: _theme.accent,
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: _openController,
                builder: (_, __) {
                  final t = _openController.value;
                  final lockOpen = Curves.easeOutBack.transform(
                    (t - 0.3).clamp(0.0, 1.0) / 0.7,
                  );
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.scale(
                        scale: 0.8 + (t * 0.4),
                        child: Transform.rotate(
                          angle: lockOpen * math.pi * 0.15,
                          child: Icon(
                            t < 0.5
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            size: 100,
                            color: _theme.accent.withValues(
                              alpha: 0.5 + t * 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        t < 0.5 ? 'Unlocking...' : 'Memories Released',
                        style: TextStyle(
                          color: _theme.accent,
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    final media = (_capsule!['media'] as List<dynamic>?) ?? [];
    final openDate = DateTime.tryParse(_capsule!['openDate'] as String? ?? '');
    final sender = _capsule!['senderUsername'] as String? ?? 'you';

    return Scaffold(
      backgroundColor: _theme.gradient.last,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: _theme.gradient.first,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _capsule!['title'] as String? ?? 'Time Capsule',
                style: const TextStyle(fontSize: 16),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _theme.gradient),
                ),
                child: Center(
                  child: Icon(
                    _theme.icon,
                    size: 64,
                    color: _theme.accent.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_capsule!['isIncoming'] == true)
                    Text(
                      'Dear ${_capsule!['recipientUsername'] ?? 'you'},',
                      style: TextStyle(
                        color: _theme.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    )
                  else
                    Text(
                      'A letter to myself,',
                      style: TextStyle(
                        color: _theme.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (openDate != null)
                    Text(
                      'Opened on ${DateFormat('MMMM d, yyyy').format(openDate)}\nFrom @$sender',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Letter Content
                  Text(
                    _capsule!['message'] as String? ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.8,
                      fontFamily: 'Georgia',
                    ),
                  ),

                  // Media Inline
                  if (media.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    ...media.map((m) {
                      final item = Map<String, dynamic>.from(m as Map);
                      final type = item['mediaType'] as String? ?? 'file';
                      final url = item['url'] as String?;

                      if (type == 'image' && url != null) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              ApiService.mediaUrl(url),
                              headers: ApiService.mediaHeadersFor(url),
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: double.infinity,
                                height: 180,
                                color: Colors.white.withValues(alpha: 0.05),
                                alignment: Alignment.center,
                                child: const Column(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.broken_image_outlined, color: Colors.white54, size: 30),
                                  SizedBox(height: 8),
                                  Text('This image is currently unavailable', style: TextStyle(color: Colors.white70)),
                                ]),
                              ),
                            ),
                          ),
                        );
                      } else {
                        // Other files as minimal attachments
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _theme.accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                type == 'video'
                                    ? Icons.videocam
                                    : Icons.insert_drive_file,
                                color: _theme.accent,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item['fileName'] ?? 'Attachment',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    }),
                  ],

                  if ((_capsule!['prediction'] as String? ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Divider(color: _theme.accent.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'P.S. A prediction from the past:',
                      style: TextStyle(
                        color: _theme.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _capsule!['prediction'] as String,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ],

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle extends StatelessWidget {
  final int i;
  final AnimationController controller;
  final Color color;

  const _Particle({
    required this.i,
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = (controller.value + i / 12) % 1.0;
        final size = MediaQuery.of(context).size;
        return Positioned(
          left: size.width * (0.1 + (i * 0.07) % 0.8),
          top: size.height * (1 - t),
          child: Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Icon(Icons.star, size: 8 + (i % 4) * 2, color: color),
          ),
        );
      },
    );
  }
}
