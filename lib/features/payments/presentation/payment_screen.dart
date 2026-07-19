import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config/payment_qr_config.dart';
import '../../../domain/models/app_models.dart';
import '../../../app/state/app_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

part 'payment/qr_payment_panel.dart';
part 'payment/cash_payment_panel.dart';

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
        unawaited(
          context.read<AppState>().createPayment(widget.orderId, _method),
        );
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
                  color: AppColors.danger,
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
                    : (values) async {
                        final value = values.first;
                        setState(() => _method = value);
                        await context.read<AppState>().createPayment(
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
                      ? () async {
                          await state.createPayment(order.id, PaymentMethod.qr);
                        }
                      : null,
                  onConfirm: visiblePayment == null || !canManage
                      ? null
                      : () async {
                          await state.confirmPayment(visiblePayment.id);
                        },
                )
              else
                _CashPaymentPanel(
                  order: order,
                  payment: visiblePayment,
                  onCreate: canManage
                      ? () async {
                          await state.createPayment(
                            order.id,
                            PaymentMethod.cash,
                          );
                        }
                      : null,
                  onConfirm: visiblePayment == null || !canManage
                      ? null
                      : () async {
                          await state.confirmPayment(visiblePayment.id);
                        },
                ),
            ],
          ),
        );
      },
    );
  }
}
