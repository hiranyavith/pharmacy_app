// lib/services/billing_service.dart
import '../db/db_helper.dart';
import '../models/bill.dart';
import 'medicine_service.dart';

class BillingService {
  final _db  = DBHelper.instance;
  final _med = MedicineService();

  // ── Daily-resetting invoice number  INV-YYYYMMDD-0001 ────────────────────
  Future<String> _generateInvoiceNo() async {
    final now      = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
    final rows = await _db.query(
      '''SELECT CAST(SUBSTRING_INDEX(invoice_no,'-',-1) AS UNSIGNED) AS seq
         FROM   bills
         WHERE  invoice_no LIKE :p0
         ORDER  BY seq DESC LIMIT 1''',
      ['INV-$datePart-%'],
    );
    final lastSeq = rows.isNotEmpty
        ? (int.tryParse(rows.first['seq']?.toString() ?? '0') ?? 0) : 0;
    return 'INV-$datePart-${(lastSeq + 1).toString().padLeft(4,'0')}';
  }

  // ── Create bill from cart ─────────────────────────────────────────────────
  Future<Bill> createBill(
    List<CartItem> cart, {
    double discount    = 0,
    double given       = 0,
    double change      = 0,
    PaymentType paymentType = PaymentType.cash,
    String customerName     = '',
  }) async {
    final invoiceNo = await _generateInvoiceNo();
    final subtotal  = cart.fold(0.0, (s, i) => s + i.lineTotal);
    final total     = subtotal - discount;
    change = given > 0 ? (given - total).clamp(0, double.infinity) : 0.0;
    final paymentStr = paymentType == PaymentType.card ? 'card' : 'cash';

    final res = await _db.execute(
      '''INSERT INTO bills
           (invoice_no,subtotal,discount,total,given_price,change_price,
            payment_type,customer_name)
         VALUES (:p0,:p1,:p2,:p3,:p4,:p5,:p6,:p7)''',
      [invoiceNo,subtotal,discount,total,given,change,paymentStr,
       customerName.trim()],
    );
    final billId = res.lastInsertID.toInt();

    // ── Insert line items ─────────────────────────────────────────────────
    // mrp = original medicine list price; unit_price = what the cashier charged
    for (final item in cart) {
      final unitPrice = item.effectivePrice;   // may differ from medicine.price
      final mrp       = item.medicine.price;
      final lineTotal = unitPrice * item.quantity;
      await _db.execute(
        '''INSERT INTO bill_items
             (bill_id,medicine_id,med_name,quantity,unit_price,line_total,mrp)
           VALUES (:p0,:p1,:p2,:p3,:p4,:p5,:p6)''',
        [billId, item.medicine.id, item.medicine.name,
         item.quantity, unitPrice, lineTotal, mrp],
      );
      await _med.reduceStock(item.medicine.id!, item.quantity);
    }

    return Bill(
      id:           billId,
      invoiceNo:    invoiceNo,
      subtotal:     subtotal,
      discount:     discount,
      total:        total,
      given:        given,
      change:       change,
      paymentType:  paymentType,
      customerName: customerName.trim(),
      createdAt:    DateTime.now(),
      items: cart.map((c) => BillItem(
        id:         0,
        billId:     billId,
        medicineId: c.medicine.id!,
        medName:    c.medicine.name,
        quantity:   c.quantity,
        unitPrice:  c.effectivePrice,
        mrp:        c.medicine.price,
      )).toList(),
    );
  }

  // ── Get all bills ─────────────────────────────────────────────────────────
  Future<List<Bill>> getAllBills() async {
    final rows = await _db.query('SELECT * FROM bills ORDER BY created_at DESC');
    return rows.map(Bill.fromMap).toList();
  }

  Future<String> getFullBillValue() async {
    final rows = await _db.query(
        'SELECT SUM(subtotal) AS total_value FROM bills');
    return rows.isNotEmpty ? rows.first['total_value'].toString() : '0.00';
  }

  // ── Search bills ──────────────────────────────────────────────────────────
  Future<List<Bill>> searchBills(String q) async {
    final rows = await _db.query(
      '''SELECT * FROM bills
         WHERE invoice_no LIKE :p0 OR CAST(created_at AS CHAR)=:p1
         ORDER BY created_at DESC''',
      ['%$q%', q],
    );
    return rows.map(Bill.fromMap).toList();
  }

  // ── Get items for one bill ────────────────────────────────────────────────
  Future<List<BillItem>> getBillItems(int billId) async {
    final rows = await _db.query(
        'SELECT * FROM bill_items WHERE bill_id=:p0', [billId]);
    return rows.map(BillItem.fromMap).toList();
  }

  // ── Update existing bill ──────────────────────────────────────────────────
  Future<void> updateBill(Bill bill) async {
    final oldItems = await getBillItems(bill.id);
    final newItemByMedId = {for (final n in bill.items) n.medicineId: n};

    for (final old in oldItems) {
      final newItem = newItemByMedId[old.medicineId];
      if (newItem == null) {
        await _med.restoreStock(old.medicineId, old.quantity);
      } else {
        final diff = newItem.quantity - old.quantity;
        if (diff > 0) await _med.reduceStock(old.medicineId, diff);
        if (diff < 0) await _med.restoreStock(old.medicineId, diff.abs());
      }
    }

    final subtotal = bill.items.fold(0.0, (s,i) => s + i.unitPrice * i.quantity);
    final total    = subtotal - bill.discount;

    await _db.execute('DELETE FROM bill_items WHERE bill_id=:p0', [bill.id]);

    for (final item in bill.items) {
      await _db.execute(
        '''INSERT INTO bill_items
             (bill_id,medicine_id,med_name,quantity,unit_price,line_total,mrp)
           VALUES (:p0,:p1,:p2,:p3,:p4,:p5,:p6)''',
        [bill.id, item.medicineId, item.medName,
         item.quantity, item.unitPrice, item.lineTotal, item.mrp],
      );
    }

    await _db.execute(
      'UPDATE bills SET subtotal=:p0,discount=:p1,total=:p2 WHERE id=:p3',
      [subtotal, bill.discount, total, bill.id],
    );
  }
}