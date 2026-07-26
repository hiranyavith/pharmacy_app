// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharmacy_app/screens/grn_screen.dart';
import '../services/auth_service.dart';
import '../services/medicine_service.dart';
import '../services/billing_service.dart';
// import '../services/claim_service.dart';
import '../models/medicine.dart';
import '../models/bill.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'medicine_screen.dart';
import 'pos_screen.dart';
import 'bill_history_screen.dart';
import 'expiry_screen.dart';
// import 'claims_screen.dart';

// ─────────────────────────────────────────────────────────────
// Dashboard Shell  (sidebar + page router)
// ─────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selected = 0;
  bool _sidebarCollapsed = false;

  // ── Stats loaded for home page ────────
  int _totalMeds = 0;
  int _lowStock = 0;
  int _expiringSoon = 0;
  int _totalBills = 0;
  int _totalClaims = 0;
  double _todaySales = 0.00;
  double _monthlyIncome = 0.00;
  double _inventoryValue = 0;
  List<Medicine> _expiringList = [];
  List<Medicine> _lowStockList = [];
  List<Bill> _recentBills = [];
  bool _loadingStats = true;

  static const _navItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', null),
    _NavItem(Icons.medication_outlined, Icons.medication, 'Inventory', null),
    _NavItem(Icons.point_of_sale_outlined, Icons.point_of_sale, 'POS / Billing',
        null),
    _NavItem(
        Icons.receipt_long_outlined, Icons.receipt_long, 'Bill History', null),
    _NavItem(Icons.warning_amber_outlined, Icons.warning_amber, 'Alerts', null),
    // _NavItem(Icons.assignment_return_outlined, Icons.assignment_return,'Claims',      null),
  ];

  final _pages = const [
    _DashboardHomePlaceholder(), // replaced dynamically below
    MedicineScreen(),
    POSScreen(),
    BillHistoryScreen(),
    ExpiryScreen(),
    GRNScreen(),
    // ClaimsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final ms = MedicineService();
    final bs = BillingService();
    // final cs  = ClaimService();
    final all = await ms.getAll();
    final low = await ms.getLowStock();
    final exp = await ms.getExpiringSoon();
    final bills = await bs.getAllBills();
    final todaySales = await bs.getTodaySales();
    final monthlyIncome = await bs.getMonthlySales();
    // final claims = await cs.getAllClaims();

    if (!mounted) return;
    setState(() {
      _totalMeds = all.length;
      _lowStock = low.length;
      _expiringSoon = exp.length;
      _totalBills = bills.length;
      _todaySales = todaySales;
      _monthlyIncome = monthlyIncome;
      // _totalClaims   = claims.length;
      _inventoryValue = all.fold(0.0, (s, m) => s + m.totalValue);
      _lowStockList = low.take(5).toList();
      _expiringList = exp.take(5).toList();
      _recentBills = bills.take(6).toList();
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
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Scaffold(
      body: Row(children: [
        // ════════════════════════════════════
        // SIDEBAR
        // ════════════════════════════════════
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _sidebarCollapsed ? 72 : 230,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
            ),
          ),
          child: Column(children: [
            // Brand header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.shop, color: Colors.white, size: 22),
                    ),
                    if (!_sidebarCollapsed) ...[
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Sampath Book Shop',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ],
                  ]),
                  if (!_sidebarCollapsed) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 36),
                      child: Text('Point Of Sale',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ),

            Container(height: 1, color: Colors.white.withOpacity(0.12)),

            // Collapse/expand toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () =>
                      setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisAlignment: _sidebarCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        Icon(
                          _sidebarCollapsed
                              ? Icons.chevron_right
                              : Icons.chevron_left,
                          color: Colors.white70,
                          size: 18,
                        ),
                        if (!_sidebarCollapsed) ...[
                          const SizedBox(width: 8),
                          Text('Collapse',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Container(height: 1, color: Colors.white.withOpacity(0.12)),

            // Section label
            if (!_sidebarCollapsed)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                child: Text('NAVIGATION',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ),

            // Nav items
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                itemCount: _navItems.length,
                itemBuilder: (_, i) {
                  final active = _selected == i;
                  // Badge count for alerts/claims
                  int? badge;
                  if (i == 4 && (_lowStock + _expiringSoon) > 0)
                    badge = _lowStock + _expiringSoon;
                  if (i == 5 && _totalClaims > 0) badge = _totalClaims;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() => _selected = i);
                          if (i == 0) _loadStats();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(
                              horizontal: _sidebarCollapsed ? 8 : 12,
                              vertical: 11),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white.withOpacity(0.16)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: active
                                ? Border.all(
                                    color: Colors.white.withOpacity(0.12))
                                : null,
                          ),
                          child: Tooltip(
                            message:
                                _sidebarCollapsed ? _navItems[i].label : '',
                            child: Row(
                              mainAxisAlignment: _sidebarCollapsed
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                if (!_sidebarCollapsed)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: active ? 3 : 0,
                                    height: active ? 18 : 0,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                Icon(
                                  active
                                      ? _navItems[i].activeIcon
                                      : _navItems[i].icon,
                                  color: active
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.55),
                                  size: 19,
                                ),
                                if (!_sidebarCollapsed) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(_navItems[i].label,
                                        style: TextStyle(
                                          color: active
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.65),
                                          fontWeight: active
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          fontSize: 13.5,
                                        )),
                                  ),
                                  if (badge != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? Colors.white.withOpacity(0.25)
                                            : Colors.red.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text('$badge',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                ] else if (badge != null)
                                  Positioned(
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 2),
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text('$badge',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom: user info
            Container(height: 1, color: Colors.white.withOpacity(0.12)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: _sidebarCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ]),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child:
                        const Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  if (!_sidebarCollapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(AuthService.currentUser ?? 'Admin',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text('Administrator',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10)),
                        ])),
                    IconButton(
                      icon: const Icon(Icons.logout,
                          color: Colors.white54, size: 17),
                      tooltip: 'Logout',
                      onPressed: _logout,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ),
          ]),
        ),

        // ════════════════════════════════════
        // MAIN CONTENT
        // ════════════════════════════════════
        Expanded(
          child: _selected == 0
              ? _DashboardHome(
                  greeting: greeting,
                  totalMeds: _totalMeds,
                  lowStock: _lowStock,
                  expiringSoon: _expiringSoon,
                  totalBills: _totalBills,
                  totalClaims: _totalClaims,
                  todaySales: _todaySales,
                  monthlyIncome: _monthlyIncome,
                  inventoryValue: _inventoryValue,
                  expiringList: _expiringList,
                  lowStockList: _lowStockList,
                  recentBills: _recentBills,
                  loading: _loadingStats,
                  onNavigate: (i) => setState(() => _selected = i),
                  onRefresh: _loadStats,
                )
              : _pages[_selected],
        ),
      ]),
    );
  }
}

