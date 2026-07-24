// lib/services/medicine_service.dart
import 'dart:math';

import '../db/db_helper.dart';
import '../models/medicine.dart';

class MedicineService {
  final _db = DBHelper.instance;

  // ── All medicines ─────────────────────────────────────────────────────────
  Future<List<Medicine>> getAll() async {
    final rows = await _db.query(
      'SELECT * FROM medicines WHERE is_active = 1 ORDER BY name ASC',
    );
    return rows.map(Medicine.fromMap).toList();
  }

  // ── Search by name, category, OR barcode ─────────────────────────────────
  Future<List<Medicine>> search(String q) async {
    final rows = await _db.query(
      '''SELECT * FROM medicines
         WHERE name     LIKE :p0
            OR category LIKE :p1
            OR barcode  LIKE :p2
         ORDER BY name''',
      ['%$q%', '%$q%', '%$q%'],
    );
    return rows.map(Medicine.fromMap).toList();
  }

  // ── Exact barcode lookup (used after a scan) ──────────────────────────────
  // Returns null if no medicine is registered with that barcode.
  Future<Medicine?> getByBarcode(String barcode) async {
    final rows = await _db.query(
      'SELECT * FROM medicines WHERE barcode = :p0 LIMIT 1',
      [barcode],
    );
    if (rows.isEmpty) return null;
    return Medicine.fromMap(rows.first);
  }

  // ── Medicines expiring within 90 days ─────────────────────────────────────
  Future<List<Medicine>> getExpiringSoon() async {
    final rows = await _db.query(
      '''SELECT * FROM medicines
         WHERE expiry_date IS NOT NULL
           AND expiry_date <= DATE_ADD(CURDATE(), INTERVAL 90 DAY)
           AND expiry_date >= CURDATE()
         ORDER BY expiry_date ASC''',
    );
    return rows.map(Medicine.fromMap).toList();
  }

  // ── Low stock medicines ───────────────────────────────────────────────────
  Future<List<Medicine>> getLowStock() async {
    final rows = await _db.query(
      '''SELECT * FROM medicines
         WHERE stock <= stock_warning_limit
         ORDER BY stock ASC''',
    );
    return rows.map(Medicine.fromMap).toList();
  }

  // ── Add ───────────────────────────────────────────────────────────────────
  Future<void> add(Medicine m) async {
    await _db.execute(
      '''INSERT INTO medicines
           (name, category, price, stock, stock_warning_limit, barcode, expiry_date)
         VALUES (:p0, :p1, :p2, :p3, :p4, :p5, :p6)''',
      [
        m.name,
        m.category,
        m.price,
        m.stock,
        m.stockWarningLimit,
        m.barcode, // ← NEW
        m.expiryDate?.toIso8601String().split('T').first,
      ],
    );
  }

  // ── Update ────────────────────────────────────────────────────────────────
  Future<void> update(Medicine m) async {
    await _db.execute(
      '''UPDATE medicines
         SET name               = :p0,
             category           = :p1,
             price              = :p2,
             stock              = :p3,
             stock_warning_limit= :p4,
             barcode            = :p5,
             expiry_date        = :p6
         WHERE id               = :p7''',
      [
        m.name,
        m.category,
        m.price,
        m.stock,
        m.stockWarningLimit,
        m.barcode, // ← NEW
        m.expiryDate?.toIso8601String().split('T').first,
        m.id,
      ],
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> delete(int id) async {
    await _db.execute('DELETE FROM medicines WHERE id = :p0', [id]);
  }

  // ── Reduce stock after sale ───────────────────────────────────────────────
  Future<void> reduceStock(int id, int qty) async {
    await _db.execute(
      'UPDATE medicines SET stock = stock - :p0 WHERE id = :p1',
      [qty, id],
    );
  }

  // ── Restore stock on bill edit/cancel ────────────────────────────────────
  Future<void> restoreStock(int medicineId, int qty) async {
    await _db.execute(
      'UPDATE medicines SET stock = stock + :p0 WHERE id = :p1',
      [qty, medicineId],
    );
  }

  Future<void> deactivate(int medicineId) async {
    await _db.execute(
      'UPDATE medicines SET is_active = 0 WHERE id = :p0',
      [medicineId],
    );
  }

  Future<void> activate(int medicineId) async {
    await _db.execute(
      'UPDATE medicines SET is_active = 1 WHERE id = :p0',
      [medicineId],
    );
  }

  Future<String> generateUniqueBarcode() async {
    final rng = Random();
    String barcode;
    bool exists = true;

    do {
      final randomDigits = List.generate(10, (_) => rng.nextInt(10)).join();
      barcode = '20$randomDigits';

      final rows = await _db.query(
          'SELECT id FROM medicines WHERE barcode = :p0 LIMIT 1', [barcode]);
      exists = rows.isNotEmpty;
    } while (exists);
    return barcode;
  }
}
