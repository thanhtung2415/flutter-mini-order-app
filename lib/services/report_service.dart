import '../models/app_models.dart';
import '../utils/formatters.dart';

class ReportService {
  String buildRevenueCsv({
    required List<Payment> payments,
    required Order? Function(String id) orderById,
    required RestaurantTable? Function(String id) tableById,
    required AppUser? Function(String id) userById,
  }) {
    final rows = <List<String>>[
      [
        'paymentId',
        'orderId',
        'ban',
        'phuongThuc',
        'tongTien',
        'ngayThanhToan',
        'nguoiXacNhan',
        'soMon',
      ],
      for (final payment in payments)
        [
          payment.id,
          payment.orderId,
          tableById(payment.tableId)?.name ?? payment.tableId,
          payment.method.label,
          payment.amount.toString(),
          payment.paidAt == null ? '' : dateTimeText(payment.paidAt!),
          payment.confirmedBy == null
              ? ''
              : userById(payment.confirmedBy!)?.fullName ??
                    payment.confirmedBy!,
          '${orderById(payment.orderId)?.totalQuantity ?? 0}',
        ],
    ];

    return rows.map(_csvRow).join('\n');
  }

  String buildKitchenReceipt({
    required Order order,
    required RestaurantTable? table,
  }) {
    final buffer = StringBuffer()
      ..writeln('PHIEU ORDER BEP')
      ..writeln('Ban: ${table?.name ?? order.tableId}')
      ..writeln('Ma don: ${order.id}')
      ..writeln('Tao luc: ${dateTimeText(order.createdAt)}')
      ..writeln('Trang thai: ${order.status.label}')
      ..writeln('------------------------------');

    for (final item in order.items) {
      buffer.writeln('${item.quantity} x ${item.productName}');
      if (item.note.isNotEmpty) {
        buffer.writeln('  Ghi chu: ${item.note}');
      }
    }

    if (order.note.isNotEmpty) {
      buffer
        ..writeln('------------------------------')
        ..writeln('Ghi chu order: ${order.note}');
    }

    return buffer.toString();
  }

  String _csvRow(List<String> values) {
    return values.map(_csvCell).join(',');
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
