import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/currency_utils.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../providers/cart_provider.dart';

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final bool enabled;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const CartItemCard({
    super.key,
    required this.item,
    required this.enabled,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final image = product.imageUrl;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadius.smRadius,
              child: image.isEmpty
                  ? Container(
                      width: 72,
                      height: 88,
                      color: AppColors.surfaceSoft,
                      child: const Icon(
                        Icons.book_outlined,
                        size: 32,
                        color: AppColors.textMuted,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      width: 72,
                      height: 88,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.surfaceSoft,
                        child: const Icon(
                          Icons.book_outlined,
                          size: 32,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyUtils.formatString(
                      product.price,
                      product.currencySymbol,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: enabled && item.quantity > 1
                            ? onDecrease
                            : null,
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: enabled ? onIncrease : null,
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'إزالة',
              onPressed: enabled ? onRemove : null,
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.accentRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
