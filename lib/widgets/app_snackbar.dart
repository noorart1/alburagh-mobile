import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';

enum _SnackKind { success, error, info }

/// Drop-in replacement for the app's old
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...)))`
/// calls: a floating, rounded, icon-led bar that's color-coded by outcome,
/// instead of the stock flat dark bar every screen used to show identically
/// for both a success message and an error.
class AppSnackBar {
  AppSnackBar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, _SnackKind.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _SnackKind.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, _SnackKind.info);

  static void _show(BuildContext context, String message, _SnackKind kind) {
    final (color, icon) = switch (kind) {
      _SnackKind.success => (AppColors.success, Icons.check_circle_rounded),
      _SnackKind.error => (AppColors.error, Icons.error_rounded),
      _SnackKind.info => (AppColors.primary, Icons.info_rounded),
    };

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: AppColors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          elevation: 4,
          // Errors get an extra beat -- they're usually longer/more
          // important to actually read than a quick success confirmation.
          duration: Duration(seconds: kind == _SnackKind.error ? 4 : 3),
        ),
      );
  }
}
