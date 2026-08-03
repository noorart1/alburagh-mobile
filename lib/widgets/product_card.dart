import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../screens/product_detail_screen.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(product.price) ?? 0;
    final regularPrice = double.tryParse(product.regularPrice) ?? 0;
    final hasDiscount = regularPrice > price;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Hero(
                      tag: 'product_${product.id}',
                      child: Container(
                        color: AppColors.surfaceSoft,
                        child: product.imageUrl.isEmpty
                            ? Icon(
                                Icons.image_not_supported,
                                color: AppColors.textMuted,
                                size: 42,
                              )
                            : CachedNetworkImage(
                                imageUrl: product.imageUrl,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                                placeholder: (context, url) => const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                  Icons.broken_image,
                                  color: AppColors.textMuted,
                                  size: 42,
                                ),
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _WishlistButton(product: product),
                  ),
                  if (!product.inStock)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textMuted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'نفذ من المخزون',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (product.category.isNotEmpty)
                      Text(
                        product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (hasDiscount)
                      Text(
                        '\$${product.regularPrice}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${product.price}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        _CartButton(product: product),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistButton extends StatelessWidget {
  final Product product;

  const _WishlistButton({required this.product});

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider>();
    final isWishlisted = wishlist.isWishlisted(product.id);

    return GestureDetector(
      onTap: () async {
        final success = await context.read<WishlistProvider>().toggle(product);
        if (!context.mounted || success) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<WishlistProvider>().error ?? 'فشل تحديث المفضلة',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: AppColors.error,
          ),
        );
      },
      child: CircleAvatar(
        radius: 15,
        backgroundColor: AppColors.white.withValues(alpha: 0.9),
        child: Icon(
          isWishlisted ? Icons.favorite : Icons.favorite_border,
          size: 16,
          color: isWishlisted ? AppColors.accentRed : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final Product product;

  const _CartButton({required this.product});

  @override
  Widget build(BuildContext context) {
    final isExternal =
        product.type == 'external' && product.externalUrl.isNotEmpty;
    final disabled = !isExternal && !product.inStock;

    return SizedBox(
      width: 32,
      height: 32,
      child: FilledButton(
        onPressed: disabled
            ? null
            : isExternal
            ? () async {
                final uri = Uri.tryParse(product.externalUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            : () async {
                final cart = context.read<CartProvider>();
                final success = await cart.addToCart(product);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'تمت الإضافة إلى السلة'
                          : cart.error ?? 'فشل إضافة المنتج للسلة',
                    ),
                    backgroundColor: success ? null : AppColors.error,
                  ),
                );
              },
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.border,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        child: Icon(
          isExternal ? Icons.open_in_new : Icons.add_shopping_cart,
          size: 16,
          color: disabled ? AppColors.textMuted : AppColors.white,
        ),
      ),
    );
  }
}
