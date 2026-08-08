import 'package:flutter/material.dart';
import '../models/product.dart';
import '../widgets/cart_app_bar_action.dart';
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
        actions: const [CartAppBarAction()],
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
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(key: ValueKey(product.id), product: product);
        },
      ),
    );
  }
}
