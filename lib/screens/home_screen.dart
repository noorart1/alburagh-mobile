import 'dart:async';

import 'package:flutter/material.dart';
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
                intellectualGamesCat.slug ??
                intellectualGamesCat.id.toString(),
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
                      child: Container(
                        color: const Color(0xFF6A1B9A),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl:
                                        'https://alburagh.com/wp-content/uploads/2021/07/d7.png',
                                    height: 40,
                                    fit: BoxFit.contain,
                                  ),
                                  const _CurrencySwitcher(),
                                ],
                              ),
                            ),
                            _HomeSearchBar(),
                          ],
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
        Container(
          height: 290,
          color: const Color(0xFFF9C900),
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

/// The home screen's search field: as-you-type suggestions in a floating
/// dropdown (via CompositedTransformTarget/Follower + an Overlay, so it
/// draws above the rest of the scroll content regardless of where this
/// widget currently sits), separate from the full results grid on
/// SearchScreen. Tapping a suggestion jumps straight to that product;
/// submitting (or the "see all" row) opens the full results grid.
class _HomeSearchBar extends StatefulWidget {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: AppRadius.lgRadius,
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
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
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
