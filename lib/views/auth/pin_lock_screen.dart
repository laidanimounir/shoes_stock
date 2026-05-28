import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/settings_local.dart';
import 'login_screen.dart';

class PinLockScreen extends StatefulWidget {
  final Widget child;
  const PinLockScreen({super.key, required this.child});
  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> with WidgetsBindingObserver {
  final _localAuth = LocalAuthentication();
  String _pin = '';
  bool _setupMode = false;
  String _confirmPin = '';
  bool _error = false;
  String _errorMsg = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _init();
    }
  }

  Future<void> _init() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
      return;
    }
    try {
      final isar = await IsarService.getInstance();
      final settings = await isar.settingsLocals.get(1);
      if (settings == null || settings.pinHash == null || settings.pinHash!.isEmpty) {
        setState(() { _setupMode = true; _isLoading = false; });
        return;
      }
      setState(() => _isLoading = false);
      bool authenticated = false;
      if (settings.biometricEnabled) {
        try {
          final canCheck = await _localAuth.canCheckBiometrics;
          if (canCheck) {
            authenticated = await _localAuth.authenticate(
              localizedReason: S.t('pin_auth_biometric_reason'),
              options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
            );
          }
        } catch (_) {}
      }
      if (!authenticated) {
        setState(() => _setupMode = false);
      } else {
        _unlock();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onDigit(String d) {
    if (_setupMode) {
      if (_confirmPin.isEmpty) {
        if (_pin.length < 4) {
          setState(() { _pin += d; _error = false; });
          if (_pin.length == 4) setState(() => _confirmPin = '');
        }
      } else {
        if (_confirmPin.length < 4) {
          setState(() => _confirmPin += d);
          if (_confirmPin.length == 4) {
            if (_pin == _confirmPin) {
              _savePin(_pin);
            } else {
              setState(() { _error = true; _errorMsg = S.t('pin_mismatch'); _pin = ''; _confirmPin = ''; });
            }
          }
        }
      }
    } else {
      if (_pin.length < 4) {
        setState(() { _pin += d; _error = false; });
        if (_pin.length == 4) _verifyPin();
      }
    }
  }

  void _onDelete() {
    if (_setupMode && _confirmPin.isNotEmpty) {
      setState(() => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
    } else if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _verifyPin() async {
    try {
      final isar = await IsarService.getInstance();
      final settings = await isar.settingsLocals.get(1);
      final hash = _hashPin(_pin);
      if (settings != null && settings.pinHash == hash) {
        _unlock();
      } else {
        setState(() { _error = true; _errorMsg = S.t('pin_incorrect'); _pin = ''; });
        HapticFeedback.vibrate();
      }
    } catch (_) {
      setState(() { _error = true; _errorMsg = S.t('msg_error'); _pin = ''; });
    }
  }

  Future<void> _savePin(String pin) async {
    final isar = await IsarService.getInstance();
    final settings = (await isar.settingsLocals.get(1)) ?? SettingsLocal();
    settings.pinHash = _hashPin(pin);
    bool bioAvailable = false;
    try { bioAvailable = await _localAuth.canCheckBiometrics; } catch (_) {}
    if (bioAvailable) {
      try {
        bioAvailable = await _localAuth.authenticate(
          localizedReason: S.t('pin_setup_biometric'),
          options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
        );
      } catch (_) { bioAvailable = false; }
    }
    settings.biometricEnabled = bioAvailable;
    await isar.writeTxn(() async => await isar.settingsLocals.put(settings));
    _unlock();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _unlock() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.child),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              _setupMode
                  ? (_confirmPin.isEmpty ? S.t('pin_setup_title') : S.t('pin_confirm_title'))
                  : S.t('pin_enter_title'),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_error)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorMsg, style: const TextStyle(color: Colors.orange, fontSize: 13)),
              ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = _setupMode && _confirmPin.isNotEmpty
                    ? i < _confirmPin.length
                    : i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? Colors.white : Colors.white24,
                  ),
                );
              }),
            ),
            const SizedBox(height: 40),
            ..._buildNumpad(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNumpad() {
    final rows = <Widget>[];
    for (var r = 0; r < 3; r++) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (c) {
              final d = '${r * 3 + c + 1}';
              return _numpadBtn(d, () => _onDigit(d));
            }),
          ),
        ),
      );
    }
    rows.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72),
            _numpadBtn('0', () => _onDigit('0')),
            _numpadBtn('⌫', _onDelete, isDelete: true),
          ],
        ),
      ),
    );
    return rows;
  }

  Widget _numpadBtn(String label, VoidCallback onTap, {bool isDelete = false}) {
    return Container(
      width: 72, height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(36),
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: onTap,
          child: Center(
            child: Text(label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDelete ? 20 : 24,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ),
      ),
    );
  }
}
