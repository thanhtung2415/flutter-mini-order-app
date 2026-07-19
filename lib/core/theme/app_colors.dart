import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFFB95D1F);
  static const primaryPressed = Color(0xFF934714);
  static const primaryContainer = Color(0xFFFFF0E5);

  static const background = Color(0xFFF7F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1C1C1C);
  static const textSecondary = Color(0xFF707070);
  static const border = Color(0xFFE7E5E1);
  static const outline = border;
  static const disabled = Color(0xFFE2E1DE);

  static const success = Color(0xFF248A3D);
  static const successContainer = Color(0xFFEAF6ED);
  static const warning = Color(0xFFD97706);
  static const warningContainer = Color(0xFFFFF4E5);
  static const danger = Color(0xFFD83A3A);
  static const error = danger;
  static const dangerContainer = Color(0xFFFDECEC);
  static const errorContainer = dangerContainer;
  static const info = Color(0xFF2563EB);
  static const infoContainer = Color(0xFFEAF2FF);
  static const paid = success;
  static const paidContainer = successContainer;
  static const reserved = Color(0xFF6D5BD0);
  static const neutral = Color(0xFF737373);
}
