class PaymentQrConfig {
  const PaymentQrConfig._();

  static const bankId = 'MB';
  static const bankName = 'MB Bank';
  static const accountNumber = '0000000000';
  static const accountName = 'MiniOrderApp';

  static Uri buildImageUri({required int amount, required String orderId}) {
    return Uri.https(
      'img.vietqr.io',
      '/image/$bankId-$accountNumber-compact2.png',
      {
        'amount': '$amount',
        'addInfo': transferContent(orderId),
        'accountName': accountName.toUpperCase(),
      },
    );
  }

  static String transferContent(String orderId) {
    final normalized = orderId
        .replaceAll(RegExp('[^A-Za-z0-9]'), '')
        .toUpperCase();
    final suffix = normalized.length <= 15
        ? normalized
        : normalized.substring(normalized.length - 15);
    return 'MINIORDER $suffix';
  }
}
