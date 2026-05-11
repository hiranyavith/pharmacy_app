// lib/screens/expiry_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/medicine_service.dart';
import '../utils/app_theme.dart';

class ExpiryScreen extends StatefulWidget {
  const ExpiryScreen({super.key});
  @override
  State<ExpiryScreen> createState() => _ExpiryScreenState();
}

class _ExpiryScreenState extends State<ExpiryScreen>
    with SingleTickerProviderStateMixin {
  final _svc = MedicineService();
  late TabController _tab;

  List<Medicine> _expiring = [];
  List<Medicine> _lowStock = [];
  bool           _loading  = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final exp = await _svc.getExpiringSoon();
    final low = await _svc.getLowStock();
    if (mounted) setState(() {
      _expiring = exp;
      _lowStock = low;
      _loading  = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Total stock values
    final expiringTotalValue = _expiring.fold(0.0, (s, m) => s + m.totalValue);
    final lowStockTotalQty   = _lowStock.fold(0,   (s, m) => s + m.stock);
    final lowStockTotalValue = _lowStock.fold(0.0, (s, m) => s + m.totalValue);

    return Column(children: [
      // ── Header ──────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Stock Alerts',
                style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _load,
              tooltip: 'Refresh',
            ),
          ]),
          const SizedBox(height: 8),
          TabBar(
            controller: _tab,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSub,
            indicatorColor: AppTheme.primary,
            tabs: [
              Tab(text: 'Expiring Soon (${_expiring.length})'),
              Tab(text: 'Low Stock (${_lowStock.length})'),
            ],
          ),
        ]),
      ),
      const Divider(height: 1),

      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tab,
                children: [
                  _ExpiryList(
                    medicines:  _expiring,
                    totalValue: expiringTotalValue,
                  ),
                  _LowStockList(
                    medicines:      _lowStock,
                    totalQty:       lowStockTotalQty,
                    totalValue:     lowStockTotalValue,
                  ),
                ],
              ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Expiring Soon list
// ─────────────────────────────────────────────────────────────
class _ExpiryList extends StatelessWidget {
  final List<Medicine> medicines;
  final double totalValue;
  const _ExpiryList({required this.medicines, required this.totalValue});

