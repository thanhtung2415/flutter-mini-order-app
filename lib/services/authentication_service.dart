import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthenticatedIdentity {
  const AuthenticatedIdentity({required this.uid, required this.email});

  final String uid;
  final String email;
}

abstract class AuthenticationService {
  Future<AuthenticatedIdentity> signIn({
    required String email,
    required String password,
  });

  Future<AuthenticatedIdentity> signInWithGoogle();

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}

class AuthenticationFailure implements Exception {
  const AuthenticationFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class FirebaseAuthenticationService implements AuthenticationService {
  FirebaseAuthenticationService(this._auth);

  final FirebaseAuth _auth;
  bool _googleInitialized = false;

  @override
  Future<AuthenticatedIdentity> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth
          .signInWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 12));
      final firebaseUser = result.user;
      final authenticatedEmail = firebaseUser?.email;
      if (firebaseUser == null || authenticatedEmail == null) {
        await _auth.signOut();
        throw const AuthenticationFailure(
          'Firebase không trả về thông tin tài khoản hợp lệ.',
          code: 'firebase-user-missing',
        );
      }
      return AuthenticatedIdentity(
        uid: firebaseUser.uid,
        email: authenticatedEmail.trim(),
      );
    } on TimeoutException {
      throw const AuthenticationFailure(
        'Firebase phản hồi quá lâu. Đang chuyển sang chế độ demo offline.',
        code: 'network-timeout',
      );
    } on FirebaseAuthException catch (error) {
      throw AuthenticationFailure(
        _messageForCode(error.code),
        code: error.code,
      );
    } on AuthenticationFailure {
      rethrow;
    }
  }

  @override
  Future<AuthenticatedIdentity> signInWithGoogle() async {
    try {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize();
        _googleInitialized = true;
      }
      final googleUser = await GoogleSignIn.instance.authenticate().timeout(
        const Duration(seconds: 20),
      );
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthenticationFailure(
          'Google không trả về mã xác thực hợp lệ.',
          code: 'google-token-missing',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 12));
      final firebaseUser = result.user;
      final email = firebaseUser?.email ?? googleUser.email;
      if (firebaseUser == null || email.trim().isEmpty) {
        await _auth.signOut();
        throw const AuthenticationFailure(
          'Tài khoản Google không cung cấp email hợp lệ.',
          code: 'google-email-missing',
        );
      }
      return AuthenticatedIdentity(uid: firebaseUser.uid, email: email.trim());
    } on TimeoutException {
      throw const AuthenticationFailure(
        'Google phản hồi quá lâu. Vui lòng kiểm tra kết nối mạng.',
        code: 'network-timeout',
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthenticationFailure(
          'Bạn đã hủy đăng nhập Google.',
          code: 'google-cancelled',
        );
      }
      throw AuthenticationFailure(
        error.code == GoogleSignInExceptionCode.clientConfigurationError ||
                error.code ==
                    GoogleSignInExceptionCode.providerConfigurationError
            ? 'Google Sign-In chưa được cấu hình đúng trên Firebase.'
            : 'Không thể đăng nhập Google. Vui lòng thử lại.',
        code: error.code.name,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthenticationFailure(
        _messageForCode(error.code),
        code: error.code,
      );
    } on AuthenticationFailure {
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth
          .sendPasswordResetEmail(email: email.trim())
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const AuthenticationFailure(
        'Firebase phản hồi quá lâu. Vui lòng thử lại.',
        code: 'network-timeout',
      );
    } on FirebaseAuthException catch (error) {
      throw AuthenticationFailure(switch (error.code) {
        'invalid-email' => 'Email không đúng định dạng.',
        'too-many-requests' =>
          'Bạn đã yêu cầu quá nhiều lần. Vui lòng thử lại sau.',
        'network-request-failed' =>
          'Không có kết nối mạng để gửi email đặt lại mật khẩu.',
        'operation-not-allowed' =>
          'Firebase chưa bật phương thức đăng nhập Email/Password.',
        _ => 'Không thể gửi email đặt lại mật khẩu. Vui lòng thử lại.',
      }, code: error.code);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } on GoogleSignInException {
        // Firebase has already ended the application session.
      }
    }
  }

  String _messageForCode(String code) {
    return switch (code) {
      'invalid-email' => 'Email không đúng định dạng.',
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => 'Sai email hoặc mật khẩu.',
      'user-disabled' => 'Tài khoản Firebase đã bị vô hiệu hóa.',
      'too-many-requests' =>
        'Đăng nhập sai quá nhiều lần. Vui lòng thử lại sau.',
      'network-request-failed' =>
        'Không có kết nối mạng để đăng nhập Firebase.',
      'operation-not-allowed' =>
        'Firebase chưa bật phương thức đăng nhập Email/Password.',
      _ => 'Không thể đăng nhập Firebase. Vui lòng thử lại.',
    };
  }
}
