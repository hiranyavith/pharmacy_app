// lib/screens/medicine_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/medicine_service.dart';
import '../utils/app_theme.dart';

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});
  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final _svc        = MedicineService();
  final _searchCtrl = TextEditingController();
  List<Medicine> _meds    = [];
  bool           _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load([String q = '']) async {
    setState(() => _loading = true);
    final list = q.isEmpty ? await _svc.getAll() : await _svc.search(q);
    if (mounted) setState(() { _meds = list; _loading = false; });
  }

  void _openForm([Medicine? med]) => showDialog(
    context: context,
    builder: (_) => _MedicineForm(medicine: med, onSaved: _load),
  );

  Future<void> _delete(Medicine m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text('Delete "${m.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
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
      await _svc.delete(m.id!);
      if (mounted) showSuccess(context, '${m.name} deleted.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    final fmt     = NumberFormat('#,##0.00');

    // ── Inventory totals (computed from current list) ──
    final totalItems    = _meds.length;
    final totalUnits    = _meds.fold(0,   (s, m) => s + m.stock);
    final totalValue    = _meds.fold(0.0, (s, m) => s + m.totalValue);
    final lowStockCount = _meds.where((m) => m.isLowStock).length;

    return Column(children: [
      // ── Top bar ────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(children: [
          const Text('Medicine Management',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: AppTheme.textMain)),
          const Spacer(),
          // Search
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by name or category…',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
              onChanged: (v) => _load(v),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Medicine'),
          ),
        ]),
      ),
      const Divider(height: 1),

      // ── Table ──────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _meds.isEmpty
                ? const Center(child: Text('No medicines found.',
                    style: TextStyle(color: AppTheme.textSub)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Card(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            AppTheme.primary.withOpacity(0.06)),
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Price (Rs.)')),
                          DataColumn(label: Text('Stock')),
                          DataColumn(label: Text('Warn Limit')),
                          DataColumn(label: Text('Stock Value (Rs.)')),
                          DataColumn(label: Text('Expiry')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _meds.map((m) {
                          Color stockColor = AppTheme.textMain;
                          if (m.isLowStock) stockColor = AppTheme.danger;

                          return DataRow(cells: [
                            DataCell(Text(m.name,
                                style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(m.category,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.primary)),
                            )),
                            DataCell(Text('Rs. ${m.price.toStringAsFixed(2)}')),
                            DataCell(Row(children: [
                              Text('${m.stock}',
                                  style: TextStyle(
                                      color: stockColor,
                                      fontWeight: FontWeight.w600)),
                              if (m.isLowStock) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.warning_amber,
                                    size: 14, color: AppTheme.warning),
                              ],
                            ])),
                            // Warning limit badge
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '≤ ${m.stockWarningLimit}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.warning,
                                    fontWeight: FontWeight.w600),
                              ),
                            )),
                            // Per-item stock value
                            DataCell(Text(
                              'Rs. ${fmt.format(m.totalValue)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textMain),
                            )),
                            DataCell(m.expiryDate == null
                                ? const Text('—')
                                : Text(
                                    dateFmt.format(m.expiryDate!),
                                    style: TextStyle(
                                      color: m.isExpiringSoon
                                          ? AppTheme.danger
                                          : AppTheme.textMain,
                                      fontWeight: m.isExpiringSoon
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  )),
                            DataCell(Row(children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18, color: AppTheme.primary),
                                tooltip: 'Edit',
                                onPressed: () => _openForm(m),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: AppTheme.danger),
                                tooltip: 'Delete',
                                onPressed: () => _delete(m),
                              ),
                            ])),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
      ),

      // ── Inventory Summary Footer ────────
      if (!_loading && _meds.isNotEmpty)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05),
                  blurRadius: 8, offset: const Offset(0, -2)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(children: [
            // Label
            const Icon(Icons.summarize_outlined,
                size: 16, color: AppTheme.textSub),
            const SizedBox(width: 6),
            Text(
              _searchCtrl.text.isEmpty
                  ? 'Inventory Summary'
                  : 'Filtered Results Summary',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSub,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 20),

            // Tile: Total Products
            _FooterTile(
              label: 'Total Products',
              value: '$totalItems',
              icon: Icons.medication_outlined,
              color: AppTheme.primary,
            ),
            _footerDivider(),

            // Tile: Total Units
            _FooterTile(
              label: 'Total Units',
              value: '$totalUnits',
              icon: Icons.inventory_2_outlined,
              color: AppTheme.secondary,
            ),
            _footerDivider(),

            // Tile: Low Stock
            _FooterTile(
              label: 'Low Stock',
              value: '$lowStockCount',
              icon: Icons.warning_amber_outlined,
              color: lowStockCount > 0 ? AppTheme.warning : AppTheme.textSub,
            ),
            _footerDivider(),

            // Tile: Total Inventory Value — highlighted
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Total Inventory Value',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.textSub)),
                    Text('Rs. ${fmt.format(totalValue)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary)),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

// ── Footer helper widgets ─────────────────
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
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color)),
      ]),
    ]),
  );
}

Widget _footerDivider() => Container(
  height: 32,
  width: 1,
  color: Colors.grey[200],
);

