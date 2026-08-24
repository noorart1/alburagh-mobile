import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/currency_utils.dart';
import '../core/order_status.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

const List<String> _arabicMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().user?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'يجب تسجيل الدخول أولاً';
      });
      return;
    }

    try {
      final data = await _api.getOrderDetails(token, widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'تعذر تحميل تفاصيل الطلب';
      });
    }
  }

  /// Matches the website's own "24 أغسطس, 2026" formatting exactly (the
  /// app has no `intl` dependency, so this is a small hand-rolled lookup
  /// rather than pulling one in for a single date format).
  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw.split(' ').first;
    return '${date.day} ${_arabicMonths[date.month - 1]}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الطلب #${widget.orderId}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            )
          : _buildBody(_order!),
    );
  }

  Widget _buildBody(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? '';
    final currencyCode = order['currency']?.toString() ?? 'USD';
    final symbol = CurrencyUtils.symbolForCode(currencyCode);
    final items = (order['items'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final billing = order['billing_address'] is Map
        ? Map<String, dynamic>.from(order['billing_address'] as Map)
        : <String, dynamic>{};
    final shipping = order['shipping_address'] is Map
        ? Map<String, dynamic>.from(order['shipping_address'] as Map)
        : <String, dynamic>{};
    final paymentMethod = order['payment_method']?.toString() ?? '';
    final itemsSubtotal = items.fold<double>(
      0,
      (sum, item) => sum + ((item['total'] as num?)?.toDouble() ?? 0),
    );
    final grandTotal = (order['total'] as num?)?.toDouble() ?? itemsSubtotal;
    // Prefer an explicit field from the backend; if it's not there, fall
    // back to (grand total - items subtotal). The website's own order
    // table never shows a separate tax/fee row (only products, المجموع,
    // الشحن, وسيلة الدفع, الإجمالي) -- so for this store, that gap is
    // reliably the shipping cost.
    final shippingRaw =
        order['shipping_total'] ?? order['shipping'] ?? order['shipping_fee'];
    final explicitShipping = shippingRaw is num
        ? shippingRaw.toDouble()
        : double.tryParse(shippingRaw?.toString() ?? '');
    final shippingTotal =
        explicitShipping ?? (grandTotal - itemsSubtotal).clamp(0, grandTotal);
    final zip = shipping['postcode']?.toString().isNotEmpty == true
        ? shipping['postcode'].toString()
        : billing['postcode']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'تم تقديم الطلب #${widget.orderId} في '
          '${_formatDate(order['date_created']?.toString())} '
          'وهو الآن في حالة ${orderStatusLabel(status)}.',
          style: const TextStyle(color: AppColors.textPrimary, height: 1.6),
        ),
        const SizedBox(height: 20),
        const Text(
          'تفاصيل الطلب',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _OrderSummaryTable(
          items: items,
          symbol: symbol,
          itemsSubtotal: itemsSubtotal,
          shippingTotal: shippingTotal,
          paymentMethod: paymentMethod,
          grandTotal: grandTotal,
        ),
        if (zip.isNotEmpty) ...[
          const SizedBox(height: 12),
          _KeyValueBox(label: 'الرمز البريدي / ZIP', value: zip),
        ],
        if (shipping.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AddressBox(title: 'عنوان الشحن', address: shipping),
        ],
        if (billing.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AddressBox(title: 'عنوان الفاتورة', address: billing),
        ],
      ],
    );
  }
}

