import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
 
import '../models/label_config.dart';
import '../models/medicine.dart';
import '../utils/app_theme.dart';
import '../utils/label_generator.dart';
 
class LabelDesignScreen extends StatefulWidget {
  final Medicine medicine;
  const LabelDesignScreen({super.key, required this.medicine});
 
  @override
  State<LabelDesignScreen> createState() => _LabelDesignScreenState();
}
 
class _LabelDesignScreenState extends State<LabelDesignScreen> {
  LabelConfig _cfg = LabelConfig();
  bool _printing = false;
 
  final _copiesCtrl     = TextEditingController(text: '1');
  final _labelHCtrl     = TextEditingController(text: '30');
 
  Medicine get m => widget.medicine;
 
  @override
  void dispose() {
    _copiesCtrl.dispose();
    _labelHCtrl.dispose();
    super.dispose();
  }
 
  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      await LabelGenerator.printLabel(m, _cfg);
      if (mounted) {
        showSuccess(context, 'Label sent to printer!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showError(context, 'Print error: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700),
        child: Row(children: [
 
          // ── LEFT: settings panel ────────────────────────────────────────
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              border: Border(right: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.07),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.label_outline,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Label Settings',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ]),
                ),
 
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
 
                        // ── Medicine name chip ──────────────────────────
                        _SectionHeader('Medicine'),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.primary.withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.medication_outlined,
                                size: 16, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                m.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppTheme.primary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 16),
 
                        // ── Field toggles ───────────────────────────────
                        _SectionHeader('Fields to Print'),
                        _Toggle(
                          icon: Icons.text_fields,
                          label: 'Medicine Name',
                          value: _cfg.showName,
                          onChanged: (v) =>
                              setState(() => _cfg = _cfg.copyWith(showName: v)),
                        ),
                        _Toggle(
                          icon: Icons.qr_code,
                          label: 'Barcode',
                          subtitle: m.barcode == null
                              ? 'No barcode registered'
                              : m.barcode!,
                          value: _cfg.showBarcode,
                          enabled: m.barcode != null,
                          onChanged: (v) => setState(
                              () => _cfg = _cfg.copyWith(showBarcode: v)),
                        ),
                        _Toggle(
                          icon: Icons.attach_money,
                          label: 'Selling Price',
                          value: _cfg.showPrice,
                          onChanged: (v) => setState(
                              () => _cfg = _cfg.copyWith(showPrice: v)),
                        ),
                        _Toggle(
                          icon: Icons.price_check,
                          label: 'MRP Label',
                          value: _cfg.showMrp,
                          onChanged: (v) =>
                              setState(() => _cfg = _cfg.copyWith(showMrp: v)),
                        ),
                        _Toggle(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: _cfg.showCategory,
                          onChanged: (v) => setState(
                              () => _cfg = _cfg.copyWith(showCategory: v)),
                        ),
                        _Toggle(
                          icon: Icons.calendar_today_outlined,
                          label: 'Expiry Date',
                          subtitle: m.expiryDate == null
                              ? 'No expiry date set'
                              : null,
                          value: _cfg.showExpiry,
                          enabled: m.expiryDate != null,
                          onChanged: (v) => setState(
                              () => _cfg = _cfg.copyWith(showExpiry: v)),
                        ),
                        _Toggle(
                          icon: Icons.inventory_2_outlined,
                          label: 'Stock Quantity',
                          value: _cfg.showStockQty,
                          onChanged: (v) => setState(
                              () => _cfg = _cfg.copyWith(showStockQty: v)),
                        ),
 
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
 
                        // ── Copies ──────────────────────────────────────
                        _SectionHeader('Print Options'),
                        Row(children: [
                          const Icon(Icons.copy_outlined,
                              size: 16, color: AppTheme.textSub),
                          const SizedBox(width: 8),
                          const Text('Copies:',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textSub)),
                          const SizedBox(width: 8),
                          // Minus
                          _SmallBtn(
                            icon: Icons.remove,
                            onTap: _cfg.copies > 1
                                ? () {
                                    final n = _cfg.copies - 1;
                                    setState(() {
                                      _cfg = _cfg.copyWith(copies: n);
                                      _copiesCtrl.text = '$n';
                                    });
                                  }
                                : null,
                          ),
                          // Input
                          SizedBox(
                            width: 52,
                            child: TextField(
                              controller: _copiesCtrl,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 8)),
                              onChanged: (v) {
                                final n = int.tryParse(v);
                                if (n != null && n >= 1) {
                                  setState(
                                      () => _cfg = _cfg.copyWith(copies: n));
                                }
                              },
                            ),
                          ),
                          // Plus
                          _SmallBtn(
                            icon: Icons.add,
                            onTap: _cfg.copies < 100
                                ? () {
                                    final n = _cfg.copies + 1;
                                    setState(() {
                                      _cfg = _cfg.copyWith(copies: n);
                                      _copiesCtrl.text = '$n';
                                    });
                                  }
                                : null,
                          ),
                        ]),
                        const SizedBox(height: 12),
 
                        // ── Label height ────────────────────────────────
                        Row(children: [
                          const Icon(Icons.height,
                              size: 16, color: AppTheme.textSub),
                          const SizedBox(width: 8),
                          const Text('Label height:',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textSub)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: _labelHCtrl,
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 8),
                                  suffixText: 'mm'),
                              onChanged: (v) {
                                final h = double.tryParse(v);
                                if (h != null && h >= 15 && h <= 100) {
                                  setState(() =>
                                      _cfg = _cfg.copyWith(labelHeightMm: h));
                                }
                              },
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        const Text(
                          'Min 15 mm · Max 100 mm',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.textSub),
                        ),
                      ],
                    ),
                  ),
                ),
 
                // ── Print button ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _printing ? null : _print,
                    icon: _printing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.print, size: 18),
                    label: Text(
                      _printing
                          ? 'Printing…'
                          : 'Print ${_cfg.copies} Label${_cfg.copies > 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
 
          // ── RIGHT: live label preview ───────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                color: Color(0xFFF0F2F8),
              ),
              child: Column(children: [
                // Preview header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                        topRight: Radius.circular(16)),
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFE0E3EC))),
                  ),
                  child: Row(children: [
                    const Icon(Icons.preview_outlined,
                        size: 18, color: AppTheme.textSub),
                    const SizedBox(width: 8),
                    const Text('Label Preview  (80 mm roll)',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMain)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_cfg.labelHeightMm.round()} mm × 72 mm',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
 
                // Preview area — scrollable so tall labels fit
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: _LabelPreview(
                          medicine: m, config: _cfg),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
 
// ── Live Flutter preview of the label ────────────────────────────────────────
//
// Mimics the thermal label layout: white card, fixed 288px width (≈72mm),
// dynamic height. Uses the same field order as LabelGenerator.
class _LabelPreview extends StatelessWidget {
  final Medicine    medicine;
  final LabelConfig config;
  const _LabelPreview({required this.medicine, required this.config});
 
  @override
  Widget build(BuildContext context) {
    final fmt    = NumberFormat('#,##0.00');
    final expFmt = DateFormat('dd/MM/yyyy');
    final m      = medicine;
 
    return Container(
      width: 288,    // 72 mm × 4 px/mm ≈ 288 logical pixels
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
 
          // Name
          if (config.showName) ...[
            Text(
              m.name.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
 
          // Category
          if (config.showCategory && m.category.isNotEmpty) ...[
            Text(m.category,
                style: TextStyle(fontSize: 9, color: Colors.grey[600])),
            const SizedBox(height: 3),
          ],
 
          // Price row
          if (config.showPrice || config.showMrp) ...[
            Row(children: [
              if (config.showPrice)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Rs. ${fmt.format(m.price)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              if (config.showPrice && config.showMrp)
                const SizedBox(width: 8),
              if (config.showMrp)
                Text(
                  'MRP: Rs. ${fmt.format(m.price)}',
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                ),
            ]),
            const SizedBox(height: 4),
          ],
 
          // Expiry
          if (config.showExpiry && m.expiryDate != null) ...[
            Text(
              'Exp: ${expFmt.format(m.expiryDate!)}',
              style: TextStyle(
                fontSize: 9,
                color: m.isExpiringSoon ? Colors.red : Colors.grey[700],
                fontWeight: m.isExpiringSoon
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 3),
          ],
 
          // Stock
          if (config.showStockQty) ...[
            Text('Stock: ${m.stock}',
                style: TextStyle(fontSize: 9, color: Colors.grey[600])),
            const SizedBox(height: 3),
          ],
 
          // Barcode placeholder
          if (config.showBarcode && m.barcode != null &&
              m.barcode!.isNotEmpty) ...[
            const SizedBox(height: 4),
            // Render barcode bars as thin vertical lines (lightweight preview)
            _BarcodePreview(barcode: m.barcode!),
          ] else if (config.showBarcode && (m.barcode == null ||
              m.barcode!.isEmpty)) ...[
            const SizedBox(height: 4),
            Container(
              height: 36,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text('No barcode',
                    style:
                        TextStyle(fontSize: 9, color: Colors.grey)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
 
// ── Lightweight barcode preview using CustomPainter ──────────────────────────
// Draws Code128-style bars without importing the barcode package at runtime.
// The actual printed output comes from LabelGenerator using the barcode package.
class _BarcodePreview extends StatelessWidget {
  final String barcode;
  const _BarcodePreview({required this.barcode});
 
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        width: double.infinity,
        height: 36,
        child: CustomPaint(painter: _BarcodePainter(barcode)),
      ),
      const SizedBox(height: 2),
      Text(
        barcode,
        style: const TextStyle(
            fontSize: 8,
            fontFamily: 'monospace',
            letterSpacing: 1.5,
            color: Colors.black),
      ),
    ]);
  }
}
 
class _BarcodePainter extends CustomPainter {
  final String data;
  _BarcodePainter(this.data);
 
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    // Generate a deterministic bar pattern from the string characters
    final seed = data.codeUnits;
    const barCount = 60;
    final barW = size.width / barCount;
    for (var i = 0; i < barCount; i++) {
      final charVal = seed[i % seed.length];
      // Alternate thick/thin based on char value parity and position
      final isBar = ((charVal + i) % 3) != 0;
      if (isBar) {
        canvas.drawRect(
          Rect.fromLTWH(i * barW, 0, barW * 0.8, size.height),
          paint,
        );
      }
    }
  }
 
  @override
  bool shouldRepaint(_BarcodePainter old) => old.data != data;
}
 
// ── Small helper widgets ──────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSub,
          letterSpacing: 0.8),
    ),
  );
}
 
class _Toggle extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final String?    subtitle;
  final bool       value;
  final bool       enabled;
  final ValueChanged<bool> onChanged;
 
  const _Toggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });
 
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(icon,
          size: 16,
          color: enabled ? AppTheme.primary : Colors.grey[400]),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: enabled
                      ? AppTheme.textMain
                      : Colors.grey[400])),
          if (subtitle != null)
            Text(subtitle!,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey[500])),
        ]),
      ),
      Switch.adaptive(
        value: value && enabled,
        onChanged: enabled ? onChanged : null,
        activeColor: AppTheme.primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ]),
  );
}
 
class _SmallBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback? onTap;
  const _SmallBtn({required this.icon, this.onTap});
 
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: onTap != null
            ? AppTheme.primary.withOpacity(0.10)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: onTap != null
              ? AppTheme.primary.withOpacity(0.3)
              : Colors.grey[300]!,
        ),
      ),
      child: Icon(icon,
          size: 16,
          color: onTap != null ? AppTheme.primary : Colors.grey[400]),
    ),
  );
}