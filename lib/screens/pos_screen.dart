// lib/screens/pos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pharmacy_app/components/stepperBtn.dart';
import '../models/medicine.dart';
import '../models/bill.dart';
import '../services/medicine_service.dart';
import '../services/billing_service.dart';
import '../utils/app_theme.dart';
import '../utils/pdf_generator.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});
  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final _medSvc       = MedicineService();
  final _billSvc      = BillingService();
  final _searchCtrl   = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _cashCtrl     = TextEditingController(text: '0');
  final _customerCtrl = TextEditingController();
  final _searchFocus  = FocusNode();

  // Per-cart-item controllers
  final Map<int, TextEditingController> _qtyControllers   = {};
  final Map<int, TextEditingController> _priceControllers = {}; // ← NEW

  List<Medicine> _searchResults = [];
  List<CartItem> _cart          = [];
  bool           _searching     = false;
  bool           _processing    = false;
  PaymentType    _paymentType   = PaymentType.cash;

  @override
  void dispose() {
    for (final c in _qtyControllers.values)   c.dispose();
    for (final c in _priceControllers.values) c.dispose();
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _cashCtrl.dispose();
    _customerCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Search ─────────────────────────────────────────────────────────────────
  Future<void> _search(String q) async {
    if (q.isEmpty) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    final r = await _medSvc.search(q);
    if (mounted) setState(() { _searchResults = r; _searching = false; });
  }

  // ── Add to cart ────────────────────────────────────────────────────────────
  void _addToCart(Medicine m) {
    if (m.stock <= 0) { showError(context, '${m.name} is out of stock.'); return; }
    setState(() {
      final idx = _cart.indexWhere((c) => c.medicine.id == m.id);
      if (idx >= 0) {
        if (_cart[idx].quantity < m.stock) {
          _cart[idx].quantity++;
          _qtyControllers[m.id!]?.text = '${_cart[idx].quantity}';
        } else {
          showError(context, 'Cannot exceed stock (${m.stock}).');
        }
      } else {
        _cart.add(CartItem(medicine: m));
        _qtyControllers[m.id!] =
            TextEditingController(text: '1');
        _priceControllers[m.id!] =
            TextEditingController(text: m.price.toStringAsFixed(2));  // ← NEW
      }
      _searchResults = [];
      _searchCtrl.clear();
    });
    _searchFocus.requestFocus();
  }

  // ── Qty stepper ────────────────────────────────────────────────────────────
  void _stepQty(int cartIdx, int delta) {
    final item   = _cart[cartIdx];
    final newQty = (item.quantity + delta).clamp(1, item.medicine.stock);
    setState(() => item.quantity = newQty);
    _qtyControllers[item.medicine.id!]?.text = '$newQty';
  }

  void _onQtyInput(int cartIdx, String val) {
    final parsed = int.tryParse(val);
    if (parsed == null || parsed < 1) return;
    final item    = _cart[cartIdx];
    final clamped = parsed.clamp(1, item.medicine.stock);
    setState(() => item.quantity = clamped);
    if (clamped != parsed)
      _qtyControllers[item.medicine.id!]?.text = '$clamped';
  }

  // ── Selling price input ────────────────────────────────────────────────────
  void _onPriceInput(int cartIdx, String val) {
    final parsed = double.tryParse(val);
    setState(() {
      // null / 0 / negative → revert to MRP (no override)
      _cart[cartIdx].sellingPrice = (parsed != null && parsed > 0) ? parsed : null;
    });
  }

  // Reset price back to MRP
  void _resetPrice(int cartIdx) {
    final item = _cart[cartIdx];
    setState(() => item.sellingPrice = null);
    _priceControllers[item.medicine.id!]?.text =
        item.medicine.price.toStringAsFixed(2);
  }

  // ── Remove / clear ─────────────────────────────────────────────────────────
  void _removeFromCart(int idx) {
    final id = _cart[idx].medicine.id!;
    _qtyControllers[id]?.dispose();
    _priceControllers[id]?.dispose();
    _qtyControllers.remove(id);
    _priceControllers.remove(id);
    setState(() => _cart.removeAt(idx));
  }

  void _clearCart() {
    for (final c in _qtyControllers.values)   c.dispose();
    for (final c in _priceControllers.values) c.dispose();
    _qtyControllers.clear();
    _priceControllers.clear();
    setState(() => _cart.clear());
  }

  // ── Totals ─────────────────────────────────────────────────────────────────
  double get _subtotal => _cart.fold(0, (s, i) => s + i.lineTotal);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _total    => (_subtotal - _discount).clamp(0, double.infinity);
  double get _cash     => double.tryParse(_cashCtrl.text) ?? 0;
  double get _change   => (_cash - _total).clamp(0, double.infinity);
  bool   get _isCard   => _paymentType == PaymentType.card;

  // ── Process sale ───────────────────────────────────────────────────────────
  Future<void> _processSale() async {
    if (_cart.isEmpty) { showError(context, 'Cart is empty.'); return; }
    setState(() => _processing = true);
    try {
      final bill = await _billSvc.createBill(
        _cart,
        discount:     _discount,
        given:        _isCard ? _total : _cash,
        paymentType:  _paymentType,
        customerName: _customerCtrl.text.trim(),
      );
      _clearCart();
      _discountCtrl.text = '0';
      _cashCtrl.text     = '0';
      _customerCtrl.clear();
      if (mounted) {
        showSuccess(context, 'Bill ${bill.invoiceNo} created!');
        _showBillDialog(bill);
      }
    } catch (e) {
      if (mounted) showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showBillDialog(Bill bill) => showDialog(
    context: context,
    builder: (_) => _BillPreviewDialog(bill: bill),
  ).then((_) => _searchFocus.requestFocus());

  // ── Quick cash amounts ─────────────────────────────────────────────────────
  List<double> _quickAmounts() {
    if (_total <= 0) return [100, 200, 500, 1000];
    final amounts = <double>[];
    for (final step in [50, 100, 200, 500, 1000]) {
      final rounded = ((_total / step).ceil() * step).toDouble();
      if (!amounts.contains(rounded)) amounts.add(rounded);
      if (amounts.length >= 4) break;
    }
    return amounts;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Row(children: [

      // ══════════════════════════════════════════════════════
      // LEFT: Search + Cart
      // ══════════════════════════════════════════════════════
      Expanded(
        flex: 3,
        child: Column(children: [

          // ── Top bar ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              const Icon(Icons.point_of_sale, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              const Text('POS / Billing',
                  style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold, color: AppTheme.textMain)),
              const Spacer(),
              if (_cart.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${_cart.length} item(s)',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              if (_cart.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearCart,
                  icon: const Icon(Icons.delete_sweep_outlined,
                      size: 16, color: AppTheme.danger),
                  label: const Text('Clear',
                      style: TextStyle(color: AppTheme.danger, fontSize: 13)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6)),
                ),
              const SizedBox(width: 8),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  focusNode: _searchFocus,
                  decoration: InputDecoration(
                    hintText: 'Search medicine to add…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchResults = []);
                            })
                        : null,
                  ),
                  onChanged: _search,
                ),
              ),
            ]),
          ),
          const Divider(height: 1),

          // ── Search results ────────────────────────────────
          if (_searchResults.isNotEmpty)
            Container(
              color: Colors.white,
              constraints: const BoxConstraints(maxHeight: 230),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (_, i) {
                  final m      = _searchResults[i];
                  final inCart = _cart.any((c) => c.medicine.id == m.id);
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.medication,
                          color: AppTheme.primary, size: 18),
                    ),
                    title: Row(children: [
                      Text(m.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13)),
                      if (inCart) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('In cart',
                              style: TextStyle(
                                  fontSize: 10, color: AppTheme.success,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                    subtitle: Text('${m.category}  ·  Stock: ${m.stock}',
                        style: const TextStyle(fontSize: 11)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Rs. ${fmt.format(m.price)}',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 14),
                      ),
                    ]),
                    onTap: () => _addToCart(m),
                  );
                },
              ),
            ),
          if (_searching)
            const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator()),

          // ── Cart ─────────────────────────────────────────
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 64, color: Colors.grey[200]),
                      const SizedBox(height: 10),
                      const Text('Cart is empty',
                          style: TextStyle(
                              color: AppTheme.textSub,
                              fontSize: 15,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      const Text('Search and add medicines above',
                          style: TextStyle(
                              color: AppTheme.textSub, fontSize: 12)),
                    ]))
                : Column(children: [
                    // ── Table header ──────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      color: AppTheme.primary.withOpacity(0.04),
                      child: const Row(children: [
                        Expanded(child: Text('Medicine',
                            style: TextStyle(fontWeight: FontWeight.w600,
                                fontSize: 12, color: AppTheme.textSub))),
                        SizedBox(width: 160,
                            child: Text('Quantity',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w600,
                                    fontSize: 12, color: AppTheme.textSub))),
                        // ← NEW column header
                        SizedBox(width: 130,
                            child: Text('Selling Price',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w600,
                                    fontSize: 12, color: AppTheme.textSub))),
                        SizedBox(width: 90,
                            child: Text('Total',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontWeight: FontWeight.w600,
                                    fontSize: 12, color: AppTheme.textSub))),
                        SizedBox(width: 36),
                      ]),
                    ),
                    const Divider(height: 1),

                    // ── Cart rows ─────────────────────────
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _cart.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 20),
                        itemBuilder: (_, i) {
                          final item       = _cart[i];
                          final medId      = item.medicine.id!;
                          final qtyCtrl    = _qtyControllers[medId]
                              ?? TextEditingController(text: '${item.quantity}');
                          final priceCtrl  = _priceControllers[medId]
                              ?? TextEditingController(
                                  text: item.medicine.price.toStringAsFixed(2));
                          final isPriceOverridden =
                              item.sellingPrice != null &&
                              item.sellingPrice != item.medicine.price;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [

                                // Medicine info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.medicine.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        Text(
                                          'MRP: Rs. ${fmt.format(item.medicine.price)}',
                                          style: const TextStyle(
                                              color: AppTheme.textSub,
                                              fontSize: 11),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '· Stock: ${item.medicine.stock}',
                                          style: const TextStyle(
                                              color: AppTheme.textSub,
                                              fontSize: 11),
                                        ),
                                      ]),
                                    ],
                                  ),
                                ),

                                // ── Qty stepper ──────────────────────
                                Container(
                                  width: 160,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: Row(children: [
                                    StepperBtn(
                                      icon: Icons.remove,
                                      enabled: item.quantity > 1,
                                      isLeft: true,
                                      onTap: () => _stepQty(i, -1),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: qtyCtrl,
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(4),
                                        ],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textMain,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 8),
                                        ),
                                        onChanged: (v) => _onQtyInput(i, v),
                                        onSubmitted: (v) {
                                          if (v.isEmpty)
                                            qtyCtrl.text = '${item.quantity}';
                                        },
                                      ),
                                    ),
                                    StepperBtn(
                                      icon: Icons.add,
                                      enabled: item.quantity < item.medicine.stock,
                                      isLeft: false,
                                      onTap: () => _stepQty(i, 1),
                                    ),
                                  ]),
                                ),

                                const SizedBox(width: 8),

                                // ── Selling price field ───────────────
                                Container(
                                  width: 122,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isPriceOverridden
                                          ? AppTheme.warning
                                          : Colors.grey[300]!,
                                      width: isPriceOverridden ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: isPriceOverridden
                                        ? AppTheme.warning.withOpacity(0.05)
                                        : Colors.white,
                                  ),
                                  child: Row(children: [
                                    // "Rs." prefix
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 8, right: 2),
                                      child: Text('Rs.',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: isPriceOverridden
                                                  ? AppTheme.warning
                                                  : AppTheme.textSub)),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: priceCtrl,
                                        textAlign: TextAlign.center,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                                decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d+\.?\d{0,2}')),
                                        ],
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isPriceOverridden
                                              ? AppTheme.warning
                                              : AppTheme.textMain,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 8),
                                        ),
                                        onChanged: (v) => _onPriceInput(i, v),
                                        onSubmitted: (v) {
                                          if (v.isEmpty) _resetPrice(i);
                                        },
                                      ),
                                    ),
                                    // Reset to MRP button — only shown when overridden
                                    if (isPriceOverridden)
                                      Tooltip(
                                        message: 'Reset to MRP',
                                        child: GestureDetector(
                                          onTap: () => _resetPrice(i),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 4),
                                            child: Icon(Icons.refresh,
                                                size: 14,
                                                color: AppTheme.warning),
                                          ),
                                        ),
                                      ),
                                  ]),
                                ),

                                const SizedBox(width: 8),

                                // Line total
                                SizedBox(
                                  width: 90,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Rs. ${fmt.format(item.lineTotal)}',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isPriceOverridden
                                                ? AppTheme.warning
                                                : AppTheme.primary),
                                      ),
                                      // Show MRP-based total in grey when overridden
                                      if (isPriceOverridden)
                                        Text(
                                          'MRP: ${fmt.format(item.medicine.price * item.quantity)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.textSub,
                                              decoration:
                                                  TextDecoration.lineThrough),
                                        ),
                                    ],
                                  ),
                                ),

                                // Remove
                                SizedBox(
                                  width: 36,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 17, color: AppTheme.danger),
                                    onPressed: () => _removeFromCart(i),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Remove',
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ]),
          ),

          // ── Cart footer subtotal ──────────────────────────
          if (_cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(children: [
                Text(
                  '${_cart.length} item(s)  ·  '
                  '${_cart.fold(0, (s, i) => s + i.quantity)} units',
                  style: const TextStyle(color: AppTheme.textSub, fontSize: 12),
                ),
                // Price-override warning badge
                if (_cart.any((c) =>
                    c.sellingPrice != null &&
                    c.sellingPrice != c.medicine.price)) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.warning.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.edit,
                          size: 11, color: AppTheme.warning),
                      const SizedBox(width: 4),
                      const Text('Custom price applied',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.warning,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
                const Spacer(),
                const Text('Subtotal: ',
                    style: TextStyle(color: AppTheme.textSub, fontSize: 13)),
                Text('Rs. ${fmt.format(_subtotal)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textMain)),
              ]),
            ),
        ]),
      ),

      // ══════════════════════════════════════════════════════
      // RIGHT: Order Summary
      // ══════════════════════════════════════════════════════
      Container(
        width: 310,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Color(0xFFE8EAF0))),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.receipt_long_outlined,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                const Text('Order Summary',
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.bold, color: AppTheme.textMain)),
              ]),
              const SizedBox(height: 16),

              // Customer name
              TextField(
                controller: _customerCtrl,
                decoration: InputDecoration(
                  labelText: 'Customer Name (optional)',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  isDense: true,
                  suffixIcon: _customerCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 15),
                          onPressed: () {
                            _customerCtrl.clear();
                            setState(() {});
                          })
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const Divider(),

              _SummaryRow('Subtotal', 'Rs. ${fmt.format(_subtotal)}'),
              const SizedBox(height: 10),

              // Discount
              Row(children: [
                const Text('Discount (Rs.):',
                    style: TextStyle(color: AppTheme.textSub, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _discountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8)),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              const Divider(),

              _SummaryRow('TOTAL', 'Rs. ${fmt.format(_total)}',
                  large: true, color: AppTheme.primary),
              const SizedBox(height: 18),

              // Payment method
              const Text('Payment Method',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSub,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _PaymentBtn(
                    label: 'Cash',
                    icon: Icons.payments_outlined,
                    selected: !_isCard,
                    color: AppTheme.success,
                    onTap: () =>
                        setState(() => _paymentType = PaymentType.cash),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PaymentBtn(
                    label: 'Card',
                    icon: Icons.credit_card,
                    selected: _isCard,
                    color: AppTheme.primary,
                    onTap: () =>
                        setState(() => _paymentType = PaymentType.card),
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // Cash / card section
              if (!_isCard) ...[
                Row(children: [
                  const Text('Cash (Rs.):',
                      style: TextStyle(color: AppTheme.textSub, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _cashCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8)),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final amt in _quickAmounts())
                    _QuickCashBtn(
                      label: 'Rs. ${amt.toInt()}',
                      onTap: () {
                        _cashCtrl.text = '$amt';
                        setState(() {});
                      },
                      selected: _cash == amt,
                    ),
                ]),
                const SizedBox(height: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _change > 0
                        ? AppTheme.success.withOpacity(0.08)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _change > 0
                          ? AppTheme.success.withOpacity(0.3)
                          : Colors.grey[200]!,
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.change_circle_outlined,
                        size: 18,
                        color: _change > 0
                            ? AppTheme.success : AppTheme.textSub),
                    const SizedBox(width: 8),
                    const Text('Change:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    Text('Rs. ${fmt.format(_change)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _change > 0
                                ? AppTheme.success : AppTheme.textSub)),
                  ]),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.credit_card,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Card payment — no change required.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500)),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed:
                      _processing || _cart.isEmpty ? null : _processSale,
                  icon: _processing
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Icon(
                          _isCard ? Icons.credit_card : Icons.payments_outlined,
                          size: 20),
                  label: Text(
                    _isCard
                        ? 'Process Card Payment'
                        : 'Process Cash Sale',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isCard ? AppTheme.primary : AppTheme.success,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Press Enter after typing qty to confirm',
                    style: TextStyle(color: AppTheme.textSub, fontSize: 10)),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Quick cash chip
// ─────────────────────────────────────────────────────────────
class _QuickCashBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _QuickCashBtn(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.success : AppTheme.success.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected
              ? AppTheme.success : AppTheme.success.withOpacity(0.3),
        ),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.success)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Payment toggle button
