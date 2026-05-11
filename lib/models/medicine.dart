// lib/models/medicine.dart
class Medicine {
  final int?    id;
  final String  name;
  final String  category;
  final double  price;
  final int     stock;
  final int     stockWarningLimit; // alert when stock falls below this
  final DateTime? expiryDate;

  Medicine({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    this.stockWarningLimit = 10,   // default warning at 10
    this.expiryDate,
  });

  factory Medicine.fromMap(Map<String, dynamic> m) => Medicine(
    id:                int.tryParse(m['id']?.toString() ?? ''),
    name:              m['name']     ?? '',
    category:          m['category'] ?? '',
    price:             double.tryParse(m['price']?.toString()             ?? '0')  ?? 0,
    stock:             int.tryParse(m['stock']?.toString()                ?? '0')  ?? 0,
    stockWarningLimit: int.tryParse(m['stock_warning_limit']?.toString()  ?? '10') ?? 10,
    expiryDate: m['expiry_date'] != null && m['expiry_date'] != ''
        ? DateTime.tryParse(m['expiry_date'].toString())
        : null,
  );

  Map<String, dynamic> toMap() => {
    'name':                name,
    'category':            category,
    'price':               price,
    'stock':               stock,
    'stock_warning_limit': stockWarningLimit,
    'expiry_date':         expiryDate?.toIso8601String().split('T').first,
  };

  // Uses the per-medicine custom limit instead of hardcoded 10
  bool get isLowStock     => stock <= stockWarningLimit;
  bool get isOutOfStock   => stock == 0;
  double get totalValue   => price * stock;   // total stock value for this medicine

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    return expiryDate!.difference(DateTime.now()).inDays <= 30;
  }
  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }
}