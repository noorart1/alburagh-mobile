import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_card.dart';

/// Shows a fixed, already-loaded list of products in a grid -- the "see
/// more" destination for home screen sections like Best Sellers, Featured
/// and New Arrivals, none of which are real WooCommerce categories, so
/// they can't be opened through CategoryScreen (which fetches by category
/// slug/id). These lists are small and already fully loaded by the home
/// screen, so no pagination or its own API call is needed here.
class ProductListScreen extends StatelessWidget {
  final String title;
  final List<Product> products;

  const ProductListScreen({
    super.key,
    required this.title,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) =>
            ProductCard(product: products[index]),
      ),
    );
  }
}
