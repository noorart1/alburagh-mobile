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
- **Cart merge on login is order-sensitive**: because the session cookie is shared/static, WooCommerce's own `WC_Session_Handler` auto-migrates (overwrites, not merges) a guest cart onto whichever account logs in next if the stale cookie is still attached. `AuthProvider.login()` calls `ApiService.resetSession()` (clears `_CookieStore`) *before* re-adding the snapshotted guest items via `CartProvider.mergeCart()`, so the authenticated request loads the account's own saved cart untouched and the guest items are added on top explicitly. `AuthProvider.logout()` similarly only clears the *local* cart display (`CartProvider.resetLocal()`) and resets the session — it must never call the server `clearCart` API, which would permanently empty the account's real cart.

Auth token, user id/email/name are cached in `SharedPreferences` for session restore on app start. `AuthProvider._loadSavedAuth()` does this restore and exposes an `initialized` Future — screens that gate on login state should await it rather than trusting `isLoggedIn` immediately.

`ApiService.getCategories()` doesn't just proxy the `/categories` endpoint: it hides non-merchandising WooCommerce categories (uncategorized, english-books, pdf, all-books, the subscription-cards and offers categories — see `_hiddenCategorySlugs`/`_hiddenCategoryNames`), sorts the rest into a fixed display order (`_categoryOrder`), and overrides each category's `image` with a curated URL (`_categoryImages`) since the site's own category thumbnails are unset (`null`) for all of them. This is the single source of truth for category display everywhere (home screen row, full categories screen) — don't re-filter/re-sort categories downstream.

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

No router package (no go_router/auto_route). `main.dart` boots into `SplashScreen` first, then a fixed-duration `Future.delayed` (1.2s, not gated on network/async init — see the "Fix app hanging on splash screen" history for why that matters) `pushReplacement`s into `MainScreen`, a 5-tab bottom nav (Home/Categories/Cart/Wishlist/Profile) where **each tab owns its own `Navigator`** (via `GlobalKey<NavigatorState>`) inside an `IndexedStack`, so each tab keeps an independent back-stack and its scroll/nav state survives tab switches. There is exactly one named route (`/cart`) registered at the `MaterialApp` level for deep-linking into the cart from outside the tab shell. There's no standalone login screen or auth-gating wrapper — `ProfileScreen` shows its own inline login/register form when logged out, and other flows that need auth (e.g. cart checkout) switch the bottom nav to the Profile tab via `MainScreen.requestedTabIndex` rather than pushing a login screen on top. Guest browsing is allowed throughout.

`SplashScreen` (`lib/screens/splash_screen.dart`) exists because Android 12+'s native `SplashScreen` API has no full-image mode — its only image slot (`windowSplashScreenAnimatedIcon`) always renders small and masked inside an icon-shaped safe zone, an OS constraint `flutter_native_splash`'s config can't override. `pubspec.yaml`'s `flutter_native_splash.android_12` block is deliberately left as a plain white background with no icon; this Flutter-rendered screen (full `icon.png`, matching the launcher icon) is what's actually meant to read as the app's splash, with the native one just a brief flash before it. Re-run `dart run flutter_native_splash:create` after changing anything under `flutter_native_splash:` in `pubspec.yaml` — editing the YAML alone doesn't regenerate the platform splash resources.

### Localization

The app is locale-locked to Arabic (`Locale('ar')`) with RTL forced via a `Directionality` wrapper in `MaterialApp.builder`, regardless of device locale. `flutter_localizations` declares support for ar/fa/en but the UI does not currently switch locales at runtime.

### Product data quirks

`Product.additionalInformation` (a `List<ProductAttribute>`) backs the product detail screen's "معلومات إضافية" tab. It comes from the PHP plugin's `alburagh_get_product_additional_information()`, which mirrors WooCommerce's own Additional Information tab: weight/dimensions rows (from the product's core Shipping fields, not `get_attributes()`) followed by every attribute marked "visible on the product page". Those WooCommerce formatting helpers (`wc_format_weight`/`wc_format_dimensions`) are written to be echoed into HTML, so their values need `html_entity_decode()` server-side before this plain-JSON API returns them — without it, the separator shows up as the literal text `&times;` instead of `×`.

`Product.descriptionTitle`/`descriptionBody` (via `StringUtils.splitLeadTitle`) split `short_description`'s HTML into a bold lead line + body paragraph(s), matching how the website renders it — that only works when the source HTML's first paragraph is wholly wrapped in `<strong>`/`<b>`; otherwise `descriptionTitle` comes back empty and callers should fall back to the plain-text `description`. `Product.toJson()` persists the already-split title/body (not the original HTML) for round-tripping through local storage (recently-viewed) — `fromJson()` prefers those explicit fields over re-deriving from `short_description` when both are present.

`ProductCard`'s `_ProductImage` resolves each image once to read its real decoded pixel size before choosing a `BoxFit`: the site serves photos in two fixed shapes (600x800 portrait, 600x600 square), and a single `BoxFit` for both distorts one of them depending on the card's own aspect ratio (which differs between the home row and the category grid — they're intentionally kept the same 170x290 size for this reason). Square sources get `BoxFit.contain` pinned `Alignment.topCenter`; portrait sources get `BoxFit.cover`.

### Code organization

Mostly flat by type rather than by feature: `lib/screens/` (14 screens, one file each), `lib/providers/`, `lib/models/` (plain Dart classes with `fromJson`/`toJson`), `lib/widgets/` (shared UI components), `lib/core/` (API, theme tokens, utils). `lib/features/` contains a single file (`category/category.dart`) — an apparent abandoned start of a feature-folder reorg; don't extend that pattern without discussing it, and don't assume other feature folders are coming.
