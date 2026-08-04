import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/currency_utils.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/recently_viewed_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    // Not awaited: purely local bookkeeping for the home screen's "recently
    // viewed" section, shouldn't block or affect this screen either way.
    context.read<RecentlyViewedProvider>().recordView(widget.product);
  }

  List<String> get _imageUrls {
    if (widget.product.imageUrls.isNotEmpty) {
      return widget.product.imageUrls;
    }

    if (widget.product.imageUrl.isNotEmpty) {
      return [widget.product.imageUrl];
    }

    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = _imageUrls;

    return Scaffold(
      appBar: AppBar(title: Text(widget.product.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductImageGallery(
              imageUrls: imageUrls,
              productId: widget.product.id,
              selectedIndex: _selectedImageIndex,
              onImageSelected: (index) {
                setState(() => _selectedImageIndex = index);
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyUtils.formatString(
                          widget.product.price,
                          widget.product.currencySymbol,
                        ),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if ((double.tryParse(widget.product.regularPrice) ?? 0) >
                          (double.tryParse(widget.product.price) ?? 0)) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            CurrencyUtils.formatString(
                              widget.product.regularPrice,
                              widget.product.currencySymbol,
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!widget.product.inStock) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'نفذ من المخزون',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'وصف المنتج:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description.isNotEmpty
                        ? widget.product.description
                        : 'يتم تحديث الوصف الكامل لهذا المنتج.',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child:
                        widget.product.type == 'external' &&
                            widget.product.externalUrl.isNotEmpty
                        ? ElevatedButton.icon(
                            onPressed: () async {
                              final uri = Uri.tryParse(
                                widget.product.externalUrl,
                              );
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: Text(
                              widget.product.buttonText.isNotEmpty
                                  ? widget.product.buttonText
                                  : 'شراء',
                              style: const TextStyle(fontSize: 18),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: !widget.product.inStock
                                ? null
                                : () async {
                                    final cart = context.read<CartProvider>();
                                    final success = await cart.addToCart(
                                      widget.product,
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'تمت إضافة ${widget.product.name} إلى السلة'
                                              : cart.error ??
                                                    'فشل إضافة المنتج للسلة',
                                        ),
                                        backgroundColor: success
                                            ? null
                                            : AppColors.error,
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.add_shopping_cart),
                            label: Text(
                              widget.product.inStock
                                  ? 'إضافة إلى السلة'
                                  : 'نفذ من المخزون',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
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

class _ProductImageGallery extends StatelessWidget {
  final List<String> imageUrls;
  final int productId;
  final int selectedIndex;
  final ValueChanged<int> onImageSelected;

  const _ProductImageGallery({
    required this.imageUrls,
    required this.productId,
    required this.selectedIndex,
    required this.onImageSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return Container(
        width: double.infinity,
        height: 300,
        color: AppColors.surfaceSoft,
        child: const Icon(
          Icons.image_not_supported,
          size: 88,
          color: AppColors.textMuted,
        ),
      );
    }

    return Column(
      children: [
        Hero(
          tag: 'product_$productId',
          child: CachedNetworkImage(
            imageUrl: imageUrls[selectedIndex],
            width: double.infinity,
            height: 300,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 300,
              color: AppColors.surfaceSoft,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              height: 300,
              color: AppColors.surfaceSoft,
              child: const Icon(
                Icons.broken_image,
                size: 88,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
        if (imageUrls.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 74,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;

                return InkWell(
                  onTap: () => onImageSelected(index),
                  borderRadius: AppRadius.smRadius,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 74,
                    height: 74,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.smRadius,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: imageUrls[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: AppColors.surfaceSoft),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.broken_image,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
