part of '../admin_home_screen.dart';

class CategoriesAdminTab extends StatelessWidget {
  const CategoriesAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        SectionTitle(
          title: 'Danh mục món',
          action: IconButton.filled(
            tooltip: 'Thêm danh mục',
            onPressed: () => _showCategoryDialog(context),
            icon: const Icon(Icons.add),
          ),
        ),
        for (final category in state.categories)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.category)),
                title: Text(category.name),
                subtitle: Text(category.description),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showCategoryDialog(context, existing: category);
                    } else if (value == 'delete') {
                      final confirmed = await showConfirmDialog(
                        context: context,
                        title: 'Xóa danh mục?',
                        message:
                            'Các món thuộc danh mục này cần được chuyển danh mục khác sau đó.',
                        confirmLabel: 'Xóa',
                        destructive: true,
                      );
                      if (confirmed && context.mounted) {
                        context.read<AppState>().deleteCategory(category.id);
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

  void _showCategoryDialog(BuildContext context, {Category? existing}) {
    final state = context.read<AppState>();
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Thêm danh mục' : 'Sửa danh mục'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên danh mục'),
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
              final saved = state.upsertCategory(
                Category(
                  id: existing?.id ?? state.nextId('category'),
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
}
