import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/lifeverse_theme.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _isLoading = false;

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);

    // Request Storage, Camera, and Notifications
    await [
      Permission.storage,
      Permission.photos,
      Permission.videos,
      Permission.notification,
    ].request();

    if (mounted) {
      setState(() => _isLoading = false);
      // After permissions, navigate to login since they just registered
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeVerseColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.security_outlined, color: LifeVerseColors.primary, size: 48),
              const SizedBox(height: 22),
              const Text(
                "Let's set up your permissions.",
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.2),
              ),
              const SizedBox(height: 20),
              const Text(
                "LifeVerse uses media access when you attach memories and can schedule notifications on this device. Recipient capsules appear in the app when the recipient next opens it.",
                style: TextStyle(color: LifeVerseColors.muted, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 28),
              _buildPermissionTile(Icons.folder, "Storage & Media", "Required to attach photos and videos up to 200MB to your Time Capsules."),
              const SizedBox(height: 20),
              _buildPermissionTile(Icons.notifications_active, "Notifications", "Optional reminders are scheduled on this device. Recipient push notifications are not available yet."),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LifeVerseColors.primary,
                    foregroundColor: LifeVerseColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: LifeVerseColors.onPrimary, strokeWidth: 2))
                      : const Text("Grant Permissions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 15),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text("Skip for now", style: TextStyle(color: LifeVerseColors.muted)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: LifeVerseColors.primary.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: LifeVerseColors.primary, size: 22),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: LifeVerseColors.muted, fontSize: 14, height: 1.4)),
            ],
          ),
        )
      ],
    );
  }
}
