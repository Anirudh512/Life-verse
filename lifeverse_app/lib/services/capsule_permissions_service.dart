import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class CapsulePermissionsService {
  static Future<Map<String, bool>> requestCapsulePermissions() async {
    if (kIsWeb) {
      return {'storage': true, 'camera': true, 'notifications': false};
    }

    final results = <String, bool>{};

    // Photos / storage
    final photos = await Permission.photos.request();
    final storage = await Permission.storage.request();
    results['storage'] = photos.isGranted || storage.isGranted;

    // Camera for capturing moments
    final camera = await Permission.camera.request();
    results['camera'] = camera.isGranted;

    // Notifications for capsule arrival
    final notifications = await Permission.notification.request();
    results['notifications'] = notifications.isGranted;

    return results;
  }
}
