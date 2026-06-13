// lib/screens/bill_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pharmacy_app/components/TotalLine.dart';
import 'package:pharmacy_app/components/stepperBtn.dart';
import '../models/bill.dart';
import '../services/billing_service.dart';
import '../utils/app_theme.dart';
import '../utils/pdf_generator.dart';

class BillHistoryScreen extends StatefulWidget {
  const BillHistoryScreen({super.key});
  @override
  State<BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends State<BillHistoryScreen> {
  final _svc = BillingService();
  final _searchCtrl = TextEditingController();
  List<Bill> _bills = [];
  bool _loading = true;
  Bill? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String q = '']) async {
    setState(() {
      _loading = true;
      _selected = null;
    });
    final list =
        q.isEmpty ? await _svc.getAllBills() : await _svc.searchBills(q);
    if (mounted)
      setState(() {
        _bills = list;
        _loading = false;
      });
  }

  Future<void> _selectBill(Bill bill) async {
    final items = await _svc.getBillItems(bill.id);
    if (mounted) setState(() => _selected = bill..items = items);
  }

  // ── Open Edit Dialog ──────────────────────────────────────────────────────
  Future<void> _openBillEditor(Bill bill) async {
    // Deep-copy items so we don't mutate the displayed bill until Save is hit
    final editItems = bill.items
        .map((e) => BillItem(
              id: e.id,
              billId: e.billId,
              medicineId: e.medicineId,
              medName: e.medName,
              quantity: e.quantity,
              unitPrice: e.unitPrice,
              // carry any other fields your BillItem has
            ))
        .toList();

    // One TextEditingController per row, keyed by index
    final controllers = {
      for (var i = 0; i < editItems.length; i++)
        i: TextEditingController(text: '${editItems[i].quantity}')
    };

    double discount = bill.discount;
    final discountCtrl =
        TextEditingController(text: discount == 0 ? '' : '$discount');

    // Recalculate totals from editItems + discount
    double subtotal() =>
        editItems.fold(0.0, (s, it) => s + it.unitPrice * it.quantity);
    double total() => subtotal() - discount;

    final fmt = NumberFormat('#,##0.00');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlg) {
          // ── step qty ──
          void stepQty(int i, int delta) {
            final next = editItems[i].quantity + delta;
            if (next < 1) return;
            setDlg(() {
              editItems[i].quantity = next;
              controllers[i]!.text = '$next';
            });
          }

          // ── manual qty input ──
          void onQtyInput(int i, String v) {
            final parsed = int.tryParse(v);
            if (parsed != null && parsed >= 1) {
              setDlg(() => editItems[i].quantity = parsed);
            }
          }

          // ── remove row ──
          void removeItem(int i) {
            setDlg(() {
              editItems.removeAt(i);
              controllers.remove(i);
              // Re-key remaining controllers
              final entries = controllers.entries.toList();
              controllers.clear();
              for (var j = 0; j < entries.length; j++) {
                controllers[j] = entries[j].value;
              }
            });
          }

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820, maxHeight: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Dialog header ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.06),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(children: [
                      const Icon(Icons.edit_note,
                          color: AppTheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Edit Bill  •  ${bill.invoiceNo}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        tooltip: 'Cancel',
                      ),
                    ]),
                  ),

                  // ── Table header ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    color: Colors.grey[50],
                    child: const Row(children: [
                      Expanded(
                          child: Text('Medicine',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppTheme.textSub))),
                      SizedBox(
                          width: 160,
                          child: Text('Quantity',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppTheme.textSub))),
                      SizedBox(
                          width: 100,
                          child: Text('Unit Price',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppTheme.textSub))),
                      SizedBox(
                          width: 100,
                          child: Text('Line Total',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppTheme.textSub))),
                      SizedBox(width: 40),
                    ]),
                  ),
                  const Divider(height: 1),

                  // ── Scrollable item rows ──
                  Expanded(
                    child: editItems.isEmpty
                        ? const Center(
                            child: Text('No items in this bill.',
                                style:
                                    TextStyle(color: AppTheme.textSub)))
                        : ListView.separated(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            itemCount: editItems.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 20),
                            itemBuilder: (_, i) {
                              final item = editItems[i];
                              final ctrl = controllers[i]!;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    // Medicine name
                                    Expanded(
                                      child: Text(item.medName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13)),
                                    ),

                                    // ── Qty Stepper ──
                                    Container(
                                      width: 160,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey[300]!),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        color: Colors.white,
                                      ),
                                      child: Row(children: [
                                        StepperBtn(
                                          icon: Icons.remove,
                                          enabled: item.quantity > 1,
                                          isLeft: true,
                                          onTap: () => stepQty(i, -1),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: ctrl,
                                            textAlign: TextAlign.center,
                                            keyboardType:
                                                TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                  4),
                                            ],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textMain,
                                            ),
                                            decoration:
                                                const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      vertical: 8),
                                            ),
                                            onChanged: (v) =>
                                                onQtyInput(i, v),
                                            onSubmitted: (v) {
                                              if (v.isEmpty) {
                                                ctrl.text =
                                                    '${item.quantity}';
                                              }
                                            },
                                          ),
                                        ),
                                        StepperBtn(
                                          icon: Icons.add,
                                          enabled: true, // add stock check if available
                                          isLeft: false,
                                          onTap: () => stepQty(i, 1),
                                        ),
                                      ]),
                                    ),

                                    // Unit price
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        'Rs. ${fmt.format(item.unitPrice)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSub),
                                      ),
                                    ),

                                    // Line total (live)
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        'Rs. ${fmt.format(item.unitPrice * item.quantity)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.primary),
                                      ),
                                    ),

                                    // Remove button
                                    SizedBox(
                                      width: 40,
                                      child: IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: AppTheme.danger),
                                        onPressed: () => removeItem(i),
                                        tooltip: 'Remove item',
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  const Divider(height: 1),

                  // ── Footer: discount + totals + actions ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Discount field
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: discountCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Discount (Rs.)',
                              prefixText: 'Rs. ',
                              isDense: true,
                            ),
                            onChanged: (v) {
                              setDlg(() =>
                                  discount = double.tryParse(v) ?? 0.0);
                            },
                          ),
                        ),

                        const Spacer(),

                        // Live totals
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _SummaryLine(
                                'Subtotal',
                                'Rs. ${fmt.format(subtotal())}'),
                            if (discount > 0)
                              _SummaryLine(
                                  'Discount',
                                  '- Rs. ${fmt.format(discount)}',
                                  color: AppTheme.danger),
                            const SizedBox(height: 4),
                            _SummaryLine(
                                'TOTAL',
                                'Rs. ${fmt.format(total())}',
                                bold: true,
                                color: AppTheme.primary),
                          ],
                        ),

                        const SizedBox(width: 24),

                        // Action buttons
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.save, size: 16),
                              label: const Text('Save Changes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: editItems.isEmpty
                                  ? null
                                  : () async {
                                      // Build updated bill
                                      final updated = bill.copyWith(
                                        items: editItems,
                                        discount: discount,
                                        subtotal: subtotal(),
                                        total: total(),
                                      );
                                      await _svc.updateBill(updated);
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                      }
                                      // Refresh list + re-select
                                      await _load(_searchCtrl.text);
                                      if (mounted) {
                                        await _selectBill(updated);
                                      }
                                    },
                            ),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    // Dispose controllers
    for (final c in controllers.values) {
      c.dispose();
    }
    discountCtrl.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy  hh:mm a');
    final dateOnly = DateFormat('dd MMM yyyy');

    return Row(children: [
      // ── Left: Bill list ────────────────────────────────────────────────────
      Expanded(
        flex: 2,
        child: Column(children: [
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              const Text('Bill History',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain)),
              const Spacer(),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText:
                        'Search by invoice no or date (YYYY-MM-DD)…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  onChanged: _load,
                ),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _bills.isEmpty
                    ? const Center(
                        child: Text('No bills found.',
                            style: TextStyle(color: AppTheme.textSub)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _bills.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final b = _bills[i];
                          final isActive = _selected?.id == b.id;
                          return InkWell(
                            onTap: () => _selectBill(b),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppTheme.primary.withOpacity(0.06)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isActive
                                      ? AppTheme.primary
                                      : Colors.transparent,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withOpacity(0.04),
                                      blurRadius: 4)
                                ],
                              ),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primary.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.receipt,
                                      color: AppTheme.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(b.invoiceNo,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w600)),
                                      Text(dateOnly.format(b.createdAt),
                                          style: const TextStyle(
                                              color: AppTheme.textSub,
                                              fontSize: 12)),
                                    ])),
                                Text('Rs. ${fmt.format(b.total)}',
                                    style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),

      const VerticalDivider(width: 1),

      // ── Right: Bill details ────────────────────────────────────────────────
      Expanded(
        flex: 3,
        child: _selected == null
            ? const Center(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 56, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Select a bill to view details',
                      style: TextStyle(color: AppTheme.textSub)),
                ],
              ))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                              Text(_selected!.invoiceNo,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textMain)),
                              Text(
                                  dateFmt
                                      .format(_selected!.createdAt),
                                  style: const TextStyle(
                                      color: AppTheme.textSub,
                                      fontSize: 13)),
                            ])),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Print'),
                          onPressed: () =>
                              PdfGenerator.printBill(_selected!),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          onPressed: () =>
                              _openBillEditor(_selected!),
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // Items table
                      Card(
                        child: Column(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primary.withOpacity(0.06),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(children: const [
                              Expanded(
                                  child: Text('Medicine',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.w600))),
                              SizedBox(
                                  width: 60,
                                  child: Text('Qty',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.w600))),
                              SizedBox(
                                  width: 100,
                                  child: Text('Unit Price',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.w600))),
                              SizedBox(
                                  width: 100,
                                  child: Text('Total',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.w600))),
                            ]),
                          ),
                          ..._selected!.items.map((item) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                    border: Border(
                                        top: BorderSide(
                                            color:
                                                Colors.grey[200]!))),
                                child: Row(children: [
                                  Expanded(
                                      child: Text(item.medName)),
                                  SizedBox(
                                      width: 60,
                                      child: Text('${item.quantity}',
                                          textAlign:
                                              TextAlign.center)),
                                  SizedBox(
                                      width: 100,
                                      child: Text(
                                          'Rs. ${fmt.format(item.unitPrice)}',
                                          textAlign:
                                              TextAlign.right)),
                                  SizedBox(
                                      width: 100,
                                      child: Text(
                                          'Rs. ${fmt.format(item.lineTotal)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w500))),
                                ]),
                              )),
                        ]),
                      ),

                      const SizedBox(height: 12),

                      // Totals
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 260,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      Colors.black.withOpacity(0.06),
                                  blurRadius: 6)
                            ],
                          ),
                          child: Column(children: [
                            TotalLine('Subtotal',
                                'Rs. ${fmt.format(_selected!.subtotal)}'),
                            TotalLine('Given Price',
                                'Rs. ${fmt.format(_selected!.given)}'),
                            TotalLine('Change Price',
                                'Rs. ${fmt.format(_selected!.change)}'),
                            if (_selected!.discount > 0)
                              TotalLine(
                                  'Discount',
                                  '- Rs. ${fmt.format(_selected!.discount)}',
                                  color: AppTheme.danger),
                            const Divider(),
                            TotalLine('TOTAL',
                                'Rs. ${fmt.format(_selected!.total)}',
                                bold: true, color: AppTheme.primary),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 260,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      Colors.black.withOpacity(0.06),
                                  blurRadius: 6)
                            ],
                          ),
                          child: Column(children: [
                            TotalLine(
                              'Payment Type',
                              _selected!.paymentType
                                  .toString()
                                  .split('.')
                                  .last
                                  .toUpperCase(),
                              color: _selected!.paymentType
                                          .toString()
                                          .split('.')
                                          .last ==
                                      'cash'
                                  ? AppTheme.success
                                  : AppTheme.textMain,
                              bold: true,
                            ),
                            TotalLine(
                                'Customer Name',
                                _selected!.customerName.isEmpty
                                    ? '-'
                                    : _selected!.customerName),
                          ]),
                        ),
                      ),
                    ]),
              ),
      ),
    ]);
  }
}

// ── Small helper widget for totals summary inside the dialog ──────────────────
class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _SummaryLine(this.label, this.value,
      {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 14 : 12,
      color: color ?? AppTheme.textMain,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label:  ', style: TextStyle(fontSize: 12, color: AppTheme.textSub)),
        Text(value, style: style),
      ]),
    );
  }
}