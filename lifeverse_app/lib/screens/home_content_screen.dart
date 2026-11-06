import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_state.dart';

class HomeContentScreen extends StatelessWidget {
  const HomeContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Consumer<UserState>(
              builder: (context, userState, _) {
                final name = userState.fullName.trim().isNotEmpty
                    ? userState.fullName.trim()
                    : userState.username.trim();
                return Text(
                  'Welcome back, ${name.isEmpty ? 'there' : name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              "Your Journey",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 15),
            _buildPillarTile(
              context,
              Icons.fitness_center,
              Colors.blueAccent,
              "Human Development",
              _buildStatusChip(
                Colors.blueAccent,
                Icons.today,
                "Review today's growth",
              ),
              '/hde_dashboard',
            ),
            _buildPillarTile(
              context,
              Icons.hourglass_bottom,
              Colors.orangeAccent,
              "Time Capsule",
              _buildStatusChip(
                Colors.orangeAccent,
                Icons.lock_clock,
                "Review your capsules",
              ),
              '/time_capsules',
            ),
            _buildPillarTile(
              context,
              Icons.history_edu,
              Colors.greenAccent,
              "Legacy System",
              _buildStatusChip(
                Colors.greenAccent,
                Icons.auto_stories,
                "Review your milestones",
              ),
              '/legacy_timeline',
            ),
            _buildPillarTile(
              context,
              Icons.smart_toy,
              Colors.purpleAccent,
              "Digital Twin",
              _buildStatusChip(
                Colors.purpleAccent,
                Icons.face_retouching_natural,
                "Reflect on your growth",
              ),
              '/digital_twin',
            ),
            _buildPillarTile(
              context,
              Icons.auto_graph,
              Colors.pinkAccent,
              "Future Simulation",
              _buildStatusChip(
                Colors.pinkAccent,
                Icons.insights,
                "Explore possible paths",
              ),
              '/future_simulation',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarTile(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    Widget subtitleWidget,
    String routeName,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: subtitleWidget,
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: routeName.isEmpty
            ? null
            : () => Navigator.pushNamed(context, routeName),
      ),
    );
  }

  Widget _buildStatusChip(Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
