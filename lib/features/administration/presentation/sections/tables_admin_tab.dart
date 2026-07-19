part of '../admin_home_screen.dart';

class TablesAdminTab extends StatelessWidget {
  const TablesAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        SectionTitle(
          title: 'Khu vực',
          action: IconButton.filled(
            tooltip: 'Thêm khu vực',
            onPressed: () => _showAreaDialog(context),
            icon: const Icon(Icons.add_location_alt),
          ),
        ),
        for (final area in state.areas)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.location_on)),
                title: Text(area.name),
                subtitle: Text(area.description),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showAreaDialog(context, existing: area);
                    } else if (value == 'delete') {
                      final confirmed = await showConfirmDialog(
                        context: context,
                        title: 'Xóa khu vực?',
                        message: 'Các bàn thuộc ${area.name} cũng sẽ bị xóa.',
                        confirmLabel: 'Xóa',
                        destructive: true,
                      );
                      if (confirmed && context.mounted) {
                        context.read<AppState>().deleteArea(area.id);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Sửa')),
                    PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
              ),
            ),
          ),
        SectionTitle(
          title: 'Bàn',
          action: IconButton.filled(
            tooltip: 'Thêm bàn',
            onPressed: () => _showTableDialog(context),
            icon: const Icon(Icons.add),
          ),
        ),
        for (final table in state.tables)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: tableStatusColor(
                    table.status,
                  ).withValues(alpha: 0.15),
                  child: Icon(
                    Icons.table_bar,
                    color: tableStatusColor(table.status),
                  ),
                ),
                title: Text(table.name),
                subtitle: Text(
                  '${state.areaById(table.areaId)?.name ?? 'Khu vực'} · ${table.capacity} khách',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showTableDialog(context, existing: table);
                    } else if (value == 'delete') {
                      final confirmed = await showConfirmDialog(
                        context: context,
                        title: 'Xóa bàn?',
                        message: 'Bàn ${table.name} sẽ bị xóa khỏi sơ đồ bàn.',
                        confirmLabel: 'Xóa',
                        destructive: true,
                      );
                      if (confirmed && context.mounted) {
                        context.read<AppState>().deleteTable(table.id);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Sửa')),
                    PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showAreaDialog(BuildContext context, {Area? existing}) {
    final state = context.read<AppState>();
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Thêm khu vực' : 'Sửa khu vực'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên khu vực'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final saved = state.upsertArea(
                Area(
                  id: existing?.id ?? state.nextId('area'),
                  name: name.text.trim(),
                  description: description.text.trim(),
                ),
              );
              if (saved) Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showTableDialog(BuildContext context, {RestaurantTable? existing}) {
    final state = context.read<AppState>();
    if (state.areas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần tạo ít nhất một khu vực trước khi thêm bàn.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final name = TextEditingController(text: existing?.name ?? '');
    final capacity = TextEditingController(text: '${existing?.capacity ?? 4}');
    final note = TextEditingController(text: existing?.note ?? '');
    var areaId = existing?.areaId ?? state.areas.first.id;
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'Thêm bàn' : 'Sửa bàn'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Tên bàn'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: capacity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Số khách'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'Ghi chú'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: areaId,
                    decoration: const InputDecoration(labelText: 'Khu vực'),
                    items: state.areas
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => areaId = value ?? areaId),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  final saved = state.upsertTable(
                    RestaurantTable(
                      id: existing?.id ?? state.nextId('table'),
                      name: name.text.trim(),
                      areaId: areaId,
                      status: existing?.status ?? TableStatus.available,
                      capacity: int.tryParse(capacity.text.trim()) ?? 4,
                      currentOrderId: existing?.currentOrderId,
                      note: note.text.trim(),
                    ),
                  );
                  if (saved) Navigator.pop(context);
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        );
      },
    );
  }
}
