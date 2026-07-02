import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../services/report_service.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_widgets.dart';
import '../staff/staff_home_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      AdminDashboardPage(),
      AdminManagementPage(),
      AdminHistoryPage(),
      TablesPage(),
    ];

    return Consumer<AppState>(
      builder: (context, state, _) {
        showStateSnackBar(context, state);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Admin Dashboard'),
                Text(
                  state.currentUser?.fullName ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Đăng xuất',
                onPressed: state.logout,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: pages[_index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Tổng quan',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: 'Quản lý',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'Lịch sử',
              ),
              NavigationDestination(
                icon: Icon(Icons.table_restaurant_outlined),
                selectedIcon: Icon(Icons.table_restaurant),
                label: 'Order',
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final bestSeller = state.bestSeller;
        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;
                  final cards = [
                    MetricCard(
                      title: 'Doanh thu hôm nay',
                      value: money(state.todayRevenue),
                      icon: Icons.trending_up,
                      color: const Color(0xFF00796B),
                      subtitle:
                          '${state.todayPaidOrderCount} đơn đã thanh toán',
                    ),
                    MetricCard(
                      title: 'Doanh thu tháng này',
                      value: money(state.monthRevenue),
                      icon: Icons.calendar_month,
                      color: const Color(0xFF1565C0),
                      subtitle:
                          '${state.monthPaidOrderCount} đơn đã thanh toán',
                    ),
                    MetricCard(
                      title: 'Tiền mặt hôm nay',
                      value: money(state.todayCashRevenue),
                      icon: Icons.payments,
                      color: const Color(0xFF2E7D32),
                      subtitle: 'Phương thức cash',
                    ),
                    MetricCard(
                      title: 'QR hôm nay',
                      value: money(state.todayQrRevenue),
                      icon: Icons.qr_code_2,
                      color: const Color(0xFF00838F),
                      subtitle: 'Phương thức chuyển khoản',
                    ),
                    MetricCard(
                      title: 'Order đang phục vụ',
                      value: '${state.activeOrders.length}',
                      icon: Icons.receipt_long,
                      color: const Color(0xFFF57C00),
                      subtitle: '${state.delayedOrders.length} đơn quá 10 phút',
                    ),
                    MetricCard(
                      title: 'Tồn kho cảnh báo',
                      value: '${state.lowStockProducts.length}',
                      icon: Icons.inventory_2,
                      color: const Color(0xFFC62828),
                      subtitle: 'Ngưỡng cảnh báo dưới 5',
                    ),
                    MetricCard(
                      title: 'Món bán chạy',
                      value: bestSeller?.name ?? 'Chưa có',
                      icon: Icons.star,
                      color: const Color(0xFF6A1B9A),
                      subtitle: 'Theo order đã thanh toán',
                    ),
                  ];
                  if (isWide) {
                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: cards,
                    );
                  }
                  return Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: card,
                        ),
                    ],
                  );
                },
              ),
            ),
            if (state.delayedOrders.isNotEmpty) ...[
              const SectionTitle(title: 'Đơn cần xử lý'),
              for (final order in state.delayedOrders)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: OrderActionCard(order: order, showAdminActions: true),
                ),
            ],
            if (state.lowStockProducts.isNotEmpty) ...[
              const SectionTitle(title: 'Tồn kho thấp'),
              for (final product in state.lowStockProducts)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _AdminProductStockTile(product: product),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _AdminProductStockTile extends StatelessWidget {
  const _AdminProductStockTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ProductAvatar(product: product),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Tồn kho: ${product.stock} · Ngưỡng: ${product.warningThreshold}',
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Giảm tồn',
              onPressed: () => state.adjustStock(product.id, -1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              tooltip: 'Tăng tồn',
              onPressed: () => state.adjustStock(product.id, 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminManagementPage extends StatelessWidget {
  const AdminManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(icon: Icon(Icons.group), text: 'Người dùng'),
                Tab(icon: Icon(Icons.restaurant_menu), text: 'Món & tồn'),
                Tab(icon: Icon(Icons.table_bar), text: 'Bàn'),
                Tab(icon: Icon(Icons.category), text: 'Danh mục'),
                Tab(icon: Icon(Icons.settings), text: 'Cấu hình'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                UsersAdminTab(),
                ProductsAdminTab(),
                TablesAdminTab(),
                CategoriesAdminTab(),
                SettingsAdminTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UsersAdminTab extends StatelessWidget {
  const UsersAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        SectionTitle(
          title: 'Tài khoản nhân viên',
          action: IconButton.filled(
            tooltip: 'Thêm tài khoản',
            onPressed: () => _showUserDialog(context),
            icon: const Icon(Icons.add),
          ),
        ),
        for (final user in state.users)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    user.role.isAdmin
                        ? Icons.admin_panel_settings
                        : Icons.badge,
                  ),
                ),
                title: Text(user.fullName),
                subtitle: Text(
                  '${user.email} · ${user.role.label} · ${user.status.label}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showUserDialog(context, existing: user);
                    } else if (value == 'lock') {
                      context.read<AppState>().toggleUserStatus(user);
                    } else if (value == 'delete') {
                      final confirmed = await showConfirmDialog(
                        context: context,
                        title: 'Xóa tài khoản?',
                        message:
                            'Tài khoản ${user.fullName} sẽ bị xóa khỏi hệ thống.',
                        confirmLabel: 'Xóa',
                        destructive: true,
                      );
                      if (confirmed && context.mounted) {
                        context.read<AppState>().deleteUser(user.id);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                    PopupMenuItem(
                      value: 'lock',
                      child: Text(
                        user.status == AccountStatus.active
                            ? 'Khóa'
                            : 'Mở khóa',
                      ),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showUserDialog(BuildContext context, {AppUser? existing}) {
    final state = context.read<AppState>();
    final name = TextEditingController(text: existing?.fullName ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final code = TextEditingController(text: existing?.employeeCode ?? '');
    final shift = TextEditingController(text: existing?.shift ?? 'Ca sáng');
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
                  onPressed: () {
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
                    state.upsertUser(user);
                    Navigator.pop(context);
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

class ProductsAdminTab extends StatelessWidget {
  const ProductsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        SectionTitle(
          title: 'Món ăn và tồn kho',
          action: IconButton.filled(
            tooltip: 'Thêm món',
            onPressed: () => _showProductDialog(context),
            icon: const Icon(Icons.add),
          ),
        ),
        for (final product in state.products)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ProductAvatar(product: product),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${money(product.price)} · Tồn ${product.stock} · ${product.status.label}',
                          ),
                          Text(
                            state.categoryById(product.categoryId)?.name ??
                                'Chưa có danh mục',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Giảm tồn',
                      onPressed: () =>
                          context.read<AppState>().adjustStock(product.id, -1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'Tăng tồn',
                      onPressed: () =>
                          context.read<AppState>().adjustStock(product.id, 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          _showProductDialog(context, existing: product);
                        } else if (value == 'delete') {
                          final confirmed = await showConfirmDialog(
                            context: context,
                            title: 'Xóa món?',
                            message:
                                'Món ${product.name} sẽ không còn hiển thị trong menu.',
                            confirmLabel: 'Xóa',
                            destructive: true,
                          );
                          if (confirmed && context.mounted) {
                            context.read<AppState>().deleteProduct(product.id);
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Sửa')),
                        PopupMenuItem(value: 'delete', child: Text('Xóa')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showProductDialog(BuildContext context, {Product? existing}) {
    final state = context.read<AppState>();
    if (state.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần tạo ít nhất một danh mục trước khi thêm món.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(
      text: existing?.shortDescription ?? '',
    );
    final imageUrl = TextEditingController(text: existing?.imageUrl ?? '');
    final price = TextEditingController(text: '${existing?.price ?? 0}');
    final stock = TextEditingController(text: '${existing?.stock ?? 0}');
    final warning = TextEditingController(
      text: '${existing?.warningThreshold ?? 5}',
    );
    var categoryId = existing?.categoryId ?? state.categories.first.id;
    var status = existing?.status ?? ProductStatus.available;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Thêm món' : 'Sửa món'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Tên món'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả ngắn',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: imageUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Link ảnh món',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Giá'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tồn kho'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: warning,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ngưỡng cảnh báo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(labelText: 'Danh mục'),
                      items: state.categories
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(
                        () => categoryId = value ?? categoryId,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ProductStatus>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                      ),
                      items: ProductStatus.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => status = value ?? status),
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
                    final now = DateTime.now();
                    final product = Product(
                      id:
                          existing?.id ??
                          'P${DateTime.now().millisecondsSinceEpoch % 100000}',
                      name: name.text.trim(),
                      price: int.tryParse(price.text.trim()) ?? 0,
                      imageUrl: imageUrl.text.trim(),
                      shortDescription: description.text.trim(),
                      categoryId: categoryId,
                      stock: int.tryParse(stock.text.trim()) ?? 0,
                      warningThreshold: int.tryParse(warning.text.trim()) ?? 5,
                      status: status,
                      createdAt: existing?.createdAt ?? now,
                      updatedAt: now,
                    );
                    state.upsertProduct(product);
                    Navigator.pop(context);
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
              state.upsertArea(
                Area(
                  id: existing?.id ?? state.nextId('area'),
                  name: name.text.trim(),
                  description: description.text.trim(),
                ),
              );
              Navigator.pop(context);
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
                  state.upsertTable(
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
                  Navigator.pop(context);
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
              state.upsertCategory(
                Category(
                  id: existing?.id ?? state.nextId('category'),
                  name: name.text.trim(),
                  description: description.text.trim(),
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

class AdminHistoryPage extends StatelessWidget {
  const AdminHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final payments = state.paidPayments;
    final orders = state.orderHistory;
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              MetricCard(
                title: 'Doanh thu ngày ${shortDate(DateTime.now())}',
                value: money(state.todayRevenue),
                icon: Icons.summarize,
                color: const Color(0xFF00796B),
                subtitle: '${state.todayPaidOrderCount} thanh toán đã xác nhận',
              ),
              const SizedBox(height: 10),
              MetricCard(
                title: 'Doanh thu tháng này',
                value: money(state.monthRevenue),
                icon: Icons.calendar_month,
                color: const Color(0xFF1565C0),
                subtitle: '${state.monthPaidOrderCount} thanh toán đã xác nhận',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Tiền mặt',
                      value: money(state.todayCashRevenue),
                      icon: Icons.payments,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricCard(
                      title: 'QR',
                      value: money(state.todayQrRevenue),
                      icon: Icons.qr_code_2,
                      color: const Color(0xFF00838F),
                    ),
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
          for (final order in orders.take(8))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _OrderHistoryCard(order: order),
            ),
        SectionTitle(
          title: 'Lịch sử thanh toán',
          action: IconButton.filledTonal(
            tooltip: 'Xuất báo cáo',
            onPressed: () {
              final csv = ReportService().buildRevenueCsv(
                payments: state.paidPayments,
                orderById: state.orderById,
                tableById: state.tableById,
                userById: state.userById,
              );
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã copy báo cáo doanh thu CSV.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.file_download_outlined),
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
          for (final payment in payments)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _PaymentHistoryCard(payment: payment),
            ),
      ],
    );
  }
}

class SettingsAdminTab extends StatelessWidget {
  const SettingsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        const SectionTitle(title: 'Dữ liệu demo'),
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
                    'Backup local',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dữ liệu CRUD/order/payment được lưu local bằng SharedPreferences để demo không mất sau khi tắt app.',
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
                            'Toàn bộ thay đổi local sẽ được thay bằng dữ liệu demo ban đầu.',
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
              title: const Text('Sẵn sàng gắn Firebase'),
              subtitle: const Text(
                'OrderRepository đã tách interface; khi có Firebase config chỉ cần thay repository implementation.',
              ),
              trailing: StatusChip(
                label: 'MVVM',
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

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final table = state.tableById(order.tableId);
    final user = state.userById(order.userId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    table?.name ?? order.tableId,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusChip(
                  label: order.status.label,
                  color: orderStatusColor(order.status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Mã đơn: ${order.id}'),
            Text('Người tạo: ${user?.fullName ?? order.userId}'),
            Text('Cập nhật: ${dateTimeText(order.updatedAt)}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('${order.totalQuantity} món')),
                Text(
                  money(order.total),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final table = state.tableById(payment.tableId);
    final order = state.orderById(payment.orderId);
    final confirmer = payment.confirmedBy == null
        ? null
        : state.userById(payment.confirmedBy!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    table?.name ?? payment.tableId,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusChip(
                  label: payment.method.label,
                  color: payment.method == PaymentMethod.cash
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF1565C0),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Order: ${payment.orderId} · ${order?.totalQuantity ?? 0} món',
            ),
            Text(
              'Xác nhận: ${payment.paidAt == null ? '--' : dateTimeText(payment.paidAt!)}',
            ),
            Text('Người xác nhận: ${confirmer?.fullName ?? 'Không rõ'}'),
            const SizedBox(height: 10),
            Text(
              money(payment.amount),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
