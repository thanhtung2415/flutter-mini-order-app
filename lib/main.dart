import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/app_models.dart';
import 'repositories/mock_order_repository.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/staff/staff_home_screen.dart';
import 'services/access_request_service.dart';
import 'services/authentication_service.dart';
import 'services/cart_draft_storage_service.dart';
import 'services/firestore_database_storage_service.dart';
import 'services/firestore_order_transaction_service.dart';
import 'services/local_database_storage_service.dart';
import 'services/user_administration_service.dart';
import 'state/app_state.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00796B),
          primary: const Color(0xFF00796B),
          secondary: const Color(0xFF6A1B9A),
          tertiary: const Color(0xFFF57C00),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF6F8FA),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE0E6EA)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD6DEE3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD6DEE3)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
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
