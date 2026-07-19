import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_order_app/features/catalog/data/product_image_local_service.dart';

void main() {
  test('builds and decodes local product image data URLs', () {
    final service = ProductImageLocalService();
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    final dataUrl = service.buildDataUrl(
      bytes: bytes,
      contentType: 'image/png',
    );
    final decoded = ProductImageLocalService.tryDecodeDataUrl(dataUrl);

    expect(dataUrl, startsWith('data:image/png;base64,'));
    expect(decoded, bytes);
    expect(
      ProductImageLocalService.tryDecodeDataUrl('https://x.test/a.png'),
      isNull,
    );
  });
}
