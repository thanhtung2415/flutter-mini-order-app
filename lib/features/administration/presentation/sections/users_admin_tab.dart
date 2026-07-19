part of '../admin_home_screen.dart';

class UsersAdminTab extends StatelessWidget {
  const UsersAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reviewRequests = state.accessRequests
        .where((request) => request.status != AccessRequestStatus.approved)
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        if (reviewRequests.isNotEmpty) ...[
          SectionTitle(
            title: 'Yêu cầu truy cập (${state.pendingAccessRequestCount})',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Card(
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < reviewRequests.length;
                    index++
                  ) ...[
                    _AccessRequestTile(
                      request: reviewRequests[index],
                      onApprove: () => _showAccessRequestDialog(
                        context,
                        reviewRequests[index],
                      ),
                    ),
                    if (index < reviewRequests.length - 1) const Divider(),
                  ],
                ],
              ),
            ),
          ),
        ],
        SectionTitle(
          title: 'Tài khoản nhân viên',
          action: IconButton(
            tooltip: 'Thêm tài khoản',
            onPressed: () => _showUserDialog(context),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Card(
            child: Column(
              children: [
                for (var index = 0; index < state.users.length; index++) ...[
                  _UserListTile(
                    user: state.users[index],
                    onEdit: () =>
                        _showUserDialog(context, existing: state.users[index]),
                  ),
                  if (index < state.users.length - 1) const Divider(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAccessRequestDialog(
    BuildContext context,
    GoogleAccessRequest request,
  ) {
    var role = UserRole.staff;
    final shift = TextEditingController(text: 'Ca sáng');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Cấp quyền tài khoản Google'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(request.email),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: UserRole.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    role = value ?? role;
                    shift.text = role.isAdmin ? 'Cả ngày' : 'Ca sáng';
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: shift,
                decoration: const InputDecoration(labelText: 'Ca làm việc'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final saved = await context
                    .read<AppState>()
                    .reviewGoogleAccessRequest(
                      request: request,
                      approved: true,
                      role: role,
                      shift: shift.text,
                    );
                if (saved && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Cấp quyền'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDialog(BuildContext context, {AppUser? existing}) {
    final state = context.read<AppState>();
    final name = TextEditingController(text: existing?.fullName ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final code = TextEditingController(text: existing?.employeeCode ?? '');
    final shift = TextEditingController(text: existing?.shift ?? 'Ca sáng');
    final password = TextEditingController();
    var role = existing?.role ?? UserRole.staff;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Thêm tài khoản' : 'Sửa tài khoản',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Họ tên'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: email,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    if (existing == null) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu tạm (tối thiểu 6 ký tự)',
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: code,
                      decoration: const InputDecoration(
                        labelText: 'Mã nhân viên',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: shift,
                      decoration: const InputDecoration(
                        labelText: 'Ca làm việc',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<UserRole>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'Vai trò'),
                      items: UserRole.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => role = value ?? role),
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
                  onPressed: () async {
                    final now = DateTime.now();
                    final user = AppUser(
                      id: existing?.id ?? state.nextId('u'),
                      employeeCode: code.text.trim().isEmpty
                          ? 'NV${state.users.length + 1}'
                          : code.text.trim(),
                      fullName: name.text.trim(),
                      email: email.text.trim(),
                      phone: phone.text.trim(),
                      username: email.text.trim().split('@').first,
                      role: role,
                      shift: shift.text.trim(),
                      status: existing?.status ?? AccountStatus.active,
                      createdAt: existing?.createdAt ?? now,
                      updatedAt: now,
                    );
                    final saved = await state.upsertUser(
                      user,
                      temporaryPassword: existing == null
                          ? password.text
                          : null,
                    );
                    if (saved && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AccessRequestTile extends StatelessWidget {
  const _AccessRequestTile({required this.request, required this.onApprove});

  final GoogleAccessRequest request;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final name = request.fullName.trim().isEmpty
        ? request.email
        : request.fullName;
    final color = request.status == AccessRequestStatus.pending
        ? AppColors.warning
        : AppColors.danger;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        child: const Icon(Icons.login, size: 20),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${request.email}\n${request.status.label}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'approve') {
            onApprove();
          } else if (value == 'reject') {
            await context.read<AppState>().reviewGoogleAccessRequest(
              request: request,
              approved: false,
              role: UserRole.staff,
              shift: 'Ca sáng',
            );
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'approve', child: Text('Cấp quyền')),
          PopupMenuItem(value: 'reject', child: Text('Từ chối')),
        ],
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  const _UserListTile({required this.user, required this.onEdit});

  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final initials = user.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final isActive = user.status == AccountStatus.active;
    return ListTile(
      contentPadding: const EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.xxs,
      ),
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.primary,
        child: Text(initials.isEmpty ? '?' : initials),
      ),
      title: Text(user.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${user.role.label} · ${user.status.label}',
            style: AppTextStyles.caption.copyWith(
              color: isActive ? AppColors.success : AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'edit') {
            onEdit();
          } else if (value == 'lock') {
            await context.read<AppState>().toggleUserStatus(user);
          } else if (value == 'delete') {
            final confirmed = await showConfirmDialog(
              context: context,
              title: 'Xóa tài khoản?',
              message: 'Tài khoản ${user.fullName} sẽ bị xóa khỏi hệ thống.',
              confirmLabel: 'Xóa',
              destructive: true,
            );
            if (confirmed && context.mounted) {
              await context.read<AppState>().deleteUser(user.id);
            }
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Sửa')),
          PopupMenuItem(
            value: 'lock',
            child: Text(isActive ? 'Khóa' : 'Mở khóa'),
          ),
          const PopupMenuItem(value: 'delete', child: Text('Xóa')),
        ],
      ),
    );
  }
}
