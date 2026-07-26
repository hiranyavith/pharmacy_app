import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharmacy_app/models/stock_movement.dart';
import '../models/medicine.dart';
import '../services/medicine_service.dart';
import '../services/barcode_scanner_service.dart';
import '../utils/app_theme.dart';
import 'label_design_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});
  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final _svc = MedicineService();
  final _searchCtrl = TextEditingController();
  List<Medicine> _meds = [];
  bool _loading = true;
  bool _showInactive = false;

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
          content: Text('No Products is registered with barcode "$code".\n'
              'Would you like to add a new Products with this barcode?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add Products')),
          ],
        ),
      );
      if (add == true && mounted) {
        // Pre-fill barcode in the Add form
        _openForm(Medicine(
            name: '',
            category: '',
            price: 0,
            stock: 0,
            barcode: code,
            isActive: true));
      }
    }
  }

  Future<void> _load([String q = '']) async {
    setState(() => _loading = true);
    final list = _showInactive
        ? (q.isEmpty ? await _svc.getInactive() : await _svc.searchInactive(q))
        : (q.isEmpty ? await _svc.getAll() : await _svc.search(q));
    if (mounted)
      setState(() {
        _meds = list;
        _loading = false;
      });
  }

  void _toggleInactiveView(bool showInactive) {
    if (_showInactive == showInactive) return;
    setState(() => _showInactive = showInactive);
    _load(_searchCtrl.text);
  }

  void _openForm([Medicine? med]) => showDialog(
        context: context,
        builder: (_) => _MedicineForm(medicine: med, onSaved: _load),
      );

  Future<void> _delete(Medicine m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Products'),
        content: Text('Delete "${m.name}"? This cannot be undone.'),
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
      await _svc.delete(m.id!);
      if (mounted) showSuccess(context, '${m.name} deleted.');
      _load();
    }
  }

  Future<void> _deactivate(Medicine m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate Medicine'),
        content: Text('Deactivate "${m.name}"?\n\n'
            'It will no longer appear in searches and new bills, '
            'but historical bills will still reference it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _svc.deactivate(m.id!);
      if (mounted) {
        showSuccess(context, '${m.name} has been deactivated.');
        _load();
      }
    }
  }

  Future<void> _activate(Medicine m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Activate Product'),
        content: Text('Reactivate "${m.name}"?\n\n'
            'It will appear in searches again and become available for new bills.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child:
                const Text('Activate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _svc.activate(m.id!);
      if (mounted) {
        showSuccess(context, '${m.name} has been activated.');
        _load(_searchCtrl.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    final fmt = NumberFormat('#,##0.00');

    final totalItems = _meds.length;
    final totalUnits = _meds.fold(0, (s, m) => s + m.stock);
    final totalValue = _meds.fold(0.0, (s, m) => s + m.totalValue);
    final lowStockCount = _meds.where((m) => m.isLowStock).length;

    return Column(children: [
      // ── Top bar ────────────────────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Text(_showInactive ? 'Deactivated Products' : 'Inventory Management',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain)),

            // Right-side controls grouped so they wrap together
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                // Active / Deactivated toggle
                Container(
                  height: 34,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _ViewToggleBtn(
                      label: 'Active',
                      icon: Icons.check_circle_outline,
                      selected: !_showInactive,
                      onTap: () => _toggleInactiveView(false),
                    ),
                    _ViewToggleBtn(
                      label: 'Deactivated',
                      icon: Icons.visibility_off_outlined,
                      selected: _showInactive,
                      onTap: () => _toggleInactiveView(true),
                    ),
                  ]),
                ),

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

                // Manual search
                SizedBox(
                  width: 220,
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

                ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Products'),
                ),
              ],
            ),
          ],
        ),
      ),
      const Divider(height: 1),

      // ── Table ──────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _meds.isEmpty
                ? const Center(
                    child: Text('No Products found.',
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
                          DataColumn(label: Text('Price')),
                          DataColumn(label: Text('Stock')),
                          DataColumn(label: Text('W_Limit')),
                          DataColumn(label: Text('Stock_v')),
                          DataColumn(label: Text('Expiry')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _meds.map((m) {
                          final stockColor = m.isLowStock
                              ? AppTheme.danger
                              : AppTheme.textMain;
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
                            DataCell(Row(
                                children: _showInactive
                                    ? [
                                        IconButton(
                                          icon: const Icon(Icons.restore,
                                              size: 18,
                                              color: AppTheme.success),
                                          tooltip: 'Activate',
                                          onPressed: () => _activate(m),
                                        ),
                                      ]
                                    : [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18,
                                              color: AppTheme.primary),
                                          tooltip: 'Edit',
                                          onPressed: () => _openForm(m),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.label_outline,
                                              size: 18,
                                              color: AppTheme.secondary),
                                          tooltip: 'Print Label',
                                          onPressed: () => showDialog(
                                            context: context,
                                            builder: (_) =>
                                                LabelDesignScreen(medicine: m),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.add_box_outlined,
                                              size: 18,
                                              color: AppTheme.success),
                                          tooltip: 'Restock',
                                          onPressed: () => showDialog(
                                            context: context,
                                            builder: (_) => _RestockDialog(
                                              medicine: m,
                                              onSaved: _load,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 18, color: AppTheme.danger),
                                          tooltip: 'Deactivate',
                                          onPressed: () => _deactivate(m),
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
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
              _searchCtrl.text.isEmpty
                  ? 'Inventory Summary'
                  : 'Filtered Results Summary',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSub,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 20),
            _FooterTile(
                label: 'Total Products',
                value: '$totalItems',
                icon: Icons.medication_outlined,
                color: AppTheme.primary),
            _footerDivider(),
            _FooterTile(
                label: 'Total Units',
                value: '$totalUnits',
                icon: Icons.inventory_2_outlined,
                color: AppTheme.secondary),
            _footerDivider(),
            _FooterTile(
                label: 'Low Stock',
                value: '$lowStockCount',
                icon: Icons.warning_amber_outlined,
                color: lowStockCount > 0 ? AppTheme.warning : AppTheme.textSub),
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

// ── Footer helpers ─────────────────────────────────────────────────────────────
class _FooterTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _FooterTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
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

// ── Add / Edit form dialog ─────────────────────────────────────────────────────
class _MedicineForm extends StatefulWidget {
  final Medicine? medicine;
  final VoidCallback onSaved;
  const _MedicineForm({this.medicine, required this.onSaved});
  @override
  State<_MedicineForm> createState() => _MedicineFormState();
}

class _ViewToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ViewToggleBtn(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 14, color: selected ? Colors.white : AppTheme.textSub),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTheme.textSub)),
          ]),
        ),
      );
}

class _MedicineFormState extends State<_MedicineForm> {
  final _formKey = GlobalKey<FormState>();
  final _svc = MedicineService();
  final _barcodeFocus = FocusNode();
  bool _generatingBarcode = false;

  late TextEditingController _name, _cat, _price, _stock, _warnLimit, _barcode;
  DateTime? _expiry;
  bool _saving = false;
  bool _barcodeJustScanned = false; // visual flash feedback

  StreamSubscription<String>? _barcodeSub;

  int get _stockVal => int.tryParse(_stock.text) ?? 0;
  int get _limitVal => int.tryParse(_warnLimit.text) ?? 10;
  bool get _willWarn => _stockVal <= _limitVal && _stockVal >= 0;

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    _name = TextEditingController(text: m?.name ?? '');
    _cat = TextEditingController(text: m?.category ?? '');
    _price = TextEditingController(
        text: m != null && m.price > 0 ? m.price.toStringAsFixed(2) : '');
    _stock = TextEditingController(
        text: m != null && m.stock > 0 ? m.stock.toString() : '');
    _warnLimit =
        TextEditingController(text: (m?.stockWarningLimit ?? 10).toString());
    _barcode = TextEditingController(text: m?.barcode ?? '');

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
    _name.dispose();
    _cat.dispose();
    _price.dispose();
    _stock.dispose();
    _warnLimit.dispose();
    _barcode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final med = Medicine(
      id: widget.medicine?.id,
      name: _name.text.trim(),
      category: _cat.text.trim(),
      price: double.tryParse(_price.text) ?? 0,
      stock: int.tryParse(_stock.text) ?? 0,
      stockWarningLimit: int.tryParse(_warnLimit.text) ?? 10,
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      expiryDate: _expiry,
      isActive: true,
    );
    try {
      widget.medicine == null ? await _svc.add(med) : await _svc.update(med);
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context,
            widget.medicine == null ? 'Product added.' : 'Product updated.');
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

