// lib/models/bill.dart
import 'medicine.dart';

enum PaymentType { cash, card }

enum DiscountType { rs, percent }

class CartItem {
  final Medicine medicine;
  int quantity;
  double? sellingPrice; // ← NEW: null means use medicine.price

  CartItem({required this.medicine, this.quantity = 1, this.sellingPrice});

  // Use override price if set, otherwise fall back to medicine price
  double get effectivePrice => sellingPrice ?? medicine.price;
  double get lineTotal => effectivePrice * quantity;
}

class BillItem {
  final int id;
  final int billId;
  final int? medicineId;
  final String medName;
  int quantity;
  final double
      unitPrice; // the ACTUAL price used (may differ from medicine.price)
  final double mrp; // ← NEW: original medicine price, for reference

  double get lineTotal => unitPrice * quantity;

  BillItem({
    required this.id,
    required this.billId,
    required this.medicineId,
    required this.medName,
    required this.quantity,
    required this.unitPrice,
    this.mrp = 0,
  });

  factory BillItem.fromMap(Map<String, dynamic> m) => BillItem(
        id: int.tryParse(m['id']?.toString() ?? '0') ?? 0,
        billId: int.tryParse(m['bill_id']?.toString() ?? '0') ?? 0,
         medicineId: m['medicine_id'] == null
            ? null
            : int.tryParse(m['medicine_id'].toString()),
        medName: m['med_name'] ?? '',
        quantity: int.tryParse(m['quantity']?.toString() ?? '0') ?? 0,
        unitPrice: double.tryParse(m['unit_price']?.toString() ?? '0') ?? 0,
        mrp: double.tryParse(m['mrp']?.toString() ?? '0') ?? 0,
      );

  BillItem copyWith({int? quantity, double? unitPrice}) => BillItem(
        id: id,
        billId: billId,
        medicineId: medicineId,
        medName: medName,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        mrp: mrp,
      );
}

class Bill {
  final int id;
  final String invoiceNo;
  final double subtotal;
  final double discount;
  final DiscountType discountType;
  final double total;
  final double given;
  final double change;
  final PaymentType paymentType;
  final String customerName;
  final DateTime createdAt;
  List<BillItem> items;

  Bill({
    required this.id,
    required this.invoiceNo,
    required this.subtotal,
    required this.discount,
    this.discountType = DiscountType.rs,
    required this.total,
    this.given = 0,
    this.change = 0,
    this.paymentType = PaymentType.cash,
    this.customerName = '',
    required this.createdAt,
    this.items = const [],
  });

  double get discountAmount {
    if (discountType == DiscountType.percent) {
      return (subtotal * discount / 100).clamp(0, subtotal);
    }
    return discount.clamp(0, subtotal);
  }

  factory Bill.fromMap(Map<String, dynamic> m) => Bill(
        id: int.tryParse(m['id']?.toString() ?? '0') ?? 0,
        invoiceNo: m['invoice_no'] ?? '',
        subtotal: double.tryParse(m['subtotal']?.toString() ?? '0') ?? 0,
        discount: double.tryParse(m['discount']?.toString() ?? '0') ?? 0,
        discountType: (m['discount_type'] ?? 'rs') == 'percent'
            ? DiscountType.percent
            : DiscountType.rs,
        total: double.tryParse(m['total']?.toString() ?? '0') ?? 0,
        given: double.tryParse(m['given_price']?.toString() ?? '0') ?? 0,
        change: double.tryParse(m['change_price']?.toString() ?? '0') ?? 0,
        paymentType: (m['payment_type'] ?? 'cash') == 'card'
            ? PaymentType.card
            : PaymentType.cash,
        customerName: m['customer_name'] ?? '',
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  Bill copyWith({
    List<BillItem>? items,
    double? discount,
    DiscountType? discountType,
    double? subtotal,
    double? total,
  }) =>
      Bill(
        id: id,
        invoiceNo: invoiceNo,
        createdAt: createdAt,
        given: given,
        change: change,
        paymentType: paymentType,
        customerName: customerName,
        items: items ?? this.items,
        discount: discount ?? this.discount,
        discountType: discountType ?? this.discountType,
        subtotal: subtotal ?? this.subtotal,
        total: total ?? this.total,
      );
}
