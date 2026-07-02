import 'dart:async';
import 'dart:convert';

import '../models/app_models.dart';
import '../models/model_serializers.dart';
import '../services/local_database_storage_service.dart';
import 'order_repository.dart';

class MockOrderRepository implements PersistentOrderRepository {
  MockOrderRepository({this.localDatabaseStorage}) {
    _seed();
  }

  final LocalDatabaseStorage? localDatabaseStorage;
  final List<AppUser> _users = [];
  final List<Area> _areas = [];
  final List<RestaurantTable> _tables = [];
  final List<Category> _categories = [];
  final List<Product> _products = [];
  final List<Order> _orders = [];
  final List<Payment> _payments = [];
  final Map<String, String> _passwords = {};
  bool _isRestoring = false;

  @override
  List<AppUser> get users => List.unmodifiable(_users);
  @override
  List<Area> get areas => List.unmodifiable(_areas);
  @override
  List<RestaurantTable> get tables => List.unmodifiable(_tables);
  @override
  List<Category> get categories => List.unmodifiable(_categories);
  @override
  List<Product> get products => List.unmodifiable(_products);
  @override
  List<Order> get orders => List.unmodifiable(_orders);
  @override
  List<Payment> get payments => List.unmodifiable(_payments);

  @override
  AppUser? authenticate(String email, String password) {
    final normalizedEmail = email.trim().toLowerCase();
    final user = _find(
      _users,
      (item) => item.email.toLowerCase() == normalizedEmail,
    );
    if (user == null || user.status == AccountStatus.locked) return null;
    if (_passwords[user.id] != password) return null;
    return user;
  }

  @override
  Area? findArea(String id) => _find(_areas, (item) => item.id == id);

  @override
  RestaurantTable? findTable(String id) =>
      _find(_tables, (item) => item.id == id);

  @override
  Category? findCategory(String id) =>
      _find(_categories, (item) => item.id == id);

  @override
  Product? findProduct(String id) => _find(_products, (item) => item.id == id);

  @override
  Order? findOrder(String id) => _find(_orders, (item) => item.id == id);

  @override
  Payment? findPayment(String id) => _find(_payments, (item) => item.id == id);

  @override
  Order? activeOrderForTable(String tableId) {
    final table = findTable(tableId);
    if (table?.currentOrderId == null) return null;
    final order = findOrder(table!.currentOrderId!);
    if (order == null || !order.isActive) return null;
    return order;
  }

  @override
  Payment? latestPaymentForOrder(String orderId) {
    final orderPayments =
        _payments.where((item) => item.orderId == orderId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (orderPayments.isEmpty) return null;
    return orderPayments.first;
  }

  @override
  void upsertUser(AppUser user, {String password = '123456'}) {
    final index = _users.indexWhere((item) => item.id == user.id);
    if (index >= 0) {
      _users[index] = user.copyWith(updatedAt: DateTime.now());
    } else {
      _users.add(user);
    }
    _passwords[user.id] = password;
    _persist();
  }

  @override
  void deleteUser(String id) {
    _users.removeWhere((item) => item.id == id);
    _passwords.remove(id);
    _persist();
  }

  @override
  void upsertArea(Area area) {
    final index = _areas.indexWhere((item) => item.id == area.id);
    if (index >= 0) {
      _areas[index] = area;
    } else {
      _areas.add(area);
    }
    _persist();
  }

  @override
  void deleteArea(String id) {
    _areas.removeWhere((item) => item.id == id);
    _tables.removeWhere((item) => item.areaId == id);
    _persist();
  }

  @override
  void upsertTable(RestaurantTable table) {
    final index = _tables.indexWhere((item) => item.id == table.id);
    if (index >= 0) {
      _tables[index] = table;
    } else {
      _tables.add(table);
    }
    _persist();
  }

  @override
  void deleteTable(String id) {
    _tables.removeWhere((item) => item.id == id);
    _persist();
  }

  @override
  void upsertCategory(Category category) {
    final index = _categories.indexWhere((item) => item.id == category.id);
    if (index >= 0) {
      _categories[index] = category;
    } else {
      _categories.add(category);
    }
    _persist();
  }

  @override
  void deleteCategory(String id) {
    _categories.removeWhere((item) => item.id == id);
    _persist();
  }

  @override
  void upsertProduct(Product product) {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index >= 0) {
      _products[index] = product.copyWith(updatedAt: DateTime.now());
    } else {
      _products.add(product);
    }
    _persist();
  }

