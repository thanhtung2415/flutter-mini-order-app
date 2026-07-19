import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/app_models.dart';
import '../../../app/state/app_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../ordering/presentation/kitchen_preview_screen.dart';
import '../../ordering/presentation/order_screen.dart';
import '../../payments/presentation/payment_screen.dart';

part 'home/tables_page.dart';
part 'home/active_orders_page.dart';
part 'home/alerts_page.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [TablesPage(), ActiveOrdersPage(), AlertsPage()];

    return Consumer<AppState>(
      builder: (context, state, _) {
        showStateSnackBar(context, state);
        final title = switch (_index) {
          1 => 'Đơn đang phục vụ',
          2 => 'Cảnh báo',
          _ => 'Danh sách bàn',
        };
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 68,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mini Order',
                  style: AppTextStyles.screenTitle.copyWith(fontSize: 21),
                ),
                Text(
                  '$title · ${state.currentUser?.fullName ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Đăng xuất',
                onPressed: state.logout,
                icon: const Icon(Icons.logout, color: AppColors.primary),
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
                  icon: Icon(Icons.table_restaurant_outlined),
                  selectedIcon: Icon(Icons.table_restaurant),
                  label: 'Bàn',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Đơn',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_none),
                  selectedIcon: Icon(Icons.notifications),
                  label: 'Cảnh báo',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
