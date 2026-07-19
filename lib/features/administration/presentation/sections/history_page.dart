part of '../admin_home_screen.dart';

class AdminHistoryPage extends StatefulWidget {
  const AdminHistoryPage({super.key});

  @override
  State<AdminHistoryPage> createState() => _AdminHistoryPageState();
}

class _AdminHistoryPageState extends State<AdminHistoryPage> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final payments = state.paidPayments.where((payment) {
      final range = _range;
      final paidAt = payment.paidAt;
      if (range == null || paidAt == null) return range == null;
      final end = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
      return !paidAt.isBefore(range.start) && !paidAt.isAfter(end);
    }).toList();
    final filteredRevenue = payments.fold<int>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final cashRevenue = payments
        .where((payment) => payment.method == PaymentMethod.cash)
        .fold<int>(0, (sum, payment) => sum + payment.amount);
    final qrRevenue = payments
        .where((payment) => payment.method == PaymentMethod.qr)
        .fold<int>(0, (sum, payment) => sum + payment.amount);
    final orders = state.orderHistory;
    final visibleOrders = orders.take(8).toList(growable: false);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          child: Column(
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.date_range),
                  title: Text(
                    _range == null
                        ? 'Tất cả thời gian'
                        : '${shortDate(_range!.start)} - ${shortDate(_range!.end)}',
                  ),
                  subtitle: Text(
                    '${payments.length} thanh toán · ${money(filteredRevenue)}',
                  ),
                  trailing: Wrap(
                    children: [
                      if (_range != null)
                        IconButton(
                          tooltip: 'Xóa bộ lọc',
                          onPressed: () => setState(() => _range = null),
                          icon: const Icon(Icons.filter_alt_off),
                        ),
                      IconButton(
                        tooltip: 'Chọn khoảng ngày',
                        onPressed: () => _pickDateRange(context),
                        icon: const Icon(Icons.edit_calendar),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                mainAxisExtent: 100,
                children: [
                  MetricCard(
                    title: 'Tổng doanh thu',
                    value: money(filteredRevenue),
                    icon: Icons.summarize_outlined,
                    color: AppColors.primary,
                  ),
                  MetricCard(
                    title: 'Giao dịch',
                    value: '${payments.length}',
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.info,
                  ),
                  MetricCard(
                    title: 'Tiền mặt',
                    value: money(cashRevenue),
                    icon: Icons.payments_outlined,
                    color: AppColors.success,
                  ),
                  MetricCard(
                    title: 'QR',
                    value: money(qrRevenue),
                    icon: Icons.qr_code_2,
                    color: AppColors.info,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionTitle(title: 'Lịch sử order'),
        if (orders.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Card(
              child: SizedBox(
                height: 180,
                child: EmptyState(
                  icon: Icons.receipt_long,
                  title: 'Chưa có order lịch sử',
                  message:
                      'Order đã thanh toán, hoàn tất hoặc hủy sẽ nằm ở đây.',
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Card(
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < visibleOrders.length;
                    index++
                  ) ...[
                    _OrderHistoryCard(order: visibleOrders[index]),
                    if (index < visibleOrders.length - 1) const Divider(),
                  ],
                ],
              ),
            ),
          ),
        SectionTitle(
          title: 'Lịch sử thanh toán',
          action: PopupMenuButton<String>(
            tooltip: 'Xuất báo cáo',
            icon: const Icon(Icons.file_download_outlined),
            onSelected: (value) async {
              if (value == 'copy_csv') {
                final csv = ReportService().buildRevenueCsv(
                  payments: payments,
                  orderById: state.orderById,
                  tableById: state.tableById,
                  userById: state.userById,
                );
                Clipboard.setData(ClipboardData(text: csv));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã copy báo cáo doanh thu CSV.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              if (value == 'share_excel') {
                try {
                  final exporter = ExportFileService();
                  final file = await exporter.createRevenueExcel(
                    payments: payments,
                    orderById: state.orderById,
                    tableById: state.tableById,
                    userById: state.userById,
                  );
                  await exporter.shareFile(
                    file: file,
                    title: 'Báo cáo doanh thu',
                    message: 'Báo cáo doanh thu Mini Order App',
                    mimeType:
                        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  );
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Không xuất được file Excel.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }

              if (value == 'share_pdf') {
                try {
                  final exporter = ExportFileService();
                  final file = await exporter.createRevenuePdf(
                    payments: payments,
                    orderById: state.orderById,
                    tableById: state.tableById,
                    userById: state.userById,
                    rangeLabel: _range == null
                        ? 'Tat ca thoi gian'
                        : '${shortDate(_range!.start)} - ${shortDate(_range!.end)}',
                  );
                  await exporter.shareFile(
                    file: file,
                    title: 'Báo cáo doanh thu PDF',
                    message: 'Báo cáo doanh thu Mini Order App',
                    mimeType: 'application/pdf',
                  );
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Không xuất được file PDF.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'copy_csv',
                child: ListTile(
                  leading: Icon(Icons.content_copy),
                  title: Text('Copy CSV'),
                ),
              ),
              PopupMenuItem(
                value: 'share_excel',
                child: ListTile(
                  leading: Icon(Icons.table_chart_outlined),
                  title: Text('Xuất Excel .xlsx'),
                ),
              ),
              PopupMenuItem(
                value: 'share_pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Xuất PDF'),
                ),
              ),
            ],
          ),
        ),
        if (payments.isEmpty)
          const SizedBox(
            height: 360,
            child: EmptyState(
              icon: Icons.history,
              title: 'Chưa có thanh toán',
              message: 'Thanh toán thành công sẽ được lưu ở đây.',
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Card(
              child: Column(
                children: [
                  for (var index = 0; index < payments.length; index++) ...[
                    _PaymentHistoryCard(payment: payments[index]),
                    if (index < payments.length - 1) const Divider(),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
      helpText: 'Chọn thời gian báo cáo',
    );
    if (selected != null && mounted) {
      setState(() => _range = selected);
    }
  }
}
