import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_service.dart';
import '../core/currency_utils.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/recently_viewed_provider.dart';
import '../providers/wishlist_provider.dart';
import '../widgets/product_card.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ApiService _api = ApiService();
  int _selectedImageIndex = 0;
  int _quantity = 1;
  List<Product> _suggestedProducts = [];

  void _incrementQuantity() => setState(() => _quantity++);

  void _decrementQuantity() {
    if (_quantity <= 1) return;
    setState(() => _quantity--);
  }

  @override
  void initState() {
    super.initState();
    // Not awaited: purely local bookkeeping for the home screen's "recently
    // viewed" section, shouldn't block or affect this screen either way.
    context.read<RecentlyViewedProvider>().recordView(widget.product);
    _loadSuggestedProducts();
  }

  Future<void> _loadSuggestedProducts() async {
    try {
      final currency = context.read<CurrencyProvider>().currency;
      // A generic product page, not a per-category endpoint -- "suggested"
      // here just means "4 random products other than this one", not a
      // real recommendation engine.
      final data = await _api.getProducts(
        page: 1,
        perPage: 20,
        currency: currency,
      );
      if (!mounted) return;
      final pool =
          data
              .map((p) => Product.fromJson(p))
              .where((p) => p.id != widget.product.id)
              .toList()
            ..shuffle(Random());
      setState(() {
        _suggestedProducts = pool.take(5).toList();
      });
    } catch (_) {
      // Leave _suggestedProducts empty; the section hides itself when empty.
    }
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
    final isExternal =
        widget.product.type == 'external' &&
        widget.product.externalUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.product.name),
        actions: [_DetailWishlistButton(product: widget.product)],
      ),
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
                  if (!isExternal) ...[
                    _QuantitySelector(
                      quantity: _quantity,
                      onIncrement: _incrementQuantity,
                      onDecrement: _decrementQuantity,
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: isExternal
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
                                      quantity: _quantity,
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
            if (_suggestedProducts.isNotEmpty)
              _SuggestedProductsSection(products: _suggestedProducts),
          ],
        ),
      ),
    );
  }
}

class _SuggestedProductsSection extends StatelessWidget {
  final List<Product> products;

  const _SuggestedProductsSection({required this.products});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'قد يعجبك أيضاً',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 290,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 170,
                  child: ProductCard(key: ValueKey(product.id), product: product),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _DetailWishlistButton extends StatelessWidget {
  final Product product;

  const _DetailWishlistButton({required this.product});

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider>();
    final isWishlisted = wishlist.isWishlisted(product.id);

    return IconButton(
      tooltip: isWishlisted ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
      icon: Icon(
        isWishlisted ? Icons.favorite : Icons.favorite_border,
        color: isWishlisted ? AppColors.accentRed : null,
      ),
      onPressed: () async {
        final success = await context.read<WishlistProvider>().toggle(product);
        if (!context.mounted || success) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<WishlistProvider>().error ?? 'فشل تحديث المفضلة',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QuantitySelector({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'الكمية:',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.smRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: quantity > 1 ? onDecrement : null,
                icon: const Icon(Icons.remove),
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows [imageUrl] with a border that hugs the actual picture, not the
/// surrounding page area. `Image`/`CachedNetworkImage` without an explicit
/// width/height does NOT reliably shrink to the image's aspect ratio in
/// both axes under loose constraints -- in practice one axis (whichever
/// isn't the binding constraint) can end up filling the full available
/// space instead of the image's real proportions, leaving the border
/// looking "tight" on one side and stretched on the other. Resolving the
/// image's actual pixel dimensions first and sizing an `AspectRatio` from
/// that is the reliable way to get a border that matches the image in
/// both dimensions.
class _FittedBorderedImage extends StatefulWidget {
  final String imageUrl;

  const _FittedBorderedImage({required this.imageUrl});

  @override
  State<_FittedBorderedImage> createState() => _FittedBorderedImageState();
}

class _FittedBorderedImageState extends State<_FittedBorderedImage> {
  // Falls back to a square box if resolution fails -- without this, a
  // failed/slow network load left the widget stuck on the loading
  // spinner forever, since nothing else ever set _aspectRatio.
  double? _aspectRatio;
  ImageStream? _stream;
  late final ImageStreamListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = ImageStreamListener(_onImageResolved, onError: _onImageError);
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _FittedBorderedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _stream?.removeListener(_listener);
      _aspectRatio = null;
      _resolve();
    }
  }

  void _resolve() {
    final stream = CachedNetworkImageProvider(
      widget.imageUrl,
    ).resolve(const ImageConfiguration());
    _stream = stream;
    stream.addListener(_listener);
  }

  void _onImageResolved(ImageInfo info, bool synchronousCall) {
    if (!mounted) return;
    setState(() {
      _aspectRatio = info.image.width / info.image.height;
    });
  }

  void _onImageError(Object exception, StackTrace? stackTrace) {
    if (!mounted) return;
    // Square fallback so CachedNetworkImage's own errorWidget still gets
    // a reasonable box to render into, instead of hanging on the spinner.
    setState(() => _aspectRatio = 1);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) =>
          const Icon(Icons.broken_image, size: 88, color: AppColors.textMuted),
    );

    // Aspect ratio not resolved yet -- show unbordered at a placeholder
    // size rather than guessing, which would flash a wrongly-sized
    // border for a moment before the real one snaps in.
    if (_aspectRatio == null) {
      return const SizedBox(
        width: 250,
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: _aspectRatio!,
      child: DecoratedBox(
        // Foreground, not background: the box is sized to exactly match
        // the image's own aspect ratio (no letterboxing), so the image
        // paints edge-to-edge -- a background-positioned border would sit
        // underneath it and be completely painted over.
        position: DecorationPosition.foreground,
        decoration: const BoxDecoration(
          border: Border.fromBorderSide(
            BorderSide(color: Colors.black, width: 1),
          ),
        ),
        child: image,
      ),
    );
  }
}

class _ProductImageGallery extends StatefulWidget {
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
  State<_ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<_ProductImageGallery> {
  late final PageController _pageController = PageController(
    initialPage: widget.selectedIndex,
  );

  @override
  void didUpdateWidget(covariant _ProductImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the swipeable page view in sync when a thumbnail tap changes
    // the selected index from outside (rather than a swipe, which already
    // reports its own index change via onPageChanged below).
    if (widget.selectedIndex != oldWidget.selectedIndex &&
        widget.selectedIndex != _pageController.page?.round()) {
      _pageController.animateToPage(
        widget.selectedIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        width: double.infinity,
        height: 300,
        color: AppColors.background,
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
          tag: 'product_${widget.productId}',
          child: Container(
            width: double.infinity,
            height: 300,
            color: AppColors.background,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: widget.onImageSelected,
              itemBuilder: (context, index) => Center(
                child: _FittedBorderedImage(imageUrl: widget.imageUrls[index]),
              ),
            ),
          ),
        ),
        if (widget.imageUrls.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 74,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: widget.imageUrls.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isSelected = widget.selectedIndex == index;

                return InkWell(
                  onTap: () => widget.onImageSelected(index),
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
                        imageUrl: widget.imageUrls[index],
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
