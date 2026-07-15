import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/payment_qr_config.dart';
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
    final paid =
        order.status == OrderStatus.paid ||
        payment?.status == PaymentStatus.paid;
    if (paid) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 48,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Thanh toán hoàn tất',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                money(payment?.amount ?? order.total),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }
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
                  child: payment!.qrContent.startsWith('https://')
                      ? SizedBox(
                          width: 270,
                          child: AspectRatio(
                            aspectRatio: 540 / 640,
                            child: Image.network(
                              payment!.qrContent,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.cloud_off, size: 40),
                                        SizedBox(height: 8),
                                        Text(
                                          'Không tải được VietQR. Vui lòng kiểm tra mạng.',
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      : QrImageView(
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
              _TransferInformation(order: order, payment: payment!),
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
                      : onConfirm == null
                      ? null
                      : () async {
                          final confirmed = await showConfirmDialog(
                            context: context,
                            title: 'Xác nhận đã thanh toán?',
                            message:
                                'Chỉ xác nhận sau khi khách đã hoàn tất chuyển khoản.',
                            confirmLabel: 'Đã thanh toán',
                          );
                          if (confirmed) onConfirm!();
                        },
                  icon: const Icon(Icons.verified),
                  label: const Text('Đã thanh toán'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransferInformation extends StatelessWidget {
  const _TransferInformation({required this.order, required this.payment});

  final Order order;
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final content = PaymentQrConfig.transferContent(order.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFB74D)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Color(0xFFE65100)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tài khoản demo phục vụ thuyết trình. Không chuyển tiền thật.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _PaymentInfoRow(
          label: 'Ngân hàng',
          value: PaymentQrConfig.bankName,
        ),
        const _PaymentInfoRow(
          label: 'Số tài khoản',
          value: PaymentQrConfig.accountNumber,
        ),
        const _PaymentInfoRow(
          label: 'Chủ tài khoản',
          value: PaymentQrConfig.accountName,
        ),
        _PaymentInfoRow(label: 'Số tiền', value: money(payment.amount)),
        _PaymentInfoRow(label: 'Nội dung', value: content),
      ],
    );
  }
}

class _PaymentInfoRow extends StatelessWidget {
  const _PaymentInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
