import 'api_service.dart';
import '../models/category.dart';
import '../models/product.dart';

/// Everything HomeScreen needs to render its category rows, fetched and
/// bundled together so it can be handed off as a single cached unit (see
/// [HomeDataCache]) instead of each row managing its own fetch/cache.
class HomeScreenData {
  final List<Category> categories;
  final Category? collectionsCategory;
  final List<Product> collectionsProducts;
  final Category? featuredBooksCategory;
  final List<Product> featuredBooksProducts;
  final Category? educationalBooksCategory;
  final List<Product> educationalBooksProducts;
  final Category? intellectualGamesCategory;
  final List<Product> intellectualGamesProducts;
  final Category? religiousCategory;
  final List<Product> religiousProducts;
  final Category? heritageBooksCategory;
  final List<Product> heritageBooksProducts;
  final Category? skillsDevelopmentCategory;
  final List<Product> skillsDevelopmentProducts;

  const HomeScreenData({
    required this.categories,
    required this.collectionsCategory,
    required this.collectionsProducts,
    required this.featuredBooksCategory,
    required this.featuredBooksProducts,
    required this.educationalBooksCategory,
    required this.educationalBooksProducts,
    required this.intellectualGamesCategory,
    required this.intellectualGamesProducts,
    required this.religiousCategory,
    required this.religiousProducts,
    required this.heritageBooksCategory,
    required this.heritageBooksProducts,
    required this.skillsDevelopmentCategory,
    required this.skillsDevelopmentProducts,
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

/// Fetches one category row's products, swallowing errors into an empty
/// list (matching the old per-section try/catch: a single failed row
/// shouldn't block or blank out the rest of the home screen).
Future<List<Product>> _fetchProductsSafe(
  ApiService api,
  Category? category,
  String currency,
) async {
  if (category == null) return [];
  try {
    final data = await api.getProducts(
      category: category.slug ?? category.id.toString(),
      currency: currency,
    );
    return data.map((p) => Product.fromJson(p)).toList();
  } catch (_) {
    return [];
  }
}

/// Fetches everything HomeScreen renders in one call. Category product rows
/// are fetched concurrently (they don't depend on each other, only on the
/// category list resolving first) rather than one after another.
Future<HomeScreenData> fetchHomeScreenData(ApiService api, String currency) async {
  final catData = await api.getCategories();
  final categories = catData.map((c) => Category.fromJson(c)).toList();

  final collectionsCategory = _findCategoryBy(categories, ['collections']);
  final featuredBooksCategory = _findCategoryBy(categories, [
    'الكتب المصورة',
    'picture-books',
  ]);
  final educationalBooksCategory = _findCategoryBy(categories, [
    'الكتب التعليمية',
    'educational',
  ]);
  final intellectualGamesCategory = _findCategoryBy(categories, [
    'الألعاب التعليمية',
    'intellectual-game',
  ]);
  final religiousCategory = _findCategoryBy(categories, [
    'دينية',
    'كتب دينية',
    'الكتب الدينية',
    'religious',
    'religious-books',
  ]);
  final heritageBooksCategory = _findCategoryBy(categories, [
    'تراثية',
    'كتب تراثية',
    'الكتب التراثية',
    'التراث',
    'heritage',
    'heritage-books',
  ]);
  final skillsDevelopmentCategory = _findCategoryBy(categories, [
    'مهارات',
    'تنمية المهارات',
    'تنمية مهارات',
    'skills',
    'skills-development',
  ]);

  final results = await Future.wait([
    _fetchProductsSafe(api, educationalBooksCategory, currency),
    _fetchProductsSafe(api, intellectualGamesCategory, currency),
    _fetchProductsSafe(api, collectionsCategory, currency),
    _fetchProductsSafe(api, featuredBooksCategory, currency),
    _fetchProductsSafe(api, religiousCategory, currency),
    _fetchProductsSafe(api, heritageBooksCategory, currency),
    _fetchProductsSafe(api, skillsDevelopmentCategory, currency),
  ]);

  return HomeScreenData(
    categories: categories,
    collectionsCategory: collectionsCategory,
    collectionsProducts: results[2],
    featuredBooksCategory: featuredBooksCategory,
    featuredBooksProducts: results[3],
    educationalBooksCategory: educationalBooksCategory,
    educationalBooksProducts: results[0],
    intellectualGamesCategory: intellectualGamesCategory,
    intellectualGamesProducts: results[1],
    religiousCategory: religiousCategory,
    religiousProducts: results[4],
    heritageBooksCategory: heritageBooksCategory,
    heritageBooksProducts: results[5],
    skillsDevelopmentCategory: skillsDevelopmentCategory,
    skillsDevelopmentProducts: results[6],
  );
}

/// Caches the last [fetchHomeScreenData] result so SplashScreen can kick the
/// fetch off early (while its fixed display timer runs, see splash_screen.dart
/// for why that timer itself must stay unconditional) and HomeScreen can
/// pick up the already-loaded (or already in-flight) result instead of
/// starting a second fetch and showing its own loading spinner.
class HomeDataCache {
  HomeDataCache._();

  static HomeScreenData? _data;
  static String? _cachedCurrency;
  static Future<HomeScreenData>? _inFlight;

  /// Returns cached data immediately if it's already loaded for [currency],
  /// without starting or waiting on a fetch.
  static HomeScreenData? peek(String currency) {
    return (_data != null && _cachedCurrency == currency) ? _data : null;
  }

  static Future<HomeScreenData> preload(
    ApiService api,
    String currency, {
    bool force = false,
  }) {
    if (!force && _data != null && _cachedCurrency == currency) {
      return Future.value(_data!);
    }
    if (!force && _inFlight != null) {
      return _inFlight!;
    }

    final future = fetchHomeScreenData(api, currency);
    _inFlight = future;
    future.then(
      (result) {
        _data = result;
        _cachedCurrency = currency;
        _inFlight = null;
      },
      onError: (_) {
        _inFlight = null;
      },
    );
    return future;
  }
}
