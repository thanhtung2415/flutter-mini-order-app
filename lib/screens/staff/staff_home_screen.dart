import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_widgets.dart';
import 'kitchen_preview_screen.dart';
import 'order_screen.dart';
import 'payment_screen.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [TablesPage(), ActiveOrdersPage(), AlertsPage()];

    return Consumer<AppState>(
      builder: (context, state, _) {
        showStateSnackBar(context, state);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mini Order'),
                Text(
                  '${state.currentUser?.fullName ?? ''} · ${state.currentUser?.role.label ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Đăng xuất',
                onPressed: state.logout,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: pages[_index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.table_restaurant_outlined),
                selectedIcon: Icon(Icons.table_restaurant),
                label: 'Bàn',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Đơn',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_none),
                selectedIcon: Icon(Icons.notifications),
                label: 'Cảnh báo',
              ),
            ],
          ),
        );
      },
    );
  }
}

class TablesPage extends StatelessWidget {
  const TablesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final tables = state.filteredTables;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _AreaFilter(state: state),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _TableSummary(state: state),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final count = width >= 900
                      ? 4
                      : width >= 640
                      ? 3
                      : 2;
                  return SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _TableCard(table: tables[index]),
                      childCount: tables.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AreaFilter extends StatelessWidget {
  const _AreaFilter({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Tất cả'),
              selected: state.selectedAreaId == 'all',
              onSelected: (_) => state.selectArea('all'),
            ),
          ),
          for (final area in state.areas)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(area.name),
                selected: state.selectedAreaId == area.id,
                onSelected: (_) => state.selectArea(area.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableSummary extends StatelessWidget {
  const _TableSummary({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final available = state.tables
        .where((table) => table.status == TableStatus.available)
        .length;
    final ordering = state.tables
        .where((table) => table.status == TableStatus.ordering)
        .length;
    final paid = state.tables
        .where((table) => table.status == TableStatus.paid)
        .length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final cards = [
          MetricCard(
            title: 'Bàn trống',
            value: '$available',
            icon: Icons.event_seat,
            color: tableStatusColor(TableStatus.available),
          ),
          MetricCard(
            title: 'Đang order',
            value: '$ordering',
            icon: Icons.room_service,
            color: tableStatusColor(TableStatus.ordering),
          ),
          MetricCard(
            title: 'Đã thanh toán',
            value: '$paid',
            icon: Icons.payments,
            color: tableStatusColor(TableStatus.paid),
          ),
        ];
        if (isWide) {
          return Row(
            children: [
              for (final card in cards)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: card,
                  ),
                ),
            ],
          );
        }
        return Column(
          children: [
            for (final card in cards)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: card),
          ],
        );
      },
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table});

  final RestaurantTable table;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final order = state.orderForTable(table.id);
    final area = state.areaById(table.areaId);
    final color = tableStatusColor(table.status);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _handleTap(context, state, order),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.table_bar, color: color),
                  ),
                  const Spacer(),
                  StatusChip(label: table.status.label, color: color),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                table.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text('${area?.name ?? 'Khu vực'} · ${table.capacity} khách'),
              const Spacer(),
              if (order != null) ...[
                Text(
                  '${order.totalQuantity} món · ${money(order.total)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (order.isDelayed)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: StatusChip(
                      label: 'Quá 10 phút',
                      color: Color(0xFFC62828),
                      icon: Icons.timer_off,
                    ),
                  ),
              ] else
                Text(
                  'Sẵn sàng nhận order',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    AppState state,
    Order? order,
  ) async {
    if (table.status == TableStatus.paid) {
      final confirmed = await showConfirmDialog(
        context: context,
        title: 'Dọn ${table.name}?',
        message: 'Sau khi dọn bàn, trạng thái bàn sẽ chuyển về trống.',
        confirmLabel: 'Dọn bàn',
      );
      if (confirmed && context.mounted) {
        state.clearTable(table.id);
      }
      return;
    }
    state.selectTable(table.id);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderScreen(tableId: table.id)),
    );
  }
}

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
                    color: Color(0xFFC62828),
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
