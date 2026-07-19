import 'dart:convert';
import 'dart:typed_data';

class ProductImageLocalService {
  String buildDataUrl({required Uint8List bytes, String? contentType}) {
    final type = _safeContentType(contentType);
    return 'data:$type;base64,${base64Encode(bytes)}';
  }

  static Uint8List? tryDecodeDataUrl(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('data:image/') || !trimmed.contains(';base64,')) {
      return null;
    }

    final payload = trimmed.split(';base64,').last;
    try {
      return base64Decode(payload);
    } on FormatException {
      return null;
    }
  }

  String _safeContentType(String? contentType) {
    final value = contentType?.trim().toLowerCase();
    if (value != null && value.startsWith('image/')) return value;
    return 'image/jpeg';
  }
}
