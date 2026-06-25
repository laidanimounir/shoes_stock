import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local_db/isar_service.dart';
import '../local_db/collections/settings_local.dart';

class InactivityTimer extends StatefulWidget {
  final Widget child;

  const InactivityTimer({super.key, required this.child});

  @override
  State<InactivityTimer> createState() => _InactivityTimerState();
}

class _InactivityTimerState extends State<InactivityTimer> {
  Timer? _timer;
  int _timeoutMinutes = 15;

  @override
  void initState() {
    super.initState();
    _loadTimeout();
  }

  Future<void> _loadTimeout() async {
    try {
      final isar = await IsarService.getInstance();
      final settings = await isar.settingsLocals.get(1);
      if (settings != null) {
        _timeoutMinutes = settings.inactivityTimeoutMinutes;
      }
    } catch (e, s) { debugPrint('[InactivityTimer] loadSettings error: $e\n$s'); }
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    if (_timeoutMinutes <= 0) return;
    _timer = Timer(Duration(minutes: _timeoutMinutes), _onTimeout);
  }

  Future<void> _onTimeout() async {
    if (!mounted) return;
    await Supabase.instance.client.auth.signOut();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      child: GestureDetector(
        onTap: () => _resetTimer(),
        onDoubleTap: () => _resetTimer(),
        onLongPress: () => _resetTimer(),
        child: widget.child,
      ),
    );
  }
}
