import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/error_messages.dart';
import '../core/home_cache.dart';
import '../core/theme/app_colors.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/cart_app_bar_action.dart';
import '../widgets/product_card.dart';
import '../widgets/skeleton_box.dart';

class CategoryScreen extends StatefulWidget {
  // Null means "no category filter" -- browse the full catalog, matching
  // exactly what the website's shop page shows. Kept separate from a magic
  // "all books" category value, since that requires every product to be
  // manually tagged into that category on the WooCommerce side and silently
  // drifts out of sync (undercounting) whenever that tagging is missed.
  final Category? category;
  final String? title;

  const CategoryScreen({super.key, this.category, this.title})
    : assert(
        category != null || title != null,
        'CategoryScreen needs a category or an explicit title',
      );

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  static const int _perPage = 30;

  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  List<Product> products = [];
  List<Product> filteredProducts = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  int _page = 1;
  String sortBy = 'newest';
  String searchQuery = '';

  // The in-page search box used to just String.contains()-filter whatever
  // page of `products` happened to be loaded so far -- diacritic-sensitive
  // and blind to anything not yet scrolled into view. It now calls the same
  // diacritic-normalizing /search endpoint the home screen uses, scoped to
  // this category (or the whole catalog when there isn't one).
  List<Product> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  int _searchGeneration = 0;

  late final CurrencyProvider _currencyProvider;

  // Scoped per category (or "all" for the whole-catalog browse) so
  // switching categories never shows another category's cached products.
  String get _cacheKey =>
      'category_products_${widget.category?.slug ?? widget.category?.id.toString() ?? 'all'}';