// ─────────────────────────────────────────────────────────────
class _PaymentBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _PaymentBtn(
      {required this.label, required this.icon,
       required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: selected ? color : Colors.grey[300]!,
            width: selected ? 1.5 : 1),
      ),
      child: Column(children: [
        Icon(icon, size: 22,
            color: selected ? Colors.white : Colors.grey[500]),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[600])),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Summary row
// ─────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool large;
  final Color color;
  const _SummaryRow(this.label, this.value,
      {this.large = false, this.color = AppTheme.textMain});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: TextStyle(
              color: large ? color : AppTheme.textSub,
              fontWeight: large ? FontWeight.bold : FontWeight.normal,
              fontSize: large ? 16 : 13)),
      Text(value,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold,
              fontSize: large ? 18 : 13)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// Bill preview dialog
// ─────────────────────────────────────────────────────────────
class _BillPreviewDialog extends StatelessWidget {
  final Bill bill;
  const _BillPreviewDialog({required this.bill});

  @override
  Widget build(BuildContext context) {
    final fmt     = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy  hh:mm a');
    final isCard  = bill.paymentType == PaymentType.card;

    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.check_circle, color: AppTheme.success, size: 22),
        const SizedBox(width: 8),
        const Text('Sale Completed'),
      ]),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Invoice header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.success.withOpacity(0.2)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(bill.invoiceNo,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(dateFmt.format(bill.createdAt),
                        style: const TextStyle(
                            color: AppTheme.textSub, fontSize: 12)),
                  ]),
                ),
                Text('Rs. ${fmt.format(bill.total)}',
                    style: const TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
              ]),
              if (bill.customerName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.person_outline,
                      size: 13, color: AppTheme.textSub),
                  const SizedBox(width: 4),
                  Text(bill.customerName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCard
                      ? AppTheme.primary.withOpacity(0.10)
                      : AppTheme.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      isCard ? Icons.credit_card : Icons.payments_outlined,
                      size: 12,
                      color: isCard ? AppTheme.primary : AppTheme.success),
                  const SizedBox(width: 4),
                  Text(isCard ? 'Card Payment' : 'Cash Payment',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color:
                              isCard ? AppTheme.primary : AppTheme.success)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Line items — show custom price tag if overridden
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7),
                  ),
                ),
                child: const Row(children: [
                  Expanded(child: Text('Medicine',
                      style: TextStyle(fontWeight: FontWeight.w600,
                          fontSize: 11, color: AppTheme.textSub))),
                  SizedBox(width: 40, child: Text('Qty',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600,
                          fontSize: 11, color: AppTheme.textSub))),
                  SizedBox(width: 80, child: Text('Price',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: FontWeight.w600,
                          fontSize: 11, color: AppTheme.textSub))),
                  SizedBox(width: 80, child: Text('Amount',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: FontWeight.w600,
                          fontSize: 11, color: AppTheme.textSub))),
                ]),
              ),
              ...bill.items.map((item) {
                final isCustomPrice = item.unitPrice != item.mrp && item.mrp > 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: Colors.grey[100]!))),
                  child: Row(children: [
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.medName,
                          style: const TextStyle(fontSize: 13)),
                      if (isCustomPrice)
                        Text('MRP: Rs. ${fmt.format(item.mrp)}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSub,
                                decoration: TextDecoration.lineThrough)),
                    ])),
                    SizedBox(width: 40,
                        child: Text('×${item.quantity}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppTheme.textSub, fontSize: 12))),
                    SizedBox(width: 80,
                        child: Text('Rs. ${fmt.format(item.unitPrice)}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 12,
                                color: isCustomPrice
                                    ? AppTheme.warning
                                    : AppTheme.textMain,
                                fontWeight: isCustomPrice
                                    ? FontWeight.w600
                                    : FontWeight.normal))),
                    SizedBox(width: 80,
                        child: Text('Rs. ${fmt.format(item.lineTotal)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500))),
                  ]),
                );
              }),
            ]),
          ),

          if (!isCard && bill.given > 0) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Cash Given:',
                  style: TextStyle(color: AppTheme.textSub, fontSize: 12)),
              Text('Rs. ${fmt.format(bill.given)}',
                  style: const TextStyle(fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Change:',
                  style: TextStyle(color: AppTheme.success,
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text('Rs. ${fmt.format(bill.change)}',
                  style: const TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.print, size: 16),
          label: const Text('Print Bill'),
          onPressed: () async {
            Navigator.pop(context);
            await PdfGenerator.printBill(bill);
          },
        ),
      ],
    );
  }
}