import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/app_models.dart';
import '../../access_control/data/access_request_service.dart';
import '../../reporting/data/export_file_service.dart';
import '../../catalog/data/product_image_local_service.dart';
import '../../reporting/data/report_service.dart';
import '../../../app/state/app_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../staff/presentation/staff_home_screen.dart';
import 'order_invoice_sheet.dart';

part 'sections/dashboard_page.dart';
part 'sections/management_page.dart';
part 'sections/users_admin_tab.dart';
part 'sections/products_admin_tab.dart';
part 'sections/tables_admin_tab.dart';
part 'sections/categories_admin_tab.dart';
part 'sections/history_page.dart';
part 'sections/settings_admin_tab.dart';
part 'sections/history_cards.dart';

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
        final pageTitle = switch (_index) {
          1 => 'Quản lý',
          2 => 'Lịch sử',
          3 => 'Danh sách bàn',
          _ => 'Xin chào, ${state.currentUser?.fullName ?? 'Quản lý'}',
        };
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pageTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.screenTitle.copyWith(fontSize: 21),
                ),
                Text(
                  _index == 0
                      ? 'Hôm nay, ${shortDate(DateTime.now())}'
                      : state.currentUser?.role.label ?? '',
                  style: AppTextStyles.caption,
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
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: NavigationBar(
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
                  label: 'Bàn',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
