part of '../staff_home_screen.dart';

class TablesPage extends StatelessWidget {
  const TablesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final tables = state.filteredTables;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  0,
                ),
                child: _AreaFilter(state: state),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: _TableSummary(state: state),
              ),
            ),
            if (tables.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.table_restaurant_outlined,
                  title: 'Không có bàn trong khu vực này',
                  message: 'Hãy chọn khu vực khác để tiếp tục.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final count = width >= 900
                        ? 4
                        : width >= 640
                        ? 3
                        : width < 340
                        ? 1
                        : 2;
                    return SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _TableCard(table: tables[index]),
                        childCount: tables.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.sm,
                        mainAxisExtent: count == 1 ? 140 : 156,
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AreaFilter extends StatelessWidget {
  const _AreaFilter({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: const Text('Tất cả'),
              selected: state.selectedAreaId == 'all',
              onSelected: (_) => state.selectArea('all'),
            ),
          ),
          for (final area in state.areas)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(area.name),
                selected: state.selectedAreaId == area.id,
                onSelected: (_) => state.selectArea(area.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableSummary extends StatelessWidget {
  const _TableSummary({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final values = [
      (
        label: 'Trống',
        value: state.tables
            .where((table) => table.status == TableStatus.available)
            .length,
        color: AppColors.success,
      ),
      (
        label: 'Phục vụ',
        value: state.tables
            .where((table) => table.status == TableStatus.ordering)
            .length,
        color: AppColors.warning,
      ),
      (
        label: 'Đã trả',
        value: state.tables
            .where((table) => table.status == TableStatus.paid)
            .length,
        color: AppColors.info,
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < values.length; index++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${values[index].value}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: values[index].color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    values[index].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ),
          if (index < values.length - 1) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table});

  final RestaurantTable table;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final order = state.orderForTable(table.id);
    final area = state.areaById(table.areaId);
    final statusColor = order?.isDelayed == true
        ? AppColors.danger
        : tableStatusColor(table.status);
    final time = order == null
        ? null
        : '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _handleTap(context, state, order),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: statusColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            table.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.sectionTitle,
                          ),
                        ),
                        Text(
                          order?.isDelayed == true
                              ? 'Quá 10 phút'
                              : table.status.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${area?.name ?? 'Khu vực'} · ${table.capacity} khách',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                    const Spacer(),
                    if (order == null)
                      Text(
                        'Sẵn sàng',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.success,
                        ),
                      )
                    else ...[
                      Text(
                        '${order.totalQuantity} món · $time',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        money(order.total),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    AppState state,
    Order? order,
  ) async {
    if (table.status == TableStatus.paid) {
      final confirmed = await showConfirmDialog(
        context: context,
        title: 'Dọn ${table.name}?',
        message: 'Sau khi dọn bàn, trạng thái bàn sẽ chuyển về trống.',
        confirmLabel: 'Dọn bàn',
      );
      if (confirmed && context.mounted) {
        await state.clearTable(table.id);
      }
      return;
    }
    state.selectTable(table.id);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderScreen(tableId: table.id)),
    );
  }
}
