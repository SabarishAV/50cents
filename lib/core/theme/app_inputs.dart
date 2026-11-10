import 'package:flutter/material.dart';

import 'package:_50cents/core/theme/app_colors.dart';

/// Shared decoration for auth form inputs — keeps login and register identical.
InputDecoration appInputDecoration(String label, IconData icon, {Widget? suffixIcon, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    labelStyle: const TextStyle(color: AppColors.textMuted),
    floatingLabelStyle: const TextStyle(color: AppColors.neonBlue),
    prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.background.withValues(alpha: 0.55),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.neonBlue, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.expense),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.expense, width: 1.4),
    ),
    errorStyle: const TextStyle(height: 0.9, fontSize: 11),
  );
}
