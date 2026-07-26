import 'dart:ui' as ui;

import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/bill.dart';

// ── Font registration (once per session) ─────────────────────────────────────
bool _fontsRegistered = false;

Future<void> _ensureFontsRegistered() async {
  if (_fontsRegistered) return;

  final loader = FontLoader('NotoSansSinhala');
  loader.addFont(Future.value(
      await rootBundle.load('assets/fonts/NotoSansSinhala-Regular.ttf')));
  await loader.load();

  final boldLoader = FontLoader('NotoSansSinhala');
  boldLoader.addFont(Future.value(
      await rootBundle.load('assets/fonts/NotoSansSinhala-Bold.ttf')));
  await boldLoader.load();

  _fontsRegistered = true;
}

// ── Sinhala → PNG (Flutter shaping engine) ───────────────────────────────────
Future<pw.MemoryImage> _sinhalaImg(
  String text, {
  double fontSizePt = 8.0,
  bool bold = false,
  bool italic = false,
  bool centered = false,
  double widthMm = 70.0,
  double pxPerMm = 11.0,
}) async {
  await _ensureFontsRegistered();

  final widthPx = (widthMm * pxPerMm).ceil();
  final fontPx = fontSizePt * pxPerMm * (25.4 / 72.0);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, widthPx.toDouble(), fontPx * 2.8),
    ui.Paint()..color = const ui.Color(0x00000000),
  );

  final paraStyle = ui.ParagraphStyle(
    fontFamily: 'NotoSansSinhala',
    fontSize: fontPx,
    fontWeight: bold ? ui.FontWeight.w800 : ui.FontWeight.w800,
    fontStyle: italic ? ui.FontStyle.italic : ui.FontStyle.normal,
    textAlign: centered ? ui.TextAlign.center : ui.TextAlign.left,
  );

  final txtStyle = ui.TextStyle(
    color: const ui.Color(0xFF000000),
    fontFamily: 'NotoSansSinhala',
    fontSize: fontPx,
    fontWeight: bold ? ui.FontWeight.w800 : ui.FontWeight.w800,
    fontStyle: italic ? ui.FontStyle.italic : ui.FontStyle.normal,
  );

  final para = (ui.ParagraphBuilder(paraStyle)
        ..pushStyle(txtStyle)
        ..addText(text))
      .build()
    ..layout(ui.ParagraphConstraints(width: widthPx.toDouble()));

  canvas.drawParagraph(para, ui.Offset.zero);

  final picture = recorder.endRecording();
  final imgH = (para.height + 2).ceil().clamp(1, 9999);
  final image = await picture.toImage(widthPx, imgH);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  return pw.MemoryImage(bytes!.buffer.asUint8List());
}

