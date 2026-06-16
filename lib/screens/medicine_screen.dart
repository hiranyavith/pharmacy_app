import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/medicine_service.dart';
import '../services/barcode_scanner_service.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
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

  StreamSubscription<String>? _barcodeSub;

  @override
  void initState() {
    super.initState();
    _load();

    // Listen for USB scanner barcodes while this screen is active
    _barcodeSub = BarcodeScannerService.instance.barcodes.listen(_onBarcode);
  }

  @override
  void dispose() {
    _barcodeSub?.cancel();
    super.dispose();
  }

  // ── Called whenever the USB scanner fires a complete code ─────────────────
  Future<void> _onBarcode(String code) async {
    if (!mounted) return;

    // Fill search box and search
    _searchCtrl.text = code;
    setState(() => _loading = true);

    final med = await _svc.getByBarcode(code);
    if (!mounted) return;

    if (med != null) {
      // Found — show it in the list
      await _load(code);
    } else {
      // Not found — offer to add
      setState(() => _loading = false);
      final add = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Barcode not found'),
          content: Text(
              'No medicine is registered with barcode "$code".\n'
              'Would you like to add a new medicine with this barcode?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add Medicine')),
          ],
        ),
      );
      if (add == true && mounted) {
        // Pre-fill barcode in the Add form
        _openForm(Medicine(
            name: '', category: '', price: 0, stock: 0, barcode: code));
      }
    }
  }

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

    final totalItems    = _meds.length;
    final totalUnits    = _meds.fold(0,   (s, m) => s + m.stock);
    final totalValue    = _meds.fold(0.0, (s, m) => s + m.totalValue);
    final lowStockCount = _meds.where((m) => m.isLowStock).length;

    return Column(children: [
      // ── Top bar ────────────────────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(children: [
          const Text('Medicine Management',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: AppTheme.textMain)),
          const Spacer(),

          // USB scanner status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.usb, size: 13, color: AppTheme.success),
              const SizedBox(width: 5),
              Text('USB Scanner Ready',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          const SizedBox(width: 12),

          // Manual search
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search name, category or barcode…',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
              onChanged: _load,
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

      // ── Table ──────────────────────────────────────────────────────────────
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
                          DataColumn(label: Text('Barcode')),
                          DataColumn(label: Text('Price (Rs.)')),
                          DataColumn(label: Text('Stock')),
                          DataColumn(label: Text('Warn Limit')),
                          DataColumn(label: Text('Stock Value (Rs.)')),
                          DataColumn(label: Text('Expiry')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _meds.map((m) {
                          final stockColor =
                              m.isLowStock ? AppTheme.danger : AppTheme.textMain;
                          return DataRow(cells: [
                            DataCell(Text(m.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500))),
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
                            DataCell(m.barcode == null || m.barcode!.isEmpty
                                ? const Text('—',
                                    style: TextStyle(color: AppTheme.textSub))
                                : Row(children: [
                                    const Icon(Icons.qr_code,
                                        size: 14, color: AppTheme.textSub),
                                    const SizedBox(width: 4),
                                    Text(m.barcode!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'monospace')),
                                  ])),
                            DataCell(
                                Text('Rs. ${m.price.toStringAsFixed(2)}')),
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
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('≤ ${m.stockWarningLimit}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.warning,
                                      fontWeight: FontWeight.w600)),
                            )),
                            DataCell(Text('Rs. ${fmt.format(m.totalValue)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textMain))),
                            DataCell(m.expiryDate == null
                                ? const Text('—')
                                : Text(dateFmt.format(m.expiryDate!),
                                    style: TextStyle(
                                      color: m.isExpiringSoon
                                          ? AppTheme.danger
                                          : AppTheme.textMain,
                                      fontWeight: m.isExpiringSoon
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ))),
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

      // ── Inventory Summary Footer ────────────────────────────────────────────
      if (!_loading && _meds.isNotEmpty)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8, offset: const Offset(0, -2))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(children: [
            const Icon(Icons.summarize_outlined, size: 16, color: AppTheme.textSub),
            const SizedBox(width: 6),
            Text(
              _searchCtrl.text.isEmpty
                  ? 'Inventory Summary' : 'Filtered Results Summary',
              style: const TextStyle(fontSize: 12,
                  color: AppTheme.textSub, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 20),
            _FooterTile(label: 'Total Products', value: '$totalItems',
                icon: Icons.medication_outlined, color: AppTheme.primary),
            _footerDivider(),
            _FooterTile(label: 'Total Units', value: '$totalUnits',
                icon: Icons.inventory_2_outlined, color: AppTheme.secondary),
            _footerDivider(),
            _FooterTile(label: 'Low Stock', value: '$lowStockCount',
                icon: Icons.warning_amber_outlined,
                color: lowStockCount > 0 ? AppTheme.warning : AppTheme.textSub),
            _footerDivider(),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Total Inventory Value',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSub)),
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

// ── Footer helpers ─────────────────────────────────────────────────────────────
class _FooterTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _FooterTile({required this.label, required this.value,
      required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSub)),
        Text(value, style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ]),
    ]),
  );
}

Widget _footerDivider() =>
    Container(height: 32, width: 1, color: Colors.grey[200]);

// ── Add / Edit form dialog ─────────────────────────────────────────────────────
class _MedicineForm extends StatefulWidget {
  final Medicine? medicine;
  final VoidCallback onSaved;
  const _MedicineForm({this.medicine, required this.onSaved});
  @override
  State<_MedicineForm> createState() => _MedicineFormState();
}

class _MedicineFormState extends State<_MedicineForm> {
  final _formKey    = GlobalKey<FormState>();
  final _svc        = MedicineService();
  final _barcodeFocus = FocusNode();

  late TextEditingController _name, _cat, _price, _stock, _warnLimit, _barcode;
  DateTime? _expiry;
  bool _saving = false;
  bool _barcodeJustScanned = false; // visual flash feedback

  StreamSubscription<String>? _barcodeSub;

  int  get _stockVal => int.tryParse(_stock.text)     ?? 0;
  int  get _limitVal => int.tryParse(_warnLimit.text) ?? 10;
  bool get _willWarn => _stockVal <= _limitVal && _stockVal >= 0;

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    _name      = TextEditingController(text: m?.name     ?? '');
    _cat       = TextEditingController(text: m?.category ?? '');
    _price     = TextEditingController(
        text: m != null && m.price > 0 ? m.price.toStringAsFixed(2) : '');
    _stock     = TextEditingController(
        text: m != null && m.stock > 0 ? m.stock.toString() : '');
    _warnLimit = TextEditingController(
        text: (m?.stockWarningLimit ?? 10).toString());
    _barcode   = TextEditingController(text: m?.barcode ?? '');

    // When a USB scan arrives while the form is open, fill the barcode field
    // regardless of which field currently has focus.
    _barcodeSub = BarcodeScannerService.instance.barcodes.listen((code) {
      if (!mounted) return;
      setState(() {
        _barcode.text = code;
        _barcodeJustScanned = true;
      });
      // Flash the field green briefly
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _barcodeJustScanned = false);
      });
    });
  }

  @override
  void dispose() {
    _barcodeSub?.cancel();
    _barcodeFocus.dispose();
    _name.dispose(); _cat.dispose(); _price.dispose();
    _stock.dispose(); _warnLimit.dispose(); _barcode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final med = Medicine(
      id:                widget.medicine?.id,
      name:              _name.text.trim(),
      category:          _cat.text.trim(),
      price:             double.tryParse(_price.text)   ?? 0,
      stock:             int.tryParse(_stock.text)      ?? 0,
      stockWarningLimit: int.tryParse(_warnLimit.text)  ?? 10,
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      expiryDate: _expiry,
    );
    try {
      widget.medicine == null ? await _svc.add(med) : await _svc.update(med);
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
          child: SingleChildScrollView(
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

              // ── Barcode field ────────────────────────────────────────
              // Highlighted green for 2 s after a USB scan fills it in.
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _barcodeJustScanned
                        ? AppTheme.success
                        : Colors.transparent,
                    width: _barcodeJustScanned ? 2 : 0,
                  ),
                  color: _barcodeJustScanned
                      ? AppTheme.success.withOpacity(0.06)
                      : Colors.transparent,
                ),
                child: TextFormField(
                  controller: _barcode,
                  focusNode: _barcodeFocus,
                  decoration: InputDecoration(
                    labelText: 'Barcode',
                    prefixIcon: Icon(
                      Icons.qr_code,
                      size: 18,
                      color: _barcodeJustScanned
                          ? AppTheme.success
                          : AppTheme.textSub,
                    ),
                    hintText: 'Scan with USB scanner or type manually',
                    // Green "Scanned!" suffix when just filled by scanner
                    suffixIcon: _barcodeJustScanned
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle,
                                color: AppTheme.success, size: 18),
                            const SizedBox(width: 4),
                            Text('Scanned!',
                                style: TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                          ])
                        : null,
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),

              // USB scanner hint
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Row(children: [
                  Icon(Icons.usb, size: 12, color: AppTheme.textSub),
                  const SizedBox(width: 4),
                  Text(
                    'Point USB scanner at product — barcode fills automatically',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSub.withOpacity(0.8)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Price + Stock
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

              // Stock Warning Limit
              TextFormField(
                controller: _warnLimit,
                decoration: InputDecoration(
                  labelText: 'Stock Warning Limit *',
                  prefixIcon: const Icon(Icons.warning_amber_outlined,
                      size: 18, color: AppTheme.warning),
                  helperText: 'Alert triggers when stock ≤ this number',
                  suffixIcon: _stockVal > 0 && _limitVal > 0
                      ? Tooltip(
                          message: _willWarn
                              ? 'Stock is AT or BELOW the warning limit!'
                              : 'Stock is above the warning limit',
                          child: Icon(
                            _willWarn
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            color: _willWarn
                                ? AppTheme.warning : AppTheme.success,
                            size: 20,
                          ))
                      : null,
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (v) => int.tryParse(v ?? '') == null
                    ? 'Enter valid number' : null,
              ),

              // Live warning preview
              if (_stockVal > 0 || _limitVal > 0) ...[
                const SizedBox(height: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
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
                            ? 'Stock ($_stockVal) is at or below the warning '
                              'limit ($_limitVal). This item will appear in '
                              'Low Stock Alerts.'
                            : 'Stock ($_stockVal) is above the warning limit '
                              '($_limitVal). No alert will be triggered.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _willWarn
                              ? AppTheme.warning : AppTheme.success,
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
                    prefixIcon:
                        Icon(Icons.calendar_today_outlined, size: 18),
                    suffixIcon: Icon(Icons.edit_calendar, size: 18),
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