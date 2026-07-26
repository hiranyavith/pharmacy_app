// lib/models/stock_movement.dart
class StockMovement {
  final int? id;
  final int medicineId;
  final int quantity;       // units received (always positive for a restock)
  final double? costPrice;  // optional: purchase price per unit
  final String? supplier;
  final String? notes;
  final DateTime createdAt;

  StockMovement({
    this.id,
    required this.medicineId,
    required this.quantity,
    this.costPrice,
    this.supplier,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StockMovement.fromMap(Map<String, dynamic> m) => StockMovement(
        id: int.tryParse(m['id']?.toString() ?? ''),
        medicineId: int.tryParse(m['medicine_id']?.toString() ?? '0') ?? 0,
        quantity: int.tryParse(m['quantity']?.toString() ?? '0') ?? 0,
        costPrice: m['cost_price'] != null
            ? double.tryParse(m['cost_price'].toString())
            : null,
        supplier: m['supplier']?.toString(),
        notes: m['notes']?.toString(),
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  double get totalCost => (costPrice ?? 0) * quantity;
}