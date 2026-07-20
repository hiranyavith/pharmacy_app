// lib/services/supplier_service.dart
import '../db/db_helper.dart';
import '../models/supplier.dart';

class SupplierService {
  final _db = DBHelper.instance;

  // ── DDL: call once from DBHelper.onCreate ─────────────────────────────────
  // Add these tables to your db_helper.dart onCreate block:
  //
  // CREATE TABLE suppliers (
  //   id              INT AUTO_INCREMENT PRIMARY KEY,
  //   name            VARCHAR(200) NOT NULL,
  //   contact_person  VARCHAR(200),
  //   phone           VARCHAR(50),
  //   email           VARCHAR(200),
  //   address         TEXT,
  //   created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  // );
  //
  // CREATE TABLE grn (
  //   id              INT AUTO_INCREMENT PRIMARY KEY,
  //   grn_number      VARCHAR(30) UNIQUE NOT NULL,
  //   invoice_number  VARCHAR(100) NOT NULL,
  //   supplier_id     INT NOT NULL,
  //   supplier_name   VARCHAR(200) NOT NULL,
  //   supply_date     DATE NOT NULL,
  //   received_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  //   status          ENUM('draft','received','cancelled') DEFAULT 'received',
  //   FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
  // );
  //
  // CREATE TABLE grn_items (
  //   id              INT AUTO_INCREMENT PRIMARY KEY,
  //   grn_id          INT NOT NULL,
  //   medicine_id     INT NOT NULL,
  //   medicine_name   VARCHAR(200) NOT NULL,
  //   quantity        INT NOT NULL,
  //   unit_cost       DECIMAL(10,2) NOT NULL,
  //   selling_price   DECIMAL(10,2) NOT NULL,
  //   FOREIGN KEY (grn_id) REFERENCES grn(id) ON DELETE CASCADE,
  //   FOREIGN KEY (medicine_id) REFERENCES medicines(id)
  // );

  // ─── Suppliers ─────────────────────────────────────────────────────────────
  Future<List<Supplier>> getAllSuppliers() async {
    final rows = await _db.query('SELECT * FROM suppliers ORDER BY name ASC');
    return rows.map(Supplier.fromMap).toList();
  }

  Future<List<Supplier>> searchSuppliers(String q) async {
    final rows = await _db.query(
      '''SELECT * FROM suppliers
         WHERE name LIKE :p0 OR contact_person LIKE :p1 OR phone LIKE :p2
         ORDER BY name''',
      ['%$q%', '%$q%', '%$q%'],
    );
    return rows.map(Supplier.fromMap).toList();
  }

  Future<void> addSupplier(Supplier s) async {
     await _db.execute(
      '''INSERT INTO suppliers (name, contact_person, phone, email, address)
         VALUES (:p0, :p1, :p2, :p3, :p4)''',
      [s.name, s.contactPerson, s.phone, s.email, s.address],
    );
  }

  Future<void> updateSupplier(Supplier s) async {
    await _db.execute(
      '''UPDATE suppliers
         SET name=:p0, contact_person=:p1, phone=:p2, email=:p3, address=:p4
         WHERE id=:p5''',
      [s.name, s.contactPerson, s.phone, s.email, s.address, s.id],
    );
  }

  Future<void> deleteSupplier(int id) async {
    await _db.execute('DELETE FROM suppliers WHERE id=:p0', [id]);
  }

  // ─── GRN Number Generator ─────────────────────────────────────────────────
  Future<String> nextGrnNumber() async {
    final year = DateTime.now().year;
    final rows = await _db.query(
      '''SELECT COUNT(*) AS cnt FROM grn
         WHERE grn_number LIKE :p0''',
      ['GRN-$year-%'],
    );
    final count = int.tryParse(rows.first['cnt']?.toString() ?? '0') ?? 0;
    final seq   = (count + 1).toString().padLeft(4, '0');
    return 'GRN-$year-$seq';
  }

