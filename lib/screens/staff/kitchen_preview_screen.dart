import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../services/report_service.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_widgets.dart';

class KitchenPreviewScreen extends StatelessWidget {
  const KitchenPreviewScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        showStateSnackBar(context, state);
        final order = state.orderById(orderId);
        if (order == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.kitchen,
              title: 'Không tìm thấy phiếu bếp',
              message: 'Order có thể đã bị hủy hoặc không tồn tại.',
            ),
          );
        }

        final table = state.tableById(order.tableId);
        return Scaffold(
          appBar: AppBar(title: const Text('Phiếu gửi bếp')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.kitchen, size: 48),
                      const SizedBox(height: 10),
                      Text(
                        'PHIẾU ORDER BẾP',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ReceiptLine(
                        label: 'Bàn',
                        value: table?.name ?? order.tableId,
                      ),
                      _ReceiptLine(label: 'Mã đơn', value: order.id),
                      _ReceiptLine(
                        label: 'Tạo lúc',
                        value: dateTimeText(order.createdAt),
                      ),
                      _ReceiptLine(
                        label: 'Trạng thái',
                        value: order.status.label,
                      ),
                      const Divider(height: 28),
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '${item.quantity}x',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (item.note.isNotEmpty) Text(item.note),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (order.note.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text('Ghi chú order: ${order.note}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (order.status == OrderStatus.pending)
                    FilledButton.icon(
                      onPressed: () => state.sendToKitchen(order.id),
                      icon: const Icon(Icons.send),
                      label: const Text('Gửi bếp'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final receipt = ReportService().buildKitchenReceipt(
                        order: order,
                        table: table,
                      );
                      Clipboard.setData(ClipboardData(text: receipt));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã copy nội dung phiếu bếp.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Xuất phiếu'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