// ── placeholder so const list compiles ───
class _DashboardHomePlaceholder extends StatelessWidget {
  const _DashboardHomePlaceholder();
  @override
  Widget build(BuildContext context) => const SizedBox();
}

// ── Nav item data ─────────────────────────
class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  final int? badge;
  const _NavItem(this.icon, this.activeIcon, this.label, this.badge);
}

// ─────────────────────────────────────────────────────────────
// DASHBOARD HOME PAGE
// ─────────────────────────────────────────────────────────────
class _DashboardHome extends StatelessWidget {
  final String greeting;
  final int totalMeds, lowStock, expiringSoon, totalBills, totalClaims;
  final double todaySales;
  final double monthlyIncome;
  final double inventoryValue;
  final List<Medicine> expiringList, lowStockList;
  final List<Bill> recentBills;
  final bool loading;
  final void Function(int) onNavigate;
  final VoidCallback onRefresh;

  const _DashboardHome({
    required this.greeting,
    required this.totalMeds,
    required this.lowStock,
    required this.expiringSoon,
    required this.totalBills,
    required this.totalClaims,
    required this.todaySales,
    required this.monthlyIncome,
    required this.inventoryValue,
    required this.expiringList,
    required this.lowStockList,
    required this.recentBills,
    required this.loading,
    required this.onNavigate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM  hh:mm a');

    return Column(children: [
      // ── Top bar ──────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain)),
            Text(
                '${AuthService.currentUser ?? "Admin"}  ·  '
                '${DateFormat("EEEE, dd MMM yyyy").format(DateTime.now())}',
                style: const TextStyle(color: AppTheme.textSub, fontSize: 13)),
          ]),
          const Spacer(),
          // Refresh
          OutlinedButton.icon(
            onPressed: loading ? null : onRefresh,
            icon: loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(width: 12),
          // New sale CTA
          ElevatedButton.icon(
            onPressed: () => onNavigate(2),
            icon: const Icon(Icons.point_of_sale, size: 16),
            label: const Text('New Sale'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ]),
      ),
      const Divider(height: 1),

      // ── Scrollable body ──────────────────
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── KPI cards row ───────────
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: _KpiCard(
                              label: 'Total Products',
                              value: '$totalMeds',
                              icon: Icons.medication_outlined,
                              color: AppTheme.primary,
                              sub: 'Products in stock',
                              onTap: () => onNavigate(1),
                            )),
                            const SizedBox(width: 14),
                            Expanded(
                                child: _KpiCard(
                              label: 'Total Bills',
                              value: '$totalBills',
                              icon: Icons.receipt_long_outlined,
                              color: AppTheme.success,
                              sub: 'All time invoices',
                              onTap: () => onNavigate(3),
                            )),
                            const SizedBox(width: 14),
                            Expanded(
                                child: _KpiCard(
                              label: 'Low Stock Items',
                              value: '$lowStock',
                              icon: Icons.inventory_2_outlined,
                              color: lowStock > 0
                                  ? AppTheme.warning
                                  : AppTheme.success,
                              sub: lowStock > 0
                                  ? 'Needs reordering'
                                  : 'All well stocked',
                              alert: lowStock > 0,
                              onTap: () => onNavigate(4),
                            )),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _KpiCard(
                                label: 'Today Sales',
                                value:
                                    'Rs. ${fmt.format(todaySales)}', // Formats as e.g. "Rs. 1,500.00"
                                icon: Icons.price_change,
                                color: AppTheme.success,
                                sub: 'Within 24 Hours',
                                alert: false,
                                onTap: () => onNavigate(3),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                                child: _KpiCard(
                              label: 'Expiring Soon',
                              value: '$expiringSoon',
                              icon: Icons.hourglass_bottom_outlined,
                              color: expiringSoon > 0
                                  ? AppTheme.danger
                                  : AppTheme.success,
                              sub: 'Within 30 days',
                              alert: expiringSoon > 0,
                              onTap: () => onNavigate(4),
                            )),
                            // Expanded(child: _KpiCard(
                            //   label: 'Open Claims',
                            //   value: '$totalClaims',
                            //   icon: Icons.assignment_return_outlined,
                            //   color: totalClaims > 0
                            //       ? AppTheme.danger : AppTheme.textSub,
                            //   sub: 'Pending returns',
                            //   alert: totalClaims > 0,
                            //   onTap: () => onNavigate(5),
                            // )),
                          ]),
                      const SizedBox(height: 20),

                      // ── Inventory value banner ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.account_balance_wallet,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text('Total Inventory Value',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text('Rs. ${fmt.format(inventoryValue)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5)),
                              ])),
                          // Mini stats inside banner
                          _BannerStat('Monthly Income',
                              'Rs. ${fmt.format(monthlyIncome)}'), // ← Added here
                          const SizedBox(width: 24),
                          _BannerStat('Products', '$totalMeds'),
                          const SizedBox(width: 24),
                          _BannerStat('Bills Issued', '$totalBills'),
                          const SizedBox(width: 24),
                          _BannerStat('Alerts', '${lowStock + expiringSoon}',
                              red: (lowStock + expiringSoon) > 0),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      // ── Bottom 3-column grid ────
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Recent Bills ──────────
                            Expanded(
                              flex: 5,
                              child: _Section(
                                title: 'Recent Bills',
                                icon: Icons.receipt_long_outlined,
                                actionLabel: 'View All',
                                onAction: () => onNavigate(3),
                                child: recentBills.isEmpty
                                    ? _Empty('No bills yet')
                                    : Column(
                                        children: recentBills.map((b) {
                                          final isCard =
                                              b.paymentType == PaymentType.card;
                                          return _ListRow(
                                            leading: Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: AppTheme.success
                                                    .withOpacity(0.10),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                isCard
                                                    ? Icons.credit_card
                                                    : Icons.payments_outlined,
                                                size: 16,
                                                color: isCard
                                                    ? AppTheme.primary
                                                    : AppTheme.success,
                                              ),
                                            ),
                                            title: b.invoiceNo,
                                            sub: dateFmt.format(b.createdAt),
                                            trailing:
                                                'Rs. ${fmt.format(b.total)}',
                                            trailingColor: AppTheme.success,
                                            onTap: () => onNavigate(3),
                                          );
                                        }).toList(),
                                      ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            // ── Low Stock ─────────────
                            Expanded(
                              flex: 4,
                              child: _Section(
                                title: 'Low Stock',
                                icon: Icons.inventory_2_outlined,
                                iconColor: AppTheme.warning,
                                actionLabel: 'Manage',
                                onAction: () => onNavigate(4),
                                child: lowStockList.isEmpty
                                    ? _Empty('All items well stocked ✓',
                                        color: AppTheme.success)
                                    : Column(
                                        children: lowStockList.map((m) {
                                          final pct = m.stockWarningLimit > 0
                                              ? (m.stock / m.stockWarningLimit)
                                                  .clamp(0.0, 1.0)
                                              : 0.0;
                                          final color = m.stock == 0
                                              ? AppTheme.danger
                                              : AppTheme.warning;
                                          return _ListRow(
                                            leading: Container(
                                              width: 36,
                                              height: 36,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.10),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text('${m.stock}',
                                                  style: TextStyle(
                                                      color: color,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13)),
                                            ),
                                            title: m.name,
                                            sub: m.category,
                                            trailing: m.stock == 0
                                                ? 'OUT'
                                                : '≤${m.stockWarningLimit}',
                                            trailingColor: color,
                                            extra: _MiniBar(pct, color),
                                            onTap: () => onNavigate(1),
                                          );
                                        }).toList(),
                                      ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            // ── Expiring Soon ─────────
                            Expanded(
                              flex: 4,
                              child: _Section(
                                title: 'Expiring Soon',
                                icon: Icons.hourglass_bottom_outlined,
                                iconColor: AppTheme.danger,
                                actionLabel: 'View All',
                                onAction: () => onNavigate(4),
                                child: expiringList.isEmpty
                                    ? _Empty('No Products expiring soon ✓',
                                        color: AppTheme.success)
                                    : Column(
                                        children: expiringList.map((m) {
                                          final days = m.expiryDate!
                                              .difference(DateTime.now())
                                              .inDays;
                                          final color = days <= 7
                                              ? AppTheme.danger
                                              : AppTheme.warning;
                                          return _ListRow(
                                            leading: Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.10),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                  Icons.hourglass_bottom,
                                                  size: 16,
                                                  color: color),
                                            ),
                                            title: m.name,
                                            sub: DateFormat('dd MMM yyyy')
                                                .format(m.expiryDate!),
                                            trailing: days == 0
                                                ? 'Today!'
                                                : '${days}d left',
                                            trailingColor: color,
                                            onTap: () => onNavigate(4),
                                          );
                                        }).toList(),
                                      ),
                              ),
                            ),
                          ]),

                      const SizedBox(height: 24),

                      // ── Quick actions row ───────
                      _Section(
                        title: 'Quick Actions',
                        icon: Icons.flash_on_outlined,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Wrap(spacing: 12, runSpacing: 10, children: [
                            _ActionChip(
                              icon: Icons.point_of_sale,
                              label: 'New Sale',
                              color: AppTheme.primary,
                              onTap: () => onNavigate(2),
                            ),
                            _ActionChip(
                              icon: Icons.add_circle_outline,
                              label: 'Add Product',
                              color: AppTheme.success,
                              onTap: () => onNavigate(1),
                            ),
                            _ActionChip(
                              icon: Icons.receipt_long_outlined,
                              label: 'Bill History',
                              color: AppTheme.secondary,
                              onTap: () => onNavigate(3),
                            ),
                            _ActionChip(
                              icon: Icons.warning_amber_outlined,
                              label: 'Expiry Alerts',
                              color: AppTheme.warning,
                              onTap: () => onNavigate(4),
                            ),
                            _ActionChip(
                              icon: Icons.support_outlined,
                              label: 'Supplier And GRN',
                              color: AppTheme.danger,
                              onTap: () => onNavigate(5),
                            ),
                            // _ActionChip(
                            //   icon: Icons.assignment_return_outlined,
                            //   label: 'Claims',
                            //   color: AppTheme.danger,
                            //   onTap: () => onNavigate(5),
                            // ),
                          ]),
                        ),
                      ),
                    ]),
              ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// KPI card
