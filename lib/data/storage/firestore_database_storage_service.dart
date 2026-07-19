import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'local_database_storage_service.dart';

class SynchronizedDatabaseStorage
    implements LocalDatabaseStorage, RealtimeDatabaseStorage {
  SynchronizedDatabaseStorage({required this.local, required this.remote});

  final LocalDatabaseStorage local;
  final LocalDatabaseStorage remote;

  @override
  Future<Map<String, dynamic>?> loadSnapshot() async {
    final localSnapshot = await local.loadSnapshot();
    try {
      final remoteSnapshot = await remote.loadSnapshot().timeout(
        const Duration(seconds: 6),
      );
      if (remoteSnapshot != null) {
        await local.saveSnapshot(remoteSnapshot);
        return remoteSnapshot;
      }
      if (localSnapshot != null) {
        await remote
            .saveSnapshot(localSnapshot)
            .timeout(const Duration(seconds: 8));
      }
    } catch (_) {
      // Local data remains the fallback when cloud sync is unavailable.
    }
    return localSnapshot;
  }

  @override
  Future<void> saveSnapshot(Map<String, Object?> snapshot) async {
    await local.saveSnapshot(snapshot);
    try {
      await remote.saveSnapshot(snapshot).timeout(const Duration(seconds: 8));
    } catch (_) {
      // The latest local snapshot will be uploaded after the next login.
    }
  }

  @override
  Future<void> clearSnapshot() async {
    await local.clearSnapshot();
    try {
      await remote.clearSnapshot().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Clearing local data must still work while offline.
    }
  }

  @override
  Stream<void> watchRemoteChanges() {
    final remoteStorage = remote;
    if (remoteStorage is RealtimeDatabaseStorage) {
      return (remoteStorage as RealtimeDatabaseStorage).watchRemoteChanges();
    }
    return const Stream<void>.empty();
  }
}

class FirestoreDatabaseStorage
    implements LocalDatabaseStorage, RealtimeDatabaseStorage {
  FirestoreDatabaseStorage(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const _collections = <String, String>{
    'users': 'userId',
    'areas': 'areaId',
    'tables': 'tableId',
    'categories': 'categoryId',
    'products': 'productId',
    'orders': 'orderId',
    'payments': 'paymentId',
  };

  // User documents are managed only by privileged Cloud Functions so a
  // normal client can never create a Firestore-only account by mistake.
  static final _clientWritableCollections = Map<String, String>.fromEntries(
    _collections.entries.where((entry) => entry.key != 'users'),
  );

  bool get _isAuthenticated => _auth.currentUser != null;

  @override
  Future<Map<String, dynamic>?> loadSnapshot() async {
    if (!_isAuthenticated) return null;

    final entries = await Future.wait(
      _collections.keys.map((name) async {
        final query = await _firestore.collection(name).get();
        return MapEntry(
          name,
          query.docs.map((document) => document.data()).toList(),
        );
      }),
    );
    final values = Map<String, dynamic>.fromEntries(entries);
    if ((values['users'] as List<dynamic>).isEmpty) return null;

    final metadata = await _firestore
        .collection('app_metadata')
        .doc('main')
        .get();
    values['version'] = metadata.data()?['version'] ?? 1;
    values['savedAt'] = metadata.data()?['savedAt'];
    return values;
  }

  @override
  Future<void> saveSnapshot(Map<String, Object?> snapshot) async {
    if (!_isAuthenticated) return;

    final existingEntries = await Future.wait(
      _clientWritableCollections.keys.map((name) async {
        final query = await _firestore.collection(name).get();
        return MapEntry(name, query.docs.map((doc) => doc.id).toSet());
      }),
    );
    final existingIds = Map<String, Set<String>>.fromEntries(existingEntries);
    final batch = _firestore.batch();

    for (final entry in _clientWritableCollections.entries) {
      final collectionName = entry.key;
      final idField = entry.value;
      final rawItems = snapshot[collectionName] as List<dynamic>? ?? const [];
      final nextIds = <String>{};

      for (final rawItem in rawItems.whereType<Map>()) {
        final item = Map<String, dynamic>.from(rawItem);
        final id = item[idField]?.toString() ?? '';
        if (id.isEmpty) continue;
        nextIds.add(id);
        batch.set(_firestore.collection(collectionName).doc(id), item);
      }

      for (final staleId in existingIds[collectionName]!.difference(nextIds)) {
        batch.delete(_firestore.collection(collectionName).doc(staleId));
      }
    }

    batch.set(_firestore.collection('app_metadata').doc('main'), {
      'version': snapshot['version'] ?? 1,
      'savedAt': snapshot['savedAt'] ?? DateTime.now().toIso8601String(),
      'updatedBy': _auth.currentUser?.email,
    });
    await batch.commit();
  }

  @override
  Future<void> clearSnapshot() async {
    if (!_isAuthenticated) return;
    final batch = _firestore.batch();
    for (final collectionName in _clientWritableCollections.keys) {
      final query = await _firestore.collection(collectionName).get();
      for (final document in query.docs) {
        batch.delete(document.reference);
      }
    }
    batch.delete(_firestore.collection('app_metadata').doc('main'));
    await batch.commit();
  }

  @override
  Stream<void> watchRemoteChanges() {
    late final StreamController<void> controller;
    final subscriptions = <StreamSubscription<Object?>>[];
    Timer? debounce;

    void scheduleRefresh() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 450), () {
        if (!controller.isClosed) controller.add(null);
      });
    }

    controller = StreamController<void>(
      onListen: () {
        for (final collectionName in _collections.keys) {
          subscriptions.add(
            _firestore
                .collection(collectionName)
                .snapshots()
                .listen((_) => scheduleRefresh(), onError: controller.addError),
          );
        }
        subscriptions.add(
          _firestore
              .collection('app_metadata')
              .snapshots()
              .listen((_) => scheduleRefresh(), onError: controller.addError),
        );
      },
      onCancel: () async {
        debounce?.cancel();
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );
      },
    );
    return controller.stream;
  }
}
