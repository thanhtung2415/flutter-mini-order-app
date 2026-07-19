part of '../app_state.dart';

extension AppStateAdminActions on AppState {
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
    _notify();
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
    _notify();
    return true;
  }

  Future<bool> deleteUser(String id) async {
    if (!_requireAdmin()) return false;
    if (id == _currentUser?.id) {
      _setError('Không thể xóa tài khoản đang đăng nhập.');
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
    _notify();
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
    _notify();
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
    _notify();
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
    _notify();
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
    _notify();
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
    _notify();
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
    _notify();
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
    _notify();
    return true;
  }

  bool deleteProduct(String id) {
    if (!_requireAdmin()) return false;
    repository.deleteProduct(id);
    _reconcileCartWithStock();
    _message = 'Đã xóa món.';
    _error = null;
    _notify();
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
    _notify();
    return true;
  }
}
