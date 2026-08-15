import 'package:flutter/widgets.dart';

/// Shared responsive column-count logic for every grid that displays
/// [ProductCard] (CategoryScreen, WishlistScreen, ProductListScreen,
/// SearchScreen, and their loading skeletons) so the same available width
/// always produces the same column count everywhere instead of each screen
/// rolling its own math.
///
/// The app is portrait-only, so this only needs to scale with width, not
/// device class/resolution/DPI.
class ResponsiveProductGrid {
  ResponsiveProductGrid._();

  /// ProductCard's reference shape (170x290), also used verbatim by the
  /// home screen's fixed-width horizontal rows -- keeping grids at the same
  /// aspect ratio means a card looks identical whether it's in a fixed-width
  /// row or a grid column that flexes with screen width.
  static const double childAspectRatio = 170 / 290;

  /// The narrowest a card is allowed to get before the grid drops to fewer
  /// columns. 170 (ProductCard's reference width) was too high a bar: on a
  /// common 360dp-wide phone, (360 - 32 padding) / 171 floors to 1 column
  /// even though two comfortably-sized cards fit. 150 keeps normal phones
  /// (~360-414dp) at 2 columns while still dropping to 1 on genuinely narrow
  /// screens (~320dp and below).
  static const double _minCardWidth = 150;

  /// [availableWidth] must be the actual layout width the grid has to work
  /// with -- e.g. from `LayoutBuilder`'s constraints or
  /// `SliverLayoutBuilder`'s `crossAxisExtent` -- not `MediaQuery`'s screen
  /// size, so this stays correct inside nested layouts and never
  /// double-counts safe-area insets.
  ///
  /// [horizontalPadding] is *per side* padding that [availableWidth] does
  /// not already exclude. Pass 0 when the caller's [availableWidth] was
  /// already measured past that padding (e.g. a `SliverLayoutBuilder`
  /// nested directly inside a `SliverPadding`).
  static int columnCountForWidth(
    double availableWidth, {
    double horizontalPadding = 16,
    double crossAxisSpacing = 1,
  }) {
    final usableWidth = availableWidth - (horizontalPadding * 2);
    if (usableWidth < _minCardWidth) return 1;
    final count =
        ((usableWidth + crossAxisSpacing) / (_minCardWidth + crossAxisSpacing))
            .floor();
    return count < 1 ? 1 : count;
  }

  /// Convenience wrapper around [columnCountForWidth] that builds the
  /// matching grid delegate directly, so callers don't duplicate the
  /// aspect ratio/spacing wiring.
  static SliverGridDelegateWithFixedCrossAxisCount delegateForWidth(
    double availableWidth, {
    double horizontalPadding = 16,
    double crossAxisSpacing = 1,
    double mainAxisSpacing = 1,
  }) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columnCountForWidth(
        availableWidth,
        horizontalPadding: horizontalPadding,
        crossAxisSpacing: crossAxisSpacing,
      ),
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
    );
  }
}
