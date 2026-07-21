class LabelConfig {
  bool showName;
  bool showBarcode;   // prints the barcode image + number below it
  bool showPrice;
  bool showMrp;       // "MRP: Rs. X.XX" line
  bool showCategory;
  bool showExpiry;
  bool showStockQty;
  int  copies;        // how many identical labels to print
 
  // Label size on 80 mm roll
  // Width is fixed at ~72 mm (80 mm roll - margins).
  // Height controls how tall each label is (in mm).
  double labelHeightMm;
 
  LabelConfig({
    this.showName      = true,
    this.showBarcode   = true,
    this.showPrice     = true,
    this.showMrp       = false,
    this.showCategory  = false,
    this.showExpiry    = false,
    this.showStockQty  = false,
    this.copies        = 1,
    this.labelHeightMm = 30,
  });
 
  LabelConfig copyWith({
    bool?   showName,
    bool?   showBarcode,
    bool?   showPrice,
    bool?   showMrp,
    bool?   showCategory,
    bool?   showExpiry,
    bool?   showStockQty,
    int?    copies,
    double? labelHeightMm,
  }) => LabelConfig(
    showName:      showName      ?? this.showName,
    showBarcode:   showBarcode   ?? this.showBarcode,
    showPrice:     showPrice     ?? this.showPrice,
    showMrp:       showMrp       ?? this.showMrp,
    showCategory:  showCategory  ?? this.showCategory,
    showExpiry:    showExpiry    ?? this.showExpiry,
    showStockQty:  showStockQty  ?? this.showStockQty,
    copies:        copies        ?? this.copies,
    labelHeightMm: labelHeightMm ?? this.labelHeightMm,
  );
}