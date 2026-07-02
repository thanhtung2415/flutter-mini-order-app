import 'package:flutter_test/flutter_test.dart';
import 'package:mini_order_app/models/app_models.dart';
import 'package:mini_order_app/models/model_serializers.dart';

void main() {
  test('serializes product using SRS field names', () {
    final now = DateTime(2026, 7, 1, 10, 30);
    final product = Product(
      id: 'P100',
      name: 'Nước ép cam',
      price: 32000,
      imageUrl: 'https://example.com/cam.jpg',
      shortDescription: 'Cam tươi',
      categoryId: 'c_drink',
      stock: 12,
      warningThreshold: 5,
      status: ProductStatus.available,
      createdAt: now,
      updatedAt: now,
    );

    final map = product.toMap();
    final restored = ProductSerializer.fromMap(map);

    expect(map['tenMon'], 'Nước ép cam');
    expect(map['soLuongTon'], 12);
    expect(restored.id, product.id);
    expect(restored.imageUrl, product.imageUrl);
    expect(restored.status, product.status);
  });

  test('round-trips order with nested items', () {
    final now = DateTime(2026, 7, 1, 11);
    final order = Order(
      id: 'ord_1',
      tableId: 't01',
      userId: 'u_staff',
      items: const [
        OrderItem(
          id: 'item_1',
          productId: 'P001',
          productName: 'Cà phê sữa',
          quantity: 2,
          unitPrice: 25000,
        ),
      ],
      status: OrderStatus.preparing,
      paymentStatus: PaymentStatus.waiting,
      createdAt: now,
      updatedAt: now,
      sentKitchenAt: now,
      note: 'Ít đá',
    );

    final restored = OrderSerializer.fromMap(order.toMap());

    expect(restored.id, order.id);
    expect(restored.total, 50000);
    expect(restored.items.single.productName, 'Cà phê sữa');
    expect(restored.status, OrderStatus.preparing);
  });
}
