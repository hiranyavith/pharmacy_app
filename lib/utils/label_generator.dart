import 'package:barcode/barcode.dart' as bc;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
 
import '../models/label_config.dart';
import '../models/medicine.dart';
 
class LabelGenerator {
  // 80 mm roll: ~72 mm usable width
  static const double _rollW  = 72 * PdfPageFormat.mm;
  static const double _marginH = 3 * PdfPageFormat.mm;
  static const double _marginV = 2 * PdfPageFormat.mm;
 
  /// Print one or more identical labels for [medicine] using [config].
  static Future<void> printLabel(
    Medicine medicine,
    LabelConfig config,
  ) async {
    final pdf    = pw.Document();
    final fmt    = NumberFormat('#,##0.00');
    final expFmt = DateFormat('dd/MM/yyyy');
 
    final labelH = config.labelHeightMm * PdfPageFormat.mm;
 
    // Build one label widget (reused for every copy)
    pw.Widget buildLabel() {
      final children = <pw.Widget>[];
 
      // ── Medicine name ────────────────────────────────────────────────────
      if (config.showName) {
        children.add(pw.Text(
          medicine.name.toUpperCase(),
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ));
        children.add(pw.SizedBox(height: 2));
      }
 
      // ── Category ─────────────────────────────────────────────────────────
      if (config.showCategory && medicine.category.isNotEmpty) {
        children.add(pw.Text(
          medicine.category,
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ));
        children.add(pw.SizedBox(height: 2));
      }
 
      // ── Price row ────────────────────────────────────────────────────────
      if (config.showPrice || config.showMrp) {
        final priceWidgets = <pw.Widget>[];
 
        if (config.showPrice) {
          priceWidgets.add(pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: const pw.BoxDecoration(
              color: PdfColors.black,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              'Rs. ${fmt.format(medicine.price)}',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
            ),
          ));
        }
 
        if (config.showMrp) {
          if (priceWidgets.isNotEmpty) priceWidgets.add(pw.SizedBox(width: 6));
          priceWidgets.add(pw.Text(
            'MRP: Rs. ${fmt.format(medicine.price)}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ));
        }
 
        children.add(pw.Row(children: priceWidgets));
        children.add(pw.SizedBox(height: 3));
      }
 
      // ── Expiry ───────────────────────────────────────────────────────────
      if (config.showExpiry && medicine.expiryDate != null) {
        children.add(pw.Text(
          'Exp: ${expFmt.format(medicine.expiryDate!)}',
          style: pw.TextStyle(
            fontSize: 7,
            color: medicine.isExpiringSoon ? PdfColors.red : PdfColors.grey700,
            fontWeight: medicine.isExpiringSoon
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
        ));
        children.add(pw.SizedBox(height: 2));
      }
 
      // ── Stock qty ────────────────────────────────────────────────────────
      if (config.showStockQty) {
        children.add(pw.Text(
          'Stock: ${medicine.stock}',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ));
        children.add(pw.SizedBox(height: 2));
      }
 
      // ── Barcode ──────────────────────────────────────────────────────────
      // Renders Code128 SVG → raster via pw.SvgImage
      if (config.showBarcode && medicine.barcode != null &&
          medicine.barcode!.isNotEmpty) {
        try {
          final barcodeSvg = bc.Barcode.code128().toSvg(
            medicine.barcode!,
            width: 200,
            height: 40,
            drawText: true,        // prints the number below the bars
            fontHeight: 10,
          );
          children.add(pw.SvgImage(svg: barcodeSvg));
        } catch (_) {
          // If the barcode string is invalid for Code128, show text only
          children.add(pw.Text(
            medicine.barcode!,
            style: const pw.TextStyle(
                fontSize: 7, color: PdfColors.grey600),
          ));
        }
      }
 
      return pw.Container(
        width:  _rollW - _marginH * 2,
        // Don't enforce a height constraint — let content dictate
        padding: pw.EdgeInsets.symmetric(
            horizontal: _marginH, vertical: _marginV),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: children,
        ),
      );
    }
 
    // ── Build page with all copies stacked vertically ─────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          _rollW,
          labelH * config.copies + _marginV * 2,
          marginAll: 0,
        ),
        build: (ctx) => pw.Column(
          children: List.generate(config.copies, (_) => buildLabel()),
        ),
      ),
    );
 
    // ── Find thermal printer and send ─────────────────────────────────────
    final printers = await Printing.listPrinters();
    final target = printers.firstWhere(
      (p) =>
          p.name.toLowerCase().contains('thermal') ||
          p.name.toLowerCase().contains('pos')     ||
          p.name.toLowerCase().contains('xp')      ||
          p.name.toLowerCase().contains('receipt')  ||
          p.name.toLowerCase().contains('label'),
      orElse: () => printers.firstWhere(
        (p) => p.isDefault,
        orElse: () => printers.first,
      ),
    );
 
    await Printing.directPrintPdf(
      printer: target,
      onLayout: (_) => pdf.save(),
      name: 'Label_${medicine.name}',
    );
  }
}
 