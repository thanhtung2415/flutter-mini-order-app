import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_models.dart';
import 'repositories/mock_order_repository.dart';
import 'screens/auth/login_screen.dart';
import 'services/cart_draft_storage_service.dart';
import 'services/local_database_storage_service.dart';
import 'state/app_state.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(
        MockOrderRepository(
          localDatabaseStorage: SharedPreferencesLocalDatabaseStorage(),
        ),
        cartDraftStorage: SharedPreferencesCartDraftStorage(),
      )..initialize(),
      child: const MiniOrderApp(),
    ),
  );
}

class MiniOrderApp extends StatelessWidget {
  const MiniOrderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Mini Order App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00796B),
          primary: const Color(0xFF00796B),
          secondary: const Color(0xFF6A1B9A),
          tertiary: const Color(0xFFF57C00),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
      ),
      home: Consumer<AppState>(
        builder: (context, state, _) {
          final user = state.currentUser;
          if (user == null) return const LoginScreen();
          return _SignedInPlaceholder(user: user);
        },
      ),
    );
  }
}

class _SignedInPlaceholder extends StatelessWidget {
  const _SignedInPlaceholder({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Mini Order App'),
        actions: [
          IconButton(
            tooltip: 'Dang xuat',
            onPressed: state.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                user.role == UserRole.admin
                    ? Icons.admin_panel_settings
                    : Icons.badge,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Dang nhap thanh cong',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text('${user.fullName} - ${user.role.label}'),
              const SizedBox(height: 8),
              Text(
                'Cac man hinh Staff va Admin se duoc merge tu nhanh cua thanh vien phu trach.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
