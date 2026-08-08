import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/currency_utils.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/product_card.dart';
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
  List<Product> collectionsProducts = [];
  Category? collectionsCategory;
  List<Product> featuredBooksProducts = [];
  Category? featuredBooksCategory;
  List<Product> educationalBooksProducts = [];
  Category? educationalBooksCategory;
  List<Product> religiousProducts = [];
  Category? religiousCategory;
  List<Product> heritageBooksProducts = [];
  Category? heritageBooksCategory;
  List<Product> skillsDevelopmentProducts = [];
  Category? skillsDevelopmentCategory;
  List<Category> categories = [];
  bool isLoading = true;

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

  Future<void> loadData() async {
    try {
      final currency = _currencyProvider.currency;
      final catData = await _api.getCategories();

      if (!mounted) return;
      setState(() {
        categories = catData.map((c) => Category.fromJson(c)).toList();
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
        isLoading = false;
      });

      // Same treatment as the other category rows below: secondary section,
      // loaded after the category list resolves which category id this is.
      try {
        final educationalBooksCat = educationalBooksCategory;
        if (educationalBooksCat != null) {
          final educationalBooksData = await _api.getProducts(
            category:
                educationalBooksCat.slug ?? educationalBooksCat.id.toString(),
            currency: currency,
          );
          if (!mounted) return;
          setState(() {
            educationalBooksProducts = educationalBooksData
                .map((p) => Product.fromJson(p))
                .toList();
          });
        }
      } catch (_) {
        // Leave educationalBooksProducts as-is; _buildSection hides itself when empty.
      }
      try {
        final intellectualGamesCat = intellectualGamesCategory;
        if (intellectualGamesCat != null) {
          final intellectualGamesData = await _api.getProducts(
            category:
                intellectualGamesCat.slug ?? intellectualGamesCat.id.toString(),
            currency: currency,
          );
          if (!mounted) return;
          setState(() {
            intellectualGamesProducts = intellectualGamesData
                .map((p) => Product.fromJson(p))
                .toList();
          });
        }
      } catch (_) {
        // Leave intellectualGamesProducts as-is; _buildSection hides itself when empty.
      }
      // Same treatment as best-sellers above: secondary section, loaded
      // after the category list resolves which category id is "Collections".
      try {
        final collectionsCat = collectionsCategory;
        if (collectionsCat != null) {
          final collectionsData = await _api.getProducts(
            category: collectionsCat.slug ?? collectionsCat.id.toString(),
            currency: currency,
          );
          if (!mounted) return;
          setState(() {
            collectionsProducts = collectionsData
                .map((p) => Product.fromJson(p))
                .toList();
          });
        }
      } catch (_) {
        // Leave collectionsProducts as-is; _buildSection hides itself when empty.
      }
      // Same treatment: the row should show this category's own products,
      // matching what its title and "more" button both point to, rather
      // than the unrelated featured-products list.
      try {
        final featuredBooksCat = featuredBooksCategory;
        if (featuredBooksCat != null) {
          final featuredBooksData = await _api.getProducts(
            category: featuredBooksCat.slug ?? featuredBooksCat.id.toString(),
            currency: currency,
          );
          if (!mounted) return;
          setState(() {
            featuredBooksProducts = featuredBooksData
                .map((p) => Product.fromJson(p))
                .toList();
          });
        }
      } catch (_) {
        // Leave featuredBooksProducts as-is; _buildSection hides itself when empty.
      }
      // Same treatment as the other secondary sections above.
      try {
        final religiousCat = religiousCategory;
        if (religiousCat != null) {
          final religiousData = await _api.getProducts(
            category: religiousCat.slug ?? religiousCat.id.toString(),
            currency: currency,
          );
          if (!mounted) return;
          setState(() {
            religiousProducts = religiousData
                .map((p) => Product.fromJson(p))
                .toList();
          });
        }
      } catch (_) {
        // Leave religiousProducts as-is; _buildSection hides itself when empty.
      }
      // Same treatment as the other secondary sections above.
      try {
        final heritageBooksCat = heritageBooksCategory;
        if (heritageBooksCat != null) {
          final heritageBooksData = await _api.getProducts(
            category: heritageBooksCat.slug ?? heritageBooksCat.id.toString(),
            currency: currency,
          );
          if (!mounted) return;
          setState(() {
            heritageBooksProducts = heritageBooksData
                .map((p) => Product.fromJson(p))
                .toList();
          });
        }
      } catch (_) {
        // Leave heritageBooksProducts as-is; _buildSection hides itself when empty.
      }
      // Same treatment as the other secondary sections above.
      try {
        final skillsDevelopmentCat = skillsDevelopmentCategory;
        if (skillsDevelopmentCat != null) {
          final skillsDevelopmentData = await _api.getProducts(
            category:
                skillsDevelopmentCat.slug ?? skillsDevelopmentCat.id.toString(),
            currency: currency,
          );
          if (!mounted) return;
          setState(() {
            skillsDevelopmentProducts = skillsDevelopmentData
                .map((p) => Product.fromJson(p))
                .toList();
          });
        }
      } catch (_) {
        // Leave skillsDevelopmentProducts as-is; _buildSection hides itself when empty.
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The header now paints purple all the way to the very top of the
      // screen, behind the status bar, instead of stopping below it --
      // so the status bar icons need to switch to light/white to stay
      // visible against that dark background.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: isLoading
            ? const SafeArea(child: Center(child: CircularProgressIndicator()))
            : RefreshIndicator(
                onRefresh: loadData,
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
                              seeMoreBuilder: collectionsCategory != null
                                  ? (context) => CategoryScreen(
                                      category: collectionsCategory,
                                    )
                                  : null,
                            ),
                            _buildSection(
                              title: 'الكتب المصورة',
                              products: featuredBooksProducts,
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
                              seeMoreBuilder: educationalBooksCategory != null
                                  ? (context) => CategoryScreen(
                                      category: educationalBooksCategory,
                                    )
                                  : null,
                            ),
                            _buildSection(
                              title: 'الألعاب التعليمية',
                              products: intellectualGamesProducts,
                              seeMoreBuilder: intellectualGamesCategory != null
                                  ? (context) => CategoryScreen(
                                      category: intellectualGamesCategory,
                                    )
                                  : null,
                            ),
                            _buildSection(
                              title: 'الكتب الدينية',
                              products: religiousProducts,
                              seeMoreBuilder: religiousCategory != null
                                  ? (context) => CategoryScreen(
                                      category: religiousCategory,
                                    )
                                  : null,
                            ),
                            _buildSection(
                              title: 'الكتب التراثية',
                              products: heritageBooksProducts,
                              seeMoreBuilder: heritageBooksCategory != null
                                  ? (context) => CategoryScreen(
                                      category: heritageBooksCategory,
                                    )
                                  : null,
                            ),
                            _buildSection(
                              title: 'تنمية المهارات',
                              products: skillsDevelopmentProducts,
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
    WidgetBuilder? seeMoreBuilder,
  }) {
    if (products.isEmpty) return const SizedBox.shrink();

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
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0), //4
                child: SizedBox(
                  width: 170,
                  child: ProductCard(key: ValueKey(product.id), product: product),
                ),
              );
            },
          ),
        ),
      ],
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

  static const List<String> _bannerImageUrls = [
    'https://alburagh.com/wp-content/uploads/2024/10/slayd-alburagh2.webp',
    'https://alburagh.com/wp-content/uploads/2024/10/slayd-alburagh3.webp',
    'https://alburagh.com/wp-content/uploads/2024/10/slayd-alburagh1.webp',
  ];

  // The banner images' own pixel proportions (used below to derive the
  // carousel's aspect ratio so nothing gets cropped -- see the comment
  // on `aspectRatio` in CarouselOptions).
  static const double _imageAspectRatio = 1343 / 571;
  static const double _viewportFraction = 0.92;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Matches the 16px horizontal margin already used by the section
      // titles and the rest of the home screen's content below the
      // header, so the banner doesn't sit edge-to-edge while everything
      // else on the page is inset.
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CarouselSlider.builder(
            itemCount: _bannerImageUrls.length,
            options: CarouselOptions(
              // CarouselOptions.aspectRatio sets the carousel's fixed
              // HEIGHT as `availableWidth / aspectRatio`, but each item's
              // own WIDTH is only `availableWidth * viewportFraction`.
              // Passing the image's raw aspect ratio here made every
              // item's box relatively taller/narrower than the source
              // image, so BoxFit.cover below was cropping the left/right
              // edges of every banner (and any Arabic text baked in near
              // those edges) to fill that mismatched box. Dividing by
              // viewportFraction makes the item box's actual ratio match
              // the image's ratio exactly, so `cover` no longer needs to
              // crop anything.
              aspectRatio: _imageAspectRatio / _viewportFraction,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 4),
              enlargeCenterPage: true,
              viewportFraction: _viewportFraction,
              onPageChanged: (index, reason) {
                setState(() => _currentBannerIndex = index);
              },
            ),
            itemBuilder: (context, index, realIndex) {
              return ClipRRect(
                borderRadius: AppRadius.mdRadius,
                child: Stack(
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
                ),
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
      ),
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
