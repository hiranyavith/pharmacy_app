// lib/models/bill.dart
import 'medicine.dart';

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
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  BillItem({
    required this.id,
    required this.billId,
    required this.medicineId,
    required this.medName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory BillItem.fromMap(Map<String, dynamic> m) => BillItem(
        id: int.tryParse(m['id']?.toString() ?? '0') ?? 0,
        billId: int.tryParse(m['bill_id']?.toString() ?? '0') ?? 0,
        medicineId: int.tryParse(m['medicine_id']?.toString() ?? '0') ?? 0,
        medName: m['med_name'] ?? '',
        quantity: int.tryParse(m['quantity']?.toString() ?? '0') ?? 0,
        unitPrice: double.tryParse(m['unit_price']?.toString() ?? '0') ?? 0,
        lineTotal: double.tryParse(m['line_total']?.toString() ?? '0') ?? 0,
      );
}

class Bill {
  final int id;
  final String invoiceNo;
  final double subtotal;
  final double discount;
  final double total;
  final double change;
  final double given;
  final DateTime createdAt;
  List<BillItem> items;

  Bill({
    required this.id,
    required this.invoiceNo,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.change,
    required this.given,
    required this.createdAt,
    this.items = const [],
  });

  factory Bill.fromMap(Map<String, dynamic> m) => Bill(
        id: int.tryParse(m['id']?.toString() ?? '0') ?? 0,
        invoiceNo: m['invoice_no'] ?? '',
        subtotal: double.tryParse(m['subtotal']?.toString() ?? '0') ?? 0,
        discount: double.tryParse(m['discount']?.toString() ?? '0') ?? 0,
        total: double.tryParse(m['total']?.toString() ?? '0') ?? 0,
        change: double.tryParse(m['change_price']?.toString() ?? '0') ?? 0,
        given: double.tryParse(m['given_price']?.toString() ?? '0') ?? 0.0,
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}
