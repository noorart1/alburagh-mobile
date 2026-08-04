import 'package:flutter/material.dart';

/// Arabic label and color for a WooCommerce order status code, shared by
/// the orders list and the order detail screen so both stay in sync
/// instead of each showing the raw English status string.
String orderStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'قيد الانتظار';
    case 'processing':
      return 'قيد التجهيز';
    case 'on-hold':
      return 'قيد التعليق';
    case 'completed':
      return 'مكتمل';
    case 'cancelled':
      return 'ملغى';
    case 'refunded':
      return 'مسترجع';
    case 'failed':
      return 'فشل الدفع';
    default:
      return status;
  }
}

Color orderStatusColor(String status) {
  switch (status) {
    case 'completed':
      return Colors.green;
    case 'processing':
      return Colors.blue;
    case 'on-hold':
      return Colors.orange;
    case 'pending':
      return Colors.amber;
    case 'cancelled':
    case 'failed':
      return Colors.red;
    case 'refunded':
      return Colors.purple;
    default:
      return Colors.grey;
  }
}
