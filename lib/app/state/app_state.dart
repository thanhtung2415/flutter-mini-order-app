import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../../core/config/payment_qr_config.dart';
import '../../domain/models/app_models.dart';
import '../../domain/repositories/order_repository.dart';
import '../../features/access_control/data/access_request_service.dart';
import '../../features/authentication/data/authentication_service.dart';
import '../../features/ordering/data/cart_draft_storage_service.dart';
import '../../features/ordering/data/firestore_order_transaction_service.dart';
import '../../features/access_control/data/user_administration_service.dart';

part 'modules/order_state.dart';
part 'modules/payment_state.dart';
part 'modules/admin_state.dart';

class AppState extends ChangeNotifier {
  AppState(
    this.repository, {
    required this.authenticationService,
    this.cartDraftStorage,
    this.accessRequestService,
    this.userAdministrationService,
    this.orderTransactionService,
  });

  final OrderRepository repository;
  final AuthenticationService authenticationService;
  final CartDraftStorage? cartDraftStorage;
  final AccessRequestService? accessRequestService;
  final UserAdministrationService? userAdministrationService;
  final OrderTransactionService? orderTransactionService;

  AppUser? _currentUser;
  String _selectedAreaId = 'all';
  String _selectedCategoryId = 'all';
  String _menuSearch = '';
  String? _selectedTableId;
  String? _message;
  String? _error;
  bool _draftLoaded = false;
  int _idCounter = 0;
  final Map<String, OrderItem> _cart = {};
  final List<GoogleAccessRequest> _accessRequests = [];
  StreamSubscription<List<GoogleAccessRequest>>? _accessRequestSubscription;
  StreamSubscription<void>? _realtimeSubscription;
  bool _realtimeSyncing = false;
  bool _realtimeRefreshPending = false;

  AppUser? get currentUser => _currentUser;
  String get selectedAreaId => _selectedAreaId;
  String get selectedCategoryId => _selectedCategoryId;
  String get menuSearch => _menuSearch;
  String? get selectedTableId => _selectedTableId;
  String? get message => _message;
  String? get error => _error;
  bool get draftLoaded => _draftLoaded;

  bool get isAdmin => _currentUser?.role.isAdmin ?? false;
  bool get isLoggedIn => _currentUser != null;

  List<AppUser> get users => repository.users;
  List<Area> get areas =>
      repository.areas.where((area) => area.visible).toList();
  List<RestaurantTable> get tables => repository.tables;
  List<Category> get categories =>
      repository.categories.where((category) => category.visible).toList();
  List<Product> get products => repository.products;
  List<Order> get orders => repository.orders;
  List<Payment> get payments => repository.payments;
  List<GoogleAccessRequest> get accessRequests =>
      List.unmodifiable(_accessRequests);
  int get pendingAccessRequestCount => _accessRequests
      .where((request) => request.status == AccessRequestStatus.pending)
      .length;
  List<OrderItem> get cartItems => _cart.values.toList();

  int get cartTotal => cartItems.fold(0, (sum, item) => sum + item.total);

  RestaurantTable? get selectedTable {
    final tableId = _selectedTableId;
    if (tableId == null) return null;
    return repository.findTable(tableId);
  }

  List<RestaurantTable> get filteredTables {
    final source = _selectedAreaId == 'all'
        ? repository.tables
        : repository.tables.where((table) => table.areaId == _selectedAreaId);
    return source.toList()..sort((a, b) {
      final areaCompare = a.areaId.compareTo(b.areaId);
      if (areaCompare != 0) return areaCompare;
      return a.name.compareTo(b.name);
    });
  }

  List<RestaurantTable> availableTablesForTransfer(String currentTableId) {
    return repository.tables
        .where(
          (table) =>
              table.id != currentTableId &&
              table.status == TableStatus.available &&
              table.currentOrderId == null,
        )
        .toList()
      ..sort((a, b) {
        final areaCompare = a.areaId.compareTo(b.areaId);
        if (areaCompare != 0) return areaCompare;
        return a.name.compareTo(b.name);
      });
  }

