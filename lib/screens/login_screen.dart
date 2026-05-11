// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading   = false;
  bool _obscure   = true;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ok = await AuthService.login(
        _userCtrl.text.trim(), _passCtrl.text.trim());
      if (!mounted) return;
      if (ok) {
        Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else {
        setState(() => _error = 'Invalid username or password.');
      }
    } catch (e) {
      setState(() => _error = 'DB connection failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Logo area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_pharmacy,
                  size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('Health Hub Pharmacy System',
                style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            const SizedBox(height: 4),
            const Text('Admin Login',
                style: TextStyle(color: AppTheme.textSub, fontSize: 14)),
            const SizedBox(height: 28),

            // Username
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 14),

            // Password
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _login(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(
                          color: AppTheme.danger, fontSize: 13))),
                ]),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Login',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 16),
            // const Text('Default: admin / admin123',
            //     style: TextStyle(color: AppTheme.textSub, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}
