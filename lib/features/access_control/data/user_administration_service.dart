import 'package:cloud_functions/cloud_functions.dart';

import '../../../domain/models/app_models.dart';

abstract class UserAdministrationService {
  Future<String> createUser({
    required AppUser user,
    required String temporaryPassword,
  });

  Future<void> updateUser(AppUser user);

  Future<void> setUserDisabled({required String uid, required bool disabled});

  Future<void> deleteUser(String uid);
}

class UserAdministrationFailure implements Exception {
  const UserAdministrationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirebaseUserAdministrationService implements UserAdministrationService {
  FirebaseUserAdministrationService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<String> createUser({
    required AppUser user,
    required String temporaryPassword,
  }) async {
    final data = await _call('adminCreateUser', {
      ..._profileData(user),
      'password': temporaryPassword,
    });
    final uid = data['uid']?.toString() ?? '';
    if (uid.isEmpty) {
      throw const UserAdministrationFailure(
        'Firebase không trả về UID của tài khoản mới.',
      );
    }
    return uid;
  }

  @override
  Future<void> updateUser(AppUser user) async {
    await _call('adminUpdateUser', {..._profileData(user), 'uid': user.id});
  }

  @override
  Future<void> setUserDisabled({
    required String uid,
    required bool disabled,
  }) async {
    await _call('adminSetUserDisabled', {'uid': uid, 'disabled': disabled});
  }

  @override
  Future<void> deleteUser(String uid) async {
    await _call('adminDeleteUser', {'uid': uid});
  }

  Map<String, Object?> _profileData(AppUser user) => {
    'employeeCode': user.employeeCode,
    'fullName': user.fullName,
    'email': user.email.trim(),
    'phone': user.phone,
    'username': user.username,
    'role': user.role.name,
    'shift': user.shift,
  };

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, Object?> parameters,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(functionName)
          .call<Map<String, dynamic>>(parameters);
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (error) {
      throw UserAdministrationFailure(
        error.message ?? 'Không thể cập nhật Firebase Authentication.',
      );
    } catch (_) {
      throw const UserAdministrationFailure(
        'Không thể kết nối dịch vụ quản lý tài khoản Firebase.',
      );
    }
  }
}
