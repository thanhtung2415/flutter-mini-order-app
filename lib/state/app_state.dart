import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../config/payment_qr_config.dart';
import '../models/app_models.dart';
import '../repositories/order_repository.dart';
import '../services/access_request_service.dart';
import '../services/authentication_service.dart';
import '../services/cart_draft_storage_service.dart';
import '../services/firestore_order_transaction_service.dart';
import '../services/user_administration_service.dart';

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
    final persistentRepository = repository;
    if (_currentUser == null ||
        persistentRepository is! PersistentOrderRepository) {
      return;
    }
    final changes = persistentRepository.watchRemoteChanges();
    if (changes == null) return;
    _realtimeSubscription = changes.listen(
      (_) => unawaited(_synchronizeRealtime()),
      onError: (_) {
        // Firestore's local cache remains available during short disconnects.
      },
    );
  }

  Future<void> _synchronizeRealtime() async {
    if (_realtimeSyncing || _currentUser == null) return;
    final persistentRepository = repository;
    if (persistentRepository is! PersistentOrderRepository) return;
    _realtimeSyncing = true;
    try {
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
    } catch (_) {
      // Keep the latest local snapshot and retry on the next remote event.
    } finally {
      _realtimeSyncing = false;
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

  void selectArea(String areaId) {
    _selectedAreaId = areaId;
    notifyListeners();
  }

  void selectCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void searchMenu(String value) {
    _menuSearch = value;
    notifyListeners();
  }

  void selectTable(String tableId) {
    if (_selectedTableId != tableId) {
      _cart.clear();
      _clearCartDraft();
    }
    _selectedTableId = tableId;
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _clearCartDraft();
    notifyListeners();
  }

  bool addToCart(Product product) {
    if (!product.canOrder) {
      return false;
    }

    final currentQuantity = _cart[product.id]?.quantity ?? 0;
    if (currentQuantity + 1 > product.stock) {
      return false;
    }

    _cart[product.id] = OrderItem(
      id: 'draft_${product.id}',
      productId: product.id,
      productName: product.name,
      quantity: currentQuantity + 1,
      unitPrice: product.price,
      note: _cart[product.id]?.note ?? '',
    );
    _persistCartDraft();
    notifyListeners();
    return true;
  }

  void increaseCartItem(String productId) {
    final product = repository.findProduct(productId);
    if (product == null) return;
    addToCart(product);
  }

  void decreaseCartItem(String productId) {
    final item = _cart[productId];
    if (item == null) return;
    if (item.quantity <= 1) {
      _cart.remove(productId);
    } else {
      _cart[productId] = item.copyWith(quantity: item.quantity - 1);
    }
    _persistCartDraft();
    notifyListeners();
  }

  void removeCartItem(String productId) {
    _cart.remove(productId);
    _persistCartDraft();
    notifyListeners();
  }

  void updateCartItemNote(String productId, String note) {
    final item = _cart[productId];
    if (item == null) return;

    _cart[productId] = item.copyWith(note: note.trim());
    _persistCartDraft();
    notifyListeners();
  }

  Future<Order?> confirmOrder(String note) async {
    final user = _currentUser;
    final table = selectedTable;
    if (user == null || table == null) {
      _setError('Bạn cần đăng nhập và chọn bàn trước khi tạo order.');
      return null;
    }

    final activeOrder = repository.activeOrderForTable(table.id);
    if (activeOrder != null && !canManageOrder(activeOrder)) {
      _setError('Bạn chỉ được thêm món vào order mình đang phục vụ.');
      return null;
    }

    if (_cart.isEmpty) {
      _setError('Giỏ hàng đang trống.');
      return null;
    }

    if (_reconcileCartWithStock()) {
      _error = null;
      _message = null;
      notifyListeners();
      return null;
    }

    for (final item in cartItems) {
      final product = repository.findProduct(item.productId);
      if (product == null ||
          !product.canOrder ||
          product.stock < item.quantity) {
        _setError('Không đủ tồn kho cho món ${item.productName}.');
        return null;
      }
    }

    final now = DateTime.now();
    final addedItems = cartItems
        .map((item) => item.copyWith(id: nextId('item')))
        .toList();
    final addedNote = note.trim();
    final nextNote = activeOrder == null || addedNote.isEmpty
        ? activeOrder?.note ?? addedNote
        : activeOrder.note.isEmpty
        ? addedNote
        : '${activeOrder.note}\n$addedNote';
    final existingItems = activeOrder == null
        ? const <OrderItem>[]
        : activeOrder.status == OrderStatus.pending
        ? activeOrder.items
        : activeOrder.items
              .map(
                (item) => item.hasBeenSentToKitchen
                    ? item
                    : item.copyWith(kitchenBatchId: 'legacy_${activeOrder.id}'),
              )
              .toList(growable: false);
    final order = activeOrder == null
        ? Order(
            id: nextId('ord'),
            tableId: table.id,
            userId: user.id,
            items: addedItems,
            status: OrderStatus.pending,
            createdAt: now,
            updatedAt: now,
            note: addedNote,
          )
        : activeOrder.copyWith(
            items: [...existingItems, ...addedItems],
            status: OrderStatus.pending,
            updatedAt: now,
            clearSentKitchenAt: true,
            clearCompletedAt: true,
            note: nextNote,
          );

    final transactions = orderTransactionService;
    if (transactions != null) {
      try {
        if (activeOrder == null) {
          await transactions.createOrder(order);
        } else {
          await transactions.appendItemsToOrder(
            order: activeOrder,
            items: addedItems,
            note: addedNote,
          );
        }
      } on OrderTransactionFailure catch (error) {
        if (error.code == 'stock-changed') {
          try {
            await restoreRepositoryData().timeout(const Duration(seconds: 8));
          } catch (_) {
            // The current snapshot is still used to lock unavailable items.
          }
          _reconcileCartWithStock();
          _error = null;
          _message = null;
          notifyListeners();
          return null;
        }
        _setError(error.message);
        return null;
      }
    }

    _mutateAfterRemoteCommit(transactions != null, () {
      if (activeOrder == null) {
        repository.addOrder(order);
      } else {
        repository.updateOrder(order);
        _expireWaitingPayments(order.id);
      }
      for (final item in addedItems) {
        final product = repository.findProduct(item.productId);
        if (product != null) {
          repository.updateProductStock(
            product.id,
            product.stock - item.quantity,
          );
        }
      }
      if (activeOrder == null) {
        repository.upsertTable(
          table.copyWith(
            status: TableStatus.ordering,
            currentOrderId: order.id,
          ),
        );
      }
    });
    _cart.clear();
    _clearCartDraft();
    _message = activeOrder == null
        ? 'Đã tạo order cho ${table.name}.'
        : 'Đã thêm món vào order của ${table.name}.';
    _error = null;
    notifyListeners();
    return order;
  }

  Order? orderForTable(String tableId) =>
      repository.activeOrderForTable(tableId);

  List<Order> ordersForTable(String tableId) =>
      repository.orders.where((order) => order.tableId == tableId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Order? orderById(String id) => repository.findOrder(id);

  Payment? paymentById(String id) => repository.findPayment(id);

  RestaurantTable? tableById(String id) => repository.findTable(id);

  Area? areaById(String id) => repository.findArea(id);

  Category? categoryById(String id) => repository.findCategory(id);

  Product? productById(String id) => repository.findProduct(id);

  AppUser? userById(String id) =>
      repository.users.where((user) => user.id == id).firstOrNull;

  Payment? latestPaymentForOrder(String orderId) =>
      repository.latestPaymentForOrder(orderId);

  bool sendToKitchen(String orderId) {
    final order = repository.findOrder(orderId);
    if (order == null) {
      _setError('Không tìm thấy order.');
      return false;
    }
    if (order.status == OrderStatus.paid ||
        order.status == OrderStatus.cancelled) {
      _setError('Order này đã đóng.');
      return false;
    }
    if (!canManageOrder(order)) {
      _setError('Nhân viên chỉ được gửi bếp order mình đang phục vụ.');
      return false;
    }
    final unsentItems = order.items
        .where((item) => !item.hasBeenSentToKitchen)
        .toList(growable: false);
    if (unsentItems.isEmpty) {
      _setError('Không có món mới cần gửi bếp.');
      return false;
    }
    final kitchenBatchId = nextId('kitchen');
    repository.updateOrder(
      order.copyWith(
        items: order.items
            .map(
              (item) => item.hasBeenSentToKitchen
                  ? item
                  : item.copyWith(kitchenBatchId: kitchenBatchId),
            )
            .toList(growable: false),
        status: OrderStatus.preparing,
        sentKitchenAt: DateTime.now(),
      ),
    );
    _message = 'Đã gửi bếp order ${order.id}.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool completeOrder(String orderId) {
    final order = repository.findOrder(orderId);
    if (order == null || !order.isActive) {
      _setError('Order không còn hoạt động.');
      return false;
    }
    if (!canManageOrder(order)) {
      _setError('Nhân viên chỉ được hoàn tất order mình đang phục vụ.');
      return false;
    }
    repository.updateOrder(
      order.copyWith(
        status: OrderStatus.completed,
        completedAt: DateTime.now(),
      ),
    );
    _message = 'Đã đánh dấu hoàn tất món.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool cancelOrder(String orderId) {
    if (!_requireAdmin()) return false;
    final order = repository.findOrder(orderId);
    if (order == null || order.status == OrderStatus.paid) {
      _setError('Không thể hủy order này.');
      return false;
    }

    for (final item in order.items) {
      final product = repository.findProduct(item.productId);
      if (product != null) {
        repository.updateProductStock(
          product.id,
          product.stock + item.quantity,
        );
      }
    }

    repository.updateOrder(order.copyWith(status: OrderStatus.cancelled));
    _expireWaitingPayments(order.id);
    final table = repository.findTable(order.tableId);
    if (table != null) {
      repository.upsertTable(
        table.copyWith(status: TableStatus.available, clearCurrentOrder: true),
      );
    }
    _message = 'Đã hủy order và hoàn lại tồn kho.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool removeOrderItem(String orderId, String orderItemId) {
    if (!_requireAdmin()) return false;
    final order = repository.findOrder(orderId);
    if (order == null) {
      _setError('Không tìm thấy order.');
      return false;
    }
    if (order.status == OrderStatus.paid ||
        order.status == OrderStatus.cancelled) {
      _setError('Không thể xóa món khỏi order đã đóng.');
      return false;
    }

    final item = order.items
        .where((value) => value.id == orderItemId)
        .firstOrNull;
    if (item == null) {
      _setError('Không tìm thấy món trong order.');
      return false;
    }

    if (order.items.length == 1) {
      return cancelOrder(orderId);
    }

    final product = repository.findProduct(item.productId);
    if (product != null) {
      repository.updateProductStock(product.id, product.stock + item.quantity);
    }

    final updatedItems = order.items
        .where((value) => value.id != orderItemId)
        .toList(growable: false);
    repository.updateOrder(order.copyWith(items: updatedItems));
    _expireWaitingPayments(order.id);
    _message = 'Đã xóa món ${item.productName} và hoàn lại tồn kho.';
    _error = null;
    notifyListeners();
    return true;
  }

  Future<bool> transferOrderToTable(
    String orderId,
    String targetTableId,
  ) async {
    final order = repository.findOrder(orderId);
    if (order == null || !order.isActive) {
      _setError('Order không còn hoạt động để chuyển bàn.');
      return false;
    }
    if (!canManageOrder(order)) {
      _setError('Bạn không có quyền chuyển order này.');
      return false;
    }

    final sourceTable = repository.findTable(order.tableId);
    final targetTable = repository.findTable(targetTableId);
    if (sourceTable == null || targetTable == null) {
      _setError('Không tìm thấy bàn cần chuyển.');
      return false;
    }
    if (sourceTable.id == targetTable.id) {
      _setError('Vui lòng chọn bàn khác để chuyển order.');
      return false;
    }
    if (targetTable.status != TableStatus.available ||
        targetTable.currentOrderId != null) {
      _setError('Bàn nhận phải đang trống.');
      return false;
    }

    final waitingPayments = repository.payments
        .where(
          (payment) =>
              payment.orderId == order.id &&
              payment.status == PaymentStatus.waiting,
        )
        .toList(growable: false);
    final transactions = orderTransactionService;
    if (transactions != null) {
      try {
        await transactions.transferOrder(
          order: order,
          sourceTable: sourceTable,
          targetTable: targetTable,
          waitingPayments: waitingPayments,
        );
      } on OrderTransactionFailure catch (error) {
        _setError(error.message);
        return false;
      }
    }

    _mutateAfterRemoteCommit(transactions != null, () {
      repository.updateOrder(order.copyWith(tableId: targetTable.id));
      repository.upsertTable(
        sourceTable.copyWith(
          status: TableStatus.available,
          clearCurrentOrder: true,
          note: '',
        ),
      );
      repository.upsertTable(
        targetTable.copyWith(
          status: TableStatus.ordering,
          currentOrderId: order.id,
        ),
      );
      for (final payment in waitingPayments) {
        repository.updatePayment(
          payment.copyWith(status: PaymentStatus.expired),
        );
      }
    });

    _selectedTableId = targetTable.id;
    _message =
        'Đã chuyển order từ ${sourceTable.name} sang ${targetTable.name}.';
    _error = null;
    notifyListeners();
    return true;
  }

  Future<Payment?> createPayment(String orderId, PaymentMethod method) async {
    final order = repository.findOrder(orderId);
    final table = order == null ? null : repository.findTable(order.tableId);
    if (order == null || table == null) {
      _setError('Không tìm thấy order cần thanh toán.');
      return null;
    }
    if (!order.isActive) {
      _setError('Order này đã đóng.');
      return null;
    }
    if (!canManageOrder(order)) {
      _setError('Nhân viên chỉ được thanh toán order mình đang phục vụ.');
      return null;
    }

    final oldPayment = repository.latestPaymentForOrder(order.id);
    if (oldPayment != null &&
        oldPayment.method == method &&
        oldPayment.status == PaymentStatus.waiting &&
        oldPayment.amount == order.total &&
        !oldPayment.isQrExpired) {
      return oldPayment;
    }

    final now = DateTime.now();
    final expiredAt = method == PaymentMethod.qr
        ? now.add(const Duration(minutes: 15))
        : null;
    final qrContent = method == PaymentMethod.qr
        ? PaymentQrConfig.buildImageUri(
            amount: order.total,
            orderId: order.id,
          ).toString()
        : '';

    final payment = Payment(
      id: nextId('pay'),
      orderId: order.id,
      tableId: table.id,
      amount: order.total,
      method: method,
      qrContent: qrContent,
      qrExpiredAt: expiredAt,
      status: PaymentStatus.waiting,
      createdAt: now,
    );
    final transactions = orderTransactionService;
    if (transactions != null) {
      try {
        await transactions.createPayment(payment);
      } on OrderTransactionFailure catch (error) {
        _setError(error.message);
        return null;
      }
    }
    _mutateAfterRemoteCommit(
      transactions != null,
      () => repository.addPayment(payment),
    );
    _message = method == PaymentMethod.qr
        ? 'Đã tạo QR thanh toán.'
        : 'Đã chọn tiền mặt.';
    _error = null;
    notifyListeners();
    return payment;
  }

  Future<bool> confirmPayment(String paymentId) async {
    final user = _currentUser;
    final payment = repository.findPayment(paymentId);
    if (user == null || payment == null) {
      _setError('Không tìm thấy thanh toán.');
      return false;
    }
    if (payment.isQrExpired) {
      repository.updatePayment(payment.copyWith(status: PaymentStatus.expired));
      _setError('QR đã hết hạn, vui lòng tạo mã mới.');
      notifyListeners();
      return false;
    }
    if (payment.status != PaymentStatus.waiting) {
      _setError('Thanh toán này không còn chờ xác nhận.');
      return false;
    }

    final order = repository.findOrder(payment.orderId);
    final table = repository.findTable(payment.tableId);
    if (order == null || table == null) {
      _setError('Dữ liệu order hoặc bàn không hợp lệ.');
      return false;
    }
    if (!canManageOrder(order)) {
      _setError('Nhân viên chỉ được xác nhận order mình đang phục vụ.');
      return false;
    }
    if (payment.amount != order.total || payment.tableId != order.tableId) {
      repository.updatePayment(payment.copyWith(status: PaymentStatus.expired));
      _setError('Order đã thay đổi. Vui lòng tạo thanh toán mới.');
      notifyListeners();
      return false;
    }

    final transactions = orderTransactionService;
    if (transactions != null) {
      try {
        await transactions.confirmPayment(
          payment: payment,
          confirmedBy: user.id,
        );
      } on OrderTransactionFailure catch (error) {
        _setError(error.message);
        return false;
      }
    }
    _mutateAfterRemoteCommit(transactions != null, () {
      repository.updatePayment(
        payment.copyWith(
          status: PaymentStatus.paid,
          confirmedBy: user.id,
          paidAt: DateTime.now(),
        ),
      );
      repository.updateOrder(
        order.copyWith(
          status: OrderStatus.paid,
          paymentStatus: PaymentStatus.paid,
          paymentMethod: payment.method,
        ),
      );
      repository.upsertTable(table.copyWith(status: TableStatus.paid));
    });
    _message = 'Đã xác nhận thanh toán cho ${table.name}.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool clearTable(String tableId) {
    final table = repository.findTable(tableId);
    if (table == null) {
      _setError('Không tìm thấy bàn.');
      return false;
    }
    if (table.status != TableStatus.paid) {
      _setError('Chỉ dọn bàn sau khi đã thanh toán.');
      return false;
    }
    repository.upsertTable(
      table.copyWith(
        status: TableStatus.available,
        clearCurrentOrder: true,
        note: '',
      ),
    );
    _message = '${table.name} đã sẵn sàng nhận khách mới.';
    _error = null;
    notifyListeners();
    return true;
  }

  Future<bool> upsertUser(AppUser user, {String? temporaryPassword}) async {
    if (!_requireAdmin()) return false;
    final duplicate = repository.users.any(
      (item) =>
          item.id != user.id &&
          item.email.toLowerCase() == user.email.trim().toLowerCase(),
    );
    if (user.fullName.trim().isEmpty || user.email.trim().isEmpty) {
      _setError('Họ tên và email không được để trống.');
      return false;
    }
    if (duplicate) {
      _setError('Email này đã tồn tại trong hệ thống.');
      return false;
    }
    var savedUser = user;
    final administration = userAdministrationService;
    if (administration != null) {
      try {
        final isNew = repository.users.every((item) => item.id != user.id);
        if (isNew) {
          final password = temporaryPassword ?? '';
          if (password.length < 6) {
            _setError('Mật khẩu tạm phải có ít nhất 6 ký tự.');
            return false;
          }
          final uid = await administration.createUser(
            user: user,
            temporaryPassword: password,
          );
          savedUser = user.copyWith(id: uid);
        } else {
          await administration.updateUser(user);
        }
      } on UserAdministrationFailure catch (error) {
        _setError(error.message);
        return false;
      }
    }
    repository.upsertUser(savedUser);
    _message = 'Đã lưu tài khoản ${user.fullName}.';
    _error = null;
    notifyListeners();
    return true;
  }

  Future<bool> toggleUserStatus(AppUser user) async {
    if (!_requireAdmin()) return false;
    if (user.id == _currentUser?.id) {
      _setError('Không thể khóa tài khoản đang đăng nhập.');
      return false;
    }
    final nextStatus = user.status == AccountStatus.active
        ? AccountStatus.locked
        : AccountStatus.active;
    final administration = userAdministrationService;
    if (administration != null) {
      try {
        await administration.setUserDisabled(
          uid: user.id,
          disabled: nextStatus == AccountStatus.locked,
        );
      } on UserAdministrationFailure catch (error) {
        _setError(error.message);
        return false;
      }
    }
    repository.upsertUser(user.copyWith(status: nextStatus));
    _message = 'Đã cập nhật trạng thái tài khoản.';
    _error = null;
    notifyListeners();
    return true;
  }

  Future<bool> deleteUser(String id) async {
    if (!_requireAdmin()) return false;
    if (id == _currentUser?.id) {
      _setError('Không thể xóa tài khoản đang đăng nhập.');
      return false;
    }
    if (repository.orders.any((order) => order.userId == id)) {
      _setError(
        'Không thể xóa người dùng đã có lịch sử order. Hãy khóa tài khoản.',
      );
      return false;
    }
    final administration = userAdministrationService;
    if (administration != null) {
      try {
        await administration.deleteUser(id);
      } on UserAdministrationFailure catch (error) {
        _setError(error.message);
        return false;
      }
    }
    repository.deleteUser(id);
    _message = 'Đã xóa tài khoản.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool upsertArea(Area area) {
    if (!_requireAdmin()) return false;
    if (area.name.trim().isEmpty) {
      _setError('Tên khu vực không được để trống.');
      return false;
    }
    repository.upsertArea(area);
    _message = 'Đã lưu khu vực ${area.name}.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool deleteArea(String id) {
    if (!_requireAdmin()) return false;
    final areaTableIds = repository.tables
        .where((table) => table.areaId == id)
        .map((table) => table.id)
        .toSet();
    if (repository.orders.any(
      (order) => areaTableIds.contains(order.tableId),
    )) {
      _setError('Không thể xóa khu vực đã có lịch sử order.');
      return false;
    }
    repository.deleteArea(id);
    _message = 'Đã xóa khu vực và các bàn liên quan.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool upsertTable(RestaurantTable table) {
    if (!_requireAdmin()) return false;
    if (table.name.trim().isEmpty || table.capacity < 1) {
      _setError('Tên bàn không được trống và số khách phải lớn hơn 0.');
      return false;
    }
    repository.upsertTable(table);
    _message = 'Đã lưu bàn ${table.name}.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool deleteTable(String id) {
    if (!_requireAdmin()) return false;
    if (repository.orders.any((order) => order.tableId == id)) {
      _setError('Không thể xóa bàn đã có lịch sử order.');
      return false;
    }
    repository.deleteTable(id);
    _message = 'Đã xóa bàn.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool upsertCategory(Category category) {
    if (!_requireAdmin()) return false;
    if (category.name.trim().isEmpty) {
      _setError('Tên danh mục không được để trống.');
      return false;
    }
    repository.upsertCategory(category);
    _message = 'Đã lưu danh mục ${category.name}.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool deleteCategory(String id) {
    if (!_requireAdmin()) return false;
    if (repository.products.any((product) => product.categoryId == id)) {
      _setError('Hãy chuyển hoặc xóa các món trong danh mục trước.');
      return false;
    }
    repository.deleteCategory(id);
    _message = 'Đã xóa danh mục.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool upsertProduct(Product product) {
    if (!_requireAdmin()) return false;
    if (product.name.trim().isEmpty || product.price <= 0) {
      _setError('Tên món không được trống và giá phải lớn hơn 0.');
      return false;
    }
    if (product.stock < 0 || product.warningThreshold < 1) {
      _setError('Tồn kho và ngưỡng cảnh báo không hợp lệ.');
      return false;
    }
    repository.upsertProduct(product);
    _reconcileCartWithStock();
    _message = 'Đã lưu món ${product.name}.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool deleteProduct(String id) {
    if (!_requireAdmin()) return false;
    repository.deleteProduct(id);
    _reconcileCartWithStock();
    _message = 'Đã xóa món.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool adjustStock(String productId, int delta) {
    if (!_requireAdmin()) return false;
    final product = repository.findProduct(productId);
    if (product == null) return false;
    final nextStock = (product.stock + delta).clamp(0, 999).toInt();
    repository.updateProductStock(product.id, nextStock);
    _reconcileCartWithStock();
    _message = 'Đã cập nhật tồn kho ${product.name}.';
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
