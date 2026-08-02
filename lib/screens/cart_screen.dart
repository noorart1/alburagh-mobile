import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ApiService _api = ApiService();

  static final Uri _originalCartUri = Uri.parse(
    'https://alburagh.com/%d8%b3%d9%84%d8%a9-%d8%a7%d9%84%d9%85%d8%b4%d8%aa%d8%b1%d9%8a%d8%a7%d8%aa/',
  );

  bool _checkoutLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CartProvider>().loadCart();
      }
    });
  }

  Future<void> _showClearConfirmation(CartProvider cart) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفريغ السلة'),
        content: const Text('هل تريد إزالة جميع المنتجات من السلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تفريغ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await cart.clearCart();
      if (!mounted || cart.error != null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تفريغ السلة')),
      );
    }
  }

  /// Sends the customer to the real website cart/checkout page — already
  /// logged in there if they're logged in in the app — so checkout (address,
  /// shipping, COD/PayPal/card, all of it) happens through WooCommerce's own
  /// working checkout instead of being reimplemented in the app.
  Future<void> _goToWebsiteCart() async {
    setState(() => _checkoutLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.user?.token;

      Uri targetUri = _originalCartUri;
      if (auth.isLoggedIn && token != null && token.isNotEmpty) {
        try {
          final url = await _api.createAutoLoginLink(
            token: token,
            redirectTo: _originalCartUri.toString(),
          );
          if (url != null && url.isNotEmpty) {
            targetUri = Uri.parse(url);
          }
        } catch (_) {
          // Fall back to the plain cart URL below; the user can still log
          // in manually on the website if needed.
        }
      }

      if (await canLaunchUrl(targetUri)) {
        await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح صفحة السلة')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkoutLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('سلة المشتريات (${cart.itemCount})'),
        actions: [
          IconButton(
            tooltip: 'فتح السلة الأصلية',
            icon: const Icon(Icons.open_in_new),
            onPressed: _checkoutLoading ? null : _goToWebsiteCart,
          ),
          if (cart.items.isNotEmpty)
            IconButton(
              tooltip: 'تفريغ السلة',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: cart.isLoading ? null : () => _showClearConfirmation(cart),
            ),
        ],
      ),
      body: _buildBody(cart),
      bottomNavigationBar: cart.items.isEmpty || cart.isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الإجمالي',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${cart.formatPrice(cart.totalPrice)} دولار',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _checkoutLoading ? null : _goToWebsiteCart,
                        icon: const Icon(Icons.payment),
                        label: Text(
                          _checkoutLoading ? 'جاري الفتح...' : 'إتمام الشراء',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody(CartProvider cart) {
    if (cart.isLoading && cart.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (cart.error != null && cart.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(cart.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: cart.isLoading ? null : cart.loadCart,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (cart.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: cart.loadCart,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey),
            SizedBox(height: 16),
            Center(child: Text('سلة المشتريات فارغة')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: cart.loadCart,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: cart.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _CartItemTile(
          item: cart.items[index],
          enabled: !cart.isLoading,
          onIncrease: () => cart.updateQuantity(
            cart.items[index].product,
            cart.items[index].quantity + 1,
          ),
          onDecrease: () => cart.updateQuantity(
            cart.items[index].product,
            cart.items[index].quantity - 1,
          ),
          onRemove: () => cart.removeFromCart(cart.items[index].product),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final bool enabled;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.enabled,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final price = double.tryParse(product.price) ?? 0;
    final image = product.imageUrl;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image.isEmpty
                  ? Container(
                      width: 72,
                      height: 88,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.book_outlined, size: 32),
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      width: 72,
                      height: 88,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.book_outlined, size: 32),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text('${price.toStringAsFixed(2)} دولار'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: enabled && item.quantity > 1
                            ? onDecrease
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: enabled ? onIncrease : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'إزالة',
              onPressed: enabled ? onRemove : null,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
