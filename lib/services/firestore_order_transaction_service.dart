import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/app_models.dart';
import '../models/model_serializers.dart';

abstract class OrderTransactionService {
  Future<void> createOrder(Order order);

  Future<void> appendItemsToOrder({
    required Order order,
    required List<OrderItem> items,
    required String note,
  });

  Future<void> transferOrder({
    required Order order,
    required RestaurantTable sourceTable,
    required RestaurantTable targetTable,
    required List<Payment> waitingPayments,
  });

  Future<void> createPayment(Payment payment);

  Future<void> confirmPayment({
    required Payment payment,
    required String confirmedBy,
  });
}

class OrderTransactionFailure implements Exception {
  const OrderTransactionFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class FirestoreOrderTransactionService implements OrderTransactionService {
  FirestoreOrderTransactionService(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> createOrder(Order order) async {
    final orderRef = _firestore.collection('orders').doc(order.id);
    final tableRef = _firestore.collection('tables').doc(order.tableId);
    final productRefs = {
      for (final item in order.items)
        item.productId: _firestore.collection('products').doc(item.productId),
    };

    try {
      await _firestore.runTransaction((transaction) async {
        final tableSnapshot = await transaction.get(tableRef);
        final productSnapshots =
            <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final entry in productRefs.entries) {
          productSnapshots[entry.key] = await transaction.get(entry.value);
        }

        final tableData = tableSnapshot.data();
        if (!tableSnapshot.exists || tableData == null) {
          throw const OrderTransactionFailure(
            'Không tìm thấy bàn trên Firestore.',
          );
        }
        final currentOrderId = tableData['orderHienTaiId']?.toString();
        if (tableData['trangThai'] != TableStatus.available.name ||
            (currentOrderId != null && currentOrderId.isNotEmpty)) {
          throw const OrderTransactionFailure(
            'Bàn vừa được thiết bị khác nhận order.',
          );
        }

        final remainingStocks = <String, int>{};
        for (final item in order.items) {
          final snapshot = productSnapshots[item.productId];
          final data = snapshot?.data();
          final stock = (data?['soLuongTon'] as num?)?.toInt() ?? -1;
          if (snapshot == null || !snapshot.exists || stock < item.quantity) {
            throw OrderTransactionFailure(
              'Tồn kho ${item.productName} vừa thay đổi, vui lòng kiểm tra lại.',
              code: 'stock-changed',
            );
          }
          remainingStocks[item.productId] = stock - item.quantity;
        }

        transaction.set(orderRef, order.toMap());
        for (final entry in productRefs.entries) {
          final remaining = remainingStocks[entry.key]!;
          transaction.update(entry.value, {
            'soLuongTon': remaining,
            'trangThai': remaining <= 0
                ? ProductStatus.soldOut.name
                : ProductStatus.available.name,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
        transaction.update(tableRef, {
          'trangThai': TableStatus.ordering.name,
          'orderHienTaiId': order.id,
        });
      });
    } on OrderTransactionFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw OrderTransactionFailure(
        error.message ?? 'Không thể tạo order an toàn trên Firestore.',
      );
    }
  }

  @override
  Future<void> appendItemsToOrder({
    required Order order,
    required List<OrderItem> items,
    required String note,
  }) async {
    final orderRef = _firestore.collection('orders').doc(order.id);
    final tableRef = _firestore.collection('tables').doc(order.tableId);
    final productRefs = {
      for (final item in items)
        item.productId: _firestore.collection('products').doc(item.productId),
    };

    try {
      await _firestore.runTransaction((transaction) async {
        final orderSnapshot = await transaction.get(orderRef);
        final tableSnapshot = await transaction.get(tableRef);
        final productSnapshots =
            <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final entry in productRefs.entries) {
          productSnapshots[entry.key] = await transaction.get(entry.value);
        }

        final remoteOrder = orderSnapshot.data();
        final remoteTable = tableSnapshot.data();
        if (remoteOrder == null || remoteTable == null) {
          throw const OrderTransactionFailure(
            'Không tìm thấy order hoặc bàn trên Firestore.',
          );
        }
        if (remoteTable['orderHienTaiId'] != order.id ||
            remoteOrder['tableId'] != order.tableId ||
            remoteOrder['trangThai'] == OrderStatus.paid.name ||
            remoteOrder['trangThai'] == OrderStatus.cancelled.name) {
          throw const OrderTransactionFailure(
            'Order của bàn đã thay đổi; vui lòng tải lại dữ liệu.',
          );
        }

        DocumentReference<Map<String, dynamic>>? pendingPaymentRef;
        DocumentSnapshot<Map<String, dynamic>>? pendingPaymentSnapshot;
        final pendingPaymentId = remoteOrder['pendingPaymentId']?.toString();
        if (pendingPaymentId != null && pendingPaymentId.isNotEmpty) {
          pendingPaymentRef = _firestore
              .collection('payments')
              .doc(pendingPaymentId);
          pendingPaymentSnapshot = await transaction.get(pendingPaymentRef);
        }

        final remainingStocks = <String, int>{};
        for (final item in items) {
          final snapshot = productSnapshots[item.productId];
          final data = snapshot?.data();
          final stock = (data?['soLuongTon'] as num?)?.toInt() ?? -1;
          if (snapshot == null || !snapshot.exists || stock < item.quantity) {
            throw OrderTransactionFailure(
              'Tồn kho ${item.productName} vừa thay đổi, vui lòng kiểm tra lại.',
              code: 'stock-changed',
            );
          }
          remainingStocks[item.productId] = stock - item.quantity;
        }

        final remoteStatus = remoteOrder['trangThai']?.toString();
        final legacyKitchenBatchId = 'legacy_${order.id}';
        final existingItems =
            (remoteOrder['items'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<Map>()
                .map((rawItem) {
                  final item = Map<String, dynamic>.from(rawItem);
                  final batchId = item['kitchenBatchId']?.toString() ?? '';
                  if (batchId.isEmpty &&
                      remoteStatus != OrderStatus.pending.name) {
                    item['kitchenBatchId'] = legacyKitchenBatchId;
                  }
                  return item;
                })
                .toList(growable: false);
        final existingNote = remoteOrder['note']?.toString().trim() ?? '';
        final addedNote = note.trim();
        final nextNote = addedNote.isEmpty
            ? existingNote
            : existingNote.isEmpty
            ? addedNote
            : '$existingNote\n$addedNote';
        final addedTotal = items.fold<int>(
          0,
          (total, item) => total + item.total,
        );
        final now = DateTime.now().toIso8601String();

        transaction.update(orderRef, {
          'items': [...existingItems, ...items.map((item) => item.toMap())],
          'tongTien':
              ((remoteOrder['tongTien'] as num?)?.toInt() ?? 0) + addedTotal,
          'trangThai': OrderStatus.pending.name,
          'updatedAt': now,
          'sentKitchenAt': null,
          'completedAt': null,
          'pendingPaymentId': null,
          'note': nextNote,
        });
        for (final entry in productRefs.entries) {
          final remaining = remainingStocks[entry.key]!;
          transaction.update(entry.value, {
            'soLuongTon': remaining,
            'trangThai': remaining <= 0
                ? ProductStatus.soldOut.name
                : ProductStatus.available.name,
            'updatedAt': now,
          });
        }
        if (pendingPaymentRef != null &&
            pendingPaymentSnapshot?.data()?['trangThai'] ==
                PaymentStatus.waiting.name) {
          transaction.update(pendingPaymentRef, {
            'trangThai': PaymentStatus.expired.name,
          });
        }
      });
    } on OrderTransactionFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw OrderTransactionFailure(
        error.message ?? 'Không thể thêm món vào order an toàn.',
      );
    }
  }

  @override
  Future<void> transferOrder({
    required Order order,
    required RestaurantTable sourceTable,
    required RestaurantTable targetTable,
    required List<Payment> waitingPayments,
  }) async {
    final orderRef = _firestore.collection('orders').doc(order.id);
    final sourceRef = _firestore.collection('tables').doc(sourceTable.id);
    final targetRef = _firestore.collection('tables').doc(targetTable.id);
    final paymentRefs = {
      for (final payment in waitingPayments)
        payment.id: _firestore.collection('payments').doc(payment.id),
    };

    try {
      await _firestore.runTransaction((transaction) async {
        final orderSnapshot = await transaction.get(orderRef);
        final sourceSnapshot = await transaction.get(sourceRef);
        final targetSnapshot = await transaction.get(targetRef);
        final paymentSnapshots =
            <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final entry in paymentRefs.entries) {
          paymentSnapshots[entry.key] = await transaction.get(entry.value);
        }

        final remoteOrder = orderSnapshot.data();
        final remoteSource = sourceSnapshot.data();
        final remoteTarget = targetSnapshot.data();
        if (remoteOrder == null ||
            remoteSource == null ||
            remoteTarget == null) {
          throw const OrderTransactionFailure(
            'Dữ liệu chuyển bàn không còn tồn tại.',
          );
        }
        if (remoteOrder['tableId'] != sourceTable.id ||
            remoteSource['orderHienTaiId'] != order.id) {
          throw const OrderTransactionFailure(
            'Order đã được thiết bị khác chuyển sang bàn khác.',
          );
        }
        final targetOrderId = remoteTarget['orderHienTaiId']?.toString();
        if (remoteTarget['trangThai'] != TableStatus.available.name ||
            (targetOrderId != null && targetOrderId.isNotEmpty)) {
          throw const OrderTransactionFailure(
            'Bàn nhận vừa được thiết bị khác sử dụng.',
          );
        }

        transaction.update(orderRef, {
          'tableId': targetTable.id,
          'updatedAt': DateTime.now().toIso8601String(),
          'pendingPaymentId': null,
        });
        transaction.update(sourceRef, {
          'trangThai': TableStatus.available.name,
          'orderHienTaiId': null,
          'ghiChu': '',
        });
        transaction.update(targetRef, {
          'trangThai': TableStatus.ordering.name,
          'orderHienTaiId': order.id,
        });
        for (final entry in paymentRefs.entries) {
          if (paymentSnapshots[entry.key]?.data()?['trangThai'] ==
              PaymentStatus.waiting.name) {
            transaction.update(entry.value, {
              'trangThai': PaymentStatus.expired.name,
            });
          }
        }
      });
    } on OrderTransactionFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw OrderTransactionFailure(
        error.message ?? 'Không thể chuyển bàn an toàn trên Firestore.',
      );
    }
  }

  @override
  Future<void> createPayment(Payment payment) async {
    final paymentRef = _firestore.collection('payments').doc(payment.id);
    final orderRef = _firestore.collection('orders').doc(payment.orderId);
    final tableRef = _firestore.collection('tables').doc(payment.tableId);

    try {
      await _firestore.runTransaction((transaction) async {
        final orderSnapshot = await transaction.get(orderRef);
        final tableSnapshot = await transaction.get(tableRef);
        final remoteOrder = orderSnapshot.data();
        final remoteTable = tableSnapshot.data();
        if (remoteOrder == null || remoteTable == null) {
          throw const OrderTransactionFailure(
            'Không tìm thấy order cần thanh toán.',
          );
        }
        final pendingPaymentId = remoteOrder['pendingPaymentId']?.toString();
        DocumentReference<Map<String, dynamic>>? pendingPaymentRef;
        DocumentSnapshot<Map<String, dynamic>>? pendingPaymentSnapshot;
        if (pendingPaymentId != null && pendingPaymentId.isNotEmpty) {
          pendingPaymentRef = _firestore
              .collection('payments')
              .doc(pendingPaymentId);
          pendingPaymentSnapshot = await transaction.get(pendingPaymentRef);
        }
        if (remoteOrder['trangThai'] == OrderStatus.paid.name ||
            remoteOrder['trangThai'] == OrderStatus.cancelled.name ||
            remoteOrder['tableId'] != payment.tableId ||
            remoteOrder['tongTien'] != payment.amount ||
            remoteTable['orderHienTaiId'] != payment.orderId) {
          throw const OrderTransactionFailure(
            'Order hoặc bàn đã thay đổi; vui lòng tải lại dữ liệu.',
          );
        }

        if (pendingPaymentRef != null &&
            pendingPaymentSnapshot?.data()?['trangThai'] ==
                PaymentStatus.waiting.name) {
          transaction.update(pendingPaymentRef, {
            'trangThai': PaymentStatus.expired.name,
          });
        }
        transaction.set(paymentRef, payment.toMap());
        transaction.update(orderRef, {
          'pendingPaymentId': payment.id,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      });
    } on OrderTransactionFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw OrderTransactionFailure(
        error.message ?? 'Không thể tạo thanh toán an toàn.',
      );
    }
  }

  @override
  Future<void> confirmPayment({
    required Payment payment,
    required String confirmedBy,
  }) async {
    final paymentRef = _firestore.collection('payments').doc(payment.id);
    final orderRef = _firestore.collection('orders').doc(payment.orderId);
    final tableRef = _firestore.collection('tables').doc(payment.tableId);

    try {
      await _firestore.runTransaction((transaction) async {
        final paymentSnapshot = await transaction.get(paymentRef);
        final orderSnapshot = await transaction.get(orderRef);
        final tableSnapshot = await transaction.get(tableRef);
        final remotePayment = paymentSnapshot.data();
        final remoteOrder = orderSnapshot.data();
        final remoteTable = tableSnapshot.data();
        if (remotePayment == null ||
            remoteOrder == null ||
            remoteTable == null) {
          throw const OrderTransactionFailure(
            'Dữ liệu thanh toán không đầy đủ.',
          );
        }
        if (remotePayment['trangThai'] != PaymentStatus.waiting.name) {
          throw const OrderTransactionFailure(
            'Thanh toán đã được thiết bị khác xử lý.',
          );
        }
        if (remoteOrder['trangThai'] == OrderStatus.paid.name ||
            remoteOrder['trangThai'] == OrderStatus.cancelled.name ||
            remoteOrder['tableId'] != payment.tableId ||
            remoteOrder['tongTien'] != payment.amount ||
            remoteTable['orderHienTaiId'] != payment.orderId) {
          throw const OrderTransactionFailure(
            'Order hoặc bàn đã thay đổi; vui lòng tải lại dữ liệu.',
          );
        }

        final paidAt = DateTime.now().toIso8601String();
        transaction.update(paymentRef, {
          'trangThai': PaymentStatus.paid.name,
          'confirmedBy': confirmedBy,
          'paidAt': paidAt,
        });
        transaction.update(orderRef, {
          'trangThai': OrderStatus.paid.name,
          'paymentStatus': PaymentStatus.paid.name,
          'paymentMethod': payment.method.name,
          'updatedAt': paidAt,
          'pendingPaymentId': null,
        });
        transaction.update(tableRef, {'trangThai': TableStatus.paid.name});
      });
    } on OrderTransactionFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw OrderTransactionFailure(
        error.message ?? 'Không thể xác nhận thanh toán an toàn.',
      );
    }
  }
}
