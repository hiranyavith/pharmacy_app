// lib/screens/pos_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final _medSvc = MedicineService();
  final _billSvc = BillingService();
  final _searchCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _cashCtrl = TextEditingController(text: '0');
  final _customerCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Medicine> _searchResults = [];
  List<CartItem> _cart = [];
  bool _searching = false;
  bool _processing = false;
  PaymentType _paymentType = PaymentType.cash;
  Bill? _lastBill;

  // ── Search medicines ──────────────────
  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final r = await _medSvc.search(q);
    if (mounted)
      setState(() {
        _searchResults = r;
        _searching = false;
      });
  }

  // ── Add to cart ───────────────────────
  void _addToCart(Medicine m) {
    if (m.stock <= 0) {
      showError(context, '${m.name} is out of stock.');
      return;
    }
    setState(() {
      final idx = _cart.indexWhere((c) => c.medicine.id == m.id);
      if (idx >= 0) {
        if (_cart[idx].quantity < m.stock) {
          _cart[idx].quantity++;
        } else {
          showError(context, 'Cannot exceed available stock (${m.stock}).');
        }
      } else {
        _cart.add(CartItem(medicine: m));
      }
      _searchResults = [];
      _searchCtrl.clear();
      _searchFocus.requestFocus();
    });
  }

  void _updateQty(int idx, int delta) {
    setState(() {
      final item = _cart[idx];
      final newQty = item.quantity + delta;
      if (newQty <= 0) {
        _cart.removeAt(idx);
      } else if (newQty <= item.medicine.stock) {
        item.quantity = newQty;
      }
    });
  }

  void _removeFromCart(int idx) => setState(() => _cart.removeAt(idx));

  double get _subtotal => _cart.fold(0, (s, i) => s + i.lineTotal);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _total => _subtotal - _discount;
  double get _cash => double.tryParse(_cashCtrl.text) ?? 0;
  double get _change => (_cash - _total).clamp(0, double.infinity);
  bool get _isCard => _paymentType == PaymentType.card;

  // ── Process sale ──────────────────────
  Future<void> _processSale() async {
    if (_cart.isEmpty) {
      showError(context, 'Cart is empty.');
      return;
    }
    setState(() => _processing = true);
    try {
      final bill = await _billSvc.createBill(
        _cart,
        discount: _discount,
        given: _isCard ? _total : _cash, // card = exact amount
        paymentType: _paymentType,
        customerName: _customerCtrl.text.trim(),
      );
      setState(() {
        _lastBill = bill;
        _cart.clear();
        _discountCtrl.text = '0';
        _cashCtrl.text = '0';
        _customerCtrl.clear();
      });
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

  void _showBillDialog(Bill bill) {
    showDialog(
      context: context,
      builder: (_) => _BillPreviewDialog(bill: bill),
      animationStyle: AnimationStyle(
        duration: Duration(milliseconds: 300),
      ),
    ).then((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Row(children: [
      // ── Left: Cart ──────────────────────
      Expanded(
        flex: 3,
        child: Column(children: [
          // Top bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              const Text('POS / Billing',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain)),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  focusNode: _searchFocus,
                  decoration: const InputDecoration(
                    hintText: 'Search medicine to add…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  onChanged: _search,
                ),
              ),
            ]),
          ),
          const Divider(height: 1),

          // Search results dropdown
          if (_searchResults.isNotEmpty)
            Container(
              color: Colors.white,
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16),
                itemBuilder: (_, i) {
                  final m = _searchResults[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.medication,
                        color: AppTheme.primary, size: 22),
                    title: Text(m.name,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${m.category}  ·  Stock: ${m.stock}'),
                    trailing: Text('Rs. ${fmt.format(m.price)}',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                    onTap: () => _addToCart(m),
                  );
                },
              ),
            ),
          if (_searching)
            const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator()),

          // Cart list
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 56, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    const Text('Cart is empty. Search and add medicines.',
                        style: TextStyle(color: AppTheme.textSub)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cart.length,
                    itemBuilder: (_, i) {
                      final item = _cart[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.medicine.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    'Rs. ${fmt.format(item.medicine.price)} each',
                                    style: const TextStyle(
                                        color: AppTheme.textSub, fontSize: 12)),
                              ],
                            )),
                            // Qty stepper
                            Row(children: [
                              _QtyBtn(Icons.remove, () => _updateQty(i, -1)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: Text('${item.quantity}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                              _QtyBtn(Icons.add, () => _updateQty(i, 1)),
                            ]),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 80,
                              child: Text('Rs. ${fmt.format(item.lineTotal)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: AppTheme.textSub),
                              onPressed: () => _removeFromCart(i),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),

      // ── Right: Order summary ────────────
      Container(
        width: 310,
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order Summary',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain)),
              const SizedBox(height: 16),

              // ── Customer Name ─────────────
              TextField(
                controller: _customerCtrl,
                decoration: InputDecoration(
                  labelText: 'Customer Name (optional)',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  isDense: true,
                  suffixIcon: _customerCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _customerCtrl.clear();
                            setState(() {});
                          })
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              const Divider(),

              // Subtotal
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
                    decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              const Divider(),
              _SummaryRow('TOTAL', 'Rs. ${fmt.format(_total)}',
                  large: true, color: AppTheme.primary),
              const SizedBox(height: 16),

              // ── Payment Type ──────────────
              const Text('Payment Method',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSub)),
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

              // ── Cash fields (only for cash) ─
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
                // Change display
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _change > 0
                        ? AppTheme.success.withOpacity(0.08)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _change > 0
                          ? AppTheme.success.withOpacity(0.3)
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.change_circle_outlined,
                            size: 16,
                            color: _change > 0
                                ? AppTheme.success
                                : AppTheme.textSub),
                        const SizedBox(width: 6),
                        const Text('Change:',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ]),
                      Text('Rs. ${fmt.format(_change)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _change > 0
                                  ? AppTheme.success
                                  : AppTheme.textSub)),
                    ],
                  ),
                ),
              ] else ...[
                // Card payment info box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.credit_card,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Card payment — no change required.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 20),

              // Items count badge
              if (_cart.isNotEmpty)
                Center(
                    child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_cart.length} item(s) in cart',
                      style: const TextStyle(
                          color: AppTheme.primary, fontSize: 12)),
                )),
              const SizedBox(height: 12),

              // Process Sale button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _processing || _cart.isEmpty ? null : _processSale,
                  icon: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Icon(
                          _isCard ? Icons.credit_card : Icons.payments_outlined,
                          size: 20),
                  label: Text(
                    _isCard ? 'Process Card Payment' : 'Process Cash Sale',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isCard ? AppTheme.primary : AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ── Payment method toggle button ──────────
class _PaymentBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _PaymentBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

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
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                size: 22, color: selected ? Colors.white : Colors.grey[500]),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey[600],
                )),
          ]),
        ),
      );
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16),
        ),
      );
}

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
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: large ? 18 : 13)),
        ],
      );
}

