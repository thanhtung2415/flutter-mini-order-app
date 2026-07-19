part of '../staff_home_screen.dart';

class ActiveOrdersPage extends StatelessWidget {
  const ActiveOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final orders = state.activeOrders;
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long,
            title: 'Chưa có order đang phục vụ',
            message:
                'Các order mới sẽ xuất hiện tại đây sau khi xác nhận giỏ hàng.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) =>
              OrderActionCard(order: orders[index]),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemCount: orders.length,
        );
      },
    );
  }
}

class OrderActionCard extends StatelessWidget {
  const OrderActionCard({
    super.key,
    required this.order,
    this.showAdminActions = false,
  });

  final Order order;
  final bool showAdminActions;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final table = state.tableById(order.tableId);
    final creator = state.userById(order.userId);
    final color = orderStatusColor(order.status);
    final canManage = state.canManageOrder(order);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table?.name ?? 'Bàn',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text('${order.id} · ${dateTimeText(order.createdAt)}'),
                      if (state.isAdmin)
                        Text(
                          'Người tạo: ${creator?.fullName ?? order.userId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                StatusChip(label: order.status.label, color: color),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in order.items.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${item.quantity} x ${item.productName}'),
              ),
            if (order.items.length > 3)
              Text('+${order.items.length - 3} món khác'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    money(order.total),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (order.isDelayed)
                  const StatusChip(
                    label: 'Quá 10 phút',
                    color: AppColors.danger,
                    icon: Icons.timer_off,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => KitchenPreviewScreen(orderId: order.id),
                    ),
                  ),
                  icon: const Icon(Icons.kitchen),
                  label: const Text('Phiếu bếp'),
                ),
                if (order.status == OrderStatus.pending)
                  FilledButton.icon(
                    onPressed: canManage
                        ? () => state.sendToKitchen(order.id)
                        : null,
                    icon: const Icon(Icons.send),
                    label: const Text('Gửi bếp'),
                  ),
                if (order.status == OrderStatus.preparing)
                  FilledButton.icon(
                    onPressed: canManage
                        ? () => state.completeOrder(order.id)
                        : null,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Hoàn tất'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: canManage
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(orderId: order.id),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Thanh toán'),
                ),
                if (showAdminActions)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context: context,
                        title: 'Hủy order?',
                        message:
                            'Order sẽ bị hủy và số lượng tồn kho được hoàn lại.',
                        confirmLabel: 'Hủy order',
                        destructive: true,
                      );
                      if (confirmed && context.mounted) {
                        context.read<AppState>().cancelOrder(order.id);
                      }
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Hủy'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