// ── Add / Edit form dialog ────────────────
class _MedicineForm extends StatefulWidget {
  final Medicine? medicine;
  final VoidCallback onSaved;
  const _MedicineForm({this.medicine, required this.onSaved});
  @override
  State<_MedicineForm> createState() => _MedicineFormState();
}

class _MedicineFormState extends State<_MedicineForm> {
  final _formKey     = GlobalKey<FormState>();
  final _svc         = MedicineService();
  late  TextEditingController _name, _cat, _price, _stock, _warnLimit;
  DateTime? _expiry;
  bool _saving = false;

  int    get _stockVal => int.tryParse(_stock.text)     ?? 0;
  int    get _limitVal => int.tryParse(_warnLimit.text) ?? 10;
  bool   get _willWarn => _stockVal <= _limitVal && _stockVal >= 0;

  @override
  void initState() {
    super.initState();
    final m  = widget.medicine;
    _name      = TextEditingController(text: m?.name     ?? '');
    _cat       = TextEditingController(text: m?.category ?? '');
    _price     = TextEditingController(text: m != null ? m.price.toStringAsFixed(2) : '');
    _stock     = TextEditingController(text: m?.stock.toString() ?? '');
    _warnLimit = TextEditingController(
        text: (m?.stockWarningLimit ?? 10).toString());
    _expiry = m?.expiryDate;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final med = Medicine(
      id:                widget.medicine?.id,
      name:              _name.text.trim(),
      category:          _cat.text.trim(),
      price:             double.tryParse(_price.text)     ?? 0,
      stock:             int.tryParse(_stock.text)        ?? 0,
      stockWarningLimit: int.tryParse(_warnLimit.text)   ?? 10,
      expiryDate:        _expiry,
    );
    try {
      if (widget.medicine == null) {
        await _svc.add(med);
      } else {
        await _svc.update(med);
      }
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context,
            widget.medicine == null ? 'Medicine added.' : 'Medicine updated.');
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d != null) setState(() => _expiry = d);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.medicine != null;
    return AlertDialog(
      title: Row(children: [
        Icon(isEdit ? Icons.edit : Icons.add_circle,
            color: AppTheme.primary, size: 22),
        const SizedBox(width: 8),
        Text(isEdit ? 'Edit Medicine' : 'Add Medicine'),
      ]),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Name
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Medicine Name *',
                prefixIcon: Icon(Icons.medication_outlined, size: 18),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Category
            TextFormField(
              controller: _cat,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 12),

            // Price + Stock row
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(
                    labelText: 'Price (Rs.) *',
                    prefixText: 'Rs. ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => double.tryParse(v ?? '') == null
                      ? 'Enter valid price' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _stock,
                  decoration: const InputDecoration(
                    labelText: 'Stock Qty *',
                    prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  validator: (v) => int.tryParse(v ?? '') == null
                      ? 'Enter valid qty' : null,
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Stock Warning Limit ──────────
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _warnLimit,
                  decoration: InputDecoration(
                    labelText: 'Stock Warning Limit *',
                    prefixIcon: const Icon(Icons.warning_amber_outlined,
                        size: 18, color: AppTheme.warning),
                    helperText: 'Alert triggers when stock ≤ this number',
                    suffixIcon: _stockVal > 0 && _limitVal > 0
                        ? Tooltip(
                            message: _willWarn
                                ? 'Current stock is AT or BELOW the warning limit!'
                                : 'Stock is above the warning limit',
                            child: Icon(
                              _willWarn
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              color: _willWarn
                                  ? AppTheme.warning : AppTheme.success,
                              size: 20,
                            ),
                          )
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  validator: (v) => int.tryParse(v ?? '') == null
                      ? 'Enter valid number' : null,
                ),
              ),
            ]),

            // ── Live warning preview ─────────
            if (_stockVal > 0 || _limitVal > 0) ...[
              const SizedBox(height: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _willWarn
                      ? AppTheme.warning.withOpacity(0.10)
                      : AppTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _willWarn
                        ? AppTheme.warning.withOpacity(0.4)
                        : AppTheme.success.withOpacity(0.3),
                  ),
                ),
                child: Row(children: [
                  Icon(
                    _willWarn
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    color: _willWarn ? AppTheme.warning : AppTheme.success,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _willWarn
                          ? 'Stock ($_stockVal) is at or below the warning limit ($_limitVal). '
                            'This item will appear in the Low Stock Alerts.'
                          : 'Stock ($_stockVal) is above the warning limit ($_limitVal). '
                            'No alert will be triggered.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _willWarn ? AppTheme.warning : AppTheme.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 12),

            // Expiry Date
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Expiry Date',
                  prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  suffixIcon: Icon(Icons.edit_calendar, size: 18),
                ),
                child: Text(
                  _expiry == null
                      ? 'Tap to select…'
                      : DateFormat('dd MMM yyyy').format(_expiry!),
                  style: TextStyle(
                    color: _expiry == null ? AppTheme.textSub : AppTheme.textMain,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Icon(isEdit ? Icons.save_outlined : Icons.add, size: 16),
          label: Text(isEdit ? 'Update' : 'Add Medicine'),
        ),
      ],
    );
  }
}