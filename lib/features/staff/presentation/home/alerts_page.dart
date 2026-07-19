part of '../staff_home_screen.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final lowStock = state.lowStockProducts;
        final delayed = state.delayedOrders;
        if (lowStock.isEmpty && delayed.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_active,
            title: 'Không có cảnh báo',
            message: 'Tồn kho và thời gian xử lý order đang ổn định.',
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            if (delayed.isNotEmpty) ...[
              const SectionTitle(title: 'Đơn quá 10 phút'),
              for (final order in delayed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: OrderActionCard(order: order),
                ),
            ],
            if (lowStock.isNotEmpty) ...[
              const SectionTitle(title: 'Tồn kho thấp'),
              for (final product in lowStock)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Card(
                    child: ListTile(
                      leading: ProductAvatar(product: product),
                      title: Text(product.name),
                      subtitle: Text(
                        product.stock == 0 ? 'Hết món' : 'Còn ${product.stock}',
                      ),
                      trailing: StatusChip(
                        label: product.stock == 0 ? 'Hết' : 'Dưới ngưỡng',
                        color: stockColor(product),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
