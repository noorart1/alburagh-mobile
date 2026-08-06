import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import 'home_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  // Was 4 -- shifted down by one now that the "الأقسام" tab is hidden below.
  static const int profileTabIndex = 3;

  /// Lets a screen nested in one tab (e.g. the cart, prompting a guest to
  /// log in before checkout) switch the bottom nav to another tab instead of
  /// pushing a screen on top of it. Set to a tab index to request a switch;
  /// consumed and reset back to null by [_MainScreenState].
  static final ValueNotifier<int?> requestedTabIndex = ValueNotifier<int?>(
    null,
  );

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    MainScreen.requestedTabIndex.addListener(_handleRequestedTab);
  }

  @override
  void dispose() {
    MainScreen.requestedTabIndex.removeListener(_handleRequestedTab);
    super.dispose();
  }

  void _handleRequestedTab() {
    final target = MainScreen.requestedTabIndex.value;
    if (target == null) return;
    MainScreen.requestedTabIndex.value = null;
    setState(() => _currentIndex = target);
    _navigatorKeys[target].currentState?.popUntil((route) => route.isFirst);
  }

  // Was 5 -- the "الأقسام" tab is temporarily hidden below (root widget,
  // nav bar item, and one navigator key removed together). To restore it:
  // add AllCategoriesScreen() back to _tabRoots and its
  // BottomNavigationBarItem back to _buildItems (both in the same
  // position they were removed from), bump this back to 5, and move
  // profileTabIndex back to 4.
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );

  final List<Widget> _tabRoots = const [
    HomeScreen(),
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
        if (shouldPop) {
          SystemNavigator.pop();
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
          backgroundColor: Colors.grey.shade300,
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: _buildItems(cartCount, wishlistCount),
        ),
      ),
    );
  }
}