// ─────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  final bool alert;
  final VoidCallback onTap;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.sub,
    required this.onTap,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
            border: alert ? Border.all(color: color.withOpacity(0.3)) : null,
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (alert)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.priority_high, size: 11, color: color),
                ),
            ]),
            const SizedBox(height: 14),
            Text(value,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppTheme.textMain)),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSub)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// Banner mini-stat
// ─────────────────────────────────────────────────────────────
class _BannerStat extends StatelessWidget {
  final String label, value;
  final bool red;
  const _BannerStat(this.label, this.value, {this.red = false});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(value,
              style: TextStyle(
                  color: red ? const Color(0xFFFF8A80) : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 11)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────
// Section card container
// ─────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor = AppTheme.primary,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 7),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textMain)),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(actionLabel!,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.primary)),
                ),
            ]),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: child,
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
// Generic list row for sections
// ─────────────────────────────────────────────────────────────
class _ListRow extends StatelessWidget {
  final Widget leading;
  final String title, sub, trailing;
  final Color trailingColor;
  final Widget? extra;
  final VoidCallback onTap;

  const _ListRow({
    required this.leading,
    required this.title,
    required this.sub,
    required this.trailing,
    required this.onTap,
    this.trailingColor = AppTheme.textMain,
    this.extra,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 12)),
                  const SizedBox(height: 1),
                  Text(sub,
                      style: const TextStyle(
                          color: AppTheme.textSub, fontSize: 10)),
                  if (extra != null) ...[
                    const SizedBox(height: 4),
                    extra!,
                  ],
                ])),
            const SizedBox(width: 8),
            Text(trailing,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: trailingColor)),
          ]),
        ),
      );
}

// Mini progress bar for stock level
class _MiniBar extends StatelessWidget {
  final double value;
  final Color color;
  const _MiniBar(this.value, this.color);
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 4,
          backgroundColor: color.withOpacity(0.12),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// Quick action chip
// ─────────────────────────────────────────────────────────────
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  final String text;
  final Color color;
  const _Empty(this.text, {this.color = AppTheme.textSub});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: Text(text, style: TextStyle(color: color, fontSize: 12))),
      );
}
