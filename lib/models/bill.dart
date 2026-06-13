// lib/models/bill.dart
import 'medicine.dart';

enum PaymentType { cash, card }

class CartItem {
  final Medicine medicine;
  int quantity;

  CartItem({required this.medicine, this.quantity = 1});

  double get lineTotal => medicine.price * quantity;
}

class BillItem {
  final int id;
  final int billId;
  final int medicineId;
  final String medName;
  int quantity;           // mutable so the edit dialog stepper can update it
  final double unitPrice;

  // ── Computed — never stored as a field so it's always consistent ──
  double get lineTotal => unitPrice * quantity;

  BillItem({
    required this.id,
    required this.billId,
    required this.medicineId,
    required this.medName,
    required this.quantity,
    required this.unitPrice,
  });

  factory BillItem.fromMap(Map<String, dynamic> m) => BillItem(
        id: int.tryParse(m['id']?.toString() ?? '0') ?? 0,
        billId: int.tryParse(m['bill_id']?.toString() ?? '0') ?? 0,
        medicineId:
            int.tryParse(m['medicine_id']?.toString() ?? '0') ?? 0,
        medName: m['med_name'] ?? '',
        quantity:
            int.tryParse(m['quantity']?.toString() ?? '0') ?? 0,
        unitPrice:
            double.tryParse(m['unit_price']?.toString() ?? '0') ?? 0,
        // line_total is ignored on read — always derived from unitPrice * quantity
      );

  /// Shallow copy with optional overrides — handy when building edited lists.
  BillItem copyWith({int? quantity}) => BillItem(
        id: id,
        billId: billId,
        medicineId: medicineId,
        medName: medName,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice,
      );
}

class Bill {
  final int id;
  final String invoiceNo;
  final double subtotal;
  final double discount;
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
    required this.total,
    this.given = 0,
    this.change = 0,
    this.paymentType = PaymentType.cash,
    this.customerName = '',
    required this.createdAt,
    this.items = const [],
  });

  factory Bill.fromMap(Map<String, dynamic> m) => Bill(
        id: int.tryParse(m['id']?.toString() ?? '0') ?? 0,
        invoiceNo: m['invoice_no'] ?? '',
        subtotal:
            double.tryParse(m['subtotal']?.toString() ?? '0') ?? 0,
        discount:
            double.tryParse(m['discount']?.toString() ?? '0') ?? 0,
        total: double.tryParse(m['total']?.toString() ?? '0') ?? 0,
        given:
            double.tryParse(m['given_price']?.toString() ?? '0') ?? 0,
        change:
            double.tryParse(m['change_price']?.toString() ?? '0') ?? 0,
        paymentType: (m['payment_type'] ?? 'cash') == 'card'
            ? PaymentType.card
            : PaymentType.cash,
        customerName: m['customer_name'] ?? '',
        createdAt:
            DateTime.tryParse(m['created_at']?.toString() ?? '') ??
                DateTime.now(),
      );

  Bill copyWith({
    List<BillItem>? items,
    double? discount,
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
        subtotal: subtotal ?? this.subtotal,
        total: total ?? this.total,
      );
}