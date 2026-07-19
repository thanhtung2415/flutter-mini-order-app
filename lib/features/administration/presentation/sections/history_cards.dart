part of '../admin_home_screen.dart';

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final table = state.tableById(order.tableId);
    final user = state.userById(order.userId);
    return InkWell(
      key: Key('order-history-${order.id}'),
      onTap: () => showOrderInvoiceDetails(context, order),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          table?.name ?? order.tableId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.sectionTitle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      StatusChip(
                        label: order.status.label,
                        color: orderStatusColor(order.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${dateTimeText(order.updatedAt)} · ${user?.fullName ?? order.userId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${order.totalQuantity} món · ${money(order.total)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final table = state.tableById(payment.tableId);
    final confirmer = payment.confirmedBy == null
        ? null
        : state.userById(payment.confirmedBy!);
    final methodColor = payment.method == PaymentMethod.cash
        ? AppColors.success
        : AppColors.info;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            payment.method == PaymentMethod.cash
                ? Icons.payments_outlined
                : Icons.qr_code_2,
            color: methodColor,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${table?.name ?? payment.tableId} · ${payment.method.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${payment.paidAt == null ? '--' : dateTimeText(payment.paidAt!)} · ${confirmer?.fullName ?? 'Không rõ'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            money(payment.amount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
