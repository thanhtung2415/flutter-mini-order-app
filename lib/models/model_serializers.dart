import 'app_models.dart';

extension AppUserSerializer on AppUser {
  Map<String, Object?> toMap() => {
    'userId': id,
    'maNhanVien': employeeCode,
    'hoTen': fullName,
    'email': email,
    'soDienThoai': phone,
    'tenDangNhap': username,
    'vaiTro': role.name,
    'caLamViec': shift,
    'trangThai': status.name,
    'createdAt': _dateToText(createdAt),
    'updatedAt': _dateToText(updatedAt),
  };

  static AppUser fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: _string(map['userId']),
      employeeCode: _string(map['maNhanVien']),
      fullName: _string(map['hoTen']),
      email: _string(map['email']),
      phone: _string(map['soDienThoai']),
      username: _string(map['tenDangNhap']),
      role: _enumValue(UserRole.values, map['vaiTro'], UserRole.staff),
      shift: _string(map['caLamViec']),
      status: _enumValue(
        AccountStatus.values,
        map['trangThai'],
        AccountStatus.active,
      ),
      createdAt: _dateValue(map['createdAt']),
      updatedAt: _dateValue(map['updatedAt']),
    );
  }
}

extension AreaSerializer on Area {
  Map<String, Object?> toMap() => {
    'areaId': id,
    'tenKhuVuc': name,
    'moTa': description,
    'trangThaiHienThi': visible,
  };

  static Area fromMap(Map<String, dynamic> map) {
    return Area(
      id: _string(map['areaId']),
      name: _string(map['tenKhuVuc']),
      description: _string(map['moTa']),
      visible: _bool(map['trangThaiHienThi'], fallback: true),
    );
  }
}

extension RestaurantTableSerializer on RestaurantTable {
  Map<String, Object?> toMap() => {
    'tableId': id,
    'tenBan': name,
    'khuVucId': areaId,
    'trangThai': status.name,
    'soLuongKhach': capacity,
    'orderHienTaiId': currentOrderId,
    'ghiChu': note,
  };

  static RestaurantTable fromMap(Map<String, dynamic> map) {
    return RestaurantTable(
      id: _string(map['tableId']),
      name: _string(map['tenBan']),
      areaId: _string(map['khuVucId']),
      status: _enumValue(
        TableStatus.values,
        map['trangThai'],
        TableStatus.available,
      ),
      capacity: _int(map['soLuongKhach']),
      currentOrderId: map['orderHienTaiId'] as String?,
      note: _string(map['ghiChu']),
    );
  }
}

extension CategorySerializer on Category {
  Map<String, Object?> toMap() => {
    'categoryId': id,
    'tenDanhMuc': name,
    'moTa': description,
    'trangThaiHienThi': visible,
  };

  static Category fromMap(Map<String, dynamic> map) {
    return Category(
      id: _string(map['categoryId']),
      name: _string(map['tenDanhMuc']),
      description: _string(map['moTa']),
      visible: _bool(map['trangThaiHienThi'], fallback: true),
    );
  }
}

extension ProductSerializer on Product {
  Map<String, Object?> toMap() => {
    'productId': id,
    'tenMon': name,
    'gia': price,
    'anhUrl': imageUrl,
    'moTaNgan': shortDescription,
    'categoryId': categoryId,
    'soLuongTon': stock,
    'nguongCanhBao': warningThreshold,
    'trangThai': status.name,
    'createdAt': _dateToText(createdAt),
    'updatedAt': _dateToText(updatedAt),
  };

  static Product fromMap(Map<String, dynamic> map) {
    return Product(
      id: _string(map['productId']),
      name: _string(map['tenMon']),
      price: _int(map['gia']),
      imageUrl: _string(map['anhUrl']),
      shortDescription: _string(map['moTaNgan']),
      categoryId: _string(map['categoryId']),
      stock: _int(map['soLuongTon']),
      warningThreshold: _int(map['nguongCanhBao'], fallback: 5),
      status: _enumValue(
        ProductStatus.values,
        map['trangThai'],
        ProductStatus.available,
      ),
      createdAt: _dateValue(map['createdAt']),
      updatedAt: _dateValue(map['updatedAt']),
    );
  }
}

