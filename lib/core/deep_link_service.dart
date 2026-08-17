import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../screens/order_detail_screen.dart';
import '../widgets/app_snackbar.dart';
import 'api_service.dart';

/// Handles the WooCommerce checkout "return to app" hop: the checkout Custom
/// Tab (see cart_screen.dart's `_goToWebsiteCart`) eventually navigates to
/// the order-received page on alburagh.com. Because that URL is a verified
/// Android App Link (see the AndroidManifest.xml intent-filter), Android
/// hands that navigation to this app instead of leaving it in the Custom
/// Tab, which closes automatically as a result.
///
/// Only alburagh.com order-received links are trusted, and even then the
/// order is re-verified server-side (via the existing /orders/{id} endpoint,
/// which 404s for an order that doesn't exist or isn't owned by the current
/// account) before the cart is touched -- a link alone is never treated as
/// proof an order was actually placed.
class DeepLinkService {
  DeepLinkService._();

  static final ApiService _api = ApiService();
  static StreamSubscription<Uri>? _subscription;

  /// [navigatorKey] must be the app's root Navigator (MaterialApp's), not
  /// one of MainScreen's per-tab Navigators, so the order screen can be
  /// pushed regardless of which tab/screen happens to be showing when the
  /// link arrives.
  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    final appLinks = AppLinks();

    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        unawaited(_handleUri(initialUri, navigatorKey));
      }
    } catch (e) {
      debugPrint('DeepLinkService: failed to read initial link: $e');
    }

    _subscription = appLinks.uriLinkStream.listen(
      (uri) => _handleUri(uri, navigatorKey),
      onError: (Object e) => debugPrint('DeepLinkService: stream error: $e'),
    );
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  static bool _isTrustedOrderReceivedLink(Uri uri) {
    return uri.scheme == 'https' &&
        (uri.host == 'alburagh.com' || uri.host == 'www.alburagh.com') &&
        uri.pathSegments.contains('order-received');
  }

  // Order-received URLs look like
  // https://www.alburagh.com/checkout/order-received/123/?key=wc_order_xxx
  // -- the numeric segment right after "order-received" is the order id.
  static int? _orderIdFrom(Uri uri) {
    final segments = uri.pathSegments;
    final index = segments.indexOf('order-received');
    if (index == -1 || index + 1 >= segments.length) return null;
    return int.tryParse(segments[index + 1]);
  }

  static Future<void> _handleUri(
    Uri uri,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (!_isTrustedOrderReceivedLink(uri)) return;

    final orderId = _orderIdFrom(uri);
    final context = navigatorKey.currentContext;
    if (orderId == null || context == null) return;

    final token = context.read<AuthProvider>().user?.token;
    if (token == null || token.isEmpty) return;

    // Confirm the order was actually created (and belongs to this account)
    // before touching the cart -- see the class doc comment. Any failure
    // here (network error, 404) means "not confirmed", so the cart is
    // deliberately left untouched, matching a failed/cancelled checkout.
    try {
      await _api.getOrderDetails(token, orderId);
    } catch (e) {
      debugPrint('DeepLinkService: order $orderId not confirmed: $e');
      return;
    }

    final freshContext = navigatorKey.currentContext;
    if (freshContext == null || !freshContext.mounted) return;

    // WooCommerce already empties the server-side cart once an order is
    // placed -- loadCart() just reflects that, the same non-destructive
    // refresh CartProvider already uses everywhere else (its clearCart()
    // calls a destructive API endpoint that only logout-adjacent flows
    // should ever use -- see CartProvider.resetLocal()'s doc comment).
    unawaited(freshContext.read<CartProvider>().loadCart());

    AppSnackBar.success(freshContext, 'تم إتمام الطلب بنجاح');
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)),
    );
  }
}
