import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_service.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../providers/cart_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ApiService _api = ApiService();
  int _selectedImageIndex = 0;
  List<Review> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final data = await _api.getReviews(productId: widget.product.id);
      if (!mounted) return;
      setState(() {
        _reviews = data.map((r) => Review.fromJson(r as Map<String, dynamic>)).toList();
        _isLoadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingReviews = false);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        backgroundColor: Colors.green,
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.product.price} دولار',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'وصف المنتج:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description.isNotEmpty
                        ? widget.product.description
                        : 'يتم تحديث الوصف الكامل لهذا المنتج.',
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'المراجعات:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingReviews)
                    const Center(child: CircularProgressIndicator())
                  else if (_reviews.isEmpty)
                    const Text('لا توجد مراجعات بعد.')
                  else
                    ..._reviews.map((review) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(review.author),
                            subtitle: Text(review.content),
                            trailing: Text('${review.rating}/5'),
                          ),
                        )),
                   const SizedBox(height: 32),
                   SizedBox(
                     width: double.infinity,
                     height: 56,
                     child: widget.product.type == 'external' && widget.product.externalUrl.isNotEmpty
                         ? ElevatedButton.icon(
                             onPressed: () async {
                               final uri = Uri.tryParse(widget.product.externalUrl);
                               if (uri != null && await canLaunchUrl(uri)) {
                                 await launchUrl(uri, mode: LaunchMode.externalApplication);
                               }
                             },
                             icon: const Icon(Icons.open_in_new),
                             label: Text(
                               widget.product.buttonText.isNotEmpty ? widget.product.buttonText : 'شراء',
                               style: const TextStyle(fontSize: 18),
                             ),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.green,
                               foregroundColor: Colors.white,
                             ),
                           )
                         : ElevatedButton.icon(
                             onPressed: () async {
                               final cart = context.read<CartProvider>();
                               final success = await cart.addToCart(widget.product);
                               if (!context.mounted) return;
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(
                                   content: Text(
                                     success
                                         ? 'تمت إضافة ${widget.product.name} إلى السلة'
                                         : cart.error ?? 'فشل إضافة المنتج للسلة',
                                   ),
                                   backgroundColor: success ? Colors.green : Colors.red,
                                 ),
                               );
                             },
                             icon: const Icon(Icons.add_shopping_cart),
                             label: const Text(
                               'إضافة إلى السلة',
                               style: TextStyle(fontSize: 18),
                             ),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.green,
                               foregroundColor: Colors.white,
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
        color: Colors.grey.shade200,
        child: Icon(
          Icons.image_not_supported,
          size: 88,
          color: Colors.grey.shade600,
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
              color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              height: 300,
              color: Colors.grey.shade200,
              child: Icon(
                Icons.broken_image,
                size: 88,
                color: Colors.grey.shade600,
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
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 74,
                    height: 74,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: imageUrls[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey.shade200),
                        errorWidget: (context, url, error) => Icon(
                          Icons.broken_image,
                          color: Colors.grey.shade500,
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
