// lib/screens/grn_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/supplier.dart';
import '../models/medicine.dart';
import '../services/supplier_service.dart';
import '../services/medicine_service.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Root: two tabs — GRN List  |  Suppliers
// ─────────────────────────────────────────────────────────────────────────────
class GRNScreen extends StatelessWidget {
  const GRNScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header bar with tabs ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.local_shipping_outlined,
                      color: AppTheme.primary, size: 22),
                  const SizedBox(width: 10),
                  const Text('Goods Received Notes',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMain)),
                ]),
                const SizedBox(height: 10),
                TabBar(
                  isScrollable: false,
                  indicatorColor: AppTheme.primary,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSub,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(
                        icon: Icon(Icons.receipt_long_outlined, size: 18),
                        text: 'GRN Records'),
                    Tab(
                        icon: Icon(Icons.business_outlined, size: 18),
                        text: 'Suppliers'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Tab views ─────────────────────────────────────────────────────
          const Expanded(
            child: TabBarView(children: [
              _GRNListTab(),
              _SuppliersTab(),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAB 1 — GRN Records
// ─────────────────────────────────────────────────────────────────────────────
class _GRNListTab extends StatefulWidget {
  const _GRNListTab();
  @override
  State<_GRNListTab> createState() => _GRNListTabState();
}

class _GRNListTabState extends State<_GRNListTab> {
  final _svc = SupplierService();
  final _searchCtrl = TextEditingController();

  List<GRN> _grns = [];
  bool _loading = true;

  // Date range filter
  DateTimeRange? _dateRange;

  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String q = '']) async {
    setState(() => _loading = true);
    List<GRN> list;
    if (_dateRange != null && q.isEmpty) {
      list = await _svc.getGRNsByDateRange(_dateRange!.start, _dateRange!.end);
    } else if (q.isNotEmpty) {
      list = await _svc.searchGRNs(q);
    } else {
      list = await _svc.getAllGRNs();
    }
    if (mounted)
      setState(() {
        _grns = list;
        _loading = false;
      });
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() => _dateRange = range);
      _load();
    }
  }

  void _clearDateRange() {
    setState(() => _dateRange = null);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final totalGRNValue = _grns
        .where((g) => g.status != 'cancelled')
        .fold(0.0, (s, g) => s + g.totalCost);

    return Column(children: [
      // ── Toolbar ───────────────────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          // Search
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search GRN no., invoice no., supplier…',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
              onChanged: (v) => _load(v),
            ),
          ),
          const SizedBox(width: 12),

          // Date range filter
          _dateRange != null
              ? Chip(
                  backgroundColor: AppTheme.primary.withOpacity(0.08),
                  side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                  label: Text(
                    '${_dateFmt.format(_dateRange!.start)} → '
                    '${_dateFmt.format(_dateRange!.end)}',
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.primary),
                  ),
                  deleteIconColor: AppTheme.primary,
                  onDeleted: _clearDateRange,
                )
              : OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: const Text('Filter by Date'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSub,
                      side: BorderSide(color: Colors.grey[300]!)),
                ),

          const Spacer(),

          ElevatedButton.icon(
            onPressed: () => _openCreateGRN(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New GRN'),
          ),
        ]),
      ),
      const Divider(height: 1),

      // ── Table ─────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _grns.isEmpty
                ? _emptyState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Card(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            AppTheme.primary.withOpacity(0.06)),
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('GRN No.')),
                          DataColumn(label: Text('Invoice No.')),
                          DataColumn(label: Text('Supplier')),
                          DataColumn(label: Text('Supply Date')),
                          DataColumn(label: Text('Received')),
                          DataColumn(label: Text('Items')),
                          DataColumn(label: Text('Total Cost (Rs.)')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _grns.map((g) => _buildRow(g)).toList(),
                      ),
                    ),
                  ),
      ),

      // ── Summary footer ────────────────────────────────────────────────────
      if (!_loading && _grns.isNotEmpty)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2))
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(children: [
            const Icon(Icons.summarize_outlined,
                size: 16, color: AppTheme.textSub),
            const SizedBox(width: 6),
            Text(
              _dateRange != null ? 'Filtered Summary' : 'GRN Summary',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSub,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 20),
            _FooterTile(
              label: 'Total GRNs',
              value: '${_grns.length}',
              icon: Icons.receipt_long_outlined,
              color: AppTheme.primary,
            ),
            _footerDivider(),
            _FooterTile(
              label: 'Received',
              value: '${_grns.where((g) => g.status == 'received').length}',
              icon: Icons.check_circle_outline,
              color: AppTheme.success,
            ),
            _footerDivider(),
            _FooterTile(
              label: 'Cancelled',
              value: '${_grns.where((g) => g.status == 'cancelled').length}',
              icon: Icons.cancel_outlined,
              color: AppTheme.danger,
            ),
            _footerDivider(),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Purchase Value',
                          style:
                              TextStyle(fontSize: 11, color: AppTheme.textSub)),
                      Text('Rs. ${_fmt.format(totalGRNValue)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary)),
                    ],
                  ),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }

  DataRow _buildRow(GRN g) {
    final isReceived = g.status == 'received';
    final isCancelled = g.status == 'cancelled';

    Color statusColor;
    IconData statusIcon;
    if (isCancelled) {
      statusColor = AppTheme.danger;
      statusIcon = Icons.cancel_outlined;
    } else {
      statusColor = AppTheme.success;
      statusIcon = Icons.check_circle_outline;
    }

    return DataRow(
      color: isCancelled
          ? WidgetStateProperty.all(AppTheme.danger.withOpacity(0.04))
          : null,
      cells: [
        // GRN Number
        DataCell(Text(g.grnNumber,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: AppTheme.primary))),

        // Invoice Number
        DataCell(Text(g.invoiceNumber,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),

        // Supplier
        DataCell(Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.business, size: 14, color: AppTheme.secondary),
          ),
          const SizedBox(width: 8),
          Text(g.supplierName,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ])),

        // Supply Date
        DataCell(Text(_dateFmt.format(g.supplyDate))),

        // Received At
        DataCell(Text(
          DateFormat('dd MMM yyyy, hh:mm a').format(g.receivedAt),
          style: const TextStyle(fontSize: 12, color: AppTheme.textSub),
        )),

        // Items count
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('${g.items.length} item${g.items.length != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
        )),

        // Total Cost
        DataCell(Text('Rs. ${_fmt.format(g.totalCost)}',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isCancelled ? AppTheme.textSub : AppTheme.textMain,
                decoration: isCancelled ? TextDecoration.lineThrough : null))),

        // Status badge
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(statusIcon, size: 12, color: statusColor),
            const SizedBox(width: 4),
            Text(
              isReceived ? 'Received' : 'Cancelled',
              style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        )),

        // Actions
        DataCell(Row(children: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined,
                size: 18, color: AppTheme.primary),
            tooltip: 'View Details',
            onPressed: () => _showGRNDetail(g),
          ),
          if (isReceived)
            IconButton(
              icon: const Icon(Icons.cancel_outlined,
                  size: 18, color: AppTheme.danger),
              tooltip: 'Cancel GRN',
              onPressed: () => _cancelGRN(g),
            ),
        ])),
      ],
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No GRN records found',
              style: TextStyle(fontSize: 16, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('Create a new GRN to record stock received from suppliers.',
              style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openCreateGRN,
            icon: const Icon(Icons.add),
            label: const Text('New GRN'),
          ),
        ]),
      );

  void _openCreateGRN() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateGRNDialog(onCreated: _load),
    );
  }

  void _showGRNDetail(GRN grn) {
    showDialog(
      context: context,
      builder: (_) => _GRNDetailDialog(grn: grn),
    );
  }

  Future<void> _cancelGRN(GRN grn) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel GRN?'),
        content: Text(
          'This will reverse all stock changes from GRN "${grn.grnNumber}".\n'
          'Total of ${grn.totalUnits} units across ${grn.items.length} items '
          'will be deducted from stock.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child:
                const Text('Cancel GRN', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SupplierService().cancelGRN(grn.id!);
      if (mounted) {
        showSuccess(context, 'GRN ${grn.grnNumber} cancelled.');
        _load();
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAB 2 — Suppliers
// ─────────────────────────────────────────────────────────────────────────────
class _SuppliersTab extends StatefulWidget {
  const _SuppliersTab();
  @override
  State<_SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<_SuppliersTab> {
  final _svc = SupplierService();
  final _searchCtrl = TextEditingController();
  List<Supplier> _suppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String q = '']) async {
    setState(() => _loading = true);
    final list = q.isEmpty
        ? await _svc.getAllSuppliers()
        : await _svc.searchSuppliers(q);
    if (mounted)
      setState(() {
        _suppliers = list;
        _loading = false;
      });
  }

  void _openForm([Supplier? s]) async {
    await showDialog(
      context: context,
      builder: (_) => _SupplierForm(supplier: s, onSaved: _load),
    );
  }

  Future<void> _delete(Supplier s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text(
          'Delete "${s.name}"?\n'
          'Existing GRN records will retain the supplier name for history.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _svc.deleteSupplier(s.id!);
      if (mounted) {
        showSuccess(context, '${s.name} deleted.');
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Toolbar ───────────────────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by name, contact or phone…',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
              onChanged: _load,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Supplier'),
          ),
        ]),
      ),
      const Divider(height: 1),

      // ── Table ─────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _suppliers.isEmpty
                ? _emptyState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Card(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            AppTheme.primary.withOpacity(0.06)),
                        columns: const [
                          DataColumn(label: Text('Supplier Name')),
                          DataColumn(label: Text('Contact Person')),
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Address')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _suppliers.map((s) {
                          return DataRow(cells: [
                            DataCell(Row(children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    s.name.isNotEmpty
                                        ? s.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ])),
                            DataCell(Text(s.contactPerson ?? '—',
                                style:
                                    const TextStyle(color: AppTheme.textSub))),
                            DataCell(s.phone == null || s.phone!.isEmpty
                                ? const Text('—',
                                    style: TextStyle(color: AppTheme.textSub))
                                : Row(children: [
                                    const Icon(Icons.phone_outlined,
                                        size: 14, color: AppTheme.textSub),
                                    const SizedBox(width: 4),
                                    Text(s.phone!),
                                  ])),
                            DataCell(s.email == null || s.email!.isEmpty
                                ? const Text('—',
                                    style: TextStyle(color: AppTheme.textSub))
                                : Row(children: [
                                    const Icon(Icons.email_outlined,
                                        size: 14, color: AppTheme.textSub),
                                    const SizedBox(width: 4),
                                    Text(s.email!,
                                        style: const TextStyle(fontSize: 13)),
                                  ])),
                            DataCell(Text(s.address ?? '—',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSub))),
                            DataCell(Row(children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18, color: AppTheme.primary),
                                tooltip: 'Edit',
                                onPressed: () => _openForm(s),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: AppTheme.danger),
                                tooltip: 'Delete',
                                onPressed: () => _delete(s),
                              ),
                            ])),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
      ),

      // ── Footer count ──────────────────────────────────────────────────────
      if (!_loading && _suppliers.isNotEmpty)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(children: [
            const Icon(Icons.business_outlined,
                size: 15, color: AppTheme.textSub),
            const SizedBox(width: 8),
            Text(
                '${_suppliers.length} supplier${_suppliers.length != 1 ? 's' : ''} registered',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
          ]),
        ),
    ]);
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.business_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No suppliers yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('Add your medicine suppliers to start creating GRNs.',
              style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Add Supplier'),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Supplier Add / Edit Form
// ─────────────────────────────────────────────────────────────────────────────
class _SupplierForm extends StatefulWidget {
  final Supplier? supplier;
  final VoidCallback onSaved;
  const _SupplierForm({this.supplier, required this.onSaved});
  @override
  State<_SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<_SupplierForm> {
  final _formKey = GlobalKey<FormState>();
  final _svc = SupplierService();
  late TextEditingController _name, _contact, _phone, _email, _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _name = TextEditingController(text: s?.name ?? '');
    _contact = TextEditingController(text: s?.contactPerson ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
    _email = TextEditingController(text: s?.email ?? '');
    _address = TextEditingController(text: s?.address ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final s = Supplier(
      id: widget.supplier?.id,
      name: _name.text.trim(),
      contactPerson: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
    );
    try {
      if (widget.supplier == null) {
        await _svc.addSupplier(s);
      } else {
        await _svc.updateSupplier(s);
      }
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context,
            widget.supplier == null ? 'Supplier added.' : 'Supplier updated.');
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplier != null;
    return AlertDialog(
      title: Row(children: [
        Icon(isEdit ? Icons.edit : Icons.business_outlined,
            color: AppTheme.primary, size: 22),
        const SizedBox(width: 8),
        Text(isEdit ? 'Edit Supplier' : 'Add Supplier'),
      ]),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Company / Supplier Name *',
                prefixIcon: Icon(Icons.business_outlined, size: 18),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contact,
              decoration: const InputDecoration(
                labelText: 'Contact Person',
                prefixIcon: Icon(Icons.person_outline, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, size: 18),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Icon(isEdit ? Icons.save_outlined : Icons.add, size: 16),
          label: Text(isEdit ? 'Update' : 'Add Supplier'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Create GRN Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _CreateGRNDialog extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateGRNDialog({required this.onCreated});
  @override
  State<_CreateGRNDialog> createState() => _CreateGRNDialogState();
}

class _CreateGRNDialogState extends State<_CreateGRNDialog> {
  final _formKey = GlobalKey<FormState>();
  final _svc = SupplierService();
  final _medSvc = MedicineService();
  final _invoiceCtrl = TextEditingController();

  List<Supplier> _suppliers = [];
  List<Medicine> _medicines = [];
  Supplier? _selectedSupplier;
  DateTime _supplyDate = DateTime.now();
  String _grnNumber = '';
  bool _loading = true;
  bool _saving = false;

  // Line items being built
  final List<_GRNLineItem> _lines = [];

  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final suppliers = await _svc.getAllSuppliers();
    final meds = await _medSvc.getAll();
    final grnNo = await _svc.nextGrnNumber();
    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        _medicines = meds;
        _grnNumber = grnNo;
        _loading = false;
      });
    }
  }

  void _addLine() {
    setState(() => _lines.add(_GRNLineItem(medicines: _medicines)));
  }

  void _removeLine(int i) {
    setState(() => _lines.removeAt(i));
  }

  double get _grandTotal => _lines.fold(0.0, (s, l) => s + l.lineTotal);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _supplyDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _supplyDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplier == null) {
      showError(context, 'Please select a supplier.');
      return;
    }
    if (_lines.isEmpty) {
      showError(context, 'Add at least one item.');
      return;
    }
    // Validate all lines
    for (int i = 0; i < _lines.length; i++) {
      if (!_lines[i].isValid) {
        showError(context, 'Row ${i + 1}: fill in all fields correctly.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final grn = GRN(
        grnNumber: _grnNumber,
        invoiceNumber: _invoiceCtrl.text.trim(),
        supplierId: _selectedSupplier!.id!,
        supplierName: _selectedSupplier!.name,
        supplyDate: _supplyDate,
        receivedAt: DateTime.now(),
        items: _lines
            .map((l) => GRNItem(
                  grnId: 0, // assigned in service
                  medicineId: l.medicine!.id!,
                  medicineName: l.medicine!.name,
                  quantity: l.qty,
                  unitCost: l.unitCost,
                  sellingPrice: l.sellingPrice,
                ))
            .toList(),
      );
      await _svc.createGRN(grn);
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, 'GRN $_grnNumber created — stock updated.');
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: SizedBox(
        width: 860,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.04),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined,
                  color: AppTheme.primary, size: 24),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Create Goods Received Note',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain)),
                Text('Auto GRN No: $_grnNumber',
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppTheme.primary)),
              ]),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _formKey,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row 1: Supplier + Invoice + Supply Date
                            Row(children: [
                              // Supplier dropdown
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<Supplier>(
                                  value: _selectedSupplier,
                                  decoration: const InputDecoration(
                                    labelText: 'Supplier *',
                                    prefixIcon:
                                        Icon(Icons.business_outlined, size: 18),
                                  ),
                                  items: _suppliers
                                      .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s.name),
                                          ))
                                      .toList(),
                                  onChanged: (s) =>
                                      setState(() => _selectedSupplier = s),
                                  validator: (v) =>
                                      v == null ? 'Select a supplier' : null,
                                  hint: _suppliers.isEmpty
                                      ? const Text(
                                          'No suppliers — add one first',
                                          style:
                                              TextStyle(color: AppTheme.danger))
                                      : const Text('Select supplier'),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Invoice number
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _invoiceCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Supplier Invoice No. *',
                                    prefixIcon: Icon(Icons.numbers, size: 18),
                                    hintText: 'e.g. INV-2025-001',
                                  ),
                                  style:
                                      const TextStyle(fontFamily: 'monospace'),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Required'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Supply date
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Supply Date *',
                                      prefixIcon: Icon(
                                          Icons.calendar_today_outlined,
                                          size: 18),
                                      suffixIcon:
                                          Icon(Icons.edit_calendar, size: 18),
                                    ),
                                    child: Text(_dateFmt.format(_supplyDate)),
                                  ),
                                ),
                              ),
                            ]),

                            const SizedBox(height: 24),

                            // Items section
                            Row(children: [
                              const Text('Items Received',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textMain)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('${_lines.length}',
                                    style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _medicines.isEmpty ? null : _addLine,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Item'),
                              ),
                            ]),
                            const SizedBox(height: 8),

                            // Column headers
                            if (_lines.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(children: [
                                  Expanded(
                                      flex: 4,
                                      child: Text('Medicine',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textSub))),
                                  SizedBox(width: 8),
                                  Expanded(
                                      flex: 2,
                                      child: Text('Qty',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textSub))),
                                  SizedBox(width: 8),
                                  Expanded(
                                      flex: 2,
                                      child: Text('Unit Cost (Rs.)',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textSub))),
                                  SizedBox(width: 8),
                                  Expanded(
                                      flex: 2,
                                      child: Text('Selling Price (Rs.)',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textSub))),
                                  SizedBox(width: 8),
                                  Expanded(
                                      flex: 2,
                                      child: Text('Line Total',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textSub))),
                                  SizedBox(width: 40),
                                ]),
                              ),
                              const SizedBox(height: 4),
                            ],

                            // Item rows
                            ...List.generate(_lines.length, (i) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _lines[i].buildRow(
                                  context,
                                  onRemove: () => _removeLine(i),
                                  onChanged: () => setState(() {}),
                                  fmt: _fmt,
                                ),
                              );
                            }),

                            if (_lines.isEmpty)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.grey[200]!,
                                      style: BorderStyle.solid),
                                ),
                                child: Column(children: [
                                  Icon(Icons.add_shopping_cart_outlined,
                                      size: 32, color: Colors.grey[350]),
                                  const SizedBox(height: 8),
                                  Text('No items added yet',
                                      style:
                                          TextStyle(color: Colors.grey[500])),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed:
                                        _medicines.isEmpty ? null : _addLine,
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add First Item'),
                                  ),
                                ]),
                              ),

                            // Grand total
                            if (_lines.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme.primary.withOpacity(0.2)),
                                ),
                                child: Row(children: [
                                  const Spacer(),
                                  const Text('Grand Total Cost:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textSub)),
                                  const SizedBox(width: 12),
                                  Text('Rs. ${_fmt.format(_grandTotal)}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary)),
                                ]),
                              ),
                            ],
                          ]),
                    ),
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(children: [
              Text(
                'Stock will be updated automatically on save.',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSub.withOpacity(0.7)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save GRN & Update Stock'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── A mutable line item in the Create GRN dialog ──────────────────────────────
class _GRNLineItem {
  final List<Medicine> medicines;
  Medicine? medicine;

  final _qtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _sellCtrl = TextEditingController();

  _GRNLineItem({required this.medicines});

  int get qty => int.tryParse(_qtyCtrl.text) ?? 0;
  double get unitCost => double.tryParse(_costCtrl.text) ?? 0;
  double get sellingPrice => double.tryParse(_sellCtrl.text) ?? 0;
  double get lineTotal => qty * unitCost;

  bool get isValid =>
      medicine != null && qty > 0 && unitCost > 0 && sellingPrice > 0;

  Widget buildRow(
    BuildContext context, {
    required VoidCallback onRemove,
    required VoidCallback onChanged,
    required NumberFormat fmt,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(children: [
        // Medicine picker
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<Medicine>(
            value: medicine,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
            ),
            hint: const Text('Select medicine', style: TextStyle(fontSize: 13)),
            items: medicines
                .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.name, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (m) {
              medicine = m;
              // Pre-fill selling price from current medicine price
              if (m != null) {
                _sellCtrl.text = m.price.toStringAsFixed(2);
              }
              onChanged();
            },
          ),
        ),
        const SizedBox(width: 8),

        // Qty
        Expanded(
          flex: 2,
          child: TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
              hintText: '0',
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Unit cost
        Expanded(
          flex: 2,
          child: TextField(
            controller: _costCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
              prefixText: 'Rs. ',
              hintText: '0.00',
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Selling price
        Expanded(
          flex: 2,
          child: TextField(
            controller: _sellCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
              prefixText: 'Rs. ',
              hintText: '0.00',
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Line total (read-only)
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: lineTotal > 0
                  ? AppTheme.primary.withOpacity(0.05)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              lineTotal > 0 ? 'Rs. ${fmt.format(lineTotal)}' : '—',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: lineTotal > 0 ? AppTheme.primary : AppTheme.textSub),
            ),
          ),
        ),

        // Remove
        SizedBox(
          width: 40,
          child: IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                size: 18, color: AppTheme.danger),
            tooltip: 'Remove row',
            onPressed: onRemove,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GRN Detail Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _GRNDetailDialog extends StatelessWidget {
  final GRN grn;
  const _GRNDetailDialog({required this.grn});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy');

    final isCancelled = grn.status == 'cancelled';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 48),
      child: SizedBox(
        width: 700,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.04),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(grn.grnNumber,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: AppTheme.primary)),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? AppTheme.danger.withOpacity(0.1)
                          : AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCancelled ? 'Cancelled' : 'Received',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              isCancelled ? AppTheme.danger : AppTheme.success),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('Supplier Invoice: ${grn.invoiceNumber}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: AppTheme.textSub)),
              ]),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // Meta strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: Colors.grey[50],
            child: Row(children: [
              _metaChip(Icons.business_outlined, 'Supplier', grn.supplierName),
              const SizedBox(width: 24),
              _metaChip(Icons.local_shipping_outlined, 'Supply Date',
                  dateFmt.format(grn.supplyDate)),
              const SizedBox(width: 24),
              _metaChip(Icons.access_time, 'Received',
                  DateFormat('dd MMM yyyy, hh:mm a').format(grn.receivedAt)),
            ]),
          ),
          const Divider(height: 1),

          // Items table
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                DataTable(
                  headingRowColor: WidgetStateProperty.all(
                      AppTheme.primary.withOpacity(0.06)),
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Medicine')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('Unit Cost')),
                    DataColumn(label: Text('Selling Price')),
                    DataColumn(label: Text('Line Total')),
                  ],
                  rows: grn.items.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item.medicineName,
                          style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text('${item.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text('Rs. ${fmt.format(item.unitCost)}')),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Rs. ${fmt.format(item.sellingPrice)}',
                            style: const TextStyle(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      )),
                      DataCell(Text('Rs. ${fmt.format(item.lineTotal)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMain))),
                    ]);
                  }).toList(),
                ),
              ]),
            ),
          ),

          // Footer total
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(children: [
              Text(
                  '${grn.items.length} item${grn.items.length != 1 ? 's' : ''} · '
                  '${grn.totalUnits} units total',
                  style:
                      const TextStyle(fontSize: 13, color: AppTheme.textSub)),
              const Spacer(),
              const Text('Grand Total Cost:',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppTheme.textSub)),
              const SizedBox(width: 12),
              Text('Rs. ${fmt.format(grn.totalCost)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, String value) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppTheme.textSub),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSub)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMain)),
      ]),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared footer helpers (same style as MedicineScreen)
// ─────────────────────────────────────────────────────────────────────────────
class _FooterTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _FooterTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: AppTheme.textSub)),
            Text(value,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ]),
        ]),
      );
}

Widget _footerDivider() =>
    Container(height: 32, width: 1, color: Colors.grey[200]);