/// One bordered table for the whole order breakdown -- line items, then
/// subtotal/shipping/payment-method/grand-total rows -- matching the
/// website's single unified table instead of separate cards per section.
class _OrderSummaryTable extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String symbol;
  final double itemsSubtotal;
  final double shippingTotal;
  final String paymentMethod;
  final double grandTotal;

  const _OrderSummaryTable({
    required this.items,
    required this.symbol,
    required this.itemsSubtotal,
    required this.shippingTotal,
    required this.paymentMethod,
    required this.grandTotal,
  });

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    );
    const labelStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    );
    const totalStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: AppColors.primary,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2)},
        border: TableBorder.all(color: AppColors.border),
        children: [
          // In RTL, a TableRow's *first* child renders in the rightmost
          // column -- the product/label belongs there, matching the
          // website's own right-to-left column order.
          const TableRow(
            decoration: BoxDecoration(color: AppColors.white),
            children: [
              _TableCell(child: Text('المنتج', style: headerStyle)),
              _TableCell(child: Text('الإجمالي', style: headerStyle)),
            ],
          ),
          for (final item in items)
            TableRow(
              decoration: const BoxDecoration(color: AppColors.white),
              children: [
                _TableCell(
                  child: Text(
                    '${item['name'] ?? ''} × ${item['quantity'] ?? 1}',
                  ),
                ),
                _TableCell(
                  child: Text(
                    CurrencyUtils.format(
                      (item['total'] as num?)?.toDouble() ?? 0,
                      symbol,
                    ),
                  ),
                ),
              ],
            ),
          TableRow(
            decoration: const BoxDecoration(color: AppColors.white),
            children: [
              const _TableCell(child: Text('المجموع:', style: labelStyle)),
              _TableCell(
                child: Text(CurrencyUtils.format(itemsSubtotal, symbol)),
              ),
            ],
          ),
          TableRow(
            decoration: const BoxDecoration(color: AppColors.white),
            children: [
              const _TableCell(child: Text('الشحن:', style: labelStyle)),
              _TableCell(
                child: Text(CurrencyUtils.format(shippingTotal, symbol)),
              ),
            ],
          ),
          if (paymentMethod.isNotEmpty)
            TableRow(
              decoration: const BoxDecoration(color: AppColors.white),
              children: [
                const _TableCell(
                  child: Text('وسيلة الدفع:', style: labelStyle),
                ),
                _TableCell(child: Text(paymentMethod)),
              ],
            ),
          TableRow(
            decoration: const BoxDecoration(color: AppColors.white),
            children: [
              const _TableCell(child: Text('الإجمالي:', style: labelStyle)),
              _TableCell(
                child: Text(
                  CurrencyUtils.format(grandTotal, symbol),
                  style: totalStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final Widget child;

  const _TableCell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        child: child,
      ),
    );
  }
}

/// A single label/value row in its own bordered box -- used for the ZIP
/// field, which the website shows separately from the address boxes below
/// rather than inline inside them.
class _KeyValueBox extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}

/// A bordered white box with a distinct header bar for its title, then the
/// address lines below -- matching the website's boxed "عنوان الشحن" /
/// "عنوان الفاتورة" cards (stacked rather than side-by-side, since this
/// screen's viewport is a phone width, not the website's desktop layout).
class _AddressBox extends StatelessWidget {
  final String title;
  final Map<String, dynamic> address;

  const _AddressBox({required this.title, required this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: _AddressText(address: address),
          ),
        ],
      ),
    );
  }
}

class _AddressText extends StatelessWidget {
  final Map<String, dynamic> address;

  const _AddressText({required this.address});

  @override
  Widget build(BuildContext context) {
    final name = [
      address['first_name'],
      address['last_name'],
    ].whereType<String>().where((v) => v.isNotEmpty).join(' ');
    final line2 = [
      address['address_1'],
      address['address_2'],
    ].whereType<String>().where((v) => v.isNotEmpty).join('، ');
    // Postcode is deliberately left out here -- the website shows it once,
    // separately (see _KeyValueBox above), not duplicated inside the
    // address box itself.
    final line3 = [
      address['city'],
      address['state'],
    ].whereType<String>().where((v) => v.isNotEmpty).join('، ');
    final country = address['country']?.toString() ?? '';
    final phone = address['phone']?.toString() ?? '';

    final lines = [
      name,
      line2,
      line3,
      country,
      if (phone.isNotEmpty) phone,
    ].where((v) => v.isNotEmpty).toList();

    if (lines.isEmpty) {
      return const Text(
        'لا يوجد عنوان',
        style: TextStyle(color: AppColors.textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(line, style: const TextStyle(fontSize: 14)),
          ),
      ],
    );
  }
}