extension OrderItemSerializer on OrderItem {
  Map<String, Object?> toMap() => {
    'orderItemId': id,
    'productId': productId,
    'tenMon': productName,
    'soLuong': quantity,
    'donGia': unitPrice,
    'thanhTien': total,
    'ghiChuMon': note,
  };

  static OrderItem fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: _string(map['orderItemId']),
      productId: _string(map['productId']),
      productName: _string(map['tenMon']),
      quantity: _int(map['soLuong']),
      unitPrice: _int(map['donGia']),
      note: _string(map['ghiChuMon']),
    );
  }
}

extension OrderSerializer on Order {
  Map<String, Object?> toMap({bool includeItems = true}) => {
    'orderId': id,
    'tableId': tableId,
    'userId': userId,
    'tongTien': total,
    'trangThai': status.name,
    'paymentStatus': paymentStatus.name,
    'paymentMethod': paymentMethod?.name,
    'createdAt': _dateToText(createdAt),
    'updatedAt': _dateToText(updatedAt),
    'sentKitchenAt': _dateToText(sentKitchenAt),
    'completedAt': _dateToText(completedAt),
    'note': note,
    if (includeItems) 'items': items.map((item) => item.toMap()).toList(),
  };

  static Order fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return Order(
      id: _string(map['orderId']),
      tableId: _string(map['tableId']),
      userId: _string(map['userId']),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(OrderItemSerializer.fromMap)
          .toList(),
      status: _enumValue(
        OrderStatus.values,
        map['trangThai'],
        OrderStatus.pending,
      ),
      paymentStatus: _enumValue(
        PaymentStatus.values,
        map['paymentStatus'],
        PaymentStatus.waiting,
      ),
      paymentMethod: _nullableEnumValue(
        PaymentMethod.values,
        map['paymentMethod'],
      ),
      createdAt: _dateValue(map['createdAt']),
      updatedAt: _dateValue(map['updatedAt']),
      sentKitchenAt: _nullableDateValue(map['sentKitchenAt']),
      completedAt: _nullableDateValue(map['completedAt']),
      note: _string(map['note']),
    );
  }
}

extension PaymentSerializer on Payment {
  Map<String, Object?> toMap() => {
    'paymentId': id,
    'orderId': orderId,
    'tableId': tableId,
    'tongTien': amount,
    'phuongThuc': method.name,
    'qrContent': qrContent,
    'qrCreatedAt': _dateToText(createdAt),
    'qrExpiredAt': _dateToText(qrExpiredAt),
    'trangThai': status.name,
    'confirmedBy': confirmedBy,
    'paidAt': _dateToText(paidAt),
  };

  static Payment fromMap(Map<String, dynamic> map) {
    return Payment(
      id: _string(map['paymentId']),
      orderId: _string(map['orderId']),
      tableId: _string(map['tableId']),
      amount: _int(map['tongTien']),
      method: _enumValue(
        PaymentMethod.values,
        map['phuongThuc'],
        PaymentMethod.cash,
      ),
      qrContent: _string(map['qrContent']),
      createdAt: _dateValue(map['qrCreatedAt']),
      qrExpiredAt: _nullableDateValue(map['qrExpiredAt']),
      status: _enumValue(
        PaymentStatus.values,
        map['trangThai'],
        PaymentStatus.waiting,
      ),
      confirmedBy: map['confirmedBy'] as String?,
      paidAt: _nullableDateValue(map['paidAt']),
    );
  }
}

String _string(Object? value) => value?.toString() ?? '';

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _bool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

T _enumValue<T extends Enum>(List<T> values, Object? rawValue, T fallback) {
  return _nullableEnumValue(values, rawValue) ?? fallback;
}

T? _nullableEnumValue<T extends Enum>(List<T> values, Object? rawValue) {
  final name = rawValue?.toString();
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

String? _dateToText(DateTime? value) => value?.toIso8601String();

DateTime _dateValue(Object? value) =>
    _nullableDateValue(value) ?? DateTime.now();

DateTime? _nullableDateValue(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
