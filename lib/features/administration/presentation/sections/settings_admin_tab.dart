part of '../admin_home_screen.dart';

class SettingsAdminTab extends StatelessWidget {
  const SettingsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        const SectionTitle(title: 'Dữ liệu hệ thống'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SettingsCountRow(
                    label: 'Người dùng',
                    value: state.users.length,
                  ),
                  _SettingsCountRow(
                    label: 'Khu vực',
                    value: state.areas.length,
                  ),
                  _SettingsCountRow(label: 'Bàn', value: state.tables.length),
                  _SettingsCountRow(
                    label: 'Danh mục',
                    value: state.categories.length,
                  ),
                  _SettingsCountRow(label: 'Món', value: state.products.length),
                  _SettingsCountRow(label: 'Order', value: state.orders.length),
                  _SettingsCountRow(
                    label: 'Thanh toán',
                    value: state.payments.length,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Backup dữ liệu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dữ liệu được lưu local để dùng ổn định và đồng bộ lên Firestore sau khi đăng nhập Firebase.',
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      final backup = state.exportBackupJson();
                      if (backup == null) return;
                      Clipboard.setData(ClipboardData(text: backup));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã copy backup JSON.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Copy backup JSON'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context: context,
                        title: 'Reset dữ liệu mẫu?',
                        message:
                            'Dữ liệu local và Firestore sẽ được thay bằng dữ liệu mẫu ban đầu.',
                        confirmLabel: 'Reset',
                        destructive: true,
                      );
                      if (confirmed && context.mounted) {
                        await context.read<AppState>().resetDemoData();
                      }
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset dữ liệu mẫu'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.cloud_queue)),
              title: const Text('Firebase Authentication + Firestore'),
              subtitle: const Text(
                'Firebase xác thực tài khoản; Firestore đồng bộ dữ liệu và SharedPreferences hỗ trợ local-first.',
              ),
              trailing: StatusChip(
                label: 'Local + Cloud',
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsCountRow extends StatelessWidget {
  const _SettingsCountRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
