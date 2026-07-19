import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/firebase/firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'domain/models/app_models.dart';
import 'data/repositories/mock_order_repository.dart';
import 'features/administration/presentation/admin_home_screen.dart';
import 'features/authentication/presentation/login_screen.dart';
import 'features/staff/presentation/staff_home_screen.dart';
import 'features/access_control/data/access_request_service.dart';
import 'features/authentication/data/authentication_service.dart';
import 'features/ordering/data/cart_draft_storage_service.dart';
import 'data/storage/firestore_database_storage_service.dart';
import 'features/ordering/data/firestore_order_transaction_service.dart';
import 'data/storage/local_database_storage_service.dart';
import 'features/access_control/data/user_administration_service.dart';
import 'app/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final firebaseAuth = FirebaseAuth.instance;
  final firebaseFunctions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  final databaseStorage = SynchronizedDatabaseStorage(
    local: SharedPreferencesLocalDatabaseStorage(),
    remote: FirestoreDatabaseStorage(FirebaseFirestore.instance, firebaseAuth),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(
        MockOrderRepository(localDatabaseStorage: databaseStorage),
        authenticationService: FirebaseAuthenticationService(firebaseAuth),
        accessRequestService: FirebaseAccessRequestService(
          firebaseFunctions,
          FirebaseFirestore.instance,
        ),
        userAdministrationService: FirebaseUserAdministrationService(
          firebaseFunctions,
        ),
        orderTransactionService: FirestoreOrderTransactionService(
          FirebaseFirestore.instance,
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
      theme: AppTheme.light,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final requestedScale = mediaQuery.textScaler.scale(1);
        final clampedScale = requestedScale.clamp(0.9, 1.25).toDouble();
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(clampedScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Consumer<AppState>(
        builder: (context, state, _) {
          final user = state.currentUser;
          if (user == null) return const LoginScreen();
          return user.role == UserRole.admin
              ? const AdminHomeScreen()
              : const StaffHomeScreen();
        },
      ),
    );
  }
}
