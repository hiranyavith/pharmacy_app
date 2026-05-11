// lib/services/billing_service.dart
import '../db/db_helper.dart';
import '../models/bill.dart';
import 'medicine_service.dart';

class BillingService {
  final _db = DBHelper.instance;
  final _med = MedicineService();

  // ── Generate unique invoice number ────
  String _generateInvoiceNo() {
    final now = DateTime.now();
    final ts = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.millisecondsSinceEpoch % 10000}';
    return 'INV-$ts';
  }

  // ── Create bill from cart ─────────────
  Future<Bill> createBill(
    List<CartItem> cart, {
    double discount = 0,
    double given = 0,
    double change = 0,
    PaymentType paymentType = PaymentType.cash,
    String customerName = '',
  }) async {
    final invoiceNo = _generateInvoiceNo();
    final subtotal = cart.fold(0.0, (s, i) => s + i.lineTotal);
    final total = subtotal - discount;
    change = given > 0 ? (given - total).clamp(0, double.infinity) : 0.0;
    final paymentStr = paymentType == PaymentType.card ? 'card' : 'cash';

    // Insert bill header
    final res = await _db.execute(
      '''INSERT INTO bills
           (invoice_no, subtotal, discount, total, given_price, change_price,
            payment_type, customer_name)
         VALUES (:p0, :p1, :p2, :p3, :p4, :p5, :p6, :p7)''',
      [
        invoiceNo,
        subtotal,
        discount,
        total,
        given,
        change,
        paymentStr,
        customerName.trim()
      ],
    );
    final billId = res.lastInsertID.toInt();

    // Insert line items + reduce stock
    for (final item in cart) {
      await _db.execute(
        '''INSERT INTO bill_items
             (bill_id, medicine_id, med_name, quantity, unit_price, line_total)
           VALUES (:p0, :p1, :p2, :p3, :p4, :p5)''',
        [
          billId,
          item.medicine.id,
          item.medicine.name,
          item.quantity,
          item.medicine.price,
          item.lineTotal
        ],
      );
      await _med.reduceStock(item.medicine.id!, item.quantity);
    }

    return Bill(
      id: billId,
      invoiceNo: invoiceNo,
      subtotal: subtotal,
      discount: discount,
      total: total,
      given: given,
      change: change,
      paymentType: paymentType,
      customerName: customerName.trim(),
      createdAt: DateTime.now(),
      items: cart
          .map((c) => BillItem(
                id: 0,
                billId: billId,
                medicineId: c.medicine.id!,
                medName: c.medicine.name,
                quantity: c.quantity,
                unitPrice: c.medicine.price,
                lineTotal: c.lineTotal,
              ))
          .toList(),
    );
  }

  // ── Get all bills ─────────────────────
  Future<List<Bill>> getAllBills() async {
    final rows = await _db.query(
      'SELECT * FROM bills ORDER BY created_at DESC',
    );
    return rows.map(Bill.fromMap).toList();
  }

  Future<String> getFullBillValue() async {
    final rows = await _db.query(
      '''SELECT SUM(b.subtotal) AS total_value
         FROM bills b''',
    );
    return rows.isNotEmpty ? rows.first['total_value'].toString() : '0.00';
  }

  // ── Search bills ──────────────────────
  Future<List<Bill>> searchBills(String q) async {
    final rows = await _db.query(
      '''SELECT * FROM bills
         WHERE invoice_no LIKE :p0
            OR CAST(created_at AS CHAR) = :p1
         ORDER BY created_at DESC''',
      ['%$q%', q],
    );
    return rows.map(Bill.fromMap).toList();
  }

  // ── Get items for one bill ────────────
  Future<List<BillItem>> getBillItems(int billId) async {
    final rows = await _db.query(
      'SELECT * FROM bill_items WHERE bill_id = :p0',
      [billId],
    );
    return rows.map(BillItem.fromMap).toList();
  }
}
