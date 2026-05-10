import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../core/sync_engine.dart';

/// Monitors network connectivity and triggers sync when back online.
class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();

  /// Broadcasts true (online) / false (offline) on every change.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Starts listening. Call once at app boot.
  Future<void> initialize() async {
    // Check initial state
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);

    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);
      _controller.add(_isOnline);

      if (_isOnline && !wasOnline) {
        debugPrint('🌐 ConnectivityService: Back ONLINE → triggering sync');
        await SyncEngine.instance.syncPending();
      } else if (!_isOnline && wasOnline) {
        debugPrint('📴 ConnectivityService: Went OFFLINE');
      }
    });

    debugPrint('🔌 ConnectivityService initialized (online: $_isOnline)');
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
