// lib/utils/pdf_generator.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill.dart';
import 'package:intl/intl.dart';

class PdfGenerator {
  // 80mm thermal roll: 72mm printable width (80mm - ~8mm margins)
  // Height is dynamic (double.infinity = auto/continuous roll)
  static const double _rollW = 72 * PdfPageFormat.mm;
  static const double _margin = 4 * PdfPageFormat.mm;

  static Future<void> printBill(Bill bill) async {
    final pdf = pw.Document();
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yy HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_rollW, double.infinity, marginAll: _margin),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── HEADER ─────────────────────
            pw.Center(
              child: pw.Column(children: [
                pw.Text('HEALTH HUB PHARMACY',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(' & GROCERY',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('623/1A Egodawatta Road, Arawwala',
                    style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text('Pannipitiya',
                    style: const pw.TextStyle(fontSize: 7.5)),
                pw.SizedBox(height: 3),
                pw.Text('Tel: +94 72 291 5064',
                    style: const pw.TextStyle(fontSize: 7.5)),
                pw.SizedBox(height: 3),
                pw.Text('-' * 12 + ' INVOICE' + '-' * 12,
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ]),
            ),

            pw.SizedBox(height: 6),
            pw.Divider(
                thickness: 0.2, height: 4, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 6),

            // ── INVOICE META ───────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('INV: ${bill.invoiceNo}',
                    style: pw.TextStyle(
                        fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                pw.Text(dateFmt.format(bill.createdAt),
                    style: const pw.TextStyle(fontSize: 7.5)),
              ],
            ),
            pw.SizedBox(height: 3),

            // Customer name (if provided)
            if (bill.customerName.isNotEmpty)
              pw.Row(children: [
                pw.Text('Customer: ',
                    style: pw.TextStyle(
                        fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                pw.Text(bill.customerName,
                    style: const pw.TextStyle(fontSize: 7.5)),
              ]),

            // Payment type
            pw.Row(children: [
              pw.Text('Payment : ',
                  style: pw.TextStyle(
                      fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                bill.paymentType == PaymentType.card ? 'CARD' : 'CASH',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: bill.paymentType == PaymentType.card
                        ? PdfColors.black
                        : PdfColors.black),
              ),
            ]),

            // _dashes(),
            pw.SizedBox(height: 4),

            pw.Divider(
                thickness: 0.2, height: 6, borderStyle: pw.BorderStyle.dashed),

            pw.SizedBox(height: 4),

            // ── COLUMN HEADERS ─────────────
            pw.Row(children: [
              pw.Expanded(flex: 5, child: _hdr('ITEM')),
              pw.Expanded(flex: 1, child: _hdr('QTY')),
              pw.Expanded(
                  flex: 2, child: _hdr('AMT', align: pw.TextAlign.right)),
            ]),
            pw.Divider(thickness: 0.5, height: 6),

            // ── LINE ITEMS ─────────────────
            ...bill.items.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(item.medName.toUpperCase(),
                          style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.black,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Row(children: [
                        pw.Expanded(
                            flex: 5,
                            child: pw.Text(
                              '  ${item.quantity} x ${fmt.format(item.unitPrice)}',
                              style: pw.TextStyle(
                                  fontSize: 7.5,
                                  color: PdfColors.black,
                                  fontStyle: pw.FontStyle.italic),
                            )),
                        pw.Expanded(
                            flex: 3,
                            child: pw.Text(fmt.format(item.lineTotal),
                                textAlign: pw.TextAlign.right,
                                style: const pw.TextStyle(fontSize: 8))),
                      ]),
                    ],
                  ),
                )),

            pw.SizedBox(height: 4),
            pw.Divider(
                thickness: 0.2, height: 4, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 6),

            // ── TOTALS ─────────────────────
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _totalRow('Subtotal :', fmt.format(bill.subtotal)),
                  if (bill.discount > 0)
                    _totalRow('Discount :', '-${fmt.format(bill.discount)}'),
                  pw.SizedBox(height: 3),
                  // TOTAL box
                  pw.Container(
                    width: 110,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4, vertical: 3),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(width: 0.8),
                        bottom: pw.BorderSide(width: 0.8),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text(fmt.format(bill.total),
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  // Cash / change (only for cash payments)
                  if (bill.paymentType == PaymentType.cash &&
                      bill.given > 0) ...[
                    pw.SizedBox(height: 3),
                    _totalRow('Cash     :', fmt.format(bill.given)),
                    _totalRow('Change   :', fmt.format(bill.change),
                        bold: true),
                  ],
                  // Card payment note
                  if (bill.paymentType == PaymentType.card) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('[ CARD PAYMENT ]',
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black)),
                  ],
                ],
              ),
            ),

            // ── FOOTER ─────────────────────
            pw.SizedBox(height: 10),
            pw.Divider(
                thickness: 0.2, height: 4, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Column(children: [
                pw.Text('Thank you come again!',
                    style: pw.TextStyle(
                        fontSize: 8, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 2),
                pw.Text('Please keep this receipt for returns.',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.black)),
                pw.SizedBox(height: 28), // feed/cut space
              ]),
            ),
          ],
        ),
      ),
    );

    // ── DIRECT PRINT — no preview dialog ──
    // Finds the first available printer and sends directly.
    // Make sure your 80mm thermal is set as Default Printer in Windows,
    // or it will pick the system default.
    final printers = await Printing.listPrinters();

    // Try to find the thermal printer by name keyword
    // Change 'thermal' / 'POS' to match your printer's Windows name
    Printer? target = printers.firstWhere(
      (p) =>
          p.name.toLowerCase().contains('thermal') ||
          p.name.toLowerCase().contains('pos') ||
          p.name.toLowerCase().contains('xp') ||
          p.name.toLowerCase().contains('receipt'),
      orElse: () =>
          printers.firstWhere((p) => p.isDefault, orElse: () => printers.first),
    );

    await Printing.directPrintPdf(
      printer: target,
      onLayout: (_) => pdf.save(),
      name: 'Invoice_${bill.invoiceNo}',
    );
  }

  // ── Helpers ───────────────────────────────

  static pw.Widget _hdr(String t, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Text(t,
          textAlign: align,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold));

  static pw.Widget _totalRow(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
          pw.SizedBox(
            width: 58,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : null)),
          ),
          pw.SizedBox(
            width: 52,
            child: pw.Text(value,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : null)),
          ),
        ]),
      );

  // Dashed separator line (receipt style)
  static pw.Widget _dashes() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Text('- ' * 32,
            maxLines: 1,
            style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey600)),
      );
}
