import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/app_models.dart';
import '../../../app/state/app_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

Future<void> showOrderInvoiceDetails(BuildContext context, Order order) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) =>
          _OrderInvoiceSheet(order: order, scrollController: scrollController),
    ),
  );
}

class _OrderInvoiceSheet extends StatelessWidget {
  const _OrderInvoiceSheet({
    required this.order,
    required this.scrollController,
  });

  final Order order;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final table = state.tableById(order.tableId);
    final creator = state.userById(order.userId);
    final payment = state.latestPaymentForOrder(order.id);
    final confirmer = payment?.confirmedBy == null
        ? null
        : state.userById(payment!.confirmedBy!);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      key: const Key('order-invoice-sheet'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chi tiết hóa đơn',
                    style: AppTextStyles.screenTitle.copyWith(fontSize: 21),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    table?.name ?? order.tableId,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
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
        const SizedBox(height: AppSpacing.lg),
        _InvoiceSection(
          title: 'Thông tin order',
          child: Column(
            children: [
              _InvoiceInfoRow(label: 'Mã đơn', value: order.id),
              _InvoiceInfoRow(
                label: 'Người tạo',
                value: creator?.fullName ?? order.userId,
              ),
              _InvoiceInfoRow(
                label: 'Tạo lúc',
                value: dateTimeText(order.createdAt),
              ),
              _InvoiceInfoRow(
                label: 'Cập nhật',
                value: dateTimeText(order.updatedAt),
              ),
              if (order.sentKitchenAt != null)
                _InvoiceInfoRow(
                  label: 'Gửi bếp',
                  value: dateTimeText(order.sentKitchenAt!),
                ),
              if (order.completedAt != null)
                _InvoiceInfoRow(
                  label: 'Hoàn tất món',
                  value: dateTimeText(order.completedAt!),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _InvoiceSection(
          title: 'Danh sách món (${order.totalQuantity})',
          child: Column(
            children: [
              for (var index = 0; index < order.items.length; index++) ...[
                _InvoiceItemRow(item: order.items[index]),
                if (index != order.items.length - 1) const Divider(height: 20),
              ],
            ],
          ),
        ),
        if (order.note.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          _InvoiceSection(
            title: 'Ghi chú order',
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(order.note.trim()),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _InvoiceSection(
          title: 'Tổng thanh toán',
          child: Column(
            children: [
              _InvoiceInfoRow(
                label: 'Tổng số lượng',
                value: '${order.totalQuantity} món',
              ),
              _InvoiceInfoRow(label: 'Tạm tính', value: money(order.total)),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text('Tổng cộng', style: AppTextStyles.sectionTitle),
                  ),
                  Text(
                    money(order.total),
                    style: AppTextStyles.total.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _InvoiceSection(
          title: 'Thanh toán',
          child: payment == null
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Order chưa có thông tin thanh toán.'),
                )
              : Column(
                  children: [
                    _InvoiceInfoRow(label: 'Mã thanh toán', value: payment.id),
                    _InvoiceInfoRow(
                      label: 'Phương thức',
                      value: payment.method.label,
                    ),
                    _InvoiceInfoRow(
                      label: 'Trạng thái',
                      value: payment.status.label,
                    ),
                    _InvoiceInfoRow(
                      label: 'Số tiền',
                      value: money(payment.amount),
                    ),
                    _InvoiceInfoRow(
                      label: 'Khởi tạo',
                      value: dateTimeText(payment.createdAt),
                    ),
                    if (payment.paidAt != null)
                      _InvoiceInfoRow(
                        label: 'Xác nhận lúc',
                        value: dateTimeText(payment.paidAt!),
                      ),
                    if (payment.confirmedBy != null)
                      _InvoiceInfoRow(
                        label: 'Người xác nhận',
                        value: confirmer?.fullName ?? payment.confirmedBy!,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('close-order-invoice'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          label: const Text('Đóng hóa đơn'),
        ),
      ],
    );
  }
}

class _InvoiceSection extends StatelessWidget {
  const _InvoiceSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        child,
        const Divider(height: AppSpacing.lg),
      ],
    );
  }
}

class _InvoiceInfoRow extends StatelessWidget {
  const _InvoiceInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceItemRow extends StatelessWidget {
  const _InvoiceItemRow({required this.item});

  final OrderItem item;

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
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.quantity} × ${money(item.unitPrice)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (item.note.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Ghi chú: ${item.note.trim()}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          money(item.total),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
