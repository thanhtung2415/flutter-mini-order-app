part of '../payment_screen.dart';

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
                  color: AppColors.successContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 48,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Thanh toán hoàn tất',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
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
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: AppColors.outline),
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
                  color: expired ? AppColors.danger : AppColors.success,
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
            color: AppColors.warningContainer,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.35),
            ),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryPressed),
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
