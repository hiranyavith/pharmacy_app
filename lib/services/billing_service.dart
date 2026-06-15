// lib/services/billing_service.dart
import '../db/db_helper.dart';
import '../models/bill.dart';
import 'medicine_service.dart';

class BillingService {
  final _db = DBHelper.instance;
  final _med = MedicineService();

  // ── Generate unique invoice number ────
  Future<String> _generateInvoiceNo() async {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}';
    final rows = await _db.query(
      '''
      SELECT CAST(
               SUBSTRING_INDEX(invoice_no, '-', -1)
             AS UNSIGNED) AS seq
      FROM   bills
      WHERE  invoice_no LIKE :p0
      ORDER  BY seq DESC
      LIMIT  1
      ''',
      ['INV-$datePart-%'],
    );

    final lastSeq = rows.isNotEmpty
        ? (int.tryParse(rows.first['seq']?.toString() ?? '0') ?? 0)
        : 0;

    final nextSeq = (lastSeq + 1).toString().padLeft(4, '0');
    return 'INV-$datePart$nextSeq';
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
    final invoiceNo = await _generateInvoiceNo();
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

  Future<void> updateBill(Bill bill) async {
    // 1. Fetch the current (pre-edit) items straight from the DB
    final oldItems = await getBillItems(bill.id);

    // Build a quick lookup: medicineId → old quantity
    final Map<int, int> oldQtyByMedId = {
      for (final old in oldItems) old.medicineId: old.quantity,
    };

    // Build a lookup for the NEW items too
    final Map<int, BillItem> newItemByMedId = {
      for (final n in bill.items) n.medicineId: n,
    };

    // 2 & 3. Reconcile stock for every OLD item
    for (final old in oldItems) {
      final newItem = newItemByMedId[old.medicineId];

      if (newItem == null) {
        // Item was REMOVED → restore the full original qty back to stock
        await _med.restoreStock(old.medicineId, old.quantity);
      } else {
        // Item still present → restore old qty then deduct new qty
        final diff = newItem.quantity - old.quantity; // positive = more sold
        if (diff > 0) {
          // Quantity increased → deduct extra from stock
          await _med.reduceStock(old.medicineId, diff);
        } else if (diff < 0) {
          // Quantity decreased → return the difference to stock
          await _med.restoreStock(old.medicineId, diff.abs());
        }
        // diff == 0 → no stock change needed
      }
    }

    // Recalculate totals from the new items (don't trust what the UI passed)
    final subtotal =
        bill.items.fold(0.0, (s, i) => s + i.unitPrice * i.quantity);
    final total = subtotal - bill.discount;

    // 4. Replace all bill_items rows
    await _db.execute(
      'DELETE FROM bill_items WHERE bill_id = :p0',
      [bill.id],
    );

    for (final item in bill.items) {
      final lineTotal = item.unitPrice * item.quantity;
      await _db.execute(
        '''INSERT INTO bill_items
             (bill_id, medicine_id, med_name, quantity, unit_price, line_total)
           VALUES (:p0, :p1, :p2, :p3, :p4, :p5)''',
        [
          bill.id,
          item.medicineId,
          item.medName,
          item.quantity,
          item.unitPrice,
          lineTotal,
        ],
      );
    }

    // 5. Update the bill header
    await _db.execute(
      '''UPDATE bills
         SET subtotal     = :p0,
             discount     = :p1,
             total        = :p2
         WHERE id         = :p3''',
      [subtotal, bill.discount, total, bill.id],
    );
  }
}
