import 'package:flutter/material.dart';
import '../widgets/capsule_delivery_overlay.dart';
import 'api_service.dart';

class CapsuleDeliveryService {
  static Future<void> checkAndShowDeliveries(
    BuildContext context,
    String userId, {
    bool markNotified = true,
  }) async {
    if (userId.isEmpty || !context.mounted) return;

    final data = await ApiService.getPendingCapsuleDeliveries(userId);
    if (data['success'] != true) return;

    final pending = (data['pending'] as List<dynamic>?) ?? [];
    if (pending.isEmpty || !context.mounted) return;

    for (final capsule in pending) {
      if (!context.mounted) break;
      await showCapsuleDeliveryOverlay(
        context,
        capsule: Map<String, dynamic>.from(capsule as Map),
        userId: userId,
      );
      if (markNotified) {
        await ApiService.markCapsuleDelivered(capsule['id'] as String);
      }
    }
  }
}
