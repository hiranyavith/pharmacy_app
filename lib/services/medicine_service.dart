// lib/services/medicine_service.dart
import '../db/db_helper.dart';
import '../models/medicine.dart';

class MedicineService {
  final _db = DBHelper.instance;

  // ── All medicines ─────────────────────
  Future<List<Medicine>> getAll() async {
    final rows = await _db.query(
      'SELECT * FROM medicines ORDER BY name ASC',
    );
    return rows.map(Medicine.fromMap).toList();
  }

  // ── Search by name or category ────────
  Future<List<Medicine>> search(String q) async {
    // This matches your DBHelper's parameter mapping
    final rows = await _db.query(
      'SELECT * FROM medicines WHERE name LIKE :p0 OR category LIKE :p1 ORDER BY name',
      ['%$q%', '%$q%'],
    );
    return rows.map(Medicine.fromMap).toList();
  }

  // ── Medicines expiring within 30 days ─
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

  // ── Low stock medicines (≤ 10) ────────
  Future<List<Medicine>> getLowStock() async {
    final rows = await _db.query(
      'SELECT * FROM medicines WHERE stock <= 10 ORDER BY stock ASC',
    );
    return rows.map(Medicine.fromMap).toList();
  }

  // ── Add ───────────────────────────────
  Future<void> add(Medicine m) async {
    await _db.execute(
      '''INSERT INTO medicines (name, category, price, stock, expiry_date)
         VALUES (:p0, :p1, :p2, :p3, :p4)''',
      [
        m.name,
        m.category,
        m.price,
        m.stock,
        m.expiryDate?.toIso8601String().split('T').first
      ],
    );
  }

  // ── Update ────────────────────────────
  Future<void> update(Medicine m) async {
    await _db.execute(
      '''UPDATE medicines
         SET name=:p0, category=:p1, price=:p2, stock=:p3, expiry_date=:p4
         WHERE id=:p5''',
      [
        m.name,
        m.category,
        m.price,
        m.stock,
        m.expiryDate?.toIso8601String().split('T').first,
        m.id
      ],
    );
  }

  // ── Delete ────────────────────────────
  Future<void> delete(int id) async {
    await _db.execute('DELETE FROM medicines WHERE id=:p0', [id]);
  }

  // ── Reduce stock after sale ───────────
  Future<void> reduceStock(int id, int qty) async {
    await _db.execute(
      'UPDATE medicines SET stock = stock - :p0 WHERE id = :p1',
      [qty, id],
    );
  }

  Future<void> restoreStock(int medicineId, int qty) async {
  await _db.execute(
    'UPDATE medicines SET stock = stock + :p0 WHERE id = :p1',
    [qty, medicineId],
  );
}
}
