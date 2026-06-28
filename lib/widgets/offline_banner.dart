import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_session.dart';
import '../core/connectivity_service.dart';
import '../core/sync_engine.dart';
import '../core/app_strings.dart';

class _T {
  _T._();
  static const statusPaidBg = Color(0xFF0D2B1A);
  static const statusUnpaidBg = Color(0xFF2B0D0D);
  static const statusPaidText = Color(0xFF4ADE80);
  static const statusUnpaidText = Color(0xFFF87171);
  static const textPrimary = Color(0xFFEEEEFF);
  static const accentGold = Color(0xFFF0A500);
}

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
              ? [_T.statusPaidBg, _T.statusPaidBg]
              : [_T.statusUnpaidBg, _T.statusUnpaidBg],
        ),
      ),
      child: _shouldShow
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOnline
                          ? _T.statusPaidText
                          : _T.statusUnpaidText,
                      boxShadow: [
                        BoxShadow(
                          color: (_isOnline
                                  ? _T.statusPaidText
                                  : _T.statusUnpaidText)
                              .withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isOnline
                        ? S.t('offline_connected')
                        : S.t('offline_mode'),
                    style: const TextStyle(
                      color: _T.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
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
                                color: _T.statusPaidText, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              S.t('offline_synced'),
                              style: const TextStyle(
                                color: _T.statusPaidText,
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
                            style: const TextStyle(
                              color: _T.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
                                          color: _T.accentGold,
                                          strokeWidth: 1.5,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.cloud_upload_outlined,
                                        color: _T.accentGold,
                                        size: 16),
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
