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
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            AppTheme.primary.withOpacity(0.06)),
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Price (Rs.)')),
                          DataColumn(label: Text('Stock')),
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
    ]);
  }
}

// ── Add / Edit form dialog ────────────────
class _MedicineForm extends StatefulWidget {
  final Medicine? medicine;
  final VoidCallback onSaved;
  const _MedicineForm({this.medicine, required this.onSaved});
  @override
  State<_MedicineForm> createState() => _MedicineFormState();
}

class _MedicineFormState extends State<_MedicineForm> {
  final _formKey  = GlobalKey<FormState>();
  final _svc      = MedicineService();
  late  TextEditingController _name, _cat, _price, _stock;
  DateTime? _expiry;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    _name  = TextEditingController(text: m?.name     ?? '');
    _cat   = TextEditingController(text: m?.category ?? '');
    _price = TextEditingController(text: m?.price.toStringAsFixed(2) ?? '');
    _stock = TextEditingController(text: m?.stock.toString() ?? '');
    _expiry = m?.expiryDate;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final med = Medicine(
      id:         widget.medicine?.id,
      name:       _name.text.trim(),
      category:   _cat.text.trim(),
      price:      double.tryParse(_price.text) ?? 0,
      stock:      int.tryParse(_stock.text)    ?? 0,
      expiryDate: _expiry,
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
      title: Text(isEdit ? 'Edit Medicine' : 'Add Medicine'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Medicine Name *'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cat,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _price,
                  decoration:
                      const InputDecoration(labelText: 'Price (Rs.) *',
                          prefixText: 'Rs. '),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? 'Enter valid price' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _stock,
                  decoration: const InputDecoration(labelText: 'Stock Qty *'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? 'Enter valid qty' : null,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Expiry Date',
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(
                  _expiry == null
                      ? 'Tap to select…'
                      : DateFormat('dd MMM yyyy').format(_expiry!),
                  style: TextStyle(
                    color: _expiry == null
                        ? AppTheme.textSub : AppTheme.textMain,
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
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
