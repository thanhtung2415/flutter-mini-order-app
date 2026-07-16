import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class CartDraft {
  const CartDraft({required this.tableId, required this.items});

  final String tableId;
  final List<OrderItem> items;

  bool get isEmpty => items.isEmpty;
}

abstract class CartDraftStorage {
  Future<CartDraft?> loadDraft();
  Future<void> saveDraft(CartDraft draft);
  Future<void> clearDraft();
}

class SharedPreferencesCartDraftStorage implements CartDraftStorage {
  static const _key = 'mini_order_cart_draft';

  @override
  Future<CartDraft?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final tableId = data['tableId'] as String?;
      final itemsJson = data['items'] as List<dynamic>? ?? [];
      if (tableId == null || tableId.isEmpty) return null;

      final items = itemsJson
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => OrderItem(
              id: item['id'] as String? ?? '',
              productId: item['productId'] as String? ?? '',
              productName: item['productName'] as String? ?? '',
              quantity: item['quantity'] as int? ?? 0,
              unitPrice: item['unitPrice'] as int? ?? 0,
              note: item['note'] as String? ?? '',
            ),
          )
          .where((item) => item.productId.isNotEmpty && item.quantity > 0)
          .toList();

      if (items.isEmpty) return null;
      return CartDraft(tableId: tableId, items: items);
    } on FormatException {
      await clearDraft();
      return null;
    } on TypeError {
      await clearDraft();
      return null;
    }
  }

  @override
  Future<void> saveDraft(CartDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    if (draft.isEmpty) {
      await prefs.remove(_key);
      return;
    }

    await prefs.setString(
      _key,
      jsonEncode({
        'tableId': draft.tableId,
        'items': draft.items
            .map(
              (item) => {
                'id': item.id,
                'productId': item.productId,
                'productName': item.productName,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'note': item.note,
              },
            )
            .toList(),
      }),
    );
  }

  @override
  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
