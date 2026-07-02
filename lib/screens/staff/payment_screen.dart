import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/app_models.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_widgets.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod _method = PaymentMethod.qr;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().createPayment(widget.orderId, _method);
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        showStateSnackBar(context, state);
        final order = state.orderById(widget.orderId);
        if (order == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.payments,
              title: 'Không tìm thấy thanh toán',
              message: 'Order có thể đã bị hủy hoặc không tồn tại.',
            ),
          );
        }

        final table = state.tableById(order.tableId);
        final payment = state.latestPaymentForOrder(order.id);
        final visiblePayment = payment?.method == _method ? payment : null;
        final canManage = state.canManageOrder(order);

        return Scaffold(
          appBar: AppBar(title: const Text('Thanh toán')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                                  table?.name ?? 'Bàn',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
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
                      const Divider(height: 28),
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.quantity} x ${item.productName}',
                                ),
                              ),
                              Text(money(item.total)),
                            ],
                          ),
                        ),
                      const Divider(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Tổng cần thu',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            money(order.total),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (!canManage) ...[
                const StatusChip(
                  label: 'Không có quyền thanh toán order này',
                  color: Color(0xFFC62828),
                  icon: Icons.lock,
                ),
                const SizedBox(height: 14),
              ],
              SegmentedButton<PaymentMethod>(
                segments: const [
                  ButtonSegment(
                    value: PaymentMethod.qr,
                    icon: Icon(Icons.qr_code_2),
                    label: Text('QR'),
                  ),
                  ButtonSegment(
                    value: PaymentMethod.cash,
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Tiền mặt'),
                  ),
                ],
                selected: {_method},
                onSelectionChanged:
                    order.status == OrderStatus.paid || !canManage
                    ? null
                    : (values) {
                        final value = values.first;
                        setState(() => _method = value);
                        context.read<AppState>().createPayment(
                          widget.orderId,
                          value,
                        );
                      },
              ),
              const SizedBox(height: 14),
              if (_method == PaymentMethod.qr)
                _QrPaymentPanel(
                  order: order,
                  payment: visiblePayment,
                  onCreate: canManage
                      ? () => state.createPayment(order.id, PaymentMethod.qr)
                      : null,
                  onConfirm: visiblePayment == null || !canManage
                      ? null
                      : () => state.confirmPayment(visiblePayment.id),
                )
              else
                _CashPaymentPanel(
                  order: order,
                  payment: visiblePayment,
                  onCreate: canManage
                      ? () => state.createPayment(order.id, PaymentMethod.cash)
                      : null,
                  onConfirm: visiblePayment == null || !canManage
                      ? null
                      : () => state.confirmPayment(visiblePayment.id),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QrPaymentPanel extends StatelessWidget {
  const _QrPaymentPanel({
    required this.order,
    required this.payment,
    required this.onCreate,
    required this.onConfirm,
  });

  final Order order;
  final Payment? payment;
  final VoidCallback? onCreate;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final expired = payment?.isQrExpired ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'QR chuyển khoản',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (payment == null) ...[
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Tạo QR'),
              ),
            ] else ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E6EA)),
                  ),
                  child: QrImageView(
                    data: payment!.qrContent,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: StatusChip(
                  label: expired
                      ? 'QR hết hạn'
                      : 'Còn hiệu lực ${remainingQrTime(payment!.qrExpiredAt)}',
                  color: expired
                      ? const Color(0xFFC62828)
                      : const Color(0xFF2E7D32),
                  icon: expired ? Icons.timer_off : Icons.timer,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                payment!.qrContent,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              if (expired)
                OutlinedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tạo QR mới'),
                )
              else
                FilledButton.icon(
                  onPressed: order.status == OrderStatus.paid
                      ? null
                      : onConfirm,
                  icon: const Icon(Icons.verified),
                  label: const Text('Xác nhận đã chuyển khoản'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CashPaymentPanel extends StatelessWidget {
  const _CashPaymentPanel({
    required this.order,
    required this.payment,
    required this.onCreate,
    required this.onConfirm,
  });

  final Order order;
  final Payment? payment;
  final VoidCallback? onCreate;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tiền mặt',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('Số tiền cần thu: ${money(order.total)}'),
            const SizedBox(height: 14),
            if (payment == null)
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.payments),
                label: const Text('Chọn tiền mặt'),
              )
            else
              FilledButton.icon(
                onPressed: order.status == OrderStatus.paid ? null : onConfirm,
                icon: const Icon(Icons.check_circle),
                label: const Text('Xác nhận đã thu tiền'),
              ),
          ],
        ),
      ),
    );
  }
}