  // ─── GRN CRUD ──────────────────────────────────────────────────────────────
  Future<List<GRN>> getAllGRNs() async {
    final rows = await _db.query(
      'SELECT * FROM grn ORDER BY received_at DESC',
    );
    final grns = <GRN>[];
    for (final row in rows) {
      final items = await _getGRNItems(
        int.tryParse(row['id']?.toString() ?? '0') ?? 0,
      );
      grns.add(GRN.fromMap(row, items: items));
    }
    return grns;
  }

  Future<List<GRN>> searchGRNs(String q) async {
    final rows = await _db.query(
      '''SELECT * FROM grn
         WHERE grn_number    LIKE :p0
            OR invoice_number LIKE :p1
            OR supplier_name  LIKE :p2
         ORDER BY received_at DESC''',
      ['%$q%', '%$q%', '%$q%'],
    );
    final grns = <GRN>[];
    for (final row in rows) {
      final items = await _getGRNItems(
        int.tryParse(row['id']?.toString() ?? '0') ?? 0,
      );
      grns.add(GRN.fromMap(row, items: items));
    }
    return grns;
  }

  Future<List<GRN>> getGRNsByDateRange(DateTime from, DateTime to) async {
    final rows = await _db.query(
      '''SELECT * FROM grn
         WHERE supply_date BETWEEN :p0 AND :p1
         ORDER BY supply_date DESC''',
      [
        from.toIso8601String().split('T').first,
        to.toIso8601String().split('T').first,
      ],
    );
    final grns = <GRN>[];
    for (final row in rows) {
      final items = await _getGRNItems(
        int.tryParse(row['id']?.toString() ?? '0') ?? 0,
      );
      grns.add(GRN.fromMap(row, items: items));
    }
    return grns;
  }

  Future<GRN?> getGRNById(int id) async {
    final rows = await _db.query(
      'SELECT * FROM grn WHERE id=:p0 LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    final items = await _getGRNItems(id);
    return GRN.fromMap(rows.first, items: items);
  }

  Future<void> createGRN(GRN grn) async {
    // Insert header
    final grnId = await _db.execute(
      '''INSERT INTO grn
           (grn_number, invoice_number, supplier_id, supplier_name,
            supply_date, received_at, status)
         VALUES (:p0,:p1,:p2,:p3,:p4,:p5,:p6)''',
      [
        grn.grnNumber,
        grn.invoiceNumber,
        grn.supplierId,
        grn.supplierName,
        grn.supplyDate.toIso8601String().split('T').first,
        grn.receivedAt.toIso8601String(),
        grn.status,
      ],
    );
    // Insert items and update stock
    for (final item in grn.items) {
      await _db.execute(
        '''INSERT INTO grn_items
             (grn_id, medicine_id, medicine_name, quantity, unit_cost, selling_price)
           VALUES (:p0,:p1,:p2,:p3,:p4,:p5)''',
        [
          grnId,
          item.medicineId,
          item.medicineName,
          item.quantity,
          item.unitCost,
          item.sellingPrice,
        ],
      );
      // Add stock
      await _db.execute(
        'UPDATE medicines SET stock = stock + :p0 WHERE id = :p1',
        [item.quantity, item.medicineId],
      );
    }
  }

  Future<void> cancelGRN(int grnId) async {
    final items = await _getGRNItems(grnId);
    // Reverse stock
    for (final item in items) {
      await _db.execute(
        'UPDATE medicines SET stock = stock - :p0 WHERE id = :p1',
        [item.quantity, item.medicineId],
      );
    }
    await _db.execute(
      "UPDATE grn SET status='cancelled' WHERE id=:p0",
      [grnId],
    );
  }

  Future<List<GRNItem>> _getGRNItems(int grnId) async {
    final rows = await _db.query(
      'SELECT * FROM grn_items WHERE grn_id=:p0 ORDER BY id ASC',
      [grnId],
    );
    return rows.map(GRNItem.fromMap).toList();
  }
}