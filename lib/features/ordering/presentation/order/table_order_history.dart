part of '../order_screen.dart';

class _TableOrderHistory extends StatelessWidget {
  const _TableOrderHistory({required this.tableId});

  final String tableId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final orders = state.ordersForTable(tableId).take(5).toList();
    if (orders.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lịch sử order của bàn',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 20,
                      color: orderStatusColor(order.status),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${order.id} · ${order.status.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Người tạo: ${state.userById(order.userId)?.fullName ?? order.userId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(dateTimeText(order.createdAt)),
                        ],
                      ),
                    ),
                    Text(
                      money(order.total),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
