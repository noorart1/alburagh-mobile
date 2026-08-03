import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/theme/app_colors.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_card.dart';

class CategoryScreen extends StatefulWidget {
  final Category category;

  const CategoryScreen({super.key, required this.category});

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

  @override
  void initState() {
    super.initState();
    loadProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!hasMore || isLoadingMore || isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreProducts();
    }
  }

  Future<void> loadProducts() async {
    try {
      if (!mounted) return;
      setState(() => isLoading = true);
      final prodData = await _api.getProducts(
        category: widget.category.slug ?? widget.category.id.toString(),
        page: 1,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        products = prodData.map((p) => Product.fromJson(p)).toList();
        _page = 1;
        hasMore = prodData.length == _perPage;
        _applyFiltersAndSort();
        isLoading = false;
      });
      // Load cart data after loading products
      await context.read<CartProvider>().loadCart();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التحميل: $e')));
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    setState(() => isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final prodData = await _api.getProducts(
        category: widget.category.slug ?? widget.category.id.toString(),
        page: nextPage,
        perPage: _perPage,
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
    filteredProducts = products.where((p) {
      return p.name.contains(searchQuery);
    }).toList();

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
        title: Text(widget.category.name),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${context.watch<CartProvider>().itemCount}'),
              child: const Icon(Icons.shopping_cart),
            ),
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pushNamed('/cart'),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                            _applyFiltersAndSort();
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'ابحث في المنتجات...',
                          prefixIcon: Icon(Icons.search),
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
                  child: filteredProducts.isEmpty
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
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 0.75,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => ProductCard(
                                      product: filteredProducts[index],
                                    ),
                                    childCount: filteredProducts.length,
                                  ),
                                ),
                              ),
                              if (isLoadingMore)
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
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
