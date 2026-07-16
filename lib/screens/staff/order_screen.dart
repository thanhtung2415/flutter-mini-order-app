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
  bool _isAddingItems = false;

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
              if (order != null &&
                  order.isActive &&
                  state.canManageOrder(order) &&
                  !_isAddingItems)
                IconButton(
                  tooltip: 'Thêm món',
                  onPressed: () => setState(() => _isAddingItems = true),
                  icon: const Icon(Icons.add_shopping_cart),
                ),
              if ((order == null || _isAddingItems) &&
                  state.cartItems.isNotEmpty)
                IconButton(
                  tooltip: 'Xóa giỏ hàng',
                  onPressed: state.clearCart,
                  icon: const Icon(Icons.remove_shopping_cart_outlined),
                ),
            ],
          ),
          body: order == null || _isAddingItems
              ? _NewOrderBody(
                  noteController: _noteController,
                  existingOrder: order,
                  onCancel: order == null
                      ? null
                      : () {
                          state.clearCart();
                          _noteController.clear();
                          setState(() => _isAddingItems = false);
                        },
                  onConfirmed: () {
                    if (order != null) {
                      setState(() => _isAddingItems = false);
                    }
                  },
                )
              : _ExistingOrderBody(
                  order: order,
                  onAddItems: state.canManageOrder(order)
                      ? () => setState(() => _isAddingItems = true)
                      : null,
                ),
        );
      },
    );
  }
}

class _NewOrderBody extends StatelessWidget {
  const _NewOrderBody({
    required this.noteController,
    required this.onConfirmed,
    this.existingOrder,
    this.onCancel,
  });

  final TextEditingController noteController;
  final Order? existingOrder;
  final VoidCallback? onCancel;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return CustomScrollView(
      slivers: [
        if (existingOrder != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.add_shopping_cart),
                  title: const Text('Thêm món vào order hiện tại'),
                  subtitle: Text(
                    '${existingOrder!.totalQuantity} món hiện có · ${money(existingOrder!.total)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Hủy thêm món',
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ),
          ),
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
            child: _CartPanel(
              noteController: noteController,
              isAddingItems: existingOrder != null,
              onConfirmed: onConfirmed,
            ),
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
  const _CartPanel({
    required this.noteController,
    required this.isAddingItems,
    required this.onConfirmed,
  });

  final TextEditingController noteController;
  final bool isAddingItems;
  final VoidCallback onConfirmed;

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
                onPressed: () async {
                  final order = await state.confirmOrder(noteController.text);
                  if (order != null) {
                    noteController.clear();
                    onConfirmed();
                  }
                },
                icon: const Icon(Icons.check_circle),
                label: Text(
                  isAddingItems ? 'Xác nhận thêm món' : 'Xác nhận order',
                ),
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
    final state = context.watch<AppState>();
    final product = state.productById(item.productId);
    final canIncrease =
        product?.canOrder == true && item.quantity < (product?.stock ?? 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                onPressed: canIncrease
                    ? () => state.increaseCartItem(item.productId)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                tooltip: 'Xóa món',
                onPressed: () => state.removeCartItem(item.productId),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _editNote(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                children: [
                  Icon(
                    item.note.isEmpty ? Icons.note_add_outlined : Icons.notes,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.note.isEmpty ? 'Thêm ghi chú cho món' : item.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.note.isEmpty
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: item.note.isEmpty
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 17),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNote(BuildContext context) async {
    final controller = TextEditingController(text: item.note);
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Ghi chú cho ${item.productName}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: ít đá, không hành, ít cay...',
            prefixIcon: Icon(Icons.notes),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (note == null || !context.mounted) return;
    context.read<AppState>().updateCartItemNote(item.productId, note);
  }
}

class _ExistingOrderBody extends StatelessWidget {
  const _ExistingOrderBody({required this.order, this.onAddItems});

  final Order order;
  final VoidCallback? onAddItems;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final table = state.tableById(order.tableId);
    final creator = state.userById(order.userId);
    final canManage = state.canManageOrder(order);
    final transferTargets = state.availableTablesForTransfer(order.tableId);
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
                          if (state.isAdmin)
                            Text(
                              'Người tạo: ${creator?.fullName ?? order.userId}',
                            ),
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
            FilledButton.icon(
              onPressed: onAddItems,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Thêm món'),
            ),
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
            OutlinedButton.icon(
              onPressed: canManage && transferTargets.isNotEmpty
                  ? () => _showTransferDialog(context, order)
                  : null,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Chuyển bàn'),
            ),
          ],
        ),
        if (state.isAdmin) ...[
          const SizedBox(height: 14),
          _TableOrderHistory(tableId: order.tableId),
        ],
      ],
    );
  }

  Future<void> _showTransferDialog(BuildContext context, Order order) async {
    final state = context.read<AppState>();
    final tables = state.availableTablesForTransfer(order.tableId);
    final target = await showModalBottomSheet<RestaurantTable>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                leading: Icon(Icons.swap_horiz),
                title: Text('Chuyển order sang bàn trống'),
                subtitle: Text('Chọn bàn nhận order hiện tại.'),
              ),
              const Divider(height: 1),
              for (final table in tables)
                ListTile(
                  leading: const Icon(Icons.table_bar),
                  title: Text(table.name),
                  subtitle: Text(
                    '${state.areaById(table.areaId)?.name ?? 'Khu vực'} · ${table.capacity} khách',
                  ),
                  onTap: () => Navigator.pop(context, table),
                ),
            ],
          ),
        );
      },
    );
    if (target == null || !context.mounted) return;

    final source = state.tableById(order.tableId);
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Chuyển sang ${target.name}?',
      message:
          'Order sẽ được chuyển từ ${source?.name ?? order.tableId} sang ${target.name}.',
      confirmLabel: 'Chuyển bàn',
    );
    if (!confirmed || !context.mounted) return;

    final moved = await context.read<AppState>().transferOrderToTable(
      order.id,
      target.id,
    );
    if (!moved || !context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OrderScreen(tableId: target.id)),
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
