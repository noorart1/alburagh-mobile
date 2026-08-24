import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/currency_utils.dart';
import '../core/motion.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/cart_item_card.dart';
import 'main_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ApiService _api = ApiService();

  static final Uri _originalCartUri = Uri.parse(
    'https://alburagh.com/shopping-cart/',
  );

  bool _checkoutLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CartProvider>().loadCart();
      }
    });
  }

  Future<void> _showClearConfirmation(CartProvider cart) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفريغ السلة'),
        content: const Text('هل تريد إزالة جميع المنتجات من السلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تفريغ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await cart.clearCart();
      if (!mounted || cart.error != null) return;
      AppSnackBar.success(context, 'تم تفريغ السلة');
    }
  }

  /// Sends the customer to the real website cart/checkout page — already
  /// logged in there if they're logged in in the app — so checkout (address,
  /// shipping, COD/PayPal/card, all of it) happens through WooCommerce's own
  /// working checkout instead of being reimplemented in the app. Guests are
  /// sent to the Profile tab first instead: the website checkout works fine
  /// for guests too, but this store wants every order tied to an account.
  /// Switching tabs (rather than pushing a login screen on top of the cart)
  /// keeps the cart visible underneath and reuses the login form Profile
  /// already shows to logged-out users.
  ///
  /// Opened in an Android Custom Tab (not the external Chrome app) so the
  /// customer never fully leaves the app; cookies/session persist across the
  /// checkout → gateway → order-received redirect chain the same as they
  /// would in a real browser tab. If checkout succeeds, the order-received
  /// page is a verified Android App Link (see AndroidManifest.xml) that
  /// hands navigation back to this app -- see DeepLinkService -- which
  /// closes the tab automatically.
  Future<void> _goToWebsiteCart() async {
    final auth = context.read<AuthProvider>();

    if (!auth.isLoggedIn) {
      AppSnackBar.info(context, 'يجب تسجيل الدخول لإتمام الشراء');
      MainScreen.requestedTabIndex.value = MainScreen.profileTabIndex;
      return;
    }

    setState(() => _checkoutLoading = true);
    try {
      final token = auth.user?.token;

      Uri targetUri = _originalCartUri;
      if (token != null && token.isNotEmpty) {
        try {
          final url = await _api.createAutoLoginLink(
            token: token,
            redirectTo: _originalCartUri.toString(),
            currency: context.read<CurrencyProvider>().currency,
          );
          if (url != null && url.isNotEmpty) {
            targetUri = Uri.parse(url);
          }
        } catch (_) {
          // Fall back to the plain cart URL below; the user can still log
          // in manually on the website if needed.
        }
      }

      if (!mounted) return;
      final toolbarColor = Theme.of(context).colorScheme.surface;
      try {
        await launchUrl(
          targetUri,
          customTabsOptions: CustomTabsOptions(
            colorSchemes: CustomTabsColorSchemes.defaults(
              toolbarColor: toolbarColor,
            ),
            urlBarHidingEnabled: true,
            showTitle: true,
          ),
        );
      } catch (_) {
        if (mounted) AppSnackBar.error(context, 'تعذر فتح صفحة السلة');
      }
    } finally {
      if (mounted) setState(() => _checkoutLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('سلة المشتريات (${cart.itemCount})'),
        actions: [
          IconButton(
            tooltip: 'فتح السلة الأصلية',
            icon: const Icon(Icons.open_in_new),
            onPressed: _checkoutLoading ? null : _goToWebsiteCart,
          ),
          if (cart.items.isNotEmpty)
            IconButton(
              tooltip: 'تفريغ السلة',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: cart.isLoading
                  ? null
                  : () => _showClearConfirmation(cart),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: resolveMotion(context, Motion.loadingCrossfade),
        child: _buildBody(cart),
      ),
      bottomNavigationBar: cart.items.isEmpty || cart.isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'المجموع الفرعي',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          // Item prices only — no shipping/tax. The real,
                          // final total (with the shipping method the
                          // customer actually picks) is shown on the website
                          // checkout this button redirects to; showing
                          // WooCommerce's auto-estimated shipping/tax here
                          // too just confuses customers with a number that
                          // may not even match what they see next.
                          CurrencyUtils.format(
                            cart.subtotal,
                            cart.currencySymbol,
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _checkoutLoading ? null : _goToWebsiteCart,
                        icon: const Icon(Icons.payment),
                        label: Text(
                          _checkoutLoading ? 'جاري الفتح...' : 'إتمام الشراء',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody(CartProvider cart) {
    if (cart.isLoading && cart.items.isEmpty) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (cart.error != null && cart.items.isEmpty) {
      return Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(cart.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: cart.isLoading ? null : cart.loadCart,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (cart.items.isEmpty) {
      return RefreshIndicator(
        key: const ValueKey('empty'),
        onRefresh: cart.loadCart,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(
              Icons.shopping_cart_outlined,
              size: 72,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 16),
            Center(child: Text('سلة المشتريات فارغة')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: cart.loadCart,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: cart.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => CartItemCard(
          item: cart.items[index],
          enabled: !cart.isLoading,
          onIncrease: () => cart.updateQuantity(
            cart.items[index].product,
            cart.items[index].quantity + 1,
          ),
          onDecrease: () => cart.updateQuantity(
            cart.items[index].product,
            cart.items[index].quantity - 1,
          ),
          onRemove: () => cart.removeFromCart(cart.items[index].product),
        ),
      ),
    );
  }
}
