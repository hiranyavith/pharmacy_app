// lib/screens/label_design_screen.dart
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
  LabelConfig _cfg = LabelConfig(); // defaults to 30×15 mm, Code128
  bool _printing = false;

  final _copiesCtrl = TextEditingController(text: '1');
  final _paperWCtrl = TextEditingController(text: '30');
  final _labelHCtrl = TextEditingController(text: '15');

  Medicine get m => widget.medicine;

  @override
  void dispose() {
    _copiesCtrl.dispose();
    _paperWCtrl.dispose();
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.07),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.label_outline, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Label Settings',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.medication_outlined, size: 16, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                m.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        // ── Paper size (printer stock) ──────────────────
                        _SectionHeader('Paper Size (XP-365B stock)'),
                        DropdownButtonFormField<PaperSize>(
                          value: PaperSize.presets.firstWhere(
                            (p) => p.matches(_cfg.paperWidthMm, _cfg.labelHeightMm),
                            orElse: () => PaperSize.custom,
                          ),
                          isExpanded: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: [
                            ...PaperSize.presets.map(
                              (p) => DropdownMenuItem(value: p, child: Text(p.label, style: const TextStyle(fontSize: 13))),
                            ),
                            const DropdownMenuItem(
                              value: PaperSize.custom,
                              child: Text('Custom size', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                          onChanged: (p) {
                            if (p == null || p == PaperSize.custom) return;
                            setState(() {
                              _cfg = _cfg.copyWith(paperWidthMm: p.widthMm, labelHeightMm: p.heightMm);
                              _paperWCtrl.text = p.widthMm.toStringAsFixed(0);
                              _labelHCtrl.text = p.heightMm.toStringAsFixed(0);
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: _MmField(
                              label: 'Width',
                              controller: _paperWCtrl,
                              onChanged: (v) {
                                final w = double.tryParse(v);
                                if (w != null && w >= 15 && w <= 120) {
                                  setState(() => _cfg = _cfg.copyWith(paperWidthMm: w));
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MmField(
                              label: 'Height',
                              controller: _labelHCtrl,
                              onChanged: (v) {
                                final h = double.tryParse(v);
                                if (h != null && h >= 10 && h <= 120) {
                                  setState(() => _cfg = _cfg.copyWith(labelHeightMm: h));
                                }
                              },
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),

                        // ── Field toggles ───────────────────────────────
                        _SectionHeader('Fields to Print'),
                        _Toggle(
                          icon: Icons.text_fields,
                          label: 'Medicine Name',
                          value: _cfg.showName,
                          onChanged: (v) => setState(() => _cfg = _cfg.copyWith(showName: v)),
                        ),
                        _Toggle(
                          icon: Icons.qr_code,
                          label: 'Barcode',
                          subtitle: m.barcode == null ? 'No barcode registered' : m.barcode!,
                          value: _cfg.showBarcode,
                          enabled: m.barcode != null,
                          onChanged: (v) => setState(() => _cfg = _cfg.copyWith(showBarcode: v)),
                        ),
                        if (_cfg.showBarcode && m.barcode != null && m.barcode!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 26, bottom: 8, top: 2),
                            child: DropdownButtonFormField<BarcodeType>(
                              value: _cfg.barcodeType,
                              isDense: true,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                labelText: 'Barcode type',
                                labelStyle: TextStyle(fontSize: 11),
                              ),
                              items: BarcodeType.values
                                  .map((t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t.label, style: const TextStyle(fontSize: 12)),
                                      ))
                                  .toList(),
                              onChanged: (t) {
                                if (t == null) return;
                                setState(() => _cfg = _cfg.copyWith(barcodeType: t));
                              },
                            ),
                          ),
                        _Toggle(
                          icon: Icons.attach_money,
                          label: 'Selling Price',
                          value: _cfg.showPrice,
                          onChanged: (v) => setState(() => _cfg = _cfg.copyWith(showPrice: v)),
                        ),
                        _Toggle(
                          icon: Icons.price_check,
                          label: 'MRP Label',
                          value: _cfg.showMrp,
                          onChanged: (v) => setState(() => _cfg = _cfg.copyWith(showMrp: v)),
                        ),
                        _Toggle(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: _cfg.showCategory,
                          onChanged: (v) => setState(() => _cfg = _cfg.copyWith(showCategory: v)),
                        ),
                        _Toggle(
                          icon: Icons.calendar_today_outlined,
                          label: 'Expiry Date',
                          subtitle: m.expiryDate == null ? 'No expiry date set' : null,
                          value: _cfg.showExpiry,
                          enabled: m.expiryDate != null,
                          onChanged: (v) => setState(() => _cfg = _cfg.copyWith(showExpiry: v)),
                        ),
                        _Toggle(
                          icon: Icons.inventory_2_outlined,
                          label: 'Stock Quantity',
                          value: _cfg.showStockQty,
                          onChanged: (v) => setState(() => _cfg = _cfg.copyWith(showStockQty: v)),
                        ),

                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),

                        // ── Copies ──────────────────────────────────────
                        _SectionHeader('Print Options'),
                        Row(children: [
                          const Icon(Icons.copy_outlined, size: 16, color: AppTheme.textSub),
                          const SizedBox(width: 8),
                          const Text('Copies:', style: TextStyle(fontSize: 13, color: AppTheme.textSub)),
                          const SizedBox(width: 8),
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
                                  isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8)),
                              onChanged: (v) {
                                final n = int.tryParse(v);
                                if (n != null && n >= 1) {
                                  setState(() => _cfg = _cfg.copyWith(copies: n));
                                }
                              },
                            ),
                          ),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.print, size: 18),
                    label: Text(
                      _printing ? 'Printing…' : 'Print ${_cfg.copies} Label${_cfg.copies > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                borderRadius: BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                color: Color(0xFFF0F2F8),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topRight: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: Color(0xFFE0E3EC))),
                  ),
                  child: Row(children: [
                    const Icon(Icons.preview_outlined, size: 18, color: AppTheme.textSub),
                    const SizedBox(width: 8),
                    const Text('Label Preview',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_cfg.paperWidthMm.round()} × ${_cfg.labelHeightMm.round()} mm',
                        style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: _LabelPreview(medicine: m, config: _cfg)),
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

// ── Live Flutter preview of the label ────────────────────────────────────
class _LabelPreview extends StatelessWidget {
  final Medicine    medicine;
  final LabelConfig config;
  const _LabelPreview({required this.medicine, required this.config});

  static const double _pxPerMm = 4;

  @override
  Widget build(BuildContext context) {
    final fmt    = NumberFormat('#,##0.00');
    final expFmt = DateFormat('dd/MM/yyyy');
    final m      = medicine;
    final bool isSmall = config.paperWidthMm <= 40 || config.labelHeightMm <= 20;

    final double nameFont  = isSmall ? 10 : 12;
    final double smallFont = isSmall ? 8  : 9;
    final double priceFont = isSmall ? 10 : 12;

    return Container(
      width: (config.paperWidthMm * _pxPerMm).clamp(90, 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: isSmall ? 6 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (config.showName) ...[
            Text(
              m.name.toUpperCase(),
              style: TextStyle(fontSize: nameFont, fontWeight: FontWeight.bold, color: Colors.black, height: 1.15),
              maxLines: isSmall ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isSmall ? 2 : 4),
          ],
          if (config.showCategory && m.category.isNotEmpty) ...[
            Text(m.category, style: TextStyle(fontSize: smallFont, color: Colors.grey[600])),
            SizedBox(height: isSmall ? 2 : 3),
          ],
          if (config.showPrice || config.showMrp) ...[
            Row(children: [
              if (config.showPrice)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 5 : 6, vertical: isSmall ? 2 : 3),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(3)),
                  child: Text('Rs. ${fmt.format(m.price)}',
                      style: TextStyle(fontSize: priceFont, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              if (config.showPrice && config.showMrp) SizedBox(width: isSmall ? 5 : 8),
              if (config.showMrp)
                Text('MRP: Rs. ${fmt.format(m.price)}', style: TextStyle(fontSize: smallFont, color: Colors.grey[600])),
            ]),
            SizedBox(height: isSmall ? 3 : 4),
          ],
          if (config.showExpiry && m.expiryDate != null) ...[
            Text(
              'Exp: ${expFmt.format(m.expiryDate!)}',
              style: TextStyle(
                fontSize: smallFont,
                color: m.isExpiringSoon ? Colors.red : Colors.grey[700],
                fontWeight: m.isExpiringSoon ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            SizedBox(height: isSmall ? 2 : 3),
          ],
          if (config.showStockQty) ...[
            Text('Stock: ${m.stock}', style: TextStyle(fontSize: smallFont, color: Colors.grey[600])),
            SizedBox(height: isSmall ? 2 : 3),
          ],
          if (config.showBarcode && m.barcode != null && m.barcode!.isNotEmpty) ...[
            SizedBox(height: isSmall ? 2 : 4),
            SizedBox(
              width: double.infinity,
              child: Center(
                child: _BarcodePreview(barcode: m.barcode!, type: config.barcodeType, compact: isSmall),
              ),
            ),
          ] else if (config.showBarcode && (m.barcode == null || m.barcode!.isEmpty)) ...[
            SizedBox(height: isSmall ? 2 : 4),
            Container(
              width: double.infinity,
              height: 32,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
              child: const Center(child: Text('No barcode', style: TextStyle(fontSize: 9, color: Colors.grey))),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Lightweight barcode preview (bars or QR grid) ─────────────────────────
class _BarcodePreview extends StatelessWidget {
  final String barcode;
  final BarcodeType type;
  final bool compact;
  const _BarcodePreview({required this.barcode, required this.type, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final bool isQr = type == BarcodeType.qrCode;
    final double size = compact ? 46 : 60;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: isQr ? size : double.infinity,
        height: isQr ? size : (compact ? 26 : 36),
        child: CustomPaint(painter: isQr ? _QrPreviewPainter(barcode) : _BarcodePainter(barcode)),
      ),
      const SizedBox(height: 2),
      Text(
        barcode,
        style: TextStyle(fontSize: compact ? 7 : 8, fontFamily: 'monospace', letterSpacing: 1.2, color: Colors.black),
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
    final seed = data.codeUnits;
    const barCount = 60;
    final barW = size.width / barCount;
    for (var i = 0; i < barCount; i++) {
      final charVal = seed[i % seed.length];
      final isBar = ((charVal + i) % 3) != 0;
      if (isBar) {
        canvas.drawRect(Rect.fromLTWH(i * barW, 0, barW * 0.8, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.data != data;
}

class _QrPreviewPainter extends CustomPainter {
  final String data;
  _QrPreviewPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    const grid = 10;
    final cell = size.width / grid;
    final seed = data.codeUnits;
    for (var y = 0; y < grid; y++) {
      for (var x = 0; x < grid; x++) {
        final v = seed[(x * grid + y) % seed.length];
        if ((v + x + y) % 3 != 0) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell * 0.9, cell * 0.9), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPreviewPainter old) => old.data != data;
}

// ── Small helper widgets ───────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSub, letterSpacing: 0.8),
    ),
  );
}

class _MmField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _MmField({required this.label, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    textAlign: TextAlign.center,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: const TextStyle(fontSize: 11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      suffixText: 'mm',
    ),
    onChanged: onChanged,
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
      Icon(icon, size: 16, color: enabled ? AppTheme.primary : Colors.grey[400]),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 13, color: enabled ? AppTheme.textMain : Colors.grey[400])),
          if (subtitle != null)
            Text(subtitle!, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
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
        color: onTap != null ? AppTheme.primary.withOpacity(0.10) : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: onTap != null ? AppTheme.primary.withOpacity(0.3) : Colors.grey[300]!),
      ),
      child: Icon(icon, size: 16, color: onTap != null ? AppTheme.primary : Colors.grey[400]),
    ),
  );
}