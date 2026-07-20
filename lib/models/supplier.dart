// lib/models/supplier.dart

class Supplier {
  final int?   id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;

  Supplier({
    this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
  });

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
    id:            int.tryParse(m['id']?.toString() ?? ''),
    name:          m['name']           ?? '',
    contactPerson: m['contact_person']?.toString(),
    phone:         m['phone']?.toString(),
    email:         m['email']?.toString(),
    address:       m['address']?.toString(),
  );

  Map<String, dynamic> toMap() => {
    'name':           name,
    'contact_person': contactPerson,
    'phone':          phone,
    'email':          email,
    'address':        address,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

class GRNItem {
  final int?   id;
  final int    grnId;
  final int    medicineId;
  final String medicineName;   // denormalised for display
  final int    quantity;
  final double unitCost;       // cost price per unit this GRN
  final double sellingPrice;   // selling price captured at time of GRN

  GRNItem({
    this.id,
    required this.grnId,
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.unitCost,
    required this.sellingPrice,
  });

  double get lineTotal => quantity * unitCost;

  factory GRNItem.fromMap(Map<String, dynamic> m) => GRNItem(
    id:           int.tryParse(m['id']?.toString() ?? ''),
    grnId:        int.tryParse(m['grn_id']?.toString() ?? '0') ?? 0,
    medicineId:   int.tryParse(m['medicine_id']?.toString() ?? '0') ?? 0,
    medicineName: m['medicine_name']?.toString() ?? '',
    quantity:     int.tryParse(m['quantity']?.toString() ?? '0') ?? 0,
    unitCost:     double.tryParse(m['unit_cost']?.toString() ?? '0') ?? 0,
    sellingPrice: double.tryParse(m['selling_price']?.toString() ?? '0') ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'grn_id':        grnId,
    'medicine_id':   medicineId,
    'medicine_name': medicineName,
    'quantity':      quantity,
    'unit_cost':     unitCost,
    'selling_price': sellingPrice,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

class GRN {
  final int?      id;
  final String    grnNumber;      // e.g. GRN-2025-0042
  final String    invoiceNumber;  // supplier's invoice ref
  final int       supplierId;
  final String    supplierName;   // denormalised for display
  final DateTime  supplyDate;
  final DateTime  receivedAt;
  final String    status;         // draft | received | cancelled
  final List<GRNItem> items;

  GRN({
    this.id,
    required this.grnNumber,
    required this.invoiceNumber,
    required this.supplierId,
    required this.supplierName,
    required this.supplyDate,
    required this.receivedAt,
    this.status = 'received',
    this.items = const [],
  });

  double get totalCost => items.fold(0, (s, i) => s + i.lineTotal);
  int    get totalUnits => items.fold(0, (s, i) => s + i.quantity);

  factory GRN.fromMap(Map<String, dynamic> m, {List<GRNItem> items = const []}) => GRN(
    id:            int.tryParse(m['id']?.toString() ?? ''),
    grnNumber:     m['grn_number']   ?? '',
    invoiceNumber: m['invoice_number'] ?? '',
    supplierId:    int.tryParse(m['supplier_id']?.toString() ?? '0') ?? 0,
    supplierName:  m['supplier_name']?.toString() ?? '',
    supplyDate:    DateTime.tryParse(m['supply_date']?.toString() ?? '') ?? DateTime.now(),
    receivedAt:    DateTime.tryParse(m['received_at']?.toString() ?? '') ?? DateTime.now(),
    status:        m['status']?.toString() ?? 'received',
    items:         items,
  );

  Map<String, dynamic> toMap() => {
    'grn_number':     grnNumber,
    'invoice_number': invoiceNumber,
    'supplier_id':    supplierId,
    'supplier_name':  supplierName,
    'supply_date':    supplyDate.toIso8601String().split('T').first,
    'received_at':    receivedAt.toIso8601String(),
    'status':         status,
  };
}