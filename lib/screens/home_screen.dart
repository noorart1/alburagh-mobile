import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/currency_utils.dart';
import '../core/home_cache.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/skeleton_box.dart';
import 'category_screen.dart';
import 'product_detail_screen.dart';
import 'product_list_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  List<Product> intellectualGamesProducts = [];
  Category? intellectualGamesCategory;
  bool intellectualGamesLoading = true;
  List<Product> collectionsProducts = [];
  Category? collectionsCategory;
  bool collectionsLoading = true;
  List<Product> featuredBooksProducts = [];
  Category? featuredBooksCategory;
  bool featuredBooksLoading = true;
  List<Product> educationalBooksProducts = [];
  Category? educationalBooksCategory;
  bool educationalBooksLoading = true;
  List<Product> religiousProducts = [];
  Category? religiousCategory;
  bool religiousLoading = true;
  List<Product> heritageBooksProducts = [];
  Category? heritageBooksCategory;
  bool heritageBooksLoading = true;
  List<Product> skillsDevelopmentProducts = [];
  Category? skillsDevelopmentCategory;
  bool skillsDevelopmentLoading = true;
  List<Category> categories = [];
  bool categoriesLoading = true;

  // Bumped on every network refresh (initial load, currency change, pull to
  // refresh, connectivity regained) so a slow, stale request can tell it's
  // no longer the latest and skip applying its response -- same pattern as
  // WishlistProvider._requestId / _HomeSearchBarState._searchGeneration.
  int _loadGeneration = 0;

  bool _hasConnection = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  late final CurrencyProvider _currencyProvider;

  @override
  void initState() {
    super.initState();
    _currencyProvider = context.read<CurrencyProvider>();
    _currencyProvider.addListener(_onCurrencyChanged);
    // Cache-first: get any last-known content on screen immediately, then
    // independently kick off the real network refresh -- neither awaits
    // the other, so a slow/offline network fetch never delays showing
    // whatever's cached, and a cache-read hiccup never delays the network
    // request starting.
    unawaited(_loadFromCache());
    unawaited(_loadFromNetwork());
    unawaited(_initConnectivity());
  }

  @override
  void dispose() {
    _currencyProvider.removeListener(_onCurrencyChanged);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _onCurrencyChanged() => _loadFromNetwork();

  Future<void> _initConnectivity() async {
    final initial = await Connectivity().checkConnectivity();
    if (!mounted) return;
    _hasConnection = initial.any((r) => r != ConnectivityResult.none);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      // Only refetch on the none -> some transition (regaining
      // connectivity), not on every connectivity event -- otherwise this
      // would also fire (redundantly) whenever the connection type merely
      // changes, e.g. wifi to mobile data.
      if (hasConnection && !_hasConnection) {
        _loadFromNetwork();
      }
      _hasConnection = hasConnection;
    });
  }

  Category? _findCategoryBy(List<Category> categories, List<String> matches) {
    final candidates = matches.map((m) => m.toLowerCase()).toSet();
    for (final cat in categories) {
      if (candidates.contains(cat.slug?.toLowerCase()) ||
          candidates.contains(cat.name.toLowerCase())) {
        return cat;
      }
    }
    return null;
  }

  void _resolveCategoryMatches() {
    collectionsCategory = _findCategoryBy(categories, ['collections']);
    featuredBooksCategory = _findCategoryBy(categories, [
      'الكتب المصورة',
      'picture-books',
    ]);
    educationalBooksCategory = _findCategoryBy(categories, [
      'الكتب التعليمية',
      'educational',
    ]);
    intellectualGamesCategory = _findCategoryBy(categories, [
      'الألعاب التعليمية',
      'intellectual-game',
    ]);
    religiousCategory = _findCategoryBy(categories, [
      'دينية',
      'كتب دينية',
      'الكتب الدينية',
      'religious',
      'religious-books',
    ]);
    heritageBooksCategory = _findCategoryBy(categories, [
      'تراثية',
      'كتب تراثية',
      'الكتب التراثية',
      'التراث',
      'heritage',
      'heritage-books',
    ]);
    skillsDevelopmentCategory = _findCategoryBy(categories, [
      'مهارات',
      'تنمية المهارات',
      'تنمية مهارات',
      'skills',
      'skills-development',
    ]);
  }

  /// Populates every section from its last-cached response, if any, so a
  /// reopened app shows real content immediately instead of a blank/loading
  /// screen while _loadFromNetwork (kicked off independently in initState)
  /// catches up in the background.
  Future<void> _loadFromCache() async {
    final cached = await Future.wait([
      HomeCache.readList(HomeCache.categoriesKey),
      HomeCache.readList(HomeCache.productsKey('collections')),
      HomeCache.readList(HomeCache.productsKey('featuredBooks')),
      HomeCache.readList(HomeCache.productsKey('educational')),
      HomeCache.readList(HomeCache.productsKey('intellectualGames')),
      HomeCache.readList(HomeCache.productsKey('religious')),
      HomeCache.readList(HomeCache.productsKey('heritageBooks')),
      HomeCache.readList(HomeCache.productsKey('skillsDevelopment')),
    ]);
    if (!mounted) return;

    void applySection(
      List<dynamic>? data,
      void Function(List<Product> products) apply,
      VoidCallback markLoaded,
    ) {
      if (data == null) return;
      apply(data.map((p) => Product.fromJson(p)).toList());
      markLoaded();
    }

    setState(() {
      final cachedCategories = cached[0];
      if (cachedCategories != null) {
        categories = cachedCategories.map((c) => Category.fromJson(c)).toList();
        _resolveCategoryMatches();
        categoriesLoading = false;
      }
      applySection(
        cached[1],
        (p) => collectionsProducts = p,
        () => collectionsLoading = false,
      );
      applySection(
        cached[2],
        (p) => featuredBooksProducts = p,
        () => featuredBooksLoading = false,
      );
      applySection(
        cached[3],
        (p) => educationalBooksProducts = p,
        () => educationalBooksLoading = false,
      );
      applySection(
        cached[4],
        (p) => intellectualGamesProducts = p,
        () => intellectualGamesLoading = false,
      );
      applySection(
        cached[5],
        (p) => religiousProducts = p,
        () => religiousLoading = false,
      );
      applySection(
        cached[6],
        (p) => heritageBooksProducts = p,
        () => heritageBooksLoading = false,
      );
      applySection(
        cached[7],
        (p) => skillsDevelopmentProducts = p,
        () => skillsDevelopmentLoading = false,
      );
    });
  }

  /// Fetches one section's products for [category] (a no-op if the category
  /// hasn't resolved), applies + caches the result, and always clears the
  /// section's loading flag when it settles (success or failure) so its
  /// skeleton never spins forever. Independent per section: a slow/failing
  /// fetch for one section never blocks or is blocked by any other.
  Future<void> _loadProductSection({
    required int generation,
    required String currency,
    required Category? category,
    required String cacheKey,
    required void Function(List<Product> products) onLoaded,
    required VoidCallback onSettled,
  }) async {
    if (category == null) {
      if (mounted && generation == _loadGeneration) setState(onSettled);
      return;
    }
    try {
      final data = await _api.getProducts(
        category: category.slug ?? category.id.toString(),
        currency: currency,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        onLoaded(data.map((p) => Product.fromJson(p)).toList());
        onSettled();
      });
      unawaited(HomeCache.writeList(HomeCache.productsKey(cacheKey), data));
    } catch (_) {
      // Leave this section's products as-is (cached/previous data, or
      // still empty); _buildSection hides itself when empty and not
      // loading, matching the previous behavior for a failed fetch.
      if (!mounted || generation != _loadGeneration) return;
      setState(onSettled);
    }
  }

  Future<void> _loadCart() async {
    // Independent, non-critical to the home screen's own content -- a cart
    // failure (or slowness) must never block or be blocked by anything
    // above.
    try {
      await context.read<CartProvider>().loadCart();
    } catch (_) {
      // Ignore cart errors so the home screen stays usable.
    }
  }

  /// Refreshes every section from the network: the real data source, run
  /// independently of and concurrently with everything else (cache
  /// population, other sections, the cart). Safe to call repeatedly
  /// (currency change, pull-to-refresh, connectivity regained) -- each call
  /// gets its own generation so a slow, superseded call's response can't
  /// clobber a newer one's.
  Future<void> _loadFromNetwork() async {
    final generation = ++_loadGeneration;
    final currency = _currencyProvider.currency;

    try {
      final catData = await _api.getCategories();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        categories = catData.map((c) => Category.fromJson(c)).toList();
        _resolveCategoryMatches();
        categoriesLoading = false;
      });
      unawaited(HomeCache.writeList(HomeCache.categoriesKey, catData));
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => categoriesLoading = false);
      // No resolved categories to fetch section products for -- but the
      // cart restore below is still independent of that failure.
      unawaited(_loadCart());
      return;
    }

    unawaited(
      _loadProductSection(
        generation: generation,
        currency: currency,
        category: collectionsCategory,
        cacheKey: 'collections',
        onLoaded: (p) => collectionsProducts = p,
        onSettled: () => collectionsLoading = false,
      ),
    );
    unawaited(
      _loadProductSection(
        generation: generation,
        currency: currency,
        category: featuredBooksCategory,
        cacheKey: 'featuredBooks',
        onLoaded: (p) => featuredBooksProducts = p,
        onSettled: () => featuredBooksLoading = false,
      ),
    );
    unawaited(
      _loadProductSection(
        generation: generation,
        currency: currency,
        category: educationalBooksCategory,
        cacheKey: 'educational',
        onLoaded: (p) => educationalBooksProducts = p,
        onSettled: () => educationalBooksLoading = false,
      ),
    );
    unawaited(
      _loadProductSection(
        generation: generation,
        currency: currency,
        category: intellectualGamesCategory,
        cacheKey: 'intellectualGames',
        onLoaded: (p) => intellectualGamesProducts = p,
        onSettled: () => intellectualGamesLoading = false,
      ),
    );
    unawaited(
      _loadProductSection(
        generation: generation,
        currency: currency,
        category: religiousCategory,
        cacheKey: 'religious',
        onLoaded: (p) => religiousProducts = p,
        onSettled: () => religiousLoading = false,
      ),
    );
    unawaited(
      _loadProductSection(
        generation: generation,
        currency: currency,
        category: heritageBooksCategory,
        cacheKey: 'heritageBooks',
        onLoaded: (p) => heritageBooksProducts = p,
        onSettled: () => heritageBooksLoading = false,
      ),
    );
    unawaited(
      _loadProductSection(
        generation: generation,
        currency: currency,
        category: skillsDevelopmentCategory,
        cacheKey: 'skillsDevelopment',
        onLoaded: (p) => skillsDevelopmentProducts = p,
        onSettled: () => skillsDevelopmentLoading = false,
      ),
    );

    unawaited(_loadCart());
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The header now paints purple all the way to the very top of the
      // screen, behind the status bar, instead of stopping below it --
      // so the status bar icons need to switch to light/white to stay
      // visible against that dark background.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _loadFromNetwork,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  color: const Color(0xFF6A1B9A),
                  // Single source of truth for the header's left/right
                  // margin -- the logo row and the search bar below
                  // both sit inside this same padding, so their edges
                  // line up on one consistent grid instead of each
                  // widget carrying its own, slightly different inset.
                  // The top inset adds the status bar's own height on
                  // top of the normal 12px breathing room, since this
                  // Container is no longer inside a SafeArea and its
                  // purple background now extends behind the status
                  // bar -- without this, the logo/currency row itself
                  // would be the thing sitting behind the icons.
                  padding: EdgeInsets.fromLTRB(
                    18,
                    MediaQuery.of(context).padding.top + 12,
                    18,
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CachedNetworkImage(
                            imageUrl:
                                'https://alburagh.com/wp-content/uploads/2021/07/d7.png',
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                          const _CurrencySwitcher(),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _HomeSearchBar(),
                    ],
                  ),
                ),
              ),
              SliverSafeArea(
                // The header above already accounted for the top
                // inset itself; this restores the normal safe-area
                // padding (left/right notches, bottom gesture area)
                // for everything else on the page.
                top: false,
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      const _BannerCarousel(),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          'الأقسام',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(
                        // Just the circle now (60 + its border) --
                        // the name/count text below it was removed.
                        height: 76,
                        child: categoriesLoading
                            ? ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                itemCount: 6,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: SkeletonBox(
                                    width: 60,
                                    height: 60,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              )
                            : ListView.builder(
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
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundColor:
                                                AppColors.surfaceSoft,
                                            // CachedNetworkImageProvider
                                            // (vs. plain NetworkImage) gives
                                            // this a disk cache, so the same
                                            // category icon isn't
                                            // re-downloaded every time the
                                            // home screen is reopened.
                                            backgroundImage:
                                                cat.imageUrl.isNotEmpty
                                                ? CachedNetworkImageProvider(
                                                    cat.imageUrl,
                                                  )
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
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      _buildSection(
                        title: 'السلاسل القصصية',
                        products: collectionsProducts,
                        loading: collectionsLoading,
                        seeMoreBuilder: collectionsCategory != null
                            ? (context) =>
                                  CategoryScreen(category: collectionsCategory)
                            : null,
                      ),
                      _buildSection(
                        title: 'الكتب المصورة',
                        products: featuredBooksProducts,
                        loading: featuredBooksLoading,
                        // Prefer the matching "الكتب المصورة" category so
                        // "more" browses that category specifically;
                        // only fall back to the whole catalog if no such
                        // category exists on the backend.
                        seeMoreBuilder: featuredBooksCategory != null
                            ? (context) => CategoryScreen(
                                category: featuredBooksCategory,
                              )
                            : (context) =>
                                  const CategoryScreen(title: 'كل الكتب'),
                      ),
                      _buildSection(
                        title: 'الكتب التعليمية',
                        products: educationalBooksProducts,
                        loading: educationalBooksLoading,
                        seeMoreBuilder: educationalBooksCategory != null
                            ? (context) => CategoryScreen(
                                category: educationalBooksCategory,
                              )
                            : null,
                      ),
                      _buildSection(
                        title: 'الألعاب التعليمية',
                        products: intellectualGamesProducts,
                        loading: intellectualGamesLoading,
                        seeMoreBuilder: intellectualGamesCategory != null
                            ? (context) => CategoryScreen(
                                category: intellectualGamesCategory,
                              )
                            : null,
                      ),
                      _buildSection(
                        title: 'الكتب الدينية',
                        products: religiousProducts,
                        loading: religiousLoading,
                        seeMoreBuilder: religiousCategory != null
                            ? (context) =>
                                  CategoryScreen(category: religiousCategory)
                            : null,
                      ),
                      _buildSection(
                        title: 'الكتب التراثية',
                        products: heritageBooksProducts,
                        loading: heritageBooksLoading,
                        seeMoreBuilder: heritageBooksCategory != null
                            ? (context) => CategoryScreen(
                                category: heritageBooksCategory,
                              )
                            : null,
                      ),
                      _buildSection(
                        title: 'تنمية المهارات',
                        products: skillsDevelopmentProducts,
                        loading: skillsDevelopmentLoading,
                        seeMoreBuilder: skillsDevelopmentCategory != null
                            ? (context) => CategoryScreen(
                                category: skillsDevelopmentCategory,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
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
    required bool loading,
    WidgetBuilder? seeMoreBuilder,
  }) {
    if (!loading && products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          // Row's child order is direction-aware: under the app's RTL
          // Directionality the title (first child) renders on the right
          // and the "see more" link (last child) renders on the left --
          // no manual textDirection juggling needed.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
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
                child: const Text(
                  'المزيد>',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 290,
          color: const Color(0xFFF9C900),
          child: loading
              ? const _ProductSectionSkeleton()
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0), //4
                      child: SizedBox(
                        width: 170,
                        child: ProductCard(
                          key: ValueKey(product.id),
                          product: product,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Matches _buildSection's real product row's geometry (170x290 cards, same
/// horizontal padding) so the layout doesn't jump when real content
/// replaces it.
class _ProductSectionSkeleton extends StatelessWidget {
  const _ProductSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 3,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: SkeletonBox(width: 170, height: 290),
      ),
    );
  }
}

/// The autoplay carousel owns its own `_currentBannerIndex` state in its
/// own widget rather than on `_HomeScreenState` -- previously every
/// auto-slide (every 4s, for as long as the home screen is alive)
/// triggered `setState` on the state that also owns every product list
/// and the categories row, rebuilding the entire home screen just to
/// move the banner dots.
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel();

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  int _currentBannerIndex = 0;

  // Empty until the live list arrives from the /banners endpoint; the
  // carousel renders nothing (see build below) while empty, whether
  // that's during the initial load or because the fetch failed.
  List<String> _bannerImageUrls = [];
  final ApiService _api = ApiService();

  // The banner images' own pixel proportions (used below to derive the
  // carousel's aspect ratio so nothing gets cropped -- see the comment
  // on `aspectRatio` in CarouselOptions). New banners uploaded to the
  // site must match this ratio or they'll be cropped/squeezed by
  // BoxFit.cover below.
  static const double _imageAspectRatio = 1343 / 571;
  static const double _viewportFraction = 1.0;

  @override
  void initState() {
    super.initState();
    _loadBannerImages();
  }

  Future<void> _loadBannerImages() async {
    try {
      final urls = await _api.getBannerImageUrls();
      if (mounted && urls.isNotEmpty) {
        setState(() => _bannerImageUrls = urls);
      }
    } catch (_) {
      // Leave the list empty; build() below renders nothing rather than
      // showing an error for a promotional banner.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerImageUrls.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Computed directly in pixels rather than via CarouselOptions.aspectRatio
        // (which derives height from width divided by a ratio applied to the
        // *carousel's* width, not each item's) -- with viewportFraction at 1.0
        // each item's width already equals the full available width, so this
        // is just availableWidth / imageAspectRatio, guaranteeing the item
        // box's ratio matches the source image's exactly. BoxFit.cover then
        // has nothing to crop or stretch.
        final bannerHeight = constraints.maxWidth / _imageAspectRatio;
        return _buildCarousel(bannerHeight);
      },
    );
  }

  Widget _buildCarousel(double bannerHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CarouselSlider.builder(
          itemCount: _bannerImageUrls.length,
          options: CarouselOptions(
            height: bannerHeight,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            viewportFraction: _viewportFraction,
            onPageChanged: (index, reason) {
              setState(() => _currentBannerIndex = index);
            },
          ),
          itemBuilder: (context, index, realIndex) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: _bannerImageUrls[index],
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.surfaceSoft,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.surfaceSoft,
                    child: const Icon(
                      Icons.image_not_supported,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                // A subtle scrim protects the readability of any text
                // near the bottom edge of the promotional artwork
                // against busy/bright photo backgrounds, independent
                // of what any individual banner image looks like.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.28),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.55],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _bannerImageUrls.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: _currentBannerIndex == index ? 18 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: _currentBannerIndex == index
                    ? AppColors.primary
                    : AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The home screen's search field: as-you-type suggestions in a floating
/// dropdown (via CompositedTransformTarget/Follower + an Overlay, so it
/// draws above the rest of the scroll content regardless of where this
/// widget currently sits), separate from the full results grid on
/// SearchScreen. Tapping a suggestion jumps straight to that product;
/// submitting (or the "see all" row) opens the full results grid.
class _HomeSearchBar extends StatefulWidget {
  const _HomeSearchBar();

  @override
  State<_HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<_HomeSearchBar> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  Timer? _debounce;
  int _searchGeneration = 0;
  List<Product> _suggestions = [];
  bool _isLoading = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    } else if (_controller.text.trim().isNotEmpty) {
      _showOverlay();
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _removeOverlay();
      return;
    }

    setState(() => _isLoading = true);
    _showOverlay();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(query.trim()),
    );
  }

  Future<void> _search(String query) async {
    final generation = ++_searchGeneration;

    try {
      final data = await _api.searchProducts(
        query,
        currency: context.read<CurrencyProvider>().currency,
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _suggestions = data.map((p) => Product.fromJson(p)).take(5).toList();
        _isLoading = false;
      });
      _showOverlay();
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _isLoading = false);
    }
  }

  void _openFullResults() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    _focusNode.unfocus();
    _removeOverlay();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(initialQuery: query),
      ),
    );
  }

  void _openProduct(Product product) {
    _focusNode.unfocus();
    _removeOverlay();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }

  void _showOverlay() {
    _removeOverlay();

    final renderBox = context.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? MediaQuery.of(context).size.width;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: _SuggestionsPanel(
            isLoading: _isLoading,
            suggestions: _suggestions,
            onProductTap: _openProduct,
            onSeeAllTap: _openFullResults,
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    // No outer margin here -- the parent header Container already applies
    // the header's single 18px horizontal margin, so this bar's left/right
    // edges line up exactly with the logo row above it instead of adding
    // a second, slightly different inset on top of that one.
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          onSubmitted: (_) => _openFullResults(),
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'ابحث عن المنتجات والفئات...',
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 15),
            prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
            // Keeps the icon's tap/visual box a fixed, centered size
            // regardless of how tight contentPadding gets, so it stays
            // clearly and consistently aligned with the hint text.
            prefixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 40),
            // The app-wide InputDecorationTheme sets `enabledBorder` and
            // `focusedBorder` as separate fields from `border` -- those
            // take precedence over `border: InputBorder.none` whenever
            // they're non-null. Left unset, this field was painting the
            // theme's own filled, bordered box (different corner radius,
            // a visible outline, a purple focus ring) nested inside this
            // widget's own pill-shaped Container, showing up as two
            // mismatched rounded boxes stacked on top of each other.
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }
}

