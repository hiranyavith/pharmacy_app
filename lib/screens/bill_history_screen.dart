// lib/screens/bill_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy  hh:mm a');
    final dateOnly = DateFormat('dd MMM yyyy');

    return Row(children: [
      // ── Left: Bill list ─────────────────
      Expanded(
        flex: 2,
        child: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                    hintText: 'Search by invoice no or date (YYYY-MM-DD)…',
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
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 4)
                                ],
                              ),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
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
                                              fontWeight: FontWeight.w600)),
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

      // ── Right: Bill details ─────────────
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(_selected!.invoiceNo,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textMain)),
                              Text(dateFmt.format(_selected!.createdAt),
                                  style: const TextStyle(
                                      color: AppTheme.textSub, fontSize: 13)),
                            ])),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Print'),
                          onPressed: () => PdfGenerator.printBill(_selected!),
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
                              color: AppTheme.primary.withOpacity(0.06),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(children: const [
                              Expanded(
                                  child: Text('Medicine',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              SizedBox(
                                  width: 60,
                                  child: Text('Qty',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              SizedBox(
                                  width: 100,
                                  child: Text('Unit Price',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              SizedBox(
                                  width: 100,
                                  child: Text('Total',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                            ]),
                          ),
                          ..._selected!.items.map((item) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                    border: Border(
                                        top: BorderSide(
                                            color: Colors.grey[200]!))),
                                child: Row(children: [
                                  Expanded(child: Text(item.medName)),
                                  SizedBox(
                                      width: 60,
                                      child: Text('${item.quantity}',
                                          textAlign: TextAlign.center)),
                                  SizedBox(
                                      width: 100,
                                      child: Text(
                                          'Rs. ${fmt.format(item.unitPrice)}',
                                          textAlign: TextAlign.right)),
                                  SizedBox(
                                      width: 100,
                                      child: Text(
                                          'Rs. ${fmt.format(item.lineTotal)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500))),
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
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 6)
                            ],
                          ),
                          child: Column(children: [
                            _TotalLine('Subtotal',
                                'Rs. ${fmt.format(_selected!.subtotal)}'),
                            _TotalLine('Given Price',
                                'Rs. ${fmt.format(_selected!.given)}'),
                            _TotalLine('Change Price',
                                'Rs. ${fmt.format(_selected!.change)}'),
                            if (_selected!.discount > 0)
                              _TotalLine('Discount',
                                  '- Rs. ${fmt.format(_selected!.discount)}',
                                  color: AppTheme.danger),
                            const Divider(),
                            _TotalLine(
                                'TOTAL', 'Rs. ${fmt.format(_selected!.total)}',
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
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 6)
                            ],
                          ),
                          child: Column(children: [
                            _TotalLine(
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
                                      "cash"
                                  ? AppTheme.success
                                  : AppTheme.textMain,
                              bold: true,
                            ),
                            _TotalLine(
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

class _TotalLine extends StatelessWidget {
  final String label, value;
  final bool large, bold;
  final Color color;
  const _TotalLine(this.label, this.value,
      {this.large = false, this.bold = false, this.color = AppTheme.textMain});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: AppTheme.textSub,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 16 : 14)),
          ],
        ),
      );
}
