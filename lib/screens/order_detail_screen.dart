import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/currency_utils.dart';
import '../core/order_status.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

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

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parts = raw.split(' ');
    return parts.first;
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDate(order['date_created']?.toString()),
              style: const TextStyle(color: AppColors.textMuted),
            ),
            _StatusBadge(status: status),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'المنتجات',
          child: Column(
            children: [
              for (final item in items) _OrderItemRow(item: item, symbol: symbol),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'الإجمالي',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المجموع الكلي', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                CurrencyUtils.format(
                  (order['total'] as num?)?.toDouble() ?? 0,
                  symbol,
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        if (paymentMethod.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(title: 'طريقة الدفع', child: Text(paymentMethod)),
        ],
        if (shipping.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'عنوان الشحن',
            child: _AddressText(address: shipping),
          ),
        ],
        if (billing.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'عنوان الفوترة',
            child: _AddressText(address: billing),
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        orderStatusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String symbol;

  const _OrderItemRow({required this.item, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? '';
    final quantity = item['quantity'] ?? 1;
    final total = (item['total'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text('$name × $quantity', style: const TextStyle(fontSize: 14)),
          ),
          Text(
            CurrencyUtils.format(total, symbol),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
    final name = [address['first_name'], address['last_name']]
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .join(' ');
    final line2 = [address['address_1'], address['address_2']]
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .join('، ');
    final line3 = [address['city'], address['state'], address['postcode']]
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .join('، ');
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
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(line, style: const TextStyle(fontSize: 14)),
          ),
      ],
    );
  }
}
