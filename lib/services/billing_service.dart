// lib/services/billing_service.dart
import '../db/db_helper.dart';
import '../models/bill.dart';
import '../models/medicine.dart';
import 'medicine_service.dart';

class BillingService {
  final _db  = DBHelper.instance;
  final _med = MedicineService();

  // ── Generate unique invoice number ────
  String _generateInvoiceNo() {
    final now = DateTime.now();
    final ts  = '${now.year}${now.month.toString().padLeft(2,'0')}'
                '${now.day.toString().padLeft(2,'0')}'
                '${now.millisecondsSinceEpoch % 10000}';
    return 'INV-$ts';
  }

  // ── Create bill from cart ─────────────
// lib/services/billing_service.dart

Future<Bill> createBill(List<CartItem> cart, {double discount = 0, double given = 0}) async {
  final invoiceNo = _generateInvoiceNo();
  final subtotal  = cart.fold(0.0, (s, i) => s + i.lineTotal);
  final total     = subtotal - discount;
  final change = given - total;

  // 1. Insert bill header using named parameters for mysql_client
  final res = await _db.execute(
    '''INSERT INTO bills (invoice_no, subtotal, discount, total, change_price, given_price)
       VALUES (:p0, :p1, :p2, :p3, :p4, :p5)''',
    [invoiceNo, subtotal, discount, total, change, given],
  );
  
  final billId = res.lastInsertID.toInt();

  // 2. Insert line items + reduce stock
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

  // 3. Construct and return the Bill object
  // This ensures the function always returns a non-null Bill
  return Bill(
    id:         billId,
    invoiceNo:  invoiceNo,
    subtotal:   subtotal,
    discount:   discount,
    total:      total,
    change: change,
    given: given,
    createdAt:  DateTime.now(),
    items:      cart.map((c) => BillItem(
      id:         0,
      billId:     billId,
      medicineId: c.medicine.id!,
      medName:    c.medicine.name,
      quantity:   c.quantity,
      unitPrice:  c.medicine.price,
      lineTotal:  c.lineTotal,
    )).toList(),
  );
}

  // ── Get all bills ─────────────────────
  Future<List<Bill>> getAllBills() async {
    final rows = await _db.query(
      'SELECT * FROM bills ORDER BY created_at DESC',
    );
    return rows.map(Bill.fromMap).toList();
  }

  // ── Search bills ──────────────────────
Future<List<Bill>> searchBills(String q) async {
  final rows = await _db.query(
    '''SELECT * FROM bills 
       WHERE invoice_no LIKE :p0 
          OR DATE(created_at) = :p1 
       ORDER BY created_at DESC''',
    ['%$q%', q],
  );
  return rows.map(Bill.fromMap).toList();
}

Future<List<BillItem>> getBillItems(int billId) async {
  final rows = await _db.query(
    'SELECT * FROM bill_items WHERE bill_id = :p0',
    [billId],
  );
  return rows.map(BillItem.fromMap).toList();
}
}
