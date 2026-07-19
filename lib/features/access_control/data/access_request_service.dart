import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../domain/models/app_models.dart';

enum AccessRequestStatus { pending, approved, rejected }

extension AccessRequestStatusLabel on AccessRequestStatus {
  String get label => switch (this) {
    AccessRequestStatus.pending => 'Chờ duyệt',
    AccessRequestStatus.approved => 'Đã cấp quyền',
    AccessRequestStatus.rejected => 'Đã từ chối',
  };
}

class GoogleAccessRequest {
  const GoogleAccessRequest({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.status,
    required this.requestedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.assignedRole,
  });

  final String uid;
  final String email;
  final String fullName;
  final AccessRequestStatus status;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final UserRole? assignedRole;

  static GoogleAccessRequest fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return GoogleAccessRequest(
      uid: data['uid']?.toString() ?? document.id,
      email: data['email']?.toString() ?? '',
      fullName: data['fullName']?.toString() ?? '',
      status: AccessRequestStatus.values.firstWhere(
        (item) => item.name == data['status'],
        orElse: () => AccessRequestStatus.pending,
      ),
      requestedAt:
          DateTime.tryParse(data['requestedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: DateTime.tryParse(data['reviewedAt']?.toString() ?? ''),
      reviewedBy: data['reviewedBy']?.toString(),
      assignedRole: UserRole.values
          .where((item) => item.name == data['assignedRole'])
          .firstOrNull,
    );
  }
}

abstract class AccessRequestService {
  Future<AccessRequestStatus> requestGoogleAccess();

  Stream<List<GoogleAccessRequest>> watchRequests();

  Future<void> reviewRequest({
    required String uid,
    required bool approved,
    required UserRole role,
    required String shift,
  });
}

class AccessRequestFailure implements Exception {
  const AccessRequestFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirebaseAccessRequestService implements AccessRequestService {
  FirebaseAccessRequestService(this._functions, this._firestore);

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  @override
  Future<AccessRequestStatus> requestGoogleAccess() async {
    final data = await _call('requestGoogleAccess', const {});
    final status = data['status']?.toString();
    return AccessRequestStatus.values.firstWhere(
      (item) => item.name == status,
      orElse: () => AccessRequestStatus.pending,
    );
  }

  @override
  Stream<List<GoogleAccessRequest>> watchRequests() {
    return _firestore
        .collection('access_requests')
        .orderBy('requestedAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(GoogleAccessRequest.fromDocument)
              .toList(growable: false),
        );
  }

  @override
  Future<void> reviewRequest({
    required String uid,
    required bool approved,
    required UserRole role,
    required String shift,
  }) async {
    await _call('adminReviewGoogleAccess', {
      'uid': uid,
      'decision': approved ? 'approved' : 'rejected',
      'role': role.name,
      'shift': shift.trim(),
    });
  }

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
      throw AccessRequestFailure(
        error.message ?? 'Không thể xử lý yêu cầu cấp quyền Google.',
      );
    } catch (_) {
      throw const AccessRequestFailure(
        'Không thể kết nối dịch vụ cấp quyền Google.',
      );
    }
  }
}
