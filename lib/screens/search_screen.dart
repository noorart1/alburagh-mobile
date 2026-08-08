import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/theme/app_colors.dart';
import '../models/product.dart';
import '../providers/currency_provider.dart';
import '../widgets/product_card.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _api = ApiService();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  List<Product> _products = [];
  bool _isLoading = false;

  Timer? _debounce;
  // Bumped on every keystroke so a slow, older request can't overwrite the
  // results of a newer one that happened to come back faster.
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _isLoading = true;
      // Not debounced: this query was already committed by the user (e.g.
      // submitted from the home screen's search field), so search
      // immediately instead of waiting out the usual as-you-type delay.
      _search(initial);
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _products = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
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
        _products = data.map((p) => Product.fromJson(p)).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('البحث')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'ابحث عن منتج...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (_products.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'اكتب كلمة بحث لعرض النتائج',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 1,
                  mainAxisSpacing: 1,
                ),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return ProductCard(key: ValueKey(product.id), product: product);
                },
              ),
            ),
        ],
      ),
    );
  }
}
