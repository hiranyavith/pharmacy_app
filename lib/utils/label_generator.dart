// lib/utils/label_generator.dart
import 'package:barcode/barcode.dart' as bc;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/label_config.dart';
import '../models/medicine.dart';

class LabelGenerator {
  /// Print one or more identical labels for [medicine] using [config].
  static Future<void> printLabel(
    Medicine medicine,
    LabelConfig config,
  ) async {
    final pdf = pw.Document();
    final fmt = NumberFormat('#,##0.00');
    final expFmt = DateFormat('dd/MM/yyyy');

    // ── Geometry driven by the selected paper size ─────────────────────────
    final double paperW = config.paperWidthMm * PdfPageFormat.mm;
    final double labelH = config.labelHeightMm * PdfPageFormat.mm;

    final bool isSmall =
        config.paperWidthMm <= 40 || config.labelHeightMm <= 20;

    final double marginH = (isSmall ? 1.5 : 3) * PdfPageFormat.mm;
    final double marginV = (isSmall ? 1.0 : 2) * PdfPageFormat.mm;
    final double contentW = paperW - marginH * 2;

    // Font sizes scale down automatically for small label stock (e.g. 30×15mm)
    final double nameFont = isSmall ? 7 : 9;
    final double smallFont = isSmall ? 5.5 : 7;
    final double priceFont = isSmall ? 8 : 10;
    final double mrpFont = isSmall ? 5.5 : 7;
    final double spacingSm = isSmall ? 1.0 : 2.0;
    final double spacingMd = isSmall ? 1.5 : 3.0;

    // Build one label widget (reused for every copy)
    pw.Widget buildLabel() {
      final children = <pw.Widget>[];

      // ── Medicine name ────────────────────────────────────────────────────
      if (config.showName) {
        children.add(pw.Text(
          medicine.name.toUpperCase(),
          maxLines: isSmall ? 1 : 2,
          overflow: pw.TextOverflow.clip,
          style:
              pw.TextStyle(fontSize: nameFont, fontWeight: pw.FontWeight.bold),
        ));
        children.add(pw.SizedBox(height: spacingSm));
      }

      // ── Category ─────────────────────────────────────────────────────────
      if (config.showCategory && medicine.category.isNotEmpty) {
        children.add(pw.Text(
          medicine.category,
          style: pw.TextStyle(fontSize: smallFont, color: PdfColors.grey700),
        ));
        children.add(pw.SizedBox(height: spacingSm));
      }

      // ── Price row ────────────────────────────────────────────────────────
      if (config.showPrice || config.showMrp) {
        final priceWidgets = <pw.Widget>[];

        if (config.showPrice) {
          priceWidgets.add(pw.Container(
            padding: pw.EdgeInsets.symmetric(
                horizontal: isSmall ? 3 : 4, vertical: isSmall ? 1 : 2),
            decoration: const pw.BoxDecoration(
              color: PdfColors.black,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              'Rs. ${fmt.format(medicine.price)}',
              style: pw.TextStyle(
                  fontSize: priceFont,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
            ),
          ));
        }

        if (config.showMrp) {
          if (priceWidgets.isNotEmpty) {
            priceWidgets.add(pw.SizedBox(width: isSmall ? 4 : 6));
          }
          priceWidgets.add(pw.Text(
            'MRP: Rs. ${fmt.format(medicine.price)}',
            style: pw.TextStyle(fontSize: mrpFont, color: PdfColors.grey700),
          ));
        }

        children.add(pw.Row(children: priceWidgets));
        children.add(pw.SizedBox(height: spacingMd));
      }

      // ── Expiry ───────────────────────────────────────────────────────────
      if (config.showExpiry && medicine.expiryDate != null) {
        children.add(pw.Text(
          'Exp: ${expFmt.format(medicine.expiryDate!)}',
          style: pw.TextStyle(
            fontSize: smallFont,
            color: medicine.isExpiringSoon ? PdfColors.red : PdfColors.grey700,
            fontWeight: medicine.isExpiringSoon
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
        ));
        children.add(pw.SizedBox(height: spacingSm));
      }

      // ── Stock qty ────────────────────────────────────────────────────────
      if (config.showStockQty) {
        children.add(pw.Text(
          'Stock: ${medicine.stock}',
          style: pw.TextStyle(fontSize: smallFont, color: PdfColors.grey700),
        ));
        children.add(pw.SizedBox(height: spacingSm));
      }

      // ── Barcode — centered on the label ─────────────────────────────────
      if (config.showBarcode &&
          medicine.barcode != null &&
          medicine.barcode!.isNotEmpty) {
        try {
          final bool isQr = config.barcodeType == BarcodeType.qrCode;

          final double bW = isQr
              ? (labelH * 0.55).clamp(28.0, 130.0)
              : (contentW * 0.92).clamp(35.0, 300.0);
          final double bH = isQr ? bW : (labelH * 0.32).clamp(14.0, 55.0);

          final barcodeSvg = _barcodeFor(config.barcodeType).toSvg(
            medicine.barcode!,
            width: bW,
            height: bH,
            drawText: !isQr,
            fontHeight: isSmall ? 6 : 10,
          );

          children.add(pw.Container(
            width: contentW,
            alignment: pw.Alignment.center,
            child: pw.SvgImage(svg: barcodeSvg),
          ));
        } catch (_) {
          // If the string is invalid for the selected symbology (e.g. EAN-13
          // needs 12-13 digits), fall back to plain text — still centered.
          children.add(pw.Container(
            width: contentW,
            alignment: pw.Alignment.center,
            child: pw.Text(
              medicine.barcode!,
              style:
                  pw.TextStyle(fontSize: smallFont, color: PdfColors.grey600),
            ),
          ));
        }
      }

      return pw.Container(
        width: contentW,
        padding:
            pw.EdgeInsets.symmetric(horizontal: marginH, vertical: marginV),
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
    final pageFormat = PdfPageFormat(
      paperW,
      labelH,
      marginAll: 0,
    );

    for (var i = 0; i < config.copies; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (ctx) => buildLabel(),
        ),
      );
    }

    // ── Find thermal printer (prefers the XP-365B) and send ───────────────
    final printers = await Printing.listPrinters();
    final target = printers.firstWhere(
      (p) {
        final n = p.name.toLowerCase();
        // Must NOT be an 80C queue, even though both contain "xp".
        // Must specifically match 365B (or explicit "label").
        return !n.contains('80c') &&
            (n.contains('365b') || n.contains('label'));
      },
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

  static bc.Barcode _barcodeFor(BarcodeType type) {
    switch (type) {
      case BarcodeType.code128:
        return bc.Barcode.code128();
      case BarcodeType.code39:
        return bc.Barcode.code39();
      case BarcodeType.ean13:
        return bc.Barcode.ean13();
      case BarcodeType.ean8:
        return bc.Barcode.ean8();
      case BarcodeType.upcA:
        return bc.Barcode.upcA();
      case BarcodeType.qrCode:
        return bc.Barcode.qrCode();
    }
  }
}