  Future<void> _generateBarcode() async {
    setState(() => _generatingBarcode = true);
    try {
      final code = await _svc.generateUniqueBarcode();
      if (mounted) {
        setState(() {
          _barcode.text = code;
          _barcodeJustScanned = true; // Flashes the green highlight feedback
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _barcodeJustScanned = false);
        });
      }
    } catch (e) {
      if (mounted) showError(context, 'Failed to generate barcode: $e');
    } finally {
      if (mounted) setState(() => _generatingBarcode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.medicine != null;
    return AlertDialog(
      title: Row(children: [
        Icon(isEdit ? Icons.edit : Icons.add_circle,
            color: AppTheme.primary, size: 22),
        const SizedBox(width: 8),
        Text(isEdit ? 'Edit Product' : 'Add Product'),
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
                  labelText: 'Product Name *',
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
                    hintText: 'Scan with USB scanner or generate',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_barcodeJustScanned) ...[
                          const Icon(Icons.check_circle,
                              color: AppTheme.success, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Updated!',
                            style: TextStyle(
                              color: AppTheme.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // ── Auto-Generate Button ────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: TextButton.icon(
                            onPressed:
                                _generatingBarcode ? null : _generateBarcode,
                            icon: _generatingBarcode
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome, size: 16),
                            label: const Text('Generate',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                        fontSize: 11, color: AppTheme.textSub.withOpacity(0.8)),
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
                        ? 'Enter valid price'
                        : null,
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
                        ? 'Enter valid qty'
                        : null,
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
                            color:
                                _willWarn ? AppTheme.warning : AppTheme.success,
                            size: 20,
                          ))
                      : null,
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Enter valid number' : null,
              ),

              // Live warning preview
              if (_stockVal > 0 || _limitVal > 0) ...[
                const SizedBox(height: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          color:
                              _willWarn ? AppTheme.warning : AppTheme.success,
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
                      color: _expiry == null
                          ? AppTheme.textSub
                          : AppTheme.textMain,
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
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Icon(isEdit ? Icons.save_outlined : Icons.add, size: 16),
          label: Text(isEdit ? 'Update' : 'Add Product'),
        ),
      ],
    );
  }
}

class _RestockDialog extends StatefulWidget {
  final Medicine medicine;
  final VoidCallback onSaved;
  const _RestockDialog({required this.medicine, required this.onSaved});
  @override
  State<_RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<_RestockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _svc = MedicineService();
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  final _supplier = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  bool _showHistory = false;
  List<StockMovement> _history = [];
  bool _loadingHistory = false;

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    _supplier.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    final h = await _svc.getStockHistory(widget.medicine.id!);
    if (mounted)
      setState(() {
        _history = h;
        _loadingHistory = false;
      });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _svc.restock(
        widget.medicine.id!,
        int.parse(_qty.text),
        costPrice: double.tryParse(_cost.text),
        supplier: _supplier.text.trim().isEmpty ? null : _supplier.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        showSuccess(
            context, '${_qty.text} units added to ${widget.medicine.name}.');
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
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
    final fmt = NumberFormat('#,##0.00');

    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.add_box_outlined, color: AppTheme.success, size: 22),
        const SizedBox(width: 8),
        Expanded(
            child: Text('Restock — ${widget.medicine.name}',
                overflow: TextOverflow.ellipsis)),
        IconButton(
          icon: Icon(_showHistory ? Icons.close : Icons.history, size: 20),
          tooltip: _showHistory ? 'Close history' : 'View stock history',
          onPressed: () {
            setState(() => _showHistory = !_showHistory);
            if (_showHistory && _history.isEmpty) _loadHistory();
          },
        ),
      ]),
      content: SizedBox(
        width: 420,
        child: _showHistory ? _buildHistory(dateFmt, fmt) : _buildForm(),
      ),
      actions: _showHistory
          ? [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ]
          : [
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
                    : const Icon(Icons.add, size: 16),
                label: const Text('Add Stock'),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              ),
            ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.inventory_2_outlined,
                size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('Current stock: ${widget.medicine.stock} units',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
        ),
        TextFormField(
          controller: _qty,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity Received *',
            prefixIcon: Icon(Icons.add_circle_outline, size: 18),
          ),
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n <= 0) return 'Enter a valid quantity';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cost,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cost Price per Unit (optional)',
            prefixText: 'Rs. ',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _supplier,
          decoration: const InputDecoration(
            labelText: 'Supplier (optional)',
            prefixIcon: Icon(Icons.local_shipping_outlined, size: 18),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notes,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            prefixIcon: Icon(Icons.note_outlined, size: 18),
          ),
          maxLines: 2,
        ),
      ]),
    );
  }

  Widget _buildHistory(DateFormat dateFmt, NumberFormat fmt) {
    if (_loadingHistory) {
      return const SizedBox(
          height: 200, child: Center(child: CircularProgressIndicator()));
    }
    if (_history.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('No stock arrivals recorded yet.',
              style: TextStyle(color: AppTheme.textSub)),
        ),
      );
    }
    return SizedBox(
      height: 320,
      child: ListView.separated(
        itemCount: _history.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final h = _history[i];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.add_box_outlined,
                color: AppTheme.success, size: 20),
            title: Text('+${h.quantity} units',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              [
                dateFmt.format(h.createdAt),
                if (h.supplier != null) h.supplier!,
                if (h.notes != null) h.notes!,
              ].join('  ·  '),
              style: const TextStyle(fontSize: 11),
            ),
            trailing: h.costPrice != null
                ? Text('Rs. ${fmt.format(h.totalCost)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500))
                : null,
          );
        },
      ),
    );
  }
}