  @override
  Widget build(BuildContext context) {
    final fmt     = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy');

    if (medicines.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, size: 56, color: AppTheme.success),
        SizedBox(height: 8),
        Text('No medicines expiring within 30 days.',
            style: TextStyle(color: AppTheme.textSub)),
      ]));
    }

    return Column(children: [
      // ── Summary bar ─────────────────────
      _SummaryBar(children: [
        _SummaryTile(
          icon: Icons.hourglass_bottom,
          color: AppTheme.danger,
          label: 'Expiring Items',
          value: '${medicines.length}',
        ),
        _SummaryTile(
          icon: Icons.inventory_2_outlined,
          color: AppTheme.warning,
          label: 'Total Units at Risk',
          value: '${medicines.fold(0, (s, m) => s + m.stock)}',
        ),
        _SummaryTile(
          icon: Icons.attach_money,
          color: AppTheme.primary,
          label: 'Total Stock Value at Risk',
          value: 'Rs. ${fmt.format(totalValue)}',
          wide: true,
        ),
      ]),

      // ── List ────────────────────────────
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: medicines.length,
          itemBuilder: (_, i) {
            final m    = medicines[i];
            final days = m.expiryDate!.difference(DateTime.now()).inDays;
            final color = days <= 7 ? AppTheme.danger : AppTheme.warning;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  // Icon
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.hourglass_bottom, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),

                  // Name + details
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('${m.category}  ·  Stock: ${m.stock} units',
                          style: const TextStyle(
                              color: AppTheme.textSub, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text('Expires: ${dateFmt.format(m.expiryDate!)}',
                          style: TextStyle(fontSize: 12, color: color,
                              fontWeight: FontWeight.w500)),
                    ],
                  )),

                  // Right side: stock value + days badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Total stock value
                      Text('Rs. ${fmt.format(m.totalValue)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14, color: AppTheme.textMain)),
                      const SizedBox(height: 2),
                      Text('stock value',
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textSub)),
                      const SizedBox(height: 6),
                      // Days badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          days == 0 ? 'Expires Today!' : 'In $days days',
                          style: TextStyle(color: color,
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Low Stock list
// ─────────────────────────────────────────────────────────────
class _LowStockList extends StatelessWidget {
  final List<Medicine> medicines;
  final int    totalQty;
  final double totalValue;
  const _LowStockList({
    required this.medicines,
    required this.totalQty,
    required this.totalValue,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    if (medicines.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, size: 56, color: AppTheme.success),
        SizedBox(height: 8),
        Text('All medicines are well stocked.',
            style: TextStyle(color: AppTheme.textSub)),
      ]));
    }

    final outOfStock = medicines.where((m) => m.isOutOfStock).length;

    return Column(children: [
      // ── Summary bar ─────────────────────
      _SummaryBar(children: [
        _SummaryTile(
          icon: Icons.warning_amber,
          color: AppTheme.warning,
          label: 'Low Stock Items',
          value: '${medicines.length}',
        ),
        _SummaryTile(
          icon: Icons.remove_shopping_cart,
          color: AppTheme.danger,
          label: 'Out of Stock',
          value: '$outOfStock',
        ),
        _SummaryTile(
          icon: Icons.inventory_2_outlined,
          color: AppTheme.secondary,
          label: 'Total Units Remaining',
          value: '$totalQty',
        ),
        _SummaryTile(
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.primary,
          label: 'Total Remaining Value',
          value: 'Rs. ${fmt.format(totalValue)}',
          wide: true,
        ),
      ]),

      // ── List ────────────────────────────
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: medicines.length,
          itemBuilder: (_, i) {
            final m     = medicines[i];
            final empty = m.isOutOfStock;
            final color = empty ? AppTheme.danger : AppTheme.warning;
            // How far below the limit
            final below = m.stockWarningLimit - m.stock;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(children: [
                  // Icon
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      empty ? Icons.remove_shopping_cart : Icons.inventory_2,
                      color: color, size: 22),
                  ),
                  const SizedBox(width: 14),

                  // Name + details
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(m.category,
                          style: const TextStyle(
                              color: AppTheme.textSub, fontSize: 12)),
                      const SizedBox(height: 6),
                      // Stock progress bar
                      _StockBar(
                          stock: m.stock,
                          limit: m.stockWarningLimit,
                          color: color),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('${m.stock} / ${m.stockWarningLimit} limit',
                            style: TextStyle(
                                fontSize: 11, color: color,
                                fontWeight: FontWeight.w500)),
                        if (below > 0) ...[
                          const SizedBox(width: 6),
                          Text('(${below} below limit)',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textSub)),
                        ],
                      ]),
                    ],
                  )),

                  const SizedBox(width: 16),

                  // Right: value + stock badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Rs. ${fmt.format(m.totalValue)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14, color: AppTheme.textMain)),
                      const SizedBox(height: 2),
                      Text('stock value',
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textSub)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          empty ? 'OUT OF STOCK' : '${m.stock} left',
                          style: TextStyle(color: color,
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Stock progress bar widget
// ─────────────────────────────────────────────────────────────
class _StockBar extends StatelessWidget {
  final int stock, limit;
  final Color color;
  const _StockBar({required this.stock, required this.limit, required this.color});

  @override
  Widget build(BuildContext context) {
    final ratio = limit > 0 ? (stock / limit).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 6,
        backgroundColor: color.withOpacity(0.15),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Summary bar (horizontal scrollable row of tiles)
// ─────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<Widget> children;
  const _SummaryBar({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: children
            .expand((w) => [w, const SizedBox(width: 10)])
            .toList()
          ..removeLast(),
      ),
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label, value;
  final bool     wide;
  const _SummaryTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: wide ? 210 : 160,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(label, style: const TextStyle(
              color: AppTheme.textSub, fontSize: 10)),
        ],
      )),
    ]),
  );
}