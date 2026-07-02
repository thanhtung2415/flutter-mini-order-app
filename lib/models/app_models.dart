enum UserRole { admin, staff }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.admin => 'Admin',
    UserRole.staff => 'Nhân viên',
  };

  bool get isAdmin => this == UserRole.admin;
}

enum AccountStatus { active, locked }

extension AccountStatusLabel on AccountStatus {
  String get label => switch (this) {
    AccountStatus.active => 'Đang hoạt động',
    AccountStatus.locked => 'Đã khóa',
  };
}

enum TableStatus { available, ordering, paid }

extension TableStatusLabel on TableStatus {
  String get label => switch (this) {
    TableStatus.available => 'Trống',
    TableStatus.ordering => 'Đang order',
    TableStatus.paid => 'Đã thanh toán',
  };
}

enum ProductStatus { available, soldOut, hidden }

extension ProductStatusLabel on ProductStatus {
  String get label => switch (this) {
    ProductStatus.available => 'Còn bán',
    ProductStatus.soldOut => 'Hết món',
    ProductStatus.hidden => 'Ẩn',
  };
}

enum OrderStatus { pending, preparing, completed, paid, cancelled }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Chờ xác nhận',
    OrderStatus.preparing => 'Đã gửi bếp',
    OrderStatus.completed => 'Hoàn tất món',
    OrderStatus.paid => 'Đã thanh toán',
    OrderStatus.cancelled => 'Đã hủy',
  };
}

enum PaymentStatus { waiting, paid, expired }

extension PaymentStatusLabel on PaymentStatus {
  String get label => switch (this) {
    PaymentStatus.waiting => 'Chờ xác nhận',
    PaymentStatus.paid => 'Đã thanh toán',
    PaymentStatus.expired => 'QR hết hạn',
  };
}

enum PaymentMethod { cash, qr }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.cash => 'Tiền mặt',
    PaymentMethod.qr => 'QR chuyển khoản',
  };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.username,
    required this.role,
    required this.shift,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String employeeCode;
  final String fullName;
  final String email;
  final String phone;
  final String username;
  final UserRole role;
  final String shift;
  final AccountStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser copyWith({
    String? id,
    String? employeeCode,
    String? fullName,
    String? email,
    String? phone,
    String? username,
    UserRole? role,
    String? shift,
    AccountStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      username: username ?? this.username,
      role: role ?? this.role,
      shift: shift ?? this.shift,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Area {
  const Area({
    required this.id,
    required this.name,
    required this.description,
    this.visible = true,
  });

  final String id;
  final String name;
  final String description;
  final bool visible;

  Area copyWith({
    String? id,
    String? name,
    String? description,
    bool? visible,
  }) {
    return Area(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      visible: visible ?? this.visible,
    );
  }
}

class RestaurantTable {
  const RestaurantTable({
    required this.id,
    required this.name,
    required this.areaId,
    required this.status,
    required this.capacity,
    this.currentOrderId,
    this.note = '',
  });

  final String id;
  final String name;
  final String areaId;
  final TableStatus status;
  final int capacity;
  final String? currentOrderId;
  final String note;

  RestaurantTable copyWith({
    String? id,
    String? name,
    String? areaId,
    TableStatus? status,
    int? capacity,
    String? currentOrderId,
    bool clearCurrentOrder = false,
    String? note,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      name: name ?? this.name,
      areaId: areaId ?? this.areaId,
      status: status ?? this.status,
      capacity: capacity ?? this.capacity,
      currentOrderId: clearCurrentOrder
          ? null
          : currentOrderId ?? this.currentOrderId,
      note: note ?? this.note,
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.description,
    this.visible = true,
  });

  final String id;
  final String name;
  final String description;
  final bool visible;

  Category copyWith({
    String? id,
    String? name,
    String? description,
    bool? visible,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      visible: visible ?? this.visible,
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.shortDescription,
    required this.categoryId,
    required this.stock,
    required this.warningThreshold,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final int price;
  final String imageUrl;
  final String shortDescription;
  final String categoryId;
  final int stock;
  final int warningThreshold;
  final ProductStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLowStock => stock > 0 && stock < warningThreshold;
  bool get canOrder => status == ProductStatus.available && stock > 0;

  Product copyWith({
    String? id,
    String? name,
    int? price,
    String? imageUrl,
    String? shortDescription,
    String? categoryId,
    int? stock,
    int? warningThreshold,
    ProductStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      shortDescription: shortDescription ?? this.shortDescription,
      categoryId: categoryId ?? this.categoryId,
      stock: stock ?? this.stock,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.note = '',
  });

  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final int unitPrice;
  final String note;

  int get total => quantity * unitPrice;

  OrderItem copyWith({
    String? id,
    String? productId,
    String? productName,
    int? quantity,
    int? unitPrice,
    String? note,
  }) {
    return OrderItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      note: note ?? this.note,
    );
  }
}

class Order {
  const Order({
    required this.id,
    required this.tableId,
    required this.userId,
    required this.items,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.paymentStatus = PaymentStatus.waiting,
    this.paymentMethod,
    this.sentKitchenAt,
    this.completedAt,
    this.note = '',
  });

  final String id;
  final String tableId;
  final String userId;
  final List<OrderItem> items;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final PaymentMethod? paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? sentKitchenAt;
  final DateTime? completedAt;
  final String note;

  int get total => items.fold(0, (sum, item) => sum + item.total);

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isActive =>
      status != OrderStatus.paid && status != OrderStatus.cancelled;

  bool get isDelayed {
    final start = sentKitchenAt ?? createdAt;
    return isActive && DateTime.now().difference(start).inMinutes >= 10;
  }

  Order copyWith({
    String? id,
    String? tableId,
    String? userId,
    List<OrderItem>? items,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    PaymentMethod? paymentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? sentKitchenAt,
    DateTime? completedAt,
    String? note,
  }) {
    return Order(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sentKitchenAt: sentKitchenAt ?? this.sentKitchenAt,
      completedAt: completedAt ?? this.completedAt,
      note: note ?? this.note,
    );
  }
}

class Payment {
  const Payment({
    required this.id,
    required this.orderId,
    required this.tableId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.qrContent = '',
    this.qrExpiredAt,
    this.confirmedBy,
    this.paidAt,
  });

  final String id;
  final String orderId;
  final String tableId;
  final int amount;
  final PaymentMethod method;
  final String qrContent;
  final DateTime createdAt;
  final DateTime? qrExpiredAt;
  final PaymentStatus status;
  final String? confirmedBy;
  final DateTime? paidAt;

  bool get isQrExpired =>
      method == PaymentMethod.qr &&
      qrExpiredAt != null &&
      DateTime.now().isAfter(qrExpiredAt!);

  Payment copyWith({
    String? id,
    String? orderId,
    String? tableId,
    int? amount,
    PaymentMethod? method,
    String? qrContent,
    DateTime? createdAt,
    DateTime? qrExpiredAt,
    PaymentStatus? status,
    String? confirmedBy,
    DateTime? paidAt,
  }) {
    return Payment(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      tableId: tableId ?? this.tableId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      qrContent: qrContent ?? this.qrContent,
      createdAt: createdAt ?? this.createdAt,
      qrExpiredAt: qrExpiredAt ?? this.qrExpiredAt,
      status: status ?? this.status,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