// ── Bill preview dialog ───────────────────
class _BillPreviewDialog extends StatelessWidget {
  final Bill bill;
  const _BillPreviewDialog({required this.bill});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy  hh:mm a');
    final isCard = bill.paymentType == PaymentType.card;

    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.receipt_long, color: AppTheme.success),
        const SizedBox(width: 8),
        const Text('Bill Created'),
      ]),
      content: SizedBox(
        width: 440,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Invoice header box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          ])),
                      Text('Rs. ${fmt.format(bill.total)}',
                          style: const TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ]),
                    // Customer name (if any)
                    if (bill.customerName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: AppTheme.textSub),
                        const SizedBox(width: 4),
                        Text(bill.customerName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                      ]),
                    ],
                    const SizedBox(height: 8),
                    // Payment type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCard
                            ? AppTheme.primary.withOpacity(0.10)
                            : AppTheme.success.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          isCard ? Icons.credit_card : Icons.payments_outlined,
                          size: 13,
                          color: isCard ? AppTheme.primary : AppTheme.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCard ? 'Card Payment' : 'Cash Payment',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  isCard ? AppTheme.primary : AppTheme.success),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Line items
              ...bill.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                          child: Text(item.medName,
                              style: const TextStyle(fontSize: 13))),
                      Text('×${item.quantity}',
                          style: const TextStyle(
                              color: AppTheme.textSub, fontSize: 12)),
                      const SizedBox(width: 12),
                      Text('Rs. ${fmt.format(item.lineTotal)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                  )),

              // Cash/change (only for cash payments)
              if (!isCard && bill.given > 0) ...[
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cash Given:',
                        style:
                            TextStyle(color: AppTheme.textSub, fontSize: 12)),
                    Text('Rs. ${fmt.format(bill.given)}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Change:',
                        style: TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                    Text('Rs. ${fmt.format(bill.change)}',
                        style: const TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
              ],
            ]),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
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

class POSScreenState extends State<POSScreen> {
  final _medSvc = MedicineService();
  final _billSvc = BillingService();
  final searchCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _cashCtrl = TextEditingController(text: '0');

  List<Medicine> _searchResults = [];
  List<CartItem> _cart = [];
  bool _searching = false;
  bool _processing = false;
  Bill? _lastBill;

