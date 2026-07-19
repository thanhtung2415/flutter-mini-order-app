part of '../payment_screen.dart';

class _CashPaymentPanel extends StatelessWidget {
  const _CashPaymentPanel({
    required this.order,
    required this.payment,
    required this.onCreate,
    required this.onConfirm,
  });

  final Order order;
  final Payment? payment;
  final VoidCallback? onCreate;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tiền mặt',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('Số tiền cần thu: ${money(order.total)}'),
            const SizedBox(height: 14),
            if (payment == null)
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.payments),
                label: const Text('Chọn tiền mặt'),
              )
            else
              FilledButton.icon(
                onPressed: order.status == OrderStatus.paid ? null : onConfirm,
                icon: const Icon(Icons.check_circle),
                label: const Text('Xác nhận đã thu tiền'),
              ),
          ],
        ),
      ),
    );
  }
}