  @override
  void deleteProduct(String id) {
    _products.removeWhere((item) => item.id == id);
    _persist();
  }

  @override
  void updateProductStock(String productId, int stock) {
    final product = findProduct(productId);
    if (product == null) return;
    final nextStatus = stock <= 0
        ? ProductStatus.soldOut
        : ProductStatus.available;
    upsertProduct(product.copyWith(stock: stock, status: nextStatus));
  }

  @override
  void addOrder(Order order) {
    _orders.add(order);
    _persist();
  }

  @override
  void updateOrder(Order order) {
    final index = _orders.indexWhere((item) => item.id == order.id);
    if (index >= 0) {
      _orders[index] = order.copyWith(updatedAt: DateTime.now());
      _persist();
    }
  }

  @override
  void addPayment(Payment payment) {
    _payments.add(payment);
    _persist();
  }

  @override
  void updatePayment(Payment payment) {
    final index = _payments.indexWhere((item) => item.id == payment.id);
    if (index >= 0) {
      _payments[index] = payment;
      _persist();
    }
  }

  @override
  int revenueForDay(DateTime day) {
    return _payments
        .where((payment) {
          final paidAt = payment.paidAt;
          return payment.status == PaymentStatus.paid &&
              paidAt != null &&
              paidAt.year == day.year &&
              paidAt.month == day.month &&
              paidAt.day == day.day;
        })
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  @override
  Map<String, int> soldQuantities() {
    final values = <String, int>{};
    for (final order in _orders.where(
      (item) => item.status == OrderStatus.paid,
    )) {
      for (final item in order.items) {
        values[item.productId] = (values[item.productId] ?? 0) + item.quantity;
      }
    }
    return values;
  }

  @override
  Future<void> restoreSavedData() async {
    final storage = localDatabaseStorage;
    if (storage == null) return;
    final snapshot = await storage.loadSnapshot();
    if (snapshot == null) return;
    _replaceWithSnapshot(snapshot);
  }

  @override
  Future<void> persistNow() async {
    final storage = localDatabaseStorage;
    if (storage == null) return;
    await storage.saveSnapshot(_snapshot());
  }

  @override
  Future<void> resetToSeedData() async {
    _clearAll();
    _seed();
    await persistNow();
  }

  @override
  String exportBackupJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_snapshot());
  }

  Map<String, Object?> _snapshot() {
    return {
      'version': 1,
      'users': _users.map((item) => item.toMap()).toList(),
      'areas': _areas.map((item) => item.toMap()).toList(),
      'tables': _tables.map((item) => item.toMap()).toList(),
      'categories': _categories.map((item) => item.toMap()).toList(),
      'products': _products.map((item) => item.toMap()).toList(),
      'orders': _orders.map((item) => item.toMap()).toList(),
      'payments': _payments.map((item) => item.toMap()).toList(),
      'passwords': Map<String, String>.from(_passwords),
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  void _replaceWithSnapshot(Map<String, dynamic> snapshot) {
    _isRestoring = true;
    try {
      _clearAll();
      _users.addAll(_readList(snapshot['users'], AppUserSerializer.fromMap));
      _areas.addAll(_readList(snapshot['areas'], AreaSerializer.fromMap));
      _tables.addAll(
        _readList(snapshot['tables'], RestaurantTableSerializer.fromMap),
      );
      _categories.addAll(
        _readList(snapshot['categories'], CategorySerializer.fromMap),
      );
      _products.addAll(
        _readList(snapshot['products'], ProductSerializer.fromMap),
      );
      _orders.addAll(_readList(snapshot['orders'], OrderSerializer.fromMap));
      _payments.addAll(
        _readList(snapshot['payments'], PaymentSerializer.fromMap),
      );

      final rawPasswords = snapshot['passwords'];
      if (rawPasswords is Map) {
        _passwords.addAll(
          rawPasswords.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
      }
      for (final user in _users) {
        _passwords.putIfAbsent(user.id, () => '123456');
      }

      if (_users.isEmpty || _areas.isEmpty || _tables.isEmpty) {
        _clearAll();
        _seed();
      }
    } finally {
      _isRestoring = false;
    }
  }

  List<T> _readList<T>(
    Object? rawValue,
    T Function(Map<String, dynamic> map) fromMap,
  ) {
    final rawItems = rawValue as List<dynamic>? ?? [];
    return rawItems
        .whereType<Map>()
        .map((item) => fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  void _persist() {
    final storage = localDatabaseStorage;
    if (storage == null || _isRestoring) return;
    unawaited(storage.saveSnapshot(_snapshot()));
  }

  void _clearAll() {
    _users.clear();
    _areas.clear();
    _tables.clear();
    _categories.clear();
    _products.clear();
    _orders.clear();
    _payments.clear();
    _passwords.clear();
  }

  void _seed() {
    final now = DateTime.now();

    _users.addAll([
      AppUser(
        id: 'u_admin',
        employeeCode: 'AD001',
        fullName: 'Quản lý cửa hàng',
        email: 'admin@miniorder.vn',
        phone: '0901000001',
        username: 'admin',
        role: UserRole.admin,
        shift: 'Cả ngày',
        status: AccountStatus.active,
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now,
      ),
      AppUser(
        id: 'u_staff',
        employeeCode: 'NV001',
        fullName: 'Nhân viên demo',
        email: 'staff@miniorder.vn',
        phone: '0901000002',
        username: 'staff',
        role: UserRole.staff,
        shift: 'Ca sáng',
        status: AccountStatus.active,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
      ),
    ]);

    _passwords.addAll({'u_admin': '123456', 'u_staff': '123456'});

    _areas.addAll(const [
      Area(id: 'a_in', name: 'Trong nhà', description: 'Khu bàn máy lạnh'),
      Area(id: 'a_out', name: 'Sân vườn', description: 'Khu ngoài trời'),
      Area(id: 'a_takeaway', name: 'Mang đi', description: 'Quầy nhận nhanh'),
    ]);

    _tables.addAll(const [
      RestaurantTable(
        id: 't01',
        name: 'Bàn 01',
        areaId: 'a_in',
        status: TableStatus.available,
        capacity: 4,
      ),
      RestaurantTable(
        id: 't02',
        name: 'Bàn 02',
        areaId: 'a_in',
        status: TableStatus.ordering,
        capacity: 4,
        currentOrderId: 'o_delay',
        note: 'Khách yêu cầu ít đá',
      ),
      RestaurantTable(
        id: 't03',
        name: 'Bàn 03',
        areaId: 'a_in',
        status: TableStatus.paid,
        capacity: 2,
        currentOrderId: 'o_paid',
      ),
      RestaurantTable(
        id: 't04',
        name: 'Bàn 04',
        areaId: 'a_out',
        status: TableStatus.available,
        capacity: 6,
      ),
      RestaurantTable(
        id: 't05',
        name: 'Bàn 05',
        areaId: 'a_out',
        status: TableStatus.available,
        capacity: 4,
      ),
      RestaurantTable(
        id: 't06',
        name: 'Bàn 06',
        areaId: 'a_out',
        status: TableStatus.available,
        capacity: 8,
      ),
      RestaurantTable(
        id: 't07',
        name: 'Mang đi 01',
        areaId: 'a_takeaway',
        status: TableStatus.available,
        capacity: 1,
      ),
      RestaurantTable(
        id: 't08',
        name: 'Mang đi 02',
        areaId: 'a_takeaway',
        status: TableStatus.available,
        capacity: 1,
      ),
    ]);

    _categories.addAll(const [
      Category(
        id: 'c_drink',
        name: 'Đồ uống',
        description: 'Cafe, trà, sinh tố',
      ),
      Category(
        id: 'c_food',
        name: 'Món ăn',
        description: 'Món chính phục vụ nhanh',
      ),
    ]);

    _products.addAll([
      Product(
        id: 'P001',
        name: 'Cà phê sữa',
        price: 25000,
        shortDescription: 'Cafe phin, sữa đặc, đá viên',
        categoryId: 'c_drink',
        stock: 20,
        warningThreshold: 5,
        status: ProductStatus.available,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'P002',
        name: 'Trà đào',
        price: 30000,
        shortDescription: 'Trà đào cam sả thơm nhẹ',
        categoryId: 'c_drink',
        stock: 4,
        warningThreshold: 5,
        status: ProductStatus.available,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'P003',
        name: 'Bạc xỉu',
        price: 28000,
        shortDescription: 'Nhiều sữa, vị cafe dịu',
        categoryId: 'c_drink',
        stock: 20,
        warningThreshold: 5,
        status: ProductStatus.available,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'P004',
        name: 'Sinh tố',
        price: 35000,
        shortDescription: 'Trái cây xay theo ngày',
        categoryId: 'c_drink',
        stock: 15,
        warningThreshold: 5,
        status: ProductStatus.available,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'P005',
        name: 'Mì xào',
        price: 45000,
        shortDescription: 'Mì xào rau củ và trứng',
        categoryId: 'c_food',
        stock: 10,
        warningThreshold: 5,
        status: ProductStatus.available,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'P006',
        name: 'Cơm gà',
        price: 50000,
        shortDescription: 'Cơm gà sốt mắm tỏi',
        categoryId: 'c_food',
        stock: 10,
        warningThreshold: 5,
        status: ProductStatus.available,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    _orders.addAll([
      Order(
        id: 'o_delay',
        tableId: 't02',
        userId: 'u_staff',
        items: const [
          OrderItem(
            id: 'oi01',
            productId: 'P002',
            productName: 'Trà đào',
            quantity: 2,
            unitPrice: 30000,
            note: 'Ít đá',
          ),
          OrderItem(
            id: 'oi02',
            productId: 'P005',
            productName: 'Mì xào',
            quantity: 1,
            unitPrice: 45000,
          ),
        ],
        status: OrderStatus.preparing,
        createdAt: now.subtract(const Duration(minutes: 16)),
        updatedAt: now.subtract(const Duration(minutes: 12)),
        sentKitchenAt: now.subtract(const Duration(minutes: 12)),
        note: 'Khách ngồi gần cửa sổ',
      ),
      Order(
        id: 'o_paid',
        tableId: 't03',
        userId: 'u_staff',
        items: const [
          OrderItem(
            id: 'oi03',
            productId: 'P001',
            productName: 'Cà phê sữa',
            quantity: 1,
            unitPrice: 25000,
          ),
          OrderItem(
            id: 'oi04',
            productId: 'P006',
            productName: 'Cơm gà',
            quantity: 2,
            unitPrice: 50000,
          ),
        ],
        status: OrderStatus.paid,
        paymentStatus: PaymentStatus.paid,
        paymentMethod: PaymentMethod.cash,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 1, minutes: 20)),
        sentKitchenAt: now.subtract(const Duration(hours: 2)),
        completedAt: now.subtract(const Duration(hours: 1, minutes: 35)),
      ),
    ]);

    _payments.add(
      Payment(
        id: 'pay_paid',
        orderId: 'o_paid',
        tableId: 't03',
        amount: 125000,
        method: PaymentMethod.cash,
        status: PaymentStatus.paid,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 22)),
        confirmedBy: 'u_staff',
        paidAt: now.subtract(const Duration(hours: 1, minutes: 20)),
      ),
    );
  }
}

T? _find<T>(Iterable<T> items, bool Function(T item) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}
