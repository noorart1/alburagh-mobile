import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/currency_utils.dart';
import '../core/theme/app_colors.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../screens/product_detail_screen.dart';
import 'app_snackbar.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(product.price) ?? 0;
    final regularPrice = double.tryParse(product.regularPrice) ?? 0;
    final hasDiscount = regularPrice > price;

    return Card(
      color: AppColors.white,
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
            // No flex ratio here on purpose: the details Padding below
            // sizes itself to exactly what its content needs (name +
            // optional discount + button row), and the image takes 100%
            // of whatever's left. That's strictly more image space than
            // any fixed flex split could give it, on every card size/
            // aspect ratio, with no risk of re-introducing the overflow a
            // fixed ratio caused before.
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Hero(
                      tag: 'product_${product.id}',
                      child: Container(
                        color: AppColors.white,
                        child: product.thumbnailUrl.isEmpty
                            ? Icon(
                                Icons.image_not_supported,
                                color: AppColors.textMuted,
                                size: 42,
                              )
                            : _ProductImage(imageUrl: product.thumbnailUrl),
                      ),
                    ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: 4),
                  if (hasDiscount)
                    Text(
                      CurrencyUtils.formatString(
                        product.regularPrice,
                        product.currencySymbol,
                      ),
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
                      Expanded(
                        child: Text(
                          CurrencyUtils.formatString(
                            product.price,
                            product.currencySymbol,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      _WishlistButton(product: product),
                      const SizedBox(width: 6),
                      _CartButton(product: product),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The site serves product photos in two fixed source sizes: 600x800
/// (portrait) and 600x600 (square). Portrait sources already roughly match
/// this card's own image slot, so BoxFit.fill looks right; stretching a
/// square source the same way visibly distorts it, so it needs
/// BoxFit.contain instead. Which one a given image is isn't known until
/// it's decoded, so this resolves the image once up front to read its
/// pixel size and picks the fit before rendering it (via the same
/// CachedNetworkImage, so the resolve is served from its cache and isn't
/// a second network fetch).
class _ProductImage extends StatefulWidget {
  final String imageUrl;

  const _ProductImage({required this.imageUrl});

  @override
  State<_ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<_ProductImage> {
  BoxFit _fit = BoxFit.fill;
  // Square (600x600) sources are shown with BoxFit.contain, which leaves
  // leftover vertical space in this taller-than-square card slot; pinning
  // that leftover space to the bottom (topCenter) keeps every square cover
  // flush with the top edge instead of floating centered with uneven gaps.
  Alignment _alignment = Alignment.center;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveFit();
  }

  @override
  void didUpdateWidget(covariant _ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolveFit();
    }
  }

  void _resolveFit() {
    _stream?.removeListener(_listener!);
    final stream = CachedNetworkImageProvider(
      widget.imageUrl,
    ).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, synchronousCall) {
      final width = info.image.width;
      final height = info.image.height;
      if (height == 0) return;
      final isSquare = (width - height).abs() / height < 0.1;
      // BoxFit.fill for the portrait source would only look right in a slot
      // whose own aspect ratio happens to match 600x800 -- this card is
      // reused in layouts with different card proportions (the home row vs.
      // the category grid), so a slot that doesn't match stretches/distorts
      // the cover. BoxFit.cover keeps the source's real proportions
      // (crops any overflow) regardless of the slot shape.
      final fit = isSquare ? BoxFit.contain : BoxFit.cover;
      //final fit = isSquare ? BoxFit.contain : BoxFit.cover;
      final alignment = isSquare ? Alignment.topCenter : Alignment.center;
      if (mounted && (fit != _fit || alignment != _alignment)) {
        setState(() {
          _fit = fit;
          _alignment = alignment;
        });
      }
    });
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: _fit,
      alignment: _alignment,
      // Grid cards display this at ~170 logical px wide; without a cache
      // size, the plugin decodes the full source resolution (often several
      // times larger) into memory for every card, which is the dominant
      // RAM cost in a long product grid. imageUrl is now the backend's
      // pre-resized thumbnail (~300px), so this mostly just caps decode
      // size on high-DPI devices rather than downsampling a full original.
      memCacheWidth: (MediaQuery.devicePixelRatioOf(context) * 220).round(),
      // Also cap what gets written to the on-disk cache, not just the
      // in-memory decode -- otherwise flutter_cache_manager stores
      // whatever bytes the server sent (fine now that it's a thumbnail,
      // but keeps disk usage bounded even if a product falls back to its
      // full-size original when no thumbnail exists).
      maxWidthDiskCache: 300,
      // The default 500ms placeholder->image fade costs an AnimatedOpacity
      // per card for every image that enters the viewport during a fling --
      // with dozens of cards streaming in per second while scrolling fast,
      // that's a lot of extra animation work competing with the scroll
      // itself. Instant swap reads as "already there" rather than a visible
      // fade, and is one less thing the GPU has to composite per frame.
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Icon(
        Icons.broken_image,
        color: AppColors.textMuted,
        size: 42,
      ),
    );
  }
}

class _WishlistButton extends StatelessWidget {
  final Product product;

  const _WishlistButton({required this.product});

  @override
  Widget build(BuildContext context) {
    // select (not watch) so this button only rebuilds when *this* product's
    // own wishlisted state changes -- watch would rebuild every card's
    // button on the provider's notifyListeners(), even for a toggle on a
    // completely different product elsewhere in the grid.
    final isWishlisted = context.select<WishlistProvider, bool>(
      (wishlist) => wishlist.isWishlisted(product.id),
    );

    return GestureDetector(
      onTap: () async {
        final success = await context.read<WishlistProvider>().toggle(product);
        if (!context.mounted || success) return;
        AppSnackBar.error(
          context,
          context.read<WishlistProvider>().error ?? 'فشل تحديث المفضلة',
        );
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceSoft,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          isWishlisted ? Icons.favorite : Icons.favorite_border,
          size: 14,
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
      width: 28,
      height: 28,
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
                if (success) {
                  AppSnackBar.success(context, 'تمت الإضافة إلى السلة');
                } else {
                  AppSnackBar.error(
                    context,
                    cart.error ?? 'فشل إضافة المنتج للسلة',
                  );
                }
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
