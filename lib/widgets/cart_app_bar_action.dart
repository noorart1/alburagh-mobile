import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/motion.dart';
import '../providers/cart_provider.dart';

/// AppBar cart icon + item-count badge, isolated into its own widget so
/// only this badge rebuilds when [CartProvider] changes. Screens that
/// inlined `context.watch<CartProvider>()` directly in their own build()
/// (to read itemCount for this badge) were rebuilding their entire body --
/// search bar, filter chips, the whole product grid's widget tree -- on
/// every cart mutation, including ones that don't touch itemCount at all
/// (e.g. the isLoading flip while an add-to-cart request is in flight).
/// `select` further narrows that to only rebuild when itemCount's value
/// itself actually changes.
class CartAppBarAction extends StatelessWidget {
  const CartAppBarAction({super.key});

  @override
  Widget build(BuildContext context) {
    final itemCount = context.select<CartProvider, int>(
      (cart) => cart.itemCount,
    );
    return IconButton(
      icon: Badge(
        label: AnimatedSwitcher(
          duration: resolveMotion(context, Motion.badgeBump),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Text('$itemCount', key: ValueKey(itemCount)),
        ),
        child: const Icon(Icons.shopping_cart),
      ),
      onPressed: () =>
          Navigator.of(context, rootNavigator: true).pushNamed('/cart'),
    );
  }
}
