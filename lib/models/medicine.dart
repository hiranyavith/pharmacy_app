// lib/models/medicine.dart
class Medicine {
  final int? id;
  final String name;
  final String category;
  final double price;
  final int stock;
  final int stockWarningLimit;
  final DateTime? expiryDate;
  final String? barcode; // ← NEW: nullable, not all items have one
  final bool isActive;
  Medicine({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    this.stockWarningLimit = 10,
    this.expiryDate,
    this.barcode,
    required this.isActive, // ← NEW
  });

  factory Medicine.fromMap(Map<String, dynamic> m) => Medicine(
      id: int.tryParse(m['id']?.toString() ?? ''),
      name: m['name'] ?? '',
      category: m['category'] ?? '',
      price: double.tryParse(m['price']?.toString() ?? '0') ?? 0,
      stock: int.tryParse(m['stock']?.toString() ?? '0') ?? 0,
      stockWarningLimit:
          int.tryParse(m['stock_warning_limit']?.toString() ?? '10') ?? 10,
      barcode: m['barcode']?.toString(), // ← NEW
      expiryDate: m['expiry_date'] != null && m['expiry_date'] != ''
          ? DateTime.tryParse(m['expiry_date'].toString())
          : null,
      isActive: m['is_active'] == 1 || m['is_active'] == true);

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'price': price,
        'stock': stock,
        'stock_warning_limit': stockWarningLimit,
        'barcode': barcode, // ← NEW
        'expiry_date': expiryDate?.toIso8601String().split('T').first,
        'is_active':isActive ? 1 : 0,
      };

  bool get isLowStock => stock <= stockWarningLimit;
  bool get isOutOfStock => stock == 0;
  double get totalValue => price * stock;

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    return expiryDate!.difference(DateTime.now()).inDays <= 30;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }
}
