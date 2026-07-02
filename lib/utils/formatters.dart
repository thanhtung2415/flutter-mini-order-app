import 'package:intl/intl.dart';

final _currencyFormatter = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: 'đ',
  decimalDigits: 0,
);

final _dateTimeFormatter = DateFormat('HH:mm dd/MM/yyyy', 'vi_VN');
final _shortDateFormatter = DateFormat('dd/MM/yyyy', 'vi_VN');
final _timeFormatter = DateFormat('HH:mm', 'vi_VN');

String money(num value) => _currencyFormatter.format(value);

String dateTimeText(DateTime value) => _dateTimeFormatter.format(value);

String shortDate(DateTime value) => _shortDateFormatter.format(value);

String timeText(DateTime value) => _timeFormatter.format(value);

String remainingQrTime(DateTime? expiredAt) {
  if (expiredAt == null) return '--:--';
  final remaining = expiredAt.difference(DateTime.now());
  if (remaining.isNegative) return '00:00';
  final minutes = remaining.inMinutes.toString().padLeft(2, '0');
  final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String elapsedMinutes(DateTime value) {
  final minutes = DateTime.now().difference(value).inMinutes;
  if (minutes < 1) return 'vừa xong';
  return '$minutes phút';
}
