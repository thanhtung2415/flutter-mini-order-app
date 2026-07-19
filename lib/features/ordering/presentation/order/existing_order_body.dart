part of '../order_screen.dart';

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

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
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
                                  style: AppTextStyles.screenTitle.copyWith(
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  'Mã đơn: ${order.id}',
                                  style: AppTextStyles.caption,
                                ),
                                if (state.isAdmin)
                                  Text(
                                    'Người tạo: ${creator?.fullName ?? order.userId}',
                                    style: AppTextStyles.caption,
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
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              color: AppColors.danger,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Đơn đã quá 10 phút',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: AppSpacing.lg),
                      for (
                        var index = 0;
                        index < order.items.length;
                        index++
                      ) ...[
                        _OrderItemRow(
                          item: order.items[index],
                          canRemove: canAdminRemoveItems,
                          onRemove: () => _confirmRemoveItem(
                            context,
                            order,
                            order.items[index],
                          ),
                        ),
                        if (index < order.items.length - 1)
                          const Divider(height: AppSpacing.md),
                      ],
                      if (order.note.isNotEmpty) ...[
                        const Divider(height: AppSpacing.lg),
                        Text('Ghi chú', style: AppTextStyles.caption),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(order.note),
                      ],
                      const Divider(height: AppSpacing.lg),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Tổng cộng',
                              style: AppTextStyles.sectionTitle,
                            ),
                          ),
                          Text(money(order.total), style: AppTextStyles.total),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  OutlinedButton.icon(
                    onPressed: onAddItems,
                    icon: const Icon(Icons.add, size: 19),
                    label: const Text('Thêm món'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => KitchenPreviewScreen(orderId: order.id),
                      ),
                    ),
                    icon: const Icon(Icons.kitchen_outlined, size: 19),
                    label: const Text('Phiếu bếp'),
                  ),
                  if (order.status == OrderStatus.pending)
                    OutlinedButton.icon(
                      onPressed: canManage
                          ? () => state.sendToKitchen(order.id)
                          : null,
                      icon: const Icon(Icons.send_outlined, size: 19),
                      label: const Text('Gửi bếp'),
                    ),
                  if (order.status == OrderStatus.preparing)
                    OutlinedButton.icon(
                      onPressed: canManage
                          ? () => state.completeOrder(order.id)
                          : null,
                      icon: const Icon(Icons.check_circle_outline, size: 19),
                      label: const Text('Hoàn tất món'),
                    ),
                  OutlinedButton.icon(
                    onPressed: canManage && transferTargets.isNotEmpty
                        ? () => _showTransferDialog(context, order)
                        : null,
                    icon: const Icon(Icons.swap_horiz, size: 19),
                    label: const Text('Chuyển bàn'),
                  ),
                ],
              ),
              if (state.isAdmin) ...[
                const SizedBox(height: AppSpacing.md),
                _TableOrderHistory(tableId: order.tableId),
              ],
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.all(AppSpacing.sm),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canManage
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(orderId: order.id),
                        ),
                      )
                    : null,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Thanh toán'),
              ),
            ),
          ),
        ),
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
              const Divider(),
              for (final table in tables)
                ListTile(
                  leading: const Icon(Icons.table_bar_outlined),
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

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({
    required this.item,
    required this.canRemove,
    required this.onRemove,
  });

  final OrderItem item;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Text(
            '${item.quantity}x',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.productName),
              if (item.note.isNotEmpty)
                Text(item.note, style: AppTextStyles.caption),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          money(item.total),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (canRemove)
          IconButton(
            tooltip: 'Xóa món khỏi bill',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            color: AppColors.danger,
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
      ],
    );
  }
}
