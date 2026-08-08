import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_service.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/wishlist_provider.dart';
import '../widgets/product_card.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final ApiService _api = ApiService();

  static final Uri _originalWishlistUri = Uri.parse(
    'https://alburagh.com/favorites/',
  );

  bool _openLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<WishlistProvider>().loadWishlist();
      }
    });
  }

  Future<void> _openWebsiteWishlist() async {
    setState(() => _openLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.user?.token;

      Uri targetUri = _originalWishlistUri;
      if (auth.isLoggedIn && token != null && token.isNotEmpty) {
        try {
          final url = await _api.createAutoLoginLink(
            token: token,
            redirectTo: _originalWishlistUri.toString(),
          );
          if (url != null && url.isNotEmpty) {
            targetUri = Uri.parse(url);
          }
        } catch (_) {
          // Fall back to the plain wishlist URL below.
        }
      }

      if (await canLaunchUrl(targetUri)) {
        await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح صفحة المفضلة')));
      }
    } finally {
      if (mounted) setState(() => _openLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('المفضلة (${wishlist.itemCount})'),
        actions: [
          IconButton(
            tooltip: 'فتح المفضلة على الموقع',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openLoading ? null : _openWebsiteWishlist,
          ),
        ],
      ),
      body: _buildBody(wishlist),
    );
  }

  Widget _buildBody(WishlistProvider wishlist) {
    if (wishlist.isLoading && wishlist.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (wishlist.error != null && wishlist.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(wishlist.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: wishlist.isLoading ? null : wishlist.loadWishlist,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (wishlist.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: wishlist.loadWishlist,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.favorite_border, size: 72, color: AppColors.textMuted),
            SizedBox(height: 16),
            Center(
              child: Text(
                'قائمة المفضلة فارغة',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: wishlist.loadWishlist,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: wishlist.items.length,
        itemBuilder: (context, index) {
          final product = wishlist.items[index];
          return ProductCard(key: ValueKey(product.id), product: product);
        },
      ),
    );
  }
}
