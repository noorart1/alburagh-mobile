import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
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
  final ApiService _api = ApiService();
  List<Product> products = [];
  List<Product> filteredProducts = [];
  bool isLoading = true;
  String sortBy = 'newest';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    try {
      if (!mounted) return;
      setState(() => isLoading = true);
      final prodData = await _api.getProducts(
        category: widget.category.id.toString(),
      );
      if (!mounted) return;
      setState(() {
        products = prodData.map((p) => Product.fromJson(p)).toList();
        _applyFiltersAndSort();
        isLoading = false;
      });
      // Load cart data after loading products
      await context.read<CartProvider>().loadCart();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التحميل: $e')),
        );
      }
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
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${context.watch<CartProvider>().itemCount}'),
              child: const Icon(Icons.shopping_cart),
            ),
            onPressed: () => Navigator.pushNamed(context, '/cart'),
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
                        decoration: InputDecoration(
                          hintText: 'ابحث في المنتجات...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
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
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchQuery.isEmpty
                                    ? 'لم يتم العثور على منتجات'
                                    : 'لم يتم العثور على نتائج للبحث',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: loadProducts,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              return ProductCard(
                                product: filteredProducts[index],
                              );
                            },
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
      backgroundColor: Colors.grey[200],
      selectedColor: primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
