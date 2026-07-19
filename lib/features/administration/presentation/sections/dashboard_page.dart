part of '../admin_home_screen.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final metrics = [
          MetricCard(
            title: 'Doanh thu hôm nay',
            value: money(state.todayRevenue),
            icon: Icons.payments_outlined,
            color: AppColors.primary,
            subtitle: '${state.todayPaidOrderCount} giao dịch',
          ),
          MetricCard(
            title: 'Số đơn hôm nay',
            value: '${state.todayPaidOrderCount}',
            icon: Icons.receipt_long_outlined,
            color: AppColors.info,
            subtitle: 'Đã thanh toán',
          ),
          MetricCard(
            title: 'Bàn đang phục vụ',
            value: '${state.activeOrders.length}',
            icon: Icons.table_restaurant_outlined,
            color: AppColors.warning,
            subtitle: '${state.delayedOrders.length} bàn quá 10 phút',
          ),
          MetricCard(
            title: 'Cảnh báo kho',
            value: '${state.lowStockProducts.length}',
            icon: Icons.inventory_2_outlined,
            color: AppColors.danger,
            subtitle: 'Món sắp hết hoặc đã hết',
          ),
        ];

        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                0,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: metrics.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  mainAxisExtent: 108,
                ),
                itemBuilder: (_, index) => metrics[index],
              ),
            ),
            if (state.delayedOrders.isNotEmpty ||
                state.lowStockProducts.isNotEmpty) ...[
              const SectionTitle(title: 'Cần xử lý'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Card(
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < state.delayedOrders.length;
                        index++
                      ) ...[
                        _DelayedOrderRow(order: state.delayedOrders[index]),
                        if (index < state.delayedOrders.length - 1 ||
                            state.lowStockProducts.isNotEmpty)
                          const Divider(),
                      ],
                      for (
                        var index = 0;
                        index < state.lowStockProducts.length;
                        index++
                      ) ...[
                        _AdminProductStockTile(
                          product: state.lowStockProducts[index],
                        ),
                        if (index < state.lowStockProducts.length - 1)
                          const Divider(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SectionTitle(title: 'Món bán chạy'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Card(
                child: state.bestSeller == null
                    ? const ListTile(
                        title: Text('Chưa có dữ liệu bán hàng'),
                        subtitle: Text(
                          'Dữ liệu sẽ có sau khi đơn được thanh toán.',
                        ),
                      )
                    : ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        leading: ProductAvatar(product: state.bestSeller!),
                        title: Text(
                          state.bestSeller!.name,
                          style: AppTextStyles.sectionTitle,
                        ),
                        subtitle: const Text('Theo lịch sử đơn đã thanh toán'),
                        trailing: const Icon(
                          Icons.trending_up,
                          color: AppColors.success,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DelayedOrderRow extends StatelessWidget {
  const _DelayedOrderRow({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final table = state.tableById(order.tableId);
    return ListTile(
      minLeadingWidth: 24,
      leading: const Icon(Icons.schedule, color: AppColors.danger, size: 21),
      title: Text(
        '${table?.name ?? 'Bàn'} · ${order.totalQuantity} món',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('Quá 10 phút · ${money(order.total)}'),
      trailing: const StatusChip(label: 'Trễ', color: AppColors.danger),
    );
  }
}

class _AdminProductStockTile extends StatelessWidget {
  const _AdminProductStockTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return ListTile(
      contentPadding: const EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.xxs,
      ),
      leading: ProductAvatar(product: product, size: 40),
      title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'Tồn ${product.stock} · Ngưỡng ${product.warningThreshold}',
      ),
      trailing: Wrap(
        spacing: 0,
        children: [
          IconButton(
            tooltip: 'Giảm tồn',
            onPressed: () => state.adjustStock(product.id, -1),
            icon: const Icon(Icons.remove, size: 20),
          ),
          IconButton(
            tooltip: 'Tăng tồn',
            onPressed: () => state.adjustStock(product.id, 1),
            icon: const Icon(Icons.add, size: 20),
          ),
        ],
      ),
    );
  }
}
