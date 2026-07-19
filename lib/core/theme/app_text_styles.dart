import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const screenTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 23,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  static const sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static const body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  static const caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );

  static const total = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
}
