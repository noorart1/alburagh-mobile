import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import 'home_screen.dart';
import 'all_categories_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    5,
    (_) => GlobalKey<NavigatorState>(),
  );

  final List<Widget> _tabRoots = const [
    HomeScreen(),
    AllCategoriesScreen(),
    CartScreen(),
    WishlistScreen(),
    ProfileScreen(),
  ];

  List<BottomNavigationBarItem> _buildItems(int cartCount, int wishlistCount) {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'الرئيسية',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.category),
        label: 'الأقسام',
      ),
      BottomNavigationBarItem(
        icon: _badgedIcon(Icons.shopping_cart, cartCount),
        label: 'السلة',
      ),
      BottomNavigationBarItem(
        icon: _badgedIcon(Icons.favorite, wishlistCount),
        label: 'المفضلة',
      ),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
    ];
  }

  Widget _badgedIcon(IconData icon, int count) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(icon),
    );
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      // Tapping the already-active tab again resets it back to its root,
      // matching the common "tap current tab to go home" convention.
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _currentIndex = index);
    }
  }

  Future<bool> _onWillPop() async {
    final navigator = _navigatorKeys[_currentIndex].currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return false;
    }
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<CartProvider, int>((c) => c.itemCount);
    final wishlistCount = context.select<WishlistProvider, int>(
      (w) => w.itemCount,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(_tabRoots.length, (index) {
            return Navigator(
              key: _navigatorKeys[index],
              onGenerateRoute: (settings) =>
                  MaterialPageRoute(builder: (context) => _tabRoots[index]),
            );
          }),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: _buildItems(cartCount, wishlistCount),
        ),
      ),
    );
  }
}
