part of '../app_state.dart';

extension AppStatePaymentActions on AppState {
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
    _notify();
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
      _notify();
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
      _notify();
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
    // Trạng thái đã được cập nhật qua repository/realtime. Không phát snackbar
    // thành công khi quay lại màn trước vì thông báo này dễ bị hiểu nhầm là
    // một sự kiện realtime lặp lại trên thiết bị khác.
    _message = null;
    _error = null;
    _notify();
    return true;
  }

  Future<bool> clearTable(String tableId) async {
    final table = repository.findTable(tableId);
    if (table == null) {
      _setError('Không tìm thấy bàn.');
      return false;
    }
    if (table.status != TableStatus.paid) {
      _setError('Chỉ dọn bàn sau khi đã thanh toán.');
      return false;
    }
    final transactions = orderTransactionService;
    if (transactions != null) {
      try {
        await transactions.clearPaidTable(table);
      } on OrderTransactionFailure catch (error) {
        _setError(error.message);
        return false;
      }
    }

    _mutateAfterRemoteCommit(transactions != null, () {
      repository.upsertTable(
        table.copyWith(
          status: TableStatus.available,
          clearCurrentOrder: true,
          note: '',
        ),
      );
    });
    if (transactions == null && repository is PersistentOrderRepository) {
      try {
        await (repository as PersistentOrderRepository).persistNow();
      } catch (_) {
        _setError('Không thể đồng bộ trạng thái dọn bàn. Vui lòng thử lại.');
        return false;
      }
    }
    _message = '${table.name} đã sẵn sàng nhận khách mới.';
    _error = null;
    _notify();
    return true;
  }
}
