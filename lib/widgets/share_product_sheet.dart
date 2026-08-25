import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../models/product.dart';
import 'app_snackbar.dart';

/// The backend doesn't expose a slug/permalink for products (see
/// [Product]), so this reconstructs a valid, clickable product URL from
/// just the id via WordPress's query-var permalink form, which WooCommerce
/// always rewrites to the real pretty permalink regardless of the site's
/// permalink settings.
String _productShareUrl(Product product) =>
    'https://alburagh.com/?post_type=product&p=${product.id}';

/// Opens each launch through [context], captured here rather than the
/// bottom sheet's own (builder-scoped) context -- the sheet is popped
/// before the async launch/error-snackbar flow runs, which would leave a
/// `context.mounted` check on the sheet's own context always false.
Future<void> _launchShareUrl(BuildContext context, Uri uri) async {
  if (!await canLaunchUrl(uri)) {
    if (context.mounted) {
      AppSnackBar.error(context, 'تعذر فتح التطبيق المطلوب');
    }
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> showShareProductSheet(BuildContext context, Product product) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
    ),
    builder: (sheetContext) => _ShareProductSheet(
      product: product,
      onLaunch: (uri) => _launchShareUrl(context, uri),
    ),
  );
}

class _ShareProductSheet extends StatelessWidget {
  final Product product;
  final Future<void> Function(Uri uri) onLaunch;

  const _ShareProductSheet({required this.product, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    final url = _productShareUrl(product);
    final shareText = 'شاهد هذا المنتج: ${product.name}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'مشاركة المنتج',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareOption(
                  label: 'واتساب',
                  icon: Icons.chat_bubble_rounded,
                  color: const Color(0xFF25D366),
                  uri: Uri.parse(
                    'https://wa.me/?text=${Uri.encodeComponent('$shareText\n$url')}',
                  ),
                  onLaunch: onLaunch,
                ),
                _ShareOption(
                  label: 'تيليجرام',
                  icon: Icons.telegram,
                  color: const Color(0xFF0088CC),
                  uri: Uri.parse(
                    'https://t.me/share/url?url=${Uri.encodeComponent(url)}'
                    '&text=${Uri.encodeComponent(shareText)}',
                  ),
                  onLaunch: onLaunch,
                ),
                _ShareOption(
                  label: 'فيسبوك',
                  icon: Icons.facebook,
                  color: const Color(0xFF1877F2),
                  uri: Uri.parse(
                    'https://www.facebook.com/sharer/sharer.php'
                    '?u=${Uri.encodeComponent(url)}',
                  ),
                  onLaunch: onLaunch,
                ),
                _ShareOption(
                  label: 'البريد الإلكتروني',
                  icon: Icons.email_rounded,
                  color: AppColors.primary,
                  uri: Uri.parse(
                    'mailto:?subject=${Uri.encodeComponent(product.name)}'
                    '&body=${Uri.encodeComponent('$shareText\n$url')}',
                  ),
                  onLaunch: onLaunch,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Uri uri;
  final Future<void> Function(Uri uri) onLaunch;

  const _ShareOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.uri,
    required this.onLaunch,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onLaunch(uri);
      },
      borderRadius: BorderRadius.circular(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color,
            child: Icon(icon, color: AppColors.white, size: 26),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
