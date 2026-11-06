import 'package:flutter/material.dart';

class CapsuleThemeStyle {
  final String id;
  final String name;
  final List<Color> gradient;
  final Color accent;
  final IconData icon;

  const CapsuleThemeStyle({
    required this.id,
    required this.name,
    required this.gradient,
    required this.accent,
    required this.icon,
  });
}

class CapsuleThemes {
  static const all = [
    CapsuleThemeStyle(
      id: 'amber_gold',
      name: 'Golden Memory',
      gradient: [Color(0xFF3D2C00), Color(0xFF1A1400)],
      accent: Color(0xFFFFB300),
      icon: Icons.wb_sunny_rounded,
    ),
    CapsuleThemeStyle(
      id: 'cosmic_purple',
      name: 'Cosmic Love',
      gradient: [Color(0xFF2D1B69), Color(0xFF0D0221)],
      accent: Color(0xFFB388FF),
      icon: Icons.auto_awesome,
    ),
    CapsuleThemeStyle(
      id: 'rose_memory',
      name: 'Rose Petal',
      gradient: [Color(0xFF4A1942), Color(0xFF1A0A16)],
      accent: Color(0xFFFF6090),
      icon: Icons.favorite_rounded,
    ),
    CapsuleThemeStyle(
      id: 'ocean_blue',
      name: 'Ocean Depth',
      gradient: [Color(0xFF0D47A1), Color(0xFF001233)],
      accent: Color(0xFF40C4FF),
      icon: Icons.waves_rounded,
    ),
  ];

  static CapsuleThemeStyle byId(String id) {
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }
}
