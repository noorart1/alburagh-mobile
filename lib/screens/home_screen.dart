import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/recently_viewed_provider.dart';
import '../widgets/product_card.dart';
import 'category_screen.dart';
import 'product_list_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  List<Product> featuredProducts = [];
  List<Product> newArrivals = [];
  List<Product> bestSellers = [];
  List<Category> categories = [];
  bool isLoading = true;
  int _currentBannerIndex = 0;

  static const List<String> _bannerImageUrls = [
    'https://alburagh.com/wp-content/uploads/2024/10/slayd-alburagh2.webp',
    'https://alburagh.com/wp-content/uploads/2024/10/slayd-alburagh3.webp',
    'https://alburagh.com/wp-content/uploads/2024/10/slayd-alburagh1.webp',
  ];

  late final CurrencyProvider _currencyProvider;

  @override
  void initState() {
    super.initState();
    _currencyProvider = context.read<CurrencyProvider>();
    _currencyProvider.addListener(_onCurrencyChanged);
    loadData();
  }

  @override
  void dispose() {
    _currencyProvider.removeListener(_onCurrencyChanged);
    super.dispose();
  }

  void _onCurrencyChanged() => loadData();

  Future<void> loadData() async {
    try {
      final currency = _currencyProvider.currency;
      final featuredData = await _api.getFeaturedProducts(currency: currency);
      final newArrivalsData = await _api.getNewArrivals(currency: currency);
      final catData = await _api.getCategories();

      if (!mounted) return;
      setState(() {
        featuredProducts = featuredData
            .map((p) => Product.fromJson(p))
            .toList();
        newArrivals = newArrivalsData.map((p) => Product.fromJson(p)).toList();
        categories = catData.map((c) => Category.fromJson(c)).toList();
        isLoading = false;
      });

      // Loaded separately, after the rest of the home screen is already
      // showing: it's a secondary section, and a slow/failed best-sellers
      // request shouldn't hold up or break the sections above it.
      try {
        final bestSellersData = await _api.getBestSellers(currency: currency);
        if (!mounted) return;
        setState(() {
          bestSellers = bestSellersData
              .map((p) => Product.fromJson(p))
              .toList();
        });
      } catch (_) {
        // Leave bestSellers as-is; _buildSection hides itself when empty.
      }
      // Load cart data after loading products. Do not let a cart failure
      // block the already-loaded home content.
      try {
        await context.read<CartProvider>().loadCart();
      } catch (_) {
        // Ignore cart errors so the home screen stays usable.
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentlyViewed = context.watch<RecentlyViewedProvider>().items;

    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: const Text(
                            'AlBuragh',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SearchBarDelegate(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SearchScreen(),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: AppRadius.lgRadius,
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.search,
                                    color: AppColors.textMuted,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'ابحث عن المنتجات والفئات...',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          CarouselSlider.builder(
                            itemCount: _bannerImageUrls.length,
                            options: CarouselOptions(
                              // Matches the banner images' actual 1343x571
                              // pixel size so BoxFit.cover below shows each one
                              // in full instead of cropping it to fit a fixed
                              // height that doesn't match their real proportions.
                              aspectRatio: 1343 / 571,
                              autoPlay: true,
                              autoPlayInterval: const Duration(seconds: 4),
                              enlargeCenterPage: true,
                              viewportFraction: 0.92,
                              onPageChanged: (index, reason) {
                                setState(() => _currentBannerIndex = index);
                              },
                            ),
                            itemBuilder: (context, index, realIndex) {
                              return ClipRRect(
                                borderRadius: AppRadius.mdRadius,
                                child: CachedNetworkImage(
                                  imageUrl: _bannerImageUrls[index],
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: AppColors.surfaceSoft,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: AppColors.surfaceSoft,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _bannerImageUrls.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: _currentBannerIndex == index ? 18 : 7,
                                height: 7,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentBannerIndex == index
                                      ? AppColors.primary
                                      : AppColors.border,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                            child: Text(
                              'الأقسام',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 146,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                return Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CategoryScreen(category: cat),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color:
                                                  AppColors
                                                      .categoryAccents[index %
                                                      AppColors
                                                          .categoryAccents
                                                          .length],
                                              width: 2,
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            radius: 30,
                                            backgroundColor:
                                                AppColors.surfaceSoft,
                                            backgroundImage:
                                                cat.imageUrl.isNotEmpty
                                                ? NetworkImage(cat.imageUrl)
                                                : null,
                                            child: cat.imageUrl.isEmpty
                                                ? Icon(
                                                    Icons.category,
                                                    color:
                                                        AppColors
                                                            .categoryAccents[index %
                                                            AppColors
                                                                .categoryAccents
                                                                .length],
                                                    size: 25,
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          width: 75,
                                          child: Text(
                                            cat.name,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textPrimary,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${cat.count} منتج',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          _buildSection(
                            title: 'شوهد مؤخراً',
                            products: recentlyViewed,
                          ),
                          _buildSection(
                            title: 'كتب وسلاسل مميزة',
                            products: featuredProducts,
                            // "More" here browses the whole catalog rather than
                            // the other featured picks (which don't really have
                            // "more" beyond the handful already shown).
                            seeMoreBuilder: (context) => CategoryScreen(
                              category: Category(
                                id: 0,
                                name: 'كل الكتب',
                                imageUrl: '',
                                slug: 'all-books',
                              ),
                            ),
                          ),
                          _buildSection(
                            title: 'الأكثر مبيعاً',
                            products: bestSellers,
                          ),
                          _buildSection(
                            title: 'وصل حديثاً',
                            products: newArrivals,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Product> products,
    WidgetBuilder? seeMoreBuilder,
  }) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
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
            itemCount: products.length + 1,
            itemBuilder: (context, index) {
              if (index == products.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: 110,
                    child: _MoreCard(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                seeMoreBuilder ??
                                (context) => ProductListScreen(
                                  title: title,
                                  products: products,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 160,
                  child: ProductCard(product: products[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Keeps the search bar pinned at the top of the scroll view (below the
/// logo, which scrolls away normally) instead of scrolling off along with
/// the rest of the home screen content.
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _SearchBarDelegate({required this.child});

  static const double _height = 72;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SearchBarDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

class _MoreCard extends StatelessWidget {
  final VoidCallback onTap;

  const _MoreCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.surfaceSoft,
                child: Icon(Icons.arrow_back, color: AppColors.primary),
              ),
              SizedBox(height: 8),
              Text(
                'المزيد',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