  // ── Search medicines ──────────────────
  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final r = await _medSvc.search(q);
    if (mounted)
      setState(() {
        _searchResults = r;
        _searching = false;
      });
  }

  // ── Add to cart ───────────────────────
  void _addToCart(Medicine m) {
    if (m.stock <= 0) {
      showError(context, '${m.name} is out of stock.');
      return;
    }
    setState(() {
      final idx = _cart.indexWhere((c) => c.medicine.id == m.id);
      if (idx >= 0) {
        if (_cart[idx].quantity < m.stock) {
          _cart[idx].quantity++;
        } else {
          showError(context, 'Cannot exceed available stock (${m.stock}).');
        }
      } else {
        _cart.add(CartItem(medicine: m));
      }
      _searchResults = [];
      searchCtrl.clear();
    });
  }

  void _updateQty(int idx, int delta) {
    setState(() {
      final item = _cart[idx];
      final newQty = item.quantity + delta;
      if (newQty <= 0) {
        _cart.removeAt(idx);
      } else if (newQty <= item.medicine.stock) {
        item.quantity = newQty;
      }
    });
  }

  void _removeFromCart(int idx) => setState(() => _cart.removeAt(idx));

  double get _subtotal => _cart.fold(0, (s, i) => s + i.lineTotal);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _total => _subtotal - _discount;
  double get _cash => double.tryParse(_cashCtrl.text) ?? 0;
  double get _change => (_cash - _total).clamp(0, double.infinity);

  // ── Process sale ──────────────────────
  Future<void> _processSale() async {
    if (_cart.isEmpty) {
      showError(context, 'Cart is empty.');
      return;
    }
    setState(() => _processing = true);
    try {
      final bill =
          await _billSvc.createBill(_cart, discount: _discount, given: _cash);
      setState(() {
        _lastBill = bill;
        _cart.clear();
        _discountCtrl.text = '0';
        _cashCtrl.text = '0';
      });
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
      );

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Row(children: [
      // ── Left: Medicine search ───────────
      Expanded(
        flex: 3,
        child: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              const Text('POS / Billing',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain)),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search medicine to add…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  onChanged: _search,
                ),
              ),
            ]),
          ),
          const Divider(height: 1),

          // Search results list
          if (_searchResults.isNotEmpty)
            Container(
              color: Colors.white,
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16),
                itemBuilder: (_, i) {
                  final m = _searchResults[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.medication,
                        color: AppTheme.primary, size: 22),
                    title: Text(m.name,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${m.category}  ·  Stock: ${m.stock}'),
                    trailing: Text('Rs. ${fmt.format(m.price)}',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                    onTap: () => _addToCart(m),
                  );
                },
              ),
            ),
          if (_searching)
            const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator()),

          // Cart
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      const Text('Cart is empty. Search and add medicines.',
                          style: TextStyle(color: AppTheme.textSub)),
                    ],
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cart.length,
                    itemBuilder: (_, i) {
                      final item = _cart[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.medicine.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    'Rs. ${fmt.format(item.medicine.price)} each',
                                    style: const TextStyle(
                                        color: AppTheme.textSub, fontSize: 12)),
                              ],
                            )),
                            // Quantity stepper
                            Row(children: [
                              _QtyBtn(Icons.remove, () => _updateQty(i, -1)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: Text('${item.quantity}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                              _QtyBtn(Icons.add, () => _updateQty(i, 1)),
                            ]),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 80,
                              child: Text('Rs. ${fmt.format(item.lineTotal)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: AppTheme.textSub),
                              onPressed: () => _removeFromCart(i),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),

      // ── Right: Order summary ────────────
      Container(
        width: 300,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Order Summary',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain)),
          const SizedBox(height: 16),
          const Divider(),

          // Subtotal
          _SummaryRow('Subtotal', 'Rs. ${fmt.format(_subtotal)}'),
          const SizedBox(height: 12),

          // Discount
          Row(children: [
            const Text('Discount (Rs.):',
                style: TextStyle(color: AppTheme.textSub, fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _discountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),

          const SizedBox(height: 12),
          const Divider(),
          _SummaryRow('TOTAL', 'Rs. ${fmt.format(_total)}',
              large: true, color: AppTheme.primary),
          const SizedBox(height: 14),

          // Cash tendered
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
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // Change
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _change > 0
                  ? AppTheme.success.withOpacity(0.08)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Change:',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Rs. ${fmt.format(_change)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color:
                            _change > 0 ? AppTheme.success : AppTheme.textSub)),
              ],
            ),
          ),
          const Spacer(),

          // Items count badge
          if (_cart.isNotEmpty)
            Center(
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${_cart.length} item(s) in cart',
                  style:
                      const TextStyle(color: AppTheme.primary, fontSize: 12)),
            )),
          const SizedBox(height: 12),

          // Process sale button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _processing || _cart.isEmpty ? null : _processSale,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Process Sale',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const QtyBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16),
        ),
      );
}

class SummaryRow extends StatelessWidget {
  final String label, value;
  final bool large;
  final Color color;
  const SummaryRow(this.label, this.value,
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
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: large ? 18 : 13)),
        ],
      );
}

// ── Bill preview dialog ───────────────────
class BillPreviewDialog extends StatelessWidget {
  final Bill bill;
  const BillPreviewDialog({required this.bill});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy  hh:mm a');

    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.receipt_long, color: AppTheme.success),
        const SizedBox(width: 8),
        const Text('Bill Created'),
      ]),
      content: SizedBox(
        width: 420,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
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
                      ])),
                  Text('Rs. ${fmt.format(bill.total)}',
                      style: const TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ]),
              ),
              const SizedBox(height: 12),
              ...bill.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                          child: Text(item.medName,
                              style: const TextStyle(fontSize: 13))),
                      Text('×${item.quantity}',
                          style: const TextStyle(
                              color: AppTheme.textSub, fontSize: 12)),
                      const SizedBox(width: 12),
                      Text('Rs. ${fmt.format(item.lineTotal)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                  )),
            ]),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
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
