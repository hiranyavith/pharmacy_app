// lib/utils/pdf_generator.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill.dart';
import 'package:intl/intl.dart';

class PdfGenerator {
  static Future<void> printBill(Bill bill) async {
    final pdf = pw.Document();
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yy HH:mm');

    // 80mm is ~227 points. Using a slightly smaller width ensures no horizontal clipping.
    const rollWidth = 72 * PdfPageFormat.mm; 

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(rollWidth, double.infinity, 
            marginAll: 5 * PdfPageFormat.mm),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('HEALTH HUB',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('PHARMACY',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('123 Wellness Ave, City Center',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Tel: +123 456 7890',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 4),
                  pw.Text('INVOICE',
                      style: pw.TextStyle(
                          fontSize: 10, 
                          decoration: pw.TextDecoration.underline,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            
            pw.SizedBox(height: 8),
            _dashedDivider(),

            // --- INFO SECTION ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('INV: ${bill.invoiceNo}', 
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(dateFmt.format(bill.createdAt), 
                    style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
            
            _dashedDivider(),
            pw.SizedBox(height: 4),

            // --- TABLE HEADER ---
            pw.Row(
              children: [
                pw.Expanded(flex: 5, child: _tableHeader('ITEM')),
                pw.Expanded(flex: 1, child: _tableHeader('QTY')),
                pw.Expanded(flex: 2, child: _tableHeader('TOTAL', align: pw.TextAlign.right)),
              ],
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Divider(thickness: 0.5),
            ),

            // --- ITEMS ---
            ...bill.items.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Text(item.medName.toUpperCase(),
                            style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text('${item.quantity}',
                            style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(fmt.format(item.lineTotal),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                    ],
                  ),
                )),

            pw.SizedBox(height: 4),
            _dashedDivider(),

            // --- TOTALS ---
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _totalRow('Subtotal:', fmt.format(bill.subtotal)),
                  if (bill.discount > 0)
                    _totalRow('Discount:', '-${fmt.format(bill.discount)}', isBold: true),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    width: 100,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(width: 1))
                    ),
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text(fmt.format(bill.total), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (bill.given > 0) ...[
                    pw.SizedBox(height: 4),
                    _totalRow('Cash:', fmt.format(bill.given)),
                    _totalRow('Change:', fmt.format(bill.change)),
                  ]
                ],
              ),
            ),

            // --- FOOTER ---
            pw.SizedBox(height: 15),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('Thank you for choosing Health Hub!',
                      style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                  pw.SizedBox(height: 2),
                  pw.Text('Please keep this receipt for returns.',
                      style: const pw.TextStyle(fontSize: 7)),
                  pw.SizedBox(height: 30), // Cutting space
                  pw.Text('.', style: const pw.TextStyle(color: PdfColors.white)), // Anchor for spacing
                ],
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
        onLayout: (fmt) => pdf.save(),
        name: 'Invoice_${bill.invoiceNo}');
  }

  // Helper for consistent headers
  static pw.Widget _tableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Text(text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold));
  }

  // Helper for total rows
  static pw.Widget _totalRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : null)),
          pw.SizedBox(width: 12),
          pw.SizedBox(
            width: 50,
            child: pw.Text(value, 
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : null)),
          ),
        ],
      ),
    );
  }

  // Creates a clean dashed line common in receipts
  static pw.Widget _dashedDivider() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        '- ' * 30,
        maxLines: 1,
        style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey700),
      ),
    );
  }
}