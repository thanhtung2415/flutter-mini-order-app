part of '../admin_home_screen.dart';

class AdminManagementPage extends StatelessWidget {
  const AdminManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Material(
            color: AppColors.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Người dùng'),
                Tab(text: 'Món & tồn'),
                Tab(text: 'Bàn'),
                Tab(text: 'Danh mục'),
                Tab(text: 'Cấu hình'),
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
