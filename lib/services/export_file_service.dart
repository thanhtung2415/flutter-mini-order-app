import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/app_models.dart';
import '../utils/formatters.dart';

class ExportFileService {
  Future<File> createKitchenReceiptPdf({
    required Order order,
    required RestaurantTable? table,
  }) async {
    final pdf = pw.Document();
    final rows = order.currentKitchenItems
        .map(
          (item) => [
            '${item.quantity}',
            _ascii(item.productName),
            _ascii(item.note.isEmpty ? '-' : item.note),
          ],
        )
        .toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'PHIEU ORDER BEP',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 18),
              _pdfLine('Ban', _ascii(table?.name ?? order.tableId)),
              _pdfLine('Ma don', order.id),
              _pdfLine('Tao luc', _ascii(dateTimeText(order.createdAt))),
              _pdfLine('Trang thai', _ascii(order.status.label)),
              pw.SizedBox(height: 14),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: const ['SL', 'Mon', 'Ghi chu'],
                data: rows,
                border: pw.TableBorder.all(color: PdfColors.grey400),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: const {0: pw.Alignment.center},
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 5,
                ),
              ),
              if (order.note.trim().isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text(
                  'Ghi chu order: ${_ascii(order.note)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    return _writeBytes(
      fileName: 'phieu_bep_${_safeName(order.id)}.pdf',
      bytes: bytes,
    );
  }

  Future<File> createRevenueExcel({
    required List<Payment> payments,
    required Order? Function(String id) orderById,
    required RestaurantTable? Function(String id) tableById,
    required AppUser? Function(String id) userById,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Bao cao doanh thu';
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, sheetName);
    }
    final sheet = excel[sheetName];

    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final headerStyle = CellStyle(bold: true);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('Bao cao doanh thu')
      ..cellStyle = titleStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
        TextCellValue('Ngay xuat: ${dateTimeText(DateTime.now())}');

    final totalRevenue = payments.fold<int>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value =
        TextCellValue('Tong doanh thu');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value =
        IntCellValue(totalRevenue);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 2)).value =
        TextCellValue('Tong thanh toan: ${payments.length}');

    final headers = [
      'Payment ID',
      'Order ID',
      'Ban',
      'Phuong thuc',
      'Tong tien',
      'Ngay thanh toan',
      'Nguoi xac nhan',
      'So mon',
    ];

    for (var column = 0; column < headers.length; column++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 4))
        ..value = TextCellValue(headers[column])
        ..cellStyle = headerStyle;
    }

    for (var index = 0; index < payments.length; index++) {
      final payment = payments[index];
      final row = index + 5;
      final order = orderById(payment.orderId);
      final values = <CellValue?>[
        TextCellValue(payment.id),
        TextCellValue(payment.orderId),
        TextCellValue(tableById(payment.tableId)?.name ?? payment.tableId),
        TextCellValue(payment.method.label),
        IntCellValue(payment.amount),
        TextCellValue(
          payment.paidAt == null ? '' : dateTimeText(payment.paidAt!),
        ),
        TextCellValue(
          payment.confirmedBy == null
              ? ''
              : userById(payment.confirmedBy!)?.fullName ??
                    payment.confirmedBy!,
        ),
        IntCellValue(order?.totalQuantity ?? 0),
      ];

      for (var column = 0; column < values.length; column++) {
        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: column,
                    rowIndex: row,
                  ),
                )
                .value =
            values[column];
      }
    }

    const widths = [22.0, 22.0, 14.0, 18.0, 14.0, 20.0, 24.0, 10.0];
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Khong tao duoc file Excel.');
    }

    return _writeBytes(
      fileName: 'bao_cao_doanh_thu_${_timestampName()}.xlsx',
      bytes: Uint8List.fromList(bytes),
    );
  }

  Future<File> createRevenuePdf({
    required List<Payment> payments,
    required Order? Function(String id) orderById,
    required RestaurantTable? Function(String id) tableById,
    required AppUser? Function(String id) userById,
    required String rangeLabel,
  }) async {
    final pdf = pw.Document();
    final totalRevenue = payments.fold<int>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final rows = payments.map((payment) {
      final order = orderById(payment.orderId);
      final confirmer = payment.confirmedBy == null
          ? '-'
          : userById(payment.confirmedBy!)?.fullName ?? payment.confirmedBy!;
      return [
        _ascii(tableById(payment.tableId)?.name ?? payment.tableId),
        _ascii(payment.method.label),
        '${payment.amount}',
        _ascii(payment.paidAt == null ? '-' : dateTimeText(payment.paidAt!)),
        _ascii(confirmer),
        '${order?.totalQuantity ?? 0}',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'BAO CAO DOANH THU',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Thoi gian: ${_ascii(rangeLabel)}'),
          pw.Text('Ngay xuat: ${_ascii(dateTimeText(DateTime.now()))}'),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('So thanh toan: ${payments.length}'),
                pw.Text(
                  'Tong doanh thu: $totalRevenue VND',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          if (rows.isEmpty)
            pw.Text('Khong co du lieu trong khoang thoi gian da chon.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Ban',
                'Phuong thuc',
                'Tong tien',
                'Thanh toan luc',
                'Nguoi xac nhan',
                'So mon',
              ],
              data: rows,
              border: pw.TableBorder.all(color: PdfColors.grey400),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellPadding: const pw.EdgeInsets.all(5),
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
        ],
      ),
    );

    return _writeBytes(
      fileName: 'bao_cao_doanh_thu_${_timestampName()}.pdf',
      bytes: await pdf.save(),
    );
  }

  Future<void> shareFile({
    required File file,
    required String title,
    required String message,
    required String mimeType,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: title,
        text: message,
      ),
    );
  }

  pw.Widget _pdfLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  Future<File> _writeBytes({
    required String fileName,
    required List<int> bytes,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    return file.writeAsBytes(bytes, flush: true);
  }

  String _timestampName() {
    final now = DateTime.now();
    return [
      now.year.toString().padLeft(4, '0'),
      now.month.toString().padLeft(2, '0'),
      now.day.toString().padLeft(2, '0'),
      '_',
      now.hour.toString().padLeft(2, '0'),
      now.minute.toString().padLeft(2, '0'),
    ].join();
  }

  String _safeName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return cleaned.isEmpty ? 'order' : cleaned;
  }

  String _ascii(String value) {
    const replacements = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
      'À': 'A',
      'Á': 'A',
      'Ạ': 'A',
      'Ả': 'A',
      'Ã': 'A',
      'Â': 'A',
      'Ầ': 'A',
      'Ấ': 'A',
      'Ậ': 'A',
      'Ẩ': 'A',
      'Ẫ': 'A',
      'Ă': 'A',
      'Ằ': 'A',
      'Ắ': 'A',
      'Ặ': 'A',
      'Ẳ': 'A',
      'Ẵ': 'A',
      'È': 'E',
      'É': 'E',
      'Ẹ': 'E',
      'Ẻ': 'E',
      'Ẽ': 'E',
      'Ê': 'E',
      'Ề': 'E',
      'Ế': 'E',
      'Ệ': 'E',
      'Ể': 'E',
      'Ễ': 'E',
      'Ì': 'I',
      'Í': 'I',
      'Ị': 'I',
      'Ỉ': 'I',
      'Ĩ': 'I',
      'Ò': 'O',
      'Ó': 'O',
      'Ọ': 'O',
      'Ỏ': 'O',
      'Õ': 'O',
      'Ô': 'O',
      'Ồ': 'O',
      'Ố': 'O',
      'Ộ': 'O',
      'Ổ': 'O',
      'Ỗ': 'O',
      'Ơ': 'O',
      'Ờ': 'O',
      'Ớ': 'O',
      'Ợ': 'O',
      'Ở': 'O',
      'Ỡ': 'O',
      'Ù': 'U',
      'Ú': 'U',
      'Ụ': 'U',
      'Ủ': 'U',
      'Ũ': 'U',
      'Ư': 'U',
      'Ừ': 'U',
      'Ứ': 'U',
      'Ự': 'U',
      'Ử': 'U',
      'Ữ': 'U',
      'Ỳ': 'Y',
      'Ý': 'Y',
      'Ỵ': 'Y',
      'Ỷ': 'Y',
      'Ỹ': 'Y',
      'Đ': 'D',
    };

    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char);
    }
    return buffer.toString();
  }
}