  @override
  void initState() {
    super.initState();
    _currencyProvider = context.read<CurrencyProvider>();
    _currencyProvider.addListener(_onCurrencyChanged);
    // Cache-first, same as HomeScreen: get the last-known page on screen
    // immediately, independent of (not gating, not gated by) the real
    // network fetch started right after.
    unawaited(_loadFromCache());
    loadProducts();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadFromCache() async {
    final cached = await HomeCache.readList(_cacheKey);
    // If the network fetch already won the race and populated products,
    // don't stomp on it with a possibly-stale cached page.
    if (!mounted || cached == null || products.isNotEmpty) return;
    setState(() {
      products = cached.map((p) => Product.fromJson(p)).toList();
      hasMore = cached.length == _perPage;
      _applyFiltersAndSort();
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _currencyProvider.removeListener(_onCurrencyChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onCurrencyChanged() => loadProducts();

  void _onScroll() {
    // Search results aren't paginated (capped server-side); only the
    // normal unfiltered browse list loads more as you scroll.
    if (searchQuery.isNotEmpty) return;
    if (!hasMore || isLoadingMore || isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreProducts();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    setState(() => searchQuery = query);

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      _applyFiltersAndSort();
      return;
    }

    setState(() => _isSearching = true);
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
        currency: _currencyProvider.currency,
        category: widget.category?.slug ?? widget.category?.id.toString(),
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchResults = data.map((p) => Product.fromJson(p)).toList();
        _isSearching = false;
        _applyFiltersAndSort();
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _isSearching = false);
    }
  }

  Future<void> loadProducts() async {
    try {
      if (!mounted) return;
      // Only block the screen with a spinner on the very first load. A
      // currency switch or pull-to-refresh calls this again with products
      // already on screen -- blanking to a spinner every time was
      // discarding a perfectly good list the user was already looking at
      // just to show the exact same data a moment later.
      if (products.isEmpty) {
        setState(() => isLoading = true);
      }
      final prodData = await _api.getProducts(
        category: widget.category?.slug ?? widget.category?.id.toString(),
        page: 1,
        perPage: _perPage,
        currency: _currencyProvider.currency,
      );
      if (!mounted) return;
      setState(() {
        products = prodData.map((p) => Product.fromJson(p)).toList();
        _page = 1;
        hasMore = prodData.length == _perPage;
        _applyFiltersAndSort();
        isLoading = false;
      });
      unawaited(HomeCache.writeList(_cacheKey, prodData));
      // Load cart data after loading products
      await context.read<CartProvider>().loadCart();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      if (mounted) {
        AppSnackBar.error(
          context,
          friendlyErrorMessage(
            e,
            fallback: 'تعذر تحميل المنتجات، حاول مرة أخرى',
          ),
        );
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    setState(() => isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final prodData = await _api.getProducts(
        category: widget.category?.slug ?? widget.category?.id.toString(),
        page: nextPage,
        perPage: _perPage,
        currency: _currencyProvider.currency,
      );
      if (!mounted) return;
      setState(() {
        products.addAll(prodData.map((p) => Product.fromJson(p)));
        _page = nextPage;
        hasMore = prodData.length == _perPage;
        _applyFiltersAndSort();
        isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingMore = false);
    }
  }

  void _applyFiltersAndSort() {
    filteredProducts = searchQuery.trim().isEmpty
        ? List.of(products)
        : List.of(_searchResults);

    switch (sortBy) {
      case 'price_low':
        filteredProducts.sort(
          (a, b) => double.parse(a.price).compareTo(double.parse(b.price)),
        );
        break;
      case 'price_high':
        filteredProducts.sort(
          (a, b) => double.parse(b.price).compareTo(double.parse(a.price)),
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.title ?? widget.category!.name),
        actions: const [CartAppBarAction()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'ابحث في المنتجات...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('الأحدث', 'newest'),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'السعر: من الأقل إلى الأعلى',
                        'price_low',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'السعر: من الأعلى إلى الأقل',
                        'price_high',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const _CategoryGridSkeleton()
                : filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isEmpty
                              ? 'لم يتم العثور على منتجات'
                              : 'لم يتم العثور على نتائج للبحث',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: loadProducts,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverGrid(
                            // SliverGridDelegateWithMaxCrossAxisExtent
                            // rounds its column count *up* to stay
                            // under the extent cap, which -- once
                            // padding/spacing are subtracted from the
                            // screen width -- often pushes a 2-column
                            // fit to 3 columns and shrinks cards well
                            // below 170. Computing the column count
                            // ourselves with floor() instead guarantees
                            // each column is at least 170, matching the
                            // home screen's row cards, at the cost of
                            // some leftover trailing width on screens
                            // that aren't an exact multiple of 170.
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: math.max(
                                    1,
                                    ((MediaQuery.sizeOf(context).width - 32) /
                                            171)
                                        .floor(),
                                  ),
                                  childAspectRatio: 170 / 290,
                                  crossAxisSpacing: 1,
                                  mainAxisSpacing: 1,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final product = filteredProducts[index];
                              // Keyed by product id (not position) so
                              // sorting/search swaps the underlying
                              // list without tearing down and
                              // rebuilding every card's element --
                              // Flutter just moves the existing
                              // element (and its already-resolved
                              // image state) to its new index
                              // instead of re-resolving images that
                              // didn't actually change.
                              return ProductCard(
                                key: ValueKey(product.id),
                                product: product,
                              );
                            }, childCount: filteredProducts.length),
                          ),
                        ),
                        if (isLoadingMore)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = sortBy == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          sortBy = value;
          _applyFiltersAndSort();
        });
      },
      backgroundColor: AppColors.surfaceSoft,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

/// Matches the real grid's column math/spacing (see the comment on the real
/// SliverGrid above) so there's no layout jump when real content replaces
/// this.
class _CategoryGridSkeleton extends StatelessWidget {
  const _CategoryGridSkeleton();

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = math.max(
      1,
      ((MediaQuery.sizeOf(context).width - 32) / 171).floor(),
    );
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 170 / 290,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: crossAxisCount * 3,
      itemBuilder: (context, index) =>
          const SkeletonBox(width: 170, height: 290),
    );
  }
}
