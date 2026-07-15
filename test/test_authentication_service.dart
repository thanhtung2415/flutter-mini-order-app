import 'package:mini_order_app/models/app_models.dart';
import 'package:mini_order_app/services/access_request_service.dart';
import 'package:mini_order_app/services/authentication_service.dart';

class TestAuthenticationService implements AuthenticationService {
  String? passwordResetEmail;

  @override
  Future<AuthenticatedIdentity> signIn({
    required String email,
    required String password,
  }) async {
    const idsByEmail = {
      'admin@miniorder.vn': 'u_admin',
      'staff@miniorder.vn': 'u_staff',
      'staff2@miniorder.vn': 'u_staff_2',
    };
    final uid = idsByEmail[email];
    if (uid == null || password != '123456') {
      throw const AuthenticationFailure('Sai email hoặc mật khẩu.');
    }
    return AuthenticatedIdentity(uid: uid, email: email);
  }

  @override
  Future<AuthenticatedIdentity> signInWithGoogle() async {
    return const AuthenticatedIdentity(
      uid: 'u_admin',
      email: 'admin@miniorder.vn',
    );
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    passwordResetEmail = email;
  }

  @override
  Future<void> signOut() async {}
}

class NewGoogleAuthenticationService implements AuthenticationService {
  var signedOut = false;

  @override
  Future<AuthenticatedIdentity> signIn({
    required String email,
    required String password,
  }) async {
    throw const AuthenticationFailure('Không hỗ trợ trong test này.');
  }

  @override
  Future<AuthenticatedIdentity> signInWithGoogle() async {
    return const AuthenticatedIdentity(
      uid: 'new_google_uid',
      email: 'new.user@gmail.com',
    );
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

class TestAccessRequestService implements AccessRequestService {
  var requested = false;

  @override
  Future<AccessRequestStatus> requestGoogleAccess() async {
    requested = true;
    return AccessRequestStatus.pending;
  }

  @override
  Stream<List<GoogleAccessRequest>> watchRequests() => const Stream.empty();

  @override
  Future<void> reviewRequest({
    required String uid,
    required bool approved,
    required UserRole role,
    required String shift,
  }) async {}
}
