import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/review.dart';

class ReviewCard extends StatelessWidget {
  final Review review;

  const ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          review.author,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        subtitle: Text(
          review.content,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 16, color: AppColors.accentYellow),
            const SizedBox(width: 4),
            Text(
              '${review.rating}/5',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
