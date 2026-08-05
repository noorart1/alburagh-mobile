# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```
flutter pub get                      # install dependencies
flutter run                          # run the app (device/emulator must be attached)
flutter test                         # run all tests
flutter test test/auth_test.dart     # run a single test file
flutter test --plain-name "test name"  # run a single test by name
flutter analyze                      # static analysis / lint (flutter_lints)
flutter build apk                    # build Android
flutter build ios                    # build iOS
```

There is no CI config, no mocking framework, and no integration_test/ directory. Tests instantiate real `Provider` classes directly — a test that exercises `ApiService` will hit the live network (`alburagh.com`), so avoid adding tests that make live calls without a fake/mocked `ApiService`.

## Architecture

This is the mobile app for **alburagh.com**, an Arabic-language WooCommerce storefront (دار البراق). The Flutter app is a thin client over a WordPress/WooCommerce backend — there is no local business logic of consequence beyond cart/wishlist/currency state; almost everything (product data, pricing, currency conversion, order status) is computed server-side and just rendered here.

### Backend integration (`lib/core/api_service.dart`)

`ApiService` wraps two `Dio` clients:
- `_dio` → the site's **custom REST plugin** at `wp-json/alburagh/v1/` (products, cart, wishlist, orders, login, addresses, reviews, coupons). This is the primary API surface — assume any new backend feature is added here first.
- `_wpDio` → raw WordPress `wp-json/` for the JWT Authentication plugin (`jwt-auth/v1/token`), used only as a login fallback if the custom `login` endpoint fails.

Two things make this file non-obvious and worth reading before touching auth or cart code:
- **Guest cart continuity**: the custom cart endpoint proxies WooCommerce's native PHP-session cart for guest (unauthenticated) users, which depends on cookies. A private `_CookieStore` (static in-memory jar) is attached to both Dio clients via interceptors to manually capture/resend the `woocommerce_cart_hash` cookie, since Dio has no native cookie jar.
- **Login has two strategies**: the custom `login` endpoint is tried first; on failure it falls back to `loginWithJwt`, including a path that resolves a username from an email address first. Any auth changes need to be tested against both paths.

Auth token, user id/email/name are cached in `SharedPreferences` for session restore on app start. `AuthProvider._loadSavedAuth()` does this restore and exposes an `initialized` Future — screens that gate on login state should await it rather than trusting `isLoggedIn` immediately.

Currency is a request param (`USD`/`IQD`) sent to the backend, not computed client-side; `CurrencyProvider` only persists the user's manual choice.

Push notifications (`lib/core/push_notifications.dart`) use Firebase Cloud Messaging + `flutter_local_notifications`. Firebase is used *only* for messaging — there's no Firebase Auth/Firestore. All devices subscribe to a single `all_users` topic (no per-user targeting). Web push is disabled (`kIsWeb` check in `main.dart`) because there's no `firebase_options.dart` for web.

### State management

**Provider** package only (`ChangeNotifier`, no Riverpod/Bloc/GetX). The five providers in `lib/providers/` are wired in `main.dart` with `ChangeNotifierProxyProvider`/`ProxyProvider2` to express cross-provider dependencies rather than manual `context.read` chains:

```
CurrencyProvider  (root)
  └─ CartProvider       (ProxyProvider<CurrencyProvider, CartProvider>)
  └─ WishlistProvider   (ProxyProvider<CurrencyProvider, WishlistProvider>)
RecentlyViewedProvider  (independent)
AuthProvider            (ProxyProvider2<CartProvider, WishlistProvider, AuthProvider> — merges/clears cart+wishlist on login/logout)
```

Each provider/screen constructs its own `ApiService()` inline — there's no shared singleton/DI container, so don't assume request-level state (like cookies) is per-instance; the cookie jar in `ApiService` is static/shared across all instances by design.

### Navigation

No router package (no go_router/auto_route). `main.dart` boots straight into `MainScreen`, a 5-tab bottom nav (Home/Categories/Cart/Wishlist/Profile) where **each tab owns its own `Navigator`** (via `GlobalKey<NavigatorState>`) inside an `IndexedStack`, so each tab keeps an independent back-stack and its scroll/nav state survives tab switches. There is exactly one named route (`/cart`) registered at the `MaterialApp` level for deep-linking into the cart from outside the tab shell. There's no standalone login screen or auth-gating wrapper — `ProfileScreen` shows its own inline login/register form when logged out, and other flows that need auth (e.g. cart checkout) switch the bottom nav to the Profile tab via `MainScreen.requestedTabIndex` rather than pushing a login screen on top. Guest browsing is allowed throughout.

### Localization

The app is locale-locked to Arabic (`Locale('ar')`) with RTL forced via a `Directionality` wrapper in `MaterialApp.builder`, regardless of device locale. `flutter_localizations` declares support for ar/fa/en but the UI does not currently switch locales at runtime.

### Code organization

Mostly flat by type rather than by feature: `lib/screens/` (14 screens, one file each), `lib/providers/`, `lib/models/` (plain Dart classes with `fromJson`/`toJson`), `lib/widgets/` (shared UI components), `lib/core/` (API, theme tokens, utils). `lib/features/` contains a single file (`category/category.dart`) — an apparent abandoned start of a feature-folder reorg; don't extend that pattern without discussing it, and don't assume other feature folders are coming.
