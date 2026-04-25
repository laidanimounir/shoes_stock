import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_session.dart';
import '../../core/connectivity_service.dart';
import '../../core/sync_engine.dart';
import '../../core/app_strings.dart';

/// Persistent top banner shown when offline or when sync items are pending.
/// Embed at the top of your main Column in each layout.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late StreamSubscription<bool> _connectSub;
  bool _isOnline = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService.instance.isOnline;
    _connectSub =
        ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _connectSub.cancel();
    super.dispose();
  }

  bool get _shouldShow => AppSession.isOfflineMode || !_isOnline;

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    await SyncEngine.instance.syncPending();
    if (mounted) setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: _shouldShow ? 36 : 0,
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isOnline
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [const Color(0xFFB71C1C), const Color(0xFFC62828)],
        ),
      ),
      child: _shouldShow
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // ── Status indicator ──
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                      boxShadow: [
                        BoxShadow(
                          color: (_isOnline ? Colors.greenAccent : Colors.redAccent)
                              .withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isOnline ? S.t('offline_connected') : S.t('offline_mode'),
                    style: GoogleFonts.raleway(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // ── Pending count ──
                  StreamBuilder<int>(
                    stream: SyncEngine.instance.pendingCountStream,
                    initialData: AppSession.pendingSync,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count == 0) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.greenAccent, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              S.t('offline_synced'),
                              style: GoogleFonts.raleway(
                                color: Colors.greenAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$count ${S.t('offline_pending')}',
                            style: GoogleFonts.raleway(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Show sync button only when online + pending > 0
                          if (_isOnline) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: _isSyncing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 1.5,
                                        ),
                                      )
                                    : const Icon(Icons.cloud_upload_outlined,
                                        color: Colors.white, size: 16),
                                onPressed: _isSyncing ? null : _triggerSync,
                                tooltip: S.t('offline_sync_now'),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