  List<Product> get filteredProducts {
    final normalizedSearch = _menuSearch.trim().toLowerCase();
    return repository.products.where((product) {
      if (product.status == ProductStatus.hidden) return false;
      final matchesCategory =
          _selectedCategoryId == 'all' ||
          product.categoryId == _selectedCategoryId;
      final matchesSearch =
          normalizedSearch.isEmpty ||
          product.name.toLowerCase().contains(normalizedSearch);
      return matchesCategory && matchesSearch;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<Product> get lowStockProducts =>
      repository.products
          .where((product) => product.isLowStock || product.stock == 0)
          .toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));

  List<Order> get activeOrders =>
      repository.orders.where((order) => order.isActive).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Order> get delayedOrders =>
      activeOrders.where((order) => order.isDelayed).toList();

  List<Order> get paidOrders =>
      repository.orders
          .where((order) => order.status == OrderStatus.paid)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<Order> get orderHistory =>
      repository.orders
          .where(
            (order) =>
                order.status == OrderStatus.paid ||
                order.status == OrderStatus.cancelled ||
                order.status == OrderStatus.completed,
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<Payment> get paidPayments =>
      repository.payments
          .where((payment) => payment.status == PaymentStatus.paid)
          .toList()
        ..sort((a, b) {
          final aPaidAt = a.paidAt ?? a.createdAt;
          final bPaidAt = b.paidAt ?? b.createdAt;
          return bPaidAt.compareTo(aPaidAt);
        });

  int get todayRevenue => repository.revenueForDay(DateTime.now());

  int get monthRevenue {
    final now = DateTime.now();
    return paidPayments
        .where((payment) {
          final paidAt = payment.paidAt;
          return paidAt != null &&
              paidAt.year == now.year &&
              paidAt.month == now.month;
        })
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  int get todayCashRevenue => _revenueForTodayByMethod(PaymentMethod.cash);

  int get todayQrRevenue => _revenueForTodayByMethod(PaymentMethod.qr);

  int get todayPaidOrderCount {
    final now = DateTime.now();
    return paidPayments.where((payment) {
      final paidAt = payment.paidAt;
      return paidAt != null &&
          paidAt.year == now.year &&
          paidAt.month == now.month &&
          paidAt.day == now.day;
    }).length;
  }

  int get monthPaidOrderCount {
    final now = DateTime.now();
    return paidPayments.where((payment) {
      final paidAt = payment.paidAt;
      return paidAt != null &&
          paidAt.year == now.year &&
          paidAt.month == now.month;
    }).length;
  }

  Product? get bestSeller {
    final sold = repository.soldQuantities();
    if (sold.isEmpty) return null;
    final entries = sold.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return repository.findProduct(entries.first.key);
  }

  bool canManageOrder(Order order) {
    final user = _currentUser;
    if (user == null) return false;
    return user.role.isAdmin || order.userId == user.id;
  }

  int _revenueForTodayByMethod(PaymentMethod method) {
    final now = DateTime.now();
    return paidPayments
        .where((payment) {
          final paidAt = payment.paidAt;
          return payment.method == method &&
              paidAt != null &&
              paidAt.year == now.year &&
              paidAt.month == now.month &&
              paidAt.day == now.day;
        })
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  String nextId(String prefix) {
    _idCounter += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  Future<void> initialize() async {
    await restoreRepositoryData();
    await restoreCartDraft();
  }

  Future<void> restoreRepositoryData() async {
    final repo = repository;
    if (repo is! PersistentOrderRepository) return;
    await repo.restoreSavedData();
    notifyListeners();
  }

  Future<void> restoreCartDraft() async {
    final storage = cartDraftStorage;
    if (storage == null || _draftLoaded) return;
    _draftLoaded = true;

    final draft = await storage.loadDraft();
    if (draft == null) return;

    final table = repository.findTable(draft.tableId);
    if (table == null || repository.activeOrderForTable(table.id) != null) {
      await storage.clearDraft();
      return;
    }

    final restoredItems = <String, OrderItem>{};
    for (final item in draft.items) {
      final product = repository.findProduct(item.productId);
      if (product == null || !product.canOrder) continue;
      final quantity = item.quantity.clamp(1, product.stock).toInt();
      restoredItems[product.id] = OrderItem(
        id: 'draft_${product.id}',
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        unitPrice: product.price,
        note: item.note,
      );
    }

    if (restoredItems.isEmpty) {
      await storage.clearDraft();
      return;
    }

    _selectedTableId = table.id;
    _cart
      ..clear()
      ..addAll(restoredItems);
    _message = 'Đã khôi phục giỏ hàng tạm cho ${table.name}.';
    _error = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      _setError('Vui lòng nhập email và mật khẩu.');
      return false;
    }

    AuthenticatedIdentity identity;
    try {
      identity = await authenticationService.signIn(
        email: email.trim(),
        password: password,
      );
    } on AuthenticationFailure catch (error) {
      if (!_canUseOfflineDemo(email, password, error.code)) {
        _setError(error.message);
        return false;
      }
      final user = repository.findUserByEmail(email);
      if (user == null || user.status == AccountStatus.locked) {
        _setError('Tài khoản demo chưa được cấp quyền hoặc đã bị khóa.');
        return false;
      }
      _currentUser = user;
      _message = 'Firebase tạm thời không phản hồi. Đã vào chế độ demo local.';
      _error = null;
      notifyListeners();
      return true;
    }

    try {
      await restoreRepositoryData().timeout(const Duration(seconds: 8));
    } catch (_) {
      // The local snapshot remains available if Firestore is temporarily slow.
    }
    final user = repository.findUserByEmail(identity.email);
    if (user == null || user.id != identity.uid) {
      await authenticationService.signOut();
      _setError(
        'Tài khoản chưa được Admin cấp quyền hoặc hồ sơ chưa khớp UID.',
      );
      return false;
    }
    if (user.status == AccountStatus.locked) {
      await authenticationService.signOut();
      _setError('Tài khoản đã bị khóa.');
      return false;
    }

    _currentUser = user;
    _startAccessRequestWatch();
    _startRealtimeSync();
    _message = 'Đăng nhập Firebase thành công.';
    _error = null;
    notifyListeners();
    return true;
  }

  Future<bool> loginWithGoogle() async {
    AuthenticatedIdentity identity;
    try {
      identity = await authenticationService.signInWithGoogle();
    } on AuthenticationFailure catch (error) {
      _setError(error.message);
      return false;
    }

    try {
      await restoreRepositoryData().timeout(const Duration(seconds: 8));
    } catch (_) {
      // The local snapshot can still identify an already provisioned account.
    }

    final user = repository.findUserByEmail(identity.email);
    if (user == null || user.id != identity.uid) {
      AccessRequestStatus status = AccessRequestStatus.pending;
      String? requestError;
      final service = accessRequestService;
      if (service != null) {
        try {
          status = await service.requestGoogleAccess();
        } on AccessRequestFailure catch (error) {
          requestError = error.message;
        }
      }
      await authenticationService.signOut();
      if (requestError != null) {
        _setError(requestError);
      } else if (status == AccessRequestStatus.rejected) {
        _setError(
          'Yêu cầu truy cập Google đã bị Admin từ chối. Vui lòng liên hệ Admin.',
        );
      } else if (status == AccessRequestStatus.approved) {
        _setError(
          'Tài khoản đã được Admin cấp quyền. Vui lòng đăng nhập lại để tải hồ sơ mới.',
        );
      } else {
        _setError(
          'Tài khoản Google chưa được cấp quyền. Yêu cầu đã gửi và đang chờ Admin duyệt.',
        );
      }
      return false;
    }
    if (user.status == AccountStatus.locked) {
      await authenticationService.signOut();
      _setError('Tài khoản đã bị khóa.');
      return false;
    }

    _currentUser = user;
    _startAccessRequestWatch();
    _startRealtimeSync();
    _message = 'Đăng nhập Google thành công.';
    _error = null;
    notifyListeners();
    return true;
  }

  Future<bool> requestPasswordReset(String email) async {
    final normalizedEmail = email.trim();
    final emailParts = normalizedEmail.split('@');
    if (emailParts.length != 2 ||
        emailParts.first.isEmpty ||
        !emailParts.last.contains('.')) {
      _setError('Vui lòng nhập email hợp lệ.');
      return false;
    }

    try {
      await authenticationService.sendPasswordResetEmail(
        email: normalizedEmail,
      );
    } on AuthenticationFailure catch (error) {
      if (error.code != 'user-not-found') {
        _setError(error.message);
        return false;
      }
    }

    _message = 'Nếu email tồn tại, Firebase đã gửi hướng dẫn đặt lại mật khẩu.';
    _error = null;
    notifyListeners();
    return true;
  }

  void logout() {
    _accessRequestSubscription?.cancel();
    _accessRequestSubscription = null;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtimeRefreshPending = false;
    _accessRequests.clear();
    unawaited(authenticationService.signOut());
    _currentUser = null;
    _selectedTableId = null;
    _selectedAreaId = 'all';
    _selectedCategoryId = 'all';
    _menuSearch = '';
    _cart.clear();
    _clearCartDraft();
    notifyListeners();
  }

  void consumeMessages() {
    _message = null;
    _error = null;
  }

  void _startAccessRequestWatch() {
    unawaited(_accessRequestSubscription?.cancel());
    _accessRequestSubscription = null;
    _accessRequests.clear();
    final service = accessRequestService;
    if (!isAdmin || service == null) return;

    _accessRequestSubscription = service.watchRequests().listen(
      (requests) {
        _accessRequests
          ..clear()
          ..addAll(requests);
        notifyListeners();
      },
      onError: (_) {
        // Account administration remains usable if the live request list is
        // temporarily unavailable.
      },
    );
  }

  void _startRealtimeSync() {
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;
    _realtimeRefreshPending = false;
    final persistentRepository = repository;
    if (_currentUser == null ||
        persistentRepository is! PersistentOrderRepository) {
      return;
    }
    final changes = persistentRepository.watchRemoteChanges();
    if (changes == null) return;
    _realtimeSubscription = changes.listen(
      (_) => _scheduleRealtimeSync(),
      onError: (_) {
        // Firestore's local cache remains available during short disconnects.
      },
    );
  }

  void _scheduleRealtimeSync() {
    if (_currentUser == null) return;
    if (_realtimeSyncing) {
      _realtimeRefreshPending = true;
      return;
    }
    unawaited(_synchronizeRealtime());
  }

  Future<void> _synchronizeRealtime() async {
    if (_currentUser == null) return;
    if (_realtimeSyncing) {
      _realtimeRefreshPending = true;
      return;
    }
    final persistentRepository = repository;
    if (persistentRepository is! PersistentOrderRepository) return;
    _realtimeSyncing = true;
    try {
      do {
        _realtimeRefreshPending = false;
        final currentUid = _currentUser!.id;
        await persistentRepository.restoreSavedData();
        final refreshedUser = repository.users
            .where((user) => user.id == currentUid)
            .firstOrNull;
        if (refreshedUser == null ||
            refreshedUser.status == AccountStatus.locked) {
          _currentUser = null;
          _selectedTableId = null;
          _cart.clear();
          _accessRequests.clear();
          _realtimeRefreshPending = false;
          unawaited(_accessRequestSubscription?.cancel());
          _accessRequestSubscription = null;
          unawaited(_realtimeSubscription?.cancel());
          _realtimeSubscription = null;
          await authenticationService.signOut();
          _error = refreshedUser == null
              ? 'Tài khoản không còn được cấp quyền truy cập.'
              : 'Tài khoản vừa bị Admin khóa.';
          _message = null;
        } else {
          _currentUser = refreshedUser;
          _reconcileCartWithStock();
        }
        notifyListeners();
      } while (_realtimeRefreshPending && _currentUser != null);
    } catch (_) {
      // Keep the latest local snapshot and retry on the next remote event.
    } finally {
      _realtimeSyncing = false;
      if (_realtimeRefreshPending && _currentUser != null) {
        _scheduleRealtimeSync();
      }
    }
  }

  Future<bool> reviewGoogleAccessRequest({
    required GoogleAccessRequest request,
    required bool approved,
    required UserRole role,
    required String shift,
  }) async {
    if (!_requireAdmin()) return false;
    final service = accessRequestService;
    if (service == null) {
      _setError('Dịch vụ duyệt tài khoản Google chưa được cấu hình.');
      return false;
    }
    try {
      await service.reviewRequest(
        uid: request.uid,
        approved: approved,
        role: role,
        shift: shift,
      );
      if (approved) {
        await restoreRepositoryData();
      }
      _message = approved
          ? 'Đã cấp quyền ${role.label} cho ${request.email}.'
          : 'Đã từ chối yêu cầu của ${request.email}.';
      _error = null;
      notifyListeners();
      return true;
    } on AccessRequestFailure catch (error) {
      _setError(error.message);
      return false;
    }
  }

  @override
  void dispose() {
    unawaited(_accessRequestSubscription?.cancel());
    unawaited(_realtimeSubscription?.cancel());
    super.dispose();
  }

  String? exportBackupJson() {
    if (!_requireAdmin()) return null;
    final repo = repository;
    if (repo is! PersistentOrderRepository) {
      _setError('Repository hiện tại không hỗ trợ backup local.');
      return null;
    }
    return repo.exportBackupJson();
  }

  Future<bool> resetDemoData() async {
    if (!_requireAdmin()) return false;
    final repo = repository;
    if (repo is! PersistentOrderRepository) {
      _setError('Repository hiện tại không hỗ trợ reset dữ liệu mẫu.');
      return false;
    }
    await repo.resetToSeedData();
    _selectedAreaId = 'all';
    _selectedCategoryId = 'all';
    _menuSearch = '';
    _selectedTableId = null;
    _cart.clear();
    _clearCartDraft();
    _message = 'Đã khôi phục dữ liệu mẫu.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool _requireAdmin() {
    if (!isAdmin) {
      _setError('Bạn không có quyền truy cập chức năng Admin.');
      return false;
    }
    return true;
  }

  void _setError(String value) {
    _error = value;
    _message = null;
    notifyListeners();
  }

  void _notify() => notifyListeners();

  T _mutateAfterRemoteCommit<T>(bool remoteCommitted, T Function() mutation) {
    final persistentRepository = repository;
    if (remoteCommitted && persistentRepository is PersistentOrderRepository) {
      return persistentRepository.mutateWithoutPersistence(mutation);
    }
    return mutation();
  }

  void _persistCartDraft() {
    final storage = cartDraftStorage;
    final tableId = _selectedTableId;
    if (storage == null || tableId == null) return;
    if (_cart.isEmpty) {
      unawaited(storage.clearDraft());
      return;
    }
    unawaited(storage.saveDraft(CartDraft(tableId: tableId, items: cartItems)));
  }

  bool _reconcileCartWithStock() {
    var changed = false;
    for (final entry in _cart.entries.toList(growable: false)) {
      final product = repository.findProduct(entry.key);
      final availableStock = product?.canOrder == true ? product!.stock : 0;
      if (availableStock <= 0) {
        _cart.remove(entry.key);
        changed = true;
      } else if (entry.value.quantity > availableStock) {
        _cart[entry.key] = entry.value.copyWith(quantity: availableStock);
        changed = true;
      }
    }
    if (changed) {
      _persistCartDraft();
    }
    return changed;
  }

  void _clearCartDraft() {
    final storage = cartDraftStorage;
    if (storage == null) return;
    unawaited(storage.clearDraft());
  }

  void _expireWaitingPayments(String orderId) {
    for (final payment in repository.payments.where(
      (payment) =>
          payment.orderId == orderId && payment.status == PaymentStatus.waiting,
    )) {
      repository.updatePayment(payment.copyWith(status: PaymentStatus.expired));
    }
  }

  bool _canUseOfflineDemo(String email, String password, String? errorCode) {
    // Demo credentials are a development aid only. A release build must
    // always authenticate against Firebase, even when the device is offline.
    if (kReleaseMode) return false;

    if (errorCode != 'network-timeout' &&
        errorCode != 'network-request-failed') {
      return false;
    }
    final normalizedEmail = email.trim().toLowerCase();
    return password == '123456' &&
        (normalizedEmail == 'admin@miniorder.vn' ||
            normalizedEmail == 'staff@miniorder.vn');
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
