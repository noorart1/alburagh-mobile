import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/error_messages.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../models/category.dart';
import '../widgets/app_snackbar.dart';
import 'category_screen.dart';

class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  final ApiService _api = ApiService();
  List<Category> categories = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      if (!mounted) return;
      setState(() => isLoading = true);
      final catData = await _api.getCategories();
      if (!mounted) return;
      setState(() {
        categories = catData.map((c) => Category.fromJson(c)).toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      if (mounted) {
        AppSnackBar.error(
          context,
          friendlyErrorMessage(e, fallback: 'تعذر تحميل الأقسام، حاول مرة أخرى'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = categories
        .where((cat) => cat.name.contains(searchQuery))
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('الأقسام'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    onChanged: (value) {
                      setState(() => searchQuery = value);
                    },
                    decoration: const InputDecoration(
                      hintText: 'ابحث في الأقسام...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: filteredCategories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.category_outlined,
                                size: 48,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchQuery.isEmpty
                                    ? 'لم يتم العثور على أقسام'
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
                          onRefresh: loadCategories,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.78,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: filteredCategories.length,
                            itemBuilder: (context, index) {
                              final cat = filteredCategories[index];
                              return _buildCategoryCard(context, cat, index);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    Category category,
    int index,
  ) {
    final accent =
        AppColors.categoryAccents[index % AppColors.categoryAccents.length];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryScreen(category: category),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        child: category.imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: category.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                // Image.network has no disk cache at all -- every time this
                // grid was rebuilt (including a pull-to-refresh), every
                // category icon was re-downloaded from scratch.
                memCacheWidth: (MediaQuery.of(context).devicePixelRatio * 180)
                    .round(),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surfaceSoft,
                  child: Icon(Icons.category, color: accent, size: 40),
                ),
              )
            : Container(
                color: accent.withValues(alpha: 0.08),
                child: Icon(Icons.category, color: accent, size: 40),
              ),
      ),
    );
  }
}
