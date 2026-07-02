import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../models/app_models.dart';
import '../repositories/order_repository.dart';
import '../services/cart_draft_storage_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.repository, {this.cartDraftStorage});

  final OrderRepository repository;
  final CartDraftStorage? cartDraftStorage;

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

  bool login(String email, String password) {
    if (email.trim().isEmpty || password.isEmpty) {
      _setError('Vui lòng nhập email và mật khẩu.');
      return false;
    }

    final user = repository.authenticate(email, password);
    if (user == null) {
      _setError('Sai tài khoản, mật khẩu hoặc tài khoản đã bị khóa.');
      return false;
    }

    _currentUser = user;
    _message = 'Đăng nhập thành công.';
    _error = null;
    notifyListeners();
    return true;
  }

  void logout() {
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
      _setError('Món ${product.name} hiện không thể order.');
      return false;
    }

    final currentQuantity = _cart[product.id]?.quantity ?? 0;
    if (currentQuantity + 1 > product.stock) {
      _setError('Tồn kho ${product.name} không đủ.');
      return false;
    }

    _cart[product.id] = OrderItem(
      id: 'draft_${product.id}',
      productId: product.id,
      productName: product.name,
      quantity: currentQuantity + 1,
      unitPrice: product.price,
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

  Order? confirmOrder(String note) {
    final user = _currentUser;
    final table = selectedTable;
    if (user == null || table == null) {
      _setError('Bạn cần đăng nhập và chọn bàn trước khi tạo order.');
      return null;
    }

    if (repository.activeOrderForTable(table.id) != null) {
      _setError('Bàn này đang có order chưa thanh toán.');
      return null;
    }

    if (_cart.isEmpty) {
      _setError('Giỏ hàng đang trống.');
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
    final order = Order(
      id: nextId('ord'),
      tableId: table.id,
      userId: user.id,
      items: cartItems
          .map((item) => item.copyWith(id: nextId('item')))
          .toList(),
      status: OrderStatus.pending,
      createdAt: now,
      updatedAt: now,
      note: note.trim(),
    );

    repository.addOrder(order);
    for (final item in order.items) {
      final product = repository.findProduct(item.productId);
      if (product != null) {
        repository.updateProductStock(
          product.id,
          product.stock - item.quantity,
        );
      }
    }
    repository.upsertTable(
      table.copyWith(status: TableStatus.ordering, currentOrderId: order.id),
    );
    _cart.clear();
    _clearCartDraft();
    _message = 'Đã tạo order cho ${table.name}.';
    _error = null;
    notifyListeners();
    return order;
  }

  Order? orderForTable(String tableId) =>
      repository.activeOrderForTable(tableId);

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
    repository.updateOrder(
      order.copyWith(
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
    _message = 'Đã xóa món ${item.productName} và hoàn lại tồn kho.';
    _error = null;
    notifyListeners();
    return true;
  }

  Payment? createPayment(String orderId, PaymentMethod method) {
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
        ? 'VietQR|MINI_ORDER|SO_TIEN=${order.total}|NOI_DUNG=${order.id}-${table.name}|HET_HAN=${expiredAt!.toIso8601String()}'
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
    repository.addPayment(payment);
    _message = method == PaymentMethod.qr
        ? 'Đã tạo QR thanh toán.'
        : 'Đã chọn tiền mặt.';
    _error = null;
    notifyListeners();
    return payment;
  }

  bool confirmPayment(String paymentId) {
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

  bool upsertUser(AppUser user, {String password = '123456'}) {
    if (!_requireAdmin()) return false;
    repository.upsertUser(user, password: password);
    _message = 'Đã lưu tài khoản ${user.fullName}.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool toggleUserStatus(AppUser user) {
    if (!_requireAdmin()) return false;
    if (user.id == _currentUser?.id) {
      _setError('Không thể khóa tài khoản đang đăng nhập.');
      return false;
    }
    final nextStatus = user.status == AccountStatus.active
        ? AccountStatus.locked
        : AccountStatus.active;
    repository.upsertUser(user.copyWith(status: nextStatus));
    _message = 'Đã cập nhật trạng thái tài khoản.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool deleteUser(String id) {
    if (!_requireAdmin()) return false;
    if (id == _currentUser?.id) {
      _setError('Không thể xóa tài khoản đang đăng nhập.');
      return false;
    }
    repository.deleteUser(id);
    _message = 'Đã xóa tài khoản.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool upsertArea(Area area) {
    if (!_requireAdmin()) return false;
    repository.upsertArea(area);
    _message = 'Đã lưu khu vực ${area.name}.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool deleteArea(String id) {
    if (!_requireAdmin()) return false;
    repository.deleteArea(id);
    _message = 'Đã xóa khu vực và các bàn liên quan.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool upsertTable(RestaurantTable table) {
    if (!_requireAdmin()) return false;
    repository.upsertTable(table);
    _message = 'Đã lưu bàn ${table.name}.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool deleteTable(String id) {
    if (!_requireAdmin()) return false;
    repository.deleteTable(id);
    _message = 'Đã xóa bàn.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool upsertCategory(Category category) {
    if (!_requireAdmin()) return false;
    repository.upsertCategory(category);
    _message = 'Đã lưu danh mục ${category.name}.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool deleteCategory(String id) {
    if (!_requireAdmin()) return false;
    repository.deleteCategory(id);
    _message = 'Đã xóa danh mục.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool upsertProduct(Product product) {
    if (!_requireAdmin()) return false;
    repository.upsertProduct(product);
    _message = 'Đã lưu món ${product.name}.';
    _error = null;
    notifyListeners();
    return true;
  }

  bool deleteProduct(String id) {
    if (!_requireAdmin()) return false;
    repository.deleteProduct(id);
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

  void _clearCartDraft() {
    final storage = cartDraftStorage;
    if (storage == null) return;
    unawaited(storage.clearDraft());
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