// ── Invoice-number barcode (Code128 via SVG) ──────────────────────────────────
// Returns a pw.Widget that draws the barcode + human-readable number below.
// widthPt / heightPt are in PDF points.
pw.Widget _invoiceBarcode(
  String invoiceNo, {
  double widthPt = 180,
  double heightPt = 36,
}) {
  try {
    final svg = bc.Barcode.code128().toSvg(
      invoiceNo,
      width: widthPt,
      height: heightPt,
      drawText: true, // prints the invoice number below the bars
      fontHeight: 9,
    );
    return pw.Center(
      child: pw.SvgImage(svg: svg, width: widthPt, height: heightPt + 12),
    );
  } catch (_) {
    // Fallback: plain text if barcode generation fails
    return pw.Center(
      child: pw.Text(
        invoiceNo,
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }
}

// ── PdfGenerator ──────────────────────────────────────────────────────────────
class PdfGenerator {
  static const double _pageW = 76 * PdfPageFormat.mm;
  static const double _marginH = 3 * PdfPageFormat.mm;
  static const double _marginV = 3 * PdfPageFormat.mm;
  static const double _mm = PdfPageFormat.mm;
  static const double _printW = 70.0; // mm

  // Distance from print head to tear bar on XP-365B (~28–32 mm)
  static const double _tearMm = 30.0;

  // Font sizes (PDF points)
  static const double _fsShop = 20.0;
  static const double _fsAddr = 7.5;
  static const double _fsMeta = 7.5;
  static const double _fsItem = 8.0;
  static const double _fsSub = 7.5;
  static const double _fsTotal = 10.0;
  static const double _fsSmall = 7.5;
  static const double _fsFoot = 8.0;

  // Section height estimates (PDF points)
  static const double _hHeader = 42 * _mm;
  static const double _hMeta = 22 * _mm;
  static const double _hColHdr = 8 * _mm;
  static const double _hItemBase = 11 * _mm;
  static const double _hTotals = 28 * _mm;
  static const double _hBarcode = 18 * _mm; // ← invoice barcode section
  static const double _hFooter = 20 * _mm;

  static Future<pw.Font?> _pwFont(String path) async {
    try {
      return pw.Font.ttf(await rootBundle.load(path));
    } catch (_) {
      return null;
    }
  }

  static Future<void> printBill(Bill bill) async {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yy HH:mm');
    final isCard = bill.paymentType == PaymentType.card;

    final pwReg = await _pwFont('assets/fonts/NotoSansSinhala-Regular.ttf');
    final pwBld = await _pwFont('assets/fonts/NotoSansSinhala-Bold.ttf');

    pw.TextStyle r({double fs = 8.0}) =>
        pw.TextStyle(fontSize: fs, font: pwReg);
    pw.TextStyle b({double fs = 8.0}) => pw.TextStyle(
        fontSize: fs, fontWeight: pw.FontWeight.bold, font: pwBld ?? pwReg);
    pw.TextStyle it({double fs = 8.0}) =>
        pw.TextStyle(fontSize: fs, fontStyle: pw.FontStyle.italic, font: pwReg);

    // Pre-render Sinhala strings
    final siShopName = await _sinhalaImg('සම්පත් පොත් හල',
        fontSizePt: _fsShop, bold: true, centered: true, widthMm: _printW);
    final siAddr1 = await _sinhalaImg('Bus Stand, ඌරුබොක්ක',
        fontSizePt: _fsAddr,
        centered: true,
        bold: true,
        italic: true,
        widthMm: _printW);
    final siWa = await _sinhalaImg('WhatsApp: +94 71 535 9983',
        fontSizePt: _fsAddr, centered: true, bold: true, widthMm: _printW);
    final siWa2 = await _sinhalaImg('Tel: +94 70 515 4300',
        fontSizePt: _fsAddr, centered: true, bold: true, widthMm: _printW);
    final siInvHdr = await _sinhalaImg('------------ INVOICE ------------',
        fontSizePt: 9, bold: true, centered: true, widthMm: _printW);

    final siCustLbl = await _sinhalaImg('ගනුදෙනුකරු : ',
        fontSizePt: _fsMeta, bold: true, widthMm: 20);
    final siPayLbl = await _sinhalaImg('ගෙවීම       : ',
        fontSizePt: _fsMeta, bold: true, widthMm: 20);
    final siCash = await _sinhalaImg('මුදල්',
        fontSizePt: _fsMeta, bold: true, widthMm: 22);
    final siCard = await _sinhalaImg('කාඩ් පත',
        fontSizePt: _fsMeta, bold: true, widthMm: 26);

    final siItemHdr =
        await _sinhalaImg('අයිතමය', fontSizePt: 7.5, bold: true, widthMm: 60);
    final siAmtHdr = await _sinhalaImg('මුළු මුදල',
        fontSizePt: 7.5, bold: true, widthMm: 60);

    final siSubLbl = await _sinhalaImg('එකතුව  :',
        fontSizePt: _fsSmall, bold: true, widthMm: 36);
    final isPercent = bill.discountType == DiscountType.percent;

    final String disLabelText = isPercent
        ? 'ඔබගේ ලාභය (${bill.discount.toStringAsFixed(0)}%) :'
        : 'ඔබගේ ලාභය :';
    final siDisLbl = await _sinhalaImg(
      disLabelText,
      fontSizePt: _fsSmall,
      bold: true,
      widthMm: 42,
    );
    final siTotLbl = await _sinhalaImg('මුළු එකතුව',
        fontSizePt: _fsTotal, bold: true, widthMm: 38);
    final siRecLbl = await _sinhalaImg('ලැබුණු  :',
        fontSizePt: _fsSmall, bold: true, italic: true, widthMm: 28);
    final siBalLbl = await _sinhalaImg('ඉතිරිය  :',
        fontSizePt: _fsSmall, bold: true, widthMm: 28);
    final siCardNote = await _sinhalaImg('[ කාඩ් ගෙවීම ]',
        fontSizePt: 8, bold: true, widthMm: 38);

    final siFooter1 = await _sinhalaImg('අප හා ගණුදෙණු කල ඔබට ස්තුතී!',
        fontSizePt: _fsFoot,
        italic: true,
        bold: true,
        centered: true,
        widthMm: _printW);
    final siFooter2 = await _sinhalaImg('නැවත පැමිණෙන්න.',
        fontSizePt: _fsFoot,
        italic: true,
        bold: true,
        centered: true,
        widthMm: _printW);

    // ── Barcode label (pre-rendered Sinhala) ────────────────────────────
    final siBarcodeLabel = await _sinhalaImg('ඉන්වොයිස් නො. / Invoice No.',
        fontSizePt: 6.5,
        centered: true,
        widthMm: _printW,
        bold: true,
        italic: true);

    // ── Page height ──────────────────────────────────────────────────────
    final customItemCount =
        bill.items.where((i) => i.unitPrice != i.mrp && i.mrp > 0).length;
    final itemsH =
        bill.items.length * _hItemBase + customItemCount * (3.5 * _mm);
    final extraH = (bill.discount > 0 ? 5 * _mm : 0.0) +
        (!isCard && bill.given > 0 ? 10 * _mm : 0.0) +
        (isCard ? 6 * _mm : 0.0) +
        (bill.customerName.isNotEmpty ? 6 * _mm : 0.0);

    final pageH = _marginV * 2 +
        _hHeader +
        _hMeta +
        _hColHdr +
        itemsH +
        _hTotals +
        extraH +
        _hBarcode // ← barcode block
        +
        _hFooter +
        _tearMm * _mm;

    // ── Build PDF ────────────────────────────────────────────────────────
    final pdf = pw.Document();

    pw.Widget si(pw.MemoryImage m, {double h = 11}) =>
        pw.Image(m, height: h, fit: pw.BoxFit.contain);
    pw.Widget siC(pw.MemoryImage m, {double h = 11}) =>
        pw.Center(child: si(m, h: h));

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat(
        _pageW,
        pageH,
        marginTop: _marginV,
        marginBottom: _marginV,
        marginLeft: _marginH,
        marginRight: _marginH,
      ),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── HEADER ───────────────────────────────────────────────
          siC(siShopName, h: 14),
          pw.SizedBox(height: 2),
          siC(siAddr1, h: 10),
          pw.SizedBox(height: 1),
          siC(siWa, h: 10),
          pw.SizedBox(height: 1),
          siC(siWa2, h: 10),
          pw.SizedBox(height: 4),
          siC(siInvHdr, h: 11),
          pw.SizedBox(height: 4), _dash(), pw.SizedBox(height: 4),

          // ── META ─────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('INV: ${bill.invoiceNo}', style: b(fs: _fsMeta)),
              pw.Text(dateFmt.format(bill.createdAt), style: r(fs: _fsMeta)),
            ],
          ),
          if (bill.customerName.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Row(children: [
              si(siCustLbl, h: 10),
              pw.Text(bill.customerName, style: r(fs: _fsMeta)),
            ]),
          ],
          pw.SizedBox(height: 2),
          pw.Row(children: [
            si(siPayLbl, h: 10),
            si(isCard ? siCard : siCash, h: 10),
          ]),
          pw.SizedBox(height: 4), _dash(), pw.SizedBox(height: 4),

          // ── COLUMN HEADERS ────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              si(siItemHdr, h: 10),
              si(siAmtHdr, h: 10),
            ],
          ),
          pw.Divider(thickness: 1.0, height: 5),

          // ── LINE ITEMS ────────────────────────────────────────────
          ...bill.items.map((item) {
            final isCustom = item.unitPrice != item.mrp && item.mrp > 0;
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(item.medName.toUpperCase(), style: b(fs: _fsItem)),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '  ${item.quantity} × Rs.${fmt.format(item.unitPrice)}'
                              '${isCustom ? ' *' : ''}',
                              style: b(fs: _fsSub),
                            ),
                            // ── MRP shown (struck-through) when a custom
                            // selling price was applied at the till ──────
                            if (isCustom)
                              pw.Text(
                                '  MRP: Rs.${fmt.format(item.mrp)}',
                                style: pw.TextStyle(
                                  fontSize: _fsSmall - 0.5,
                                  font: pwReg,
                                  color: PdfColors.grey600,
                                  decoration: pw.TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                      ),
                      pw.SizedBox(
                        width: 70,
                        child: pw.Text(
                          'Rs.${fmt.format(item.lineTotal)}',
                          textAlign: pw.TextAlign.right,
                          style: r(fs: _fsItem),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          pw.SizedBox(height: 4), _dash(), pw.SizedBox(height: 5),

          // ── TOTALS ────────────────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                  si(siSubLbl, h: 10),
                  pw.SizedBox(width: 4),
                  pw.SizedBox(
                    width: 66,
                    child: pw.Text('Rs.${fmt.format(bill.subtotal)}',
                        textAlign: pw.TextAlign.right, style: r(fs: _fsSmall)),
                  ),
                ]),
                if (bill.discount > 0)
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      si(siDisLbl, h: 10),
                      pw.SizedBox(width: 4),
                      pw.SizedBox(
                        width: 66,
                        child: pw.Text(
                          '-Rs.${fmt.format(bill.discountAmount)}',
                          textAlign: pw.TextAlign.right,
                          style: r(fs: _fsSmall),
                        ),
                      ),
                    ],
                  ),
                pw.SizedBox(height: 3),
                pw.Container(
                  width: 154,
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(width: 1.0),
                      bottom: pw.BorderSide(width: 1.0),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      si(siTotLbl, h: 13),
                      pw.Text('Rs.${fmt.format(bill.total)}',
                          style: b(fs: _fsTotal)),
                    ],
                  ),
                ),
                if (!isCard && bill.given > 0) ...[
                  pw.SizedBox(height: 3),
                  pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                    si(siRecLbl, h: 10),
                    pw.SizedBox(width: 4),
                    pw.SizedBox(
                      width: 72,
                      child: pw.Text('Rs.${fmt.format(bill.given)}',
                          textAlign: pw.TextAlign.right,
                          style: r(fs: _fsSmall)),
                    ),
                  ]),
                  pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                    si(siBalLbl, h: 10),
                    pw.SizedBox(width: 4),
                    pw.SizedBox(
                      width: 72,
                      child: pw.Text('Rs.${fmt.format(bill.change)}',
                          textAlign: pw.TextAlign.right,
                          style: b(fs: _fsSmall)),
                    ),
                  ]),
                ],
                if (isCard) ...[
                  pw.SizedBox(height: 4),
                  si(siCardNote, h: 11),
                ],
              ],
            ),
          ),

          // ── INVOICE BARCODE ───────────────────────────────────────
          // Printed before the footer so cashier can scan this receipt
          // to pull up the bill in Bill History.
          pw.SizedBox(height: 8), _dash(), pw.SizedBox(height: 6),
          siC(siBarcodeLabel, h: 9), // small Sinhala/English label
          pw.SizedBox(height: 3),
          _invoiceBarcode(
            bill.invoiceNo,
            widthPt: 180, // fits comfortably in 70 mm printable area
            heightPt: 32,
          ),

          // ── FOOTER ────────────────────────────────────────────────
          pw.SizedBox(height: 8), _dash(), pw.SizedBox(height: 6),
          pw.Center(
              child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              siC(siFooter1, h: 11),
              pw.SizedBox(height: 4),
              siC(siFooter2, h: 11),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Powered by Klyro Pvt Ltd',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
              ),
            ],
          )),

          // ── TEAR-BAR ADVANCE ──────────────────────────────────────
          pw.SizedBox(height: _tearMm * _mm),
        ],
      ),
    ));

    // ── Print ────────────────────────────────────────────────────────────
    final printers = await Printing.listPrinters();
    if (printers.isEmpty) return;

    final target = printers.firstWhere(
      (p) {
        final n = p.name.toLowerCase();
        // Must NOT be the 365B label printer.
        // Must specifically match 80C (or explicit "receipt"/"pos").
        return !n.contains('365b') &&
            (n.contains('80c') || n.contains('receipt') || n.contains('pos'));
      },
      orElse: () => printers.firstWhere(
        (p) => p.isDefault,
        orElse: () => printers.first,
      ),
    );

    await Printing.directPrintPdf(
      printer: target,
      onLayout: (_) => pdf.save(),
      name: 'Invoice_${bill.invoiceNo}',
    );
  }

  static pw.Widget _dash() =>
      pw.Divider(thickness: 0.2, height: 2, borderStyle: pw.BorderStyle.dashed);
}
