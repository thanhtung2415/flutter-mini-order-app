import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_widgets.dart';
import 'kitchen_preview_screen.dart';
import 'payment_screen.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.tableId});

  final String tableId;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().selectTable(widget.tableId);
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        showStateSnackBar(context, state);
        final table = state.tableById(widget.tableId);
        final order = state.orderForTable(widget.tableId);
        if (table == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.table_bar,
              title: 'Không tìm thấy bàn',
              message: 'Vui lòng quay lại danh sách bàn.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(table.name),
                Text(
                  table.status.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              if (order == null && state.cartItems.isNotEmpty)
                IconButton(
                  tooltip: 'Xóa giỏ hàng',
                  onPressed: state.clearCart,
                  icon: const Icon(Icons.remove_shopping_cart_outlined),
                ),
            ],
          ),
          body: order == null
              ? _NewOrderBody(noteController: _noteController)
              : _ExistingOrderBody(order: order),
        );
      },
    );
  }
}

class _NewOrderBody extends StatelessWidget {
  const _NewOrderBody({required this.noteController});

  final TextEditingController noteController;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: state.searchMenu,
                  decoration: const InputDecoration(
                    labelText: 'Tìm kiếm món',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                _CategoryFilter(state: state),
              ],
            ),
          ),
        ),
        if (state.filteredProducts.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.restaurant_menu,
              title: 'Không tìm thấy món',
              message: 'Thử đổi danh mục hoặc từ khóa tìm kiếm.',
            ),
          )
        else
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
                    (context, index) =>
                        _ProductCard(product: state.filteredProducts[index]),
                    childCount: state.filteredProducts.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: width >= 640 ? 0.95 : 0.78,
                  ),
                );
              },
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: _CartPanel(noteController: noteController),
          ),
        ),
      ],
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Tất cả món'),
                selected: state.selectedCategoryId == 'all',
                onSelected: (_) => state.selectCategory('all'),
              ),
            ),
            for (final category in state.categories)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category.name),
                  selected: state.selectedCategoryId == category.id,
                  onSelected: (_) => state.selectCategory(category.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final color = stockColor(product);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProductAvatar(product: product, size: 52),
                const Spacer(),
                StatusChip(
                  label: product.stock == 0 ? 'Hết' : 'Còn ${product.stock}',
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              product.shortDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              money(product.price),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: product.canOrder
                    ? () => state.addToCart(product)
                    : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Thêm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.noteController});

  final TextEditingController noteController;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final table = state.selectedTable;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Giỏ hàng ${table == null ? '' : '· ${table.name}'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusChip(
                  label: '${state.cartItems.length} món',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.cartItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Giỏ hàng trống',
                  message: 'Chọn món trong menu để tạo order.',
                ),
              )
            else ...[
              for (final item in state.cartItems) _CartItemTile(item: item),
              const Divider(height: 24),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú order',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tổng tiền',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    money(state.cartTotal),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  final order = state.confirmOrder(noteController.text);
                  if (order != null) {
                    noteController.clear();
                  }
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Xác nhận order'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(money(item.total)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Giảm',
            onPressed: () => state.decreaseCartItem(item.productId),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Tăng',
            onPressed: () => state.increaseCartItem(item.productId),
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            tooltip: 'Xóa món',
            onPressed: () => state.removeCartItem(item.productId),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _ExistingOrderBody extends StatelessWidget {
  const _ExistingOrderBody({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final table = state.tableById(order.tableId);
    final canManage = state.canManageOrder(order);
    final canAdminRemoveItems =
        state.isAdmin &&
        order.status != OrderStatus.paid &&
        order.status != OrderStatus.cancelled;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
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
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text('Mã đơn: ${order.id}'),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: order.status.label,
                      color: orderStatusColor(order.status),
                    ),
                  ],
                ),
                if (order.isDelayed) ...[
                  const SizedBox(height: 10),
                  const StatusChip(
                    label: 'Đơn quá 10 phút',
                    color: Color(0xFFC62828),
                    icon: Icons.timer_off,
                  ),
                ],
                const Divider(height: 28),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${item.quantity}x',
                            style: const TextStyle(fontWeight: FontWeight.w800),
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
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(money(item.total)),
                            if (canAdminRemoveItems)
                              IconButton(
                                tooltip: 'Admin xóa món khỏi bill',
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _confirmRemoveItem(context, order, item),
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (order.note.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text('Ghi chú: ${order.note}'),
                ],
                const Divider(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tổng cộng',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      money(order.total),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
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
                label: const Text('Hoàn tất món'),
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
              icon: const Icon(Icons.payments),
              label: const Text('Thanh toán'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmRemoveItem(
    BuildContext context,
    Order order,
    OrderItem item,
  ) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Xóa món khỏi bill?',
      message:
          'Món ${item.productName} sẽ bị xóa khỏi order và số lượng tồn kho được hoàn lại.',
      confirmLabel: 'Xóa món',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    context.read<AppState>().removeOrderItem(order.id, item.id);
  }
}
