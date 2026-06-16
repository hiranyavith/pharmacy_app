import 'dart:async';
import 'package:flutter/services.dart';

class BarcodeScannerService {
  BarcodeScannerService._();
  static final instance = BarcodeScannerService._();

  // ── Config ──────────────────────────────────────────────────────────────
  /// Minimum characters to treat as a barcode (filters accidental keypresses)
  static const int _minLength = 4;

  /// If no new character arrives within this window, flush the buffer as a
  /// barcode even without an Enter key.
  static const int _timeoutMs = 100;

  // ── Internals ────────────────────────────────────────────────────────────
  final _controller = StreamController<String>.broadcast();
  final StringBuffer _buffer = StringBuffer();
  Timer? _debounce;
  bool _attached = false;

  /// Broadcast stream — subscribe to receive completed barcode strings.
  Stream<String> get barcodes => _controller.stream;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  void attach() {
    if (_attached) return;
    HardwareKeyboard.instance.addHandler(_onKey);
    _attached = true;
  }

  void detach() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _debounce?.cancel();
    _buffer.clear();
    _attached = false;
  }

  void dispose() {
    detach();
    _controller.close();
  }

  // ── Key handler ───────────────────────────────────────────────────────────
  bool _onKey(KeyEvent event) {
    // Only act on key-down events
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;

    // Enter / NumpadEnter → flush whatever is in the buffer
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _flush();
      return false; // don't consume Enter so text fields still work
    }

    // Ignore non-printable keys (Shift, Ctrl, Alt, arrows, F-keys …)
    final char = _characterFromKey(key);
    if (char == null) return false;

    // Cancel any pending timeout flush and restart it
    _debounce?.cancel();
    _buffer.write(char);
    _debounce = Timer(
      const Duration(milliseconds: _timeoutMs),
      _flush,
    );

    // Return false — we don't consume the event so normal text fields
    // still receive the characters (important when the barcode field
    // itself is focused and the user wants the value to appear there too).
    return false;
  }

  void _flush() {
    _debounce?.cancel();
    final code = _buffer.toString().trim();
    _buffer.clear();
    if (code.length >= _minLength) {
      _controller.add(code);
    }
  }

  // ── Helper: map LogicalKeyboardKey → printable character ─────────────────
  //
  // Flutter doesn't expose a direct "character" property on LogicalKeyboardKey
  // for all keys, so we derive it from the key label for common characters.
  String? _characterFromKey(LogicalKeyboardKey key) {
    // key.keyLabel is the human-readable label, e.g. "A", "1", "-", etc.
    // For printable single characters this is exactly what we want.
    final label = key.keyLabel;
    if (label.length == 1) return label;

    // Map some common keys that have multi-char labels
    const extras = {
      'Minus':     '-',
      'Equal':     '=',
      'Backslash': '\\',
      'Slash':     '/',
      'Period':    '.',
      'Comma':     ',',
      'Semicolon': ';',
      'Quote':     "'",
      'Backquote': '`',
      'Digit0': '0', 'Digit1': '1', 'Digit2': '2', 'Digit3': '3',
      'Digit4': '4', 'Digit5': '5', 'Digit6': '6', 'Digit7': '7',
      'Digit8': '8', 'Digit9': '9',
    };
    return extras[label];
  }
}