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

  List<Medicine> _expiring  = [];
  List<Medicine> _lowStock  = [];
  bool           _loading   = true;

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
    return Column(children: [
      // Header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Alerts',
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
                  _ExpiryList(medicines: _expiring),
                  _LowStockList(medicines: _lowStock),
                ],
              ),
      ),
    ]);
  }
}

// ── Expiring Soon list ────────────────────
class _ExpiryList extends StatelessWidget {
  final List<Medicine> medicines;
  const _ExpiryList({required this.medicines});

  @override
  Widget build(BuildContext context) {
    if (medicines.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min,
          children: [
        Icon(Icons.check_circle_outline, size: 56, color: AppTheme.success),
        SizedBox(height: 8),
        Text('No medicines expiring within 30 days.',
            style: TextStyle(color: AppTheme.textSub)),
      ]));
    }
    final dateFmt = DateFormat('dd MMM yyyy');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: medicines.length,
      itemBuilder: (_, i) {
        final m    = medicines[i];
        final days = m.expiryDate!.difference(DateTime.now()).inDays;
        final color = days <= 7 ? AppTheme.danger : AppTheme.warning;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            leading: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.hourglass_bottom, color: color, size: 24),
            ),
            title: Text(m.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Category: ${m.category}  ·  Stock: ${m.stock}',
                  style: const TextStyle(fontSize: 12)),
              Text('Expires: ${dateFmt.format(m.expiryDate!)}',
                  style: TextStyle(fontSize: 12, color: color)),
            ]),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                days == 0 ? 'Today!' : 'In $days days',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Low Stock list ────────────────────────
class _LowStockList extends StatelessWidget {
  final List<Medicine> medicines;
  const _LowStockList({required this.medicines});

  @override
  Widget build(BuildContext context) {
    if (medicines.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min,
          children: [
        Icon(Icons.check_circle_outline, size: 56, color: AppTheme.success),
        SizedBox(height: 8),
        Text('All medicines are well stocked.',
            style: TextStyle(color: AppTheme.textSub)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: medicines.length,
      itemBuilder: (_, i) {
        final m     = medicines[i];
        final empty = m.stock == 0;
        final color = empty ? AppTheme.danger : AppTheme.warning;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            leading: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                  empty ? Icons.remove_shopping_cart : Icons.inventory_2,
                  color: color, size: 24),
            ),
            title: Text(m.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Category: ${m.category}',
                style: const TextStyle(fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                empty ? 'OUT OF STOCK' : '${m.stock} left',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        );
      },
    );
  }
}