class _SuggestionsPanel extends StatelessWidget {
  final bool isLoading;
  final List<Product> suggestions;
  final ValueChanged<Product> onProductTap;
  final VoidCallback onSeeAllTap;

  const _SuggestionsPanel({
    required this.isLoading,
    required this.suggestions,
    required this.onProductTap,
    required this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: AppRadius.mdRadius,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : suggestions.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'لا توجد نتائج',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final product = suggestions[index];
                        return ListTile(
                          dense: true,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: product.imageUrl.isEmpty
                                  ? Container(color: AppColors.surfaceSoft)
                                  : CachedNetworkImage(
                                      imageUrl: product.imageUrl,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 80,
                                      memCacheHeight: 80,
                                    ),
                            ),
                          ),
                          title: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            CurrencyUtils.formatString(
                              product.price,
                              product.currencySymbol,
                            ),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () => onProductTap(product),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    dense: true,
                    title: const Text(
                      'عرض كل النتائج',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    onTap: onSeeAllTap,
                  ),
                ],
              ),
      ),
    );
  }
}

class _CurrencySwitcher extends StatelessWidget {
  const _CurrencySwitcher();

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>().currency;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: AppRadius.mdRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CurrencyOption(
            label: 'USD',
            selected: currency == 'USD',
            onTap: () => context.read<CurrencyProvider>().setCurrency('USD'),
          ),
          _CurrencyOption(
            label: 'IQD',
            selected: currency == 'IQD',
            onTap: () => context.read<CurrencyProvider>().setCurrency('IQD'),
          ),
        ],
      ),
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: AppRadius.mdRadius,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
