// lib/models/label_config.dart
enum BarcodeType { code128, code39, ean13, ean8, upcA, qrCode }

extension BarcodeTypeLabel on BarcodeType {
  String get label {
    switch (this) {
      case BarcodeType.code128:
        return 'Code 128';
      case BarcodeType.code39:
        return 'Code 39';
      case BarcodeType.ean13:
        return 'EAN-13';
      case BarcodeType.ean8:
        return 'EAN-8';
      case BarcodeType.upcA:
        return 'UPC-A';
      case BarcodeType.qrCode:
        return 'QR Code';
    }
  }
}

class PaperSize {
  final String label;
  final double widthMm;
  final double heightMm;
  const PaperSize(this.label, this.widthMm, this.heightMm);

  static const List<PaperSize> presets = [
    PaperSize('30 × 15 mm', 30, 15),
    PaperSize('30 × 20 mm', 30, 20),
    PaperSize('40 × 30 mm', 40, 30),
    PaperSize('50 × 25 mm', 50, 25),
    PaperSize('50 × 30 mm', 50, 30),
    PaperSize('58 × 40 mm', 58, 40),
    PaperSize('80 mm Roll (72 mm usable)', 72, 30),
  ];

  static const custom = PaperSize('Custom size', 0, 0);

  bool matches(double w, double h) =>
      (widthMm - w).abs() < 0.01 && (heightMm - h).abs() < 0.01;
}

class LabelConfig {
  bool showName;
  bool showBarcode;   // prints the barcode image + number below it
  bool showPrice;
  bool showMrp;       // "MRP: Rs. X.XX" line
  bool showCategory;
  bool showExpiry;
  bool showStockQty;
  int  copies;        // how many identical labels to print

  // Label size — width and height are both selectable (mm).
  // Defaults match the XP-365B's common 30×15 mm stock.
  double paperWidthMm;
  double labelHeightMm;

  // Which barcode symbology to render (centered on the label).
  BarcodeType barcodeType;

  LabelConfig({
    this.showName      = true,
    this.showBarcode   = true,
    this.showPrice     = true,
    this.showMrp       = false,
    this.showCategory  = false,
    this.showExpiry    = false,
    this.showStockQty  = false,
    this.copies        = 1,
    this.paperWidthMm  = 30,
    this.labelHeightMm = 15,
    this.barcodeType   = BarcodeType.ean13,
  });

  LabelConfig copyWith({
    bool?        showName,
    bool?        showBarcode,
    bool?        showPrice,
    bool?        showMrp,
    bool?        showCategory,
    bool?        showExpiry,
    bool?        showStockQty,
    int?         copies,
    double?      paperWidthMm,
    double?      labelHeightMm,
    BarcodeType? barcodeType,
  }) => LabelConfig(
    showName:      showName      ?? this.showName,
    showBarcode:   showBarcode   ?? this.showBarcode,
    showPrice:     showPrice     ?? this.showPrice,
    showMrp:       showMrp       ?? this.showMrp,
    showCategory:  showCategory  ?? this.showCategory,
    showExpiry:    showExpiry    ?? this.showExpiry,
    showStockQty:  showStockQty  ?? this.showStockQty,
    copies:        copies        ?? this.copies,
    paperWidthMm:  paperWidthMm  ?? this.paperWidthMm,
    labelHeightMm: labelHeightMm ?? this.labelHeightMm,
    barcodeType:   barcodeType   ?? this.barcodeType,
  );
}