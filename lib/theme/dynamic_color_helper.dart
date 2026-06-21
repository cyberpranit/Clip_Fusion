import 'package:flutter/material.dart';

class DynamicColorHelper {
  static Color getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return const Color(0xFFE50914);
      case 'instagram':
        return const Color(0xFFD62976);
      case 'tiktok':
        return const Color(0xFF00F2FE);
      case 'whatsapp':
        return const Color(0xFF25D366);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'x':
      case 'twitter':
        return const Color(0xFFFFFFFF);
      default:
        return const Color(0xFF8E2DE2); // default electric purple
    }
  }

  static Gradient getPlatformGradient(String platform) {
    final baseColor = getPlatformColor(platform);
    
    if (platform.toLowerCase() == 'instagram') {
      return const LinearGradient(
        colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF56040)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (platform.toLowerCase() == 'x' || platform.toLowerCase() == 'twitter') {
      return const LinearGradient(
        colors: [Color(0xFF111111), Color(0xFFFFFFFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    
    return LinearGradient(
      colors: [baseColor, baseColor.withValues(alpha: 0.5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
