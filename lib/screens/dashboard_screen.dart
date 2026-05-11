import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/medicine_service.dart';
import '../services/billing_service.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'medicine_screen.dart';
import 'pos_screen.dart';
import 'bill_history_screen.dart';
import 'expiry_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selected = 0;

  // Summary counts
  int _totalMeds = 0;
  int _lowStock = 0;
  int _expiringSoon = 0;
  int _totalBills = 0;
  double _totalBillsValue = 0;
  bool _loadingStats = true;

  final _pages = const [
    _DashboardHome(),
    MedicineScreen(),
    POSScreen(),
    BillHistoryScreen(),
    ExpiryScreen(),
  ];

  final _navItems = const [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _NavItem(Icons.medication_outlined, Icons.medication, 'Medicines'),
    _NavItem(
        Icons.point_of_sale_outlined, Icons.point_of_sale, 'POS / Billing'),
    _NavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Bill History'),
    _NavItem(
        Icons.warning_amber_outlined, Icons.warning_amber, 'Expiry Alerts'),
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final ms = MedicineService();
    final bs = BillingService();
    final all = await ms.getAll();
    final low = await ms.getLowStock();
    final exp = await ms.getExpiringSoon();
    final bills = await bs.getAllBills();
    final totalValue = await bs.getFullBillValue();

    if (!mounted) return;
    setState(() {
      _totalMeds = all.length;
      _lowStock = low.length;
      _expiringSoon = exp.length;
      _totalBills = bills.length;
      _totalBillsValue = double.tryParse(totalValue) ?? 0.00;
      _loadingStats = false;
    });
  }

  void _logout() {
    AuthService.logout();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        // ── Sidebar ───────────────────────────
        Container(
          width: 220,
          color: AppTheme.primary,
          child: Column(children: [
            // Brand
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Row(children: [
                const Icon(Icons.local_pharmacy, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Health Hub Pharmacy System',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),

            // Nav items
            Expanded(
              child: ListView.builder(
                itemCount: _navItems.length,
                itemBuilder: (_, i) {
                  final active = _selected == i;
                  return InkWell(
                    onTap: () {
                      setState(() => _selected = i);
                      if (i == 0) _loadStats();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(
                            active
                                ? _navItems[i].activeIcon
                                : _navItems[i].icon,
                            color: active ? Colors.white : Colors.white70,
                            size: 20),
                        const SizedBox(width: 12),
                        Text(_navItems[i].label,
                            style: TextStyle(
                              color: active ? Colors.white : Colors.white70,
                              fontWeight:
                                  active ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 14,
                            )),
                      ]),
                    ),
                  );
                },
              ),
            ),

            // User + logout
            const Divider(color: Colors.white24, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(AuthService.currentUser ?? 'Admin',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13)),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.logout, color: Colors.white70, size: 18),
                  tooltip: 'Logout',
                  onPressed: _logout,
                ),
              ]),
            ),
          ]),
        ),

        // ── Main content ──────────────────────
        Expanded(
          child: _selected == 0
              ? _DashboardHome(
                  totalMeds: _totalMeds,
                  lowStock: _lowStock,
                  expiringSoon: _expiringSoon,
                  totalBills: _totalBills,
                  totalBillsValue: _totalBillsValue,
                  loading: _loadingStats,
                  onNavigate: (i) => setState(() => _selected = i),
                )
              : _pages[_selected],
        ),
      ]),
    );
  }
}

// ── Nav item data ─────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

// ── Dashboard home (summary cards) ────────
class _DashboardHome extends StatelessWidget {
  final int totalMeds;
  final int lowStock;
  final int expiringSoon;
  final int totalBills;
  final double totalBillsValue;
  final bool loading;
  final void Function(int)? onNavigate;

  const _DashboardHome({
    this.totalMeds = 0,
    this.lowStock = 0,
    this.expiringSoon = 0,
    this.totalBills = 0,
    this.totalBillsValue = 0,
    this.loading = false,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Text('Dashboard',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain)),
        const SizedBox(height: 4),
        Text('Welcome back, ${AuthService.currentUser ?? "Admin"}',
            style: const TextStyle(color: AppTheme.textSub)),
        const SizedBox(height: 24),

        // Summary cards
        loading
            ? const Center(child: CircularProgressIndicator())
            : Wrap(spacing: 40, runSpacing: 20, children: [
                _StatCard('Total Medicines', '$totalMeds', Icons.medication,
                    AppTheme.primary,
                    onTap: () => onNavigate?.call(1)),
                _StatCard('Low Stock', '$lowStock', Icons.inventory_2,
                    AppTheme.warning,
                    onTap: () => onNavigate?.call(1)),
                _StatCard('Expiring Soon', '$expiringSoon', Icons.warning_amber,
                    AppTheme.danger,
                    onTap: () => onNavigate?.call(4)),
                _StatCard('Total Bills', '$totalBills', Icons.receipt_long,
                    AppTheme.success,
                    onTap: () => onNavigate?.call(3)),
                _StatCard('Total Bills Value', 'Rs $totalBillsValue',
                    Icons.currency_rupee, AppTheme.success,
                    onTap: () => onNavigate?.call(3)),
              ]),

        const SizedBox(height: 32),

        // Quick actions
        const Text('Quick Actions',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMain)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _QuickAction('New Sale', Icons.point_of_sale, AppTheme.primary,
              () => onNavigate?.call(2)),
          _QuickAction('Add Medicine', Icons.add_circle, AppTheme.success,
              () => onNavigate?.call(1)),
          _QuickAction('Bill History', Icons.history, AppTheme.secondary,
              () => onNavigate?.call(3)),
          _QuickAction('Expiry Alerts', Icons.warning_amber, AppTheme.danger,
              () => onNavigate?.call(4)),
        ]),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard(this.label, this.value, this.icon, this.color, {this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 14),
            Text(value,
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: AppTheme.textSub, fontSize: 15)),
          ]),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}
