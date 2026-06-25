import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/app_colors.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';
import '../../core/connectivity_service.dart';
import '../../core/sync_engine.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/sync_metadata.dart';
import '../../local_db/collections/sync_queue_item.dart';
import '../../local_db/collections/store_local.dart';
import '../../local_db/collections/user_profile_local.dart';
import '../../local_db/collections/customer_local.dart';
import '../../local_db/collections/supplier_local.dart';
import '../../local_db/collections/product_local.dart';
import '../../local_db/collections/product_variant_local.dart';
import '../../local_db/collections/inventory_local.dart';
import '../../local_db/collections/invoice_local.dart';
import '../../local_db/collections/payment_local.dart';
import '../../local_db/collections/transaction_local.dart';
import '../../local_db/collections/expense_local.dart';
import '../../services/backup_service.dart';
import '../../shared/widgets/confirm_dialog.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  bool _isOnline = true;
  DateTime? _lastSyncAt;
  int _pendingCount = 0;
  int _failedCount = 0;
  List<SyncQueueItem> _queueItems = [];
  Map<String, int> _collectionCounts = {};
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      _isOnline = ConnectivityService.instance.isOnline;

      final isar = await IsarService.getInstance();

      final meta = await isar.syncMetadatas.get(1);
      _lastSyncAt = meta?.lastSyncAt;

      _pendingCount = await isar.syncQueueItems
          .filter()
          .statusEqualTo('pending')
          .count();

      _failedCount = await isar.syncQueueItems
          .filter()
          .statusEqualTo('failed')
          .count();

      _queueItems = await isar.syncQueueItems
          .where()
          .sortByCreatedAtDesc()
          .limit(20)
          .findAll();

      _collectionCounts = {
        'Stores': await isar.storeLocals.where().count(),
        'Profils': await isar.userProfileLocals.where().count(),
        'Clients': await isar.customerLocals.where().count(),
        'Fournisseurs': await isar.supplierLocals.where().count(),
        'Produits': await isar.productLocals.where().count(),
        'Variantes': await isar.productVariantLocals.where().count(),
        'Inventaire': await isar.inventoryLocals.where().count(),
        'Factures': await isar.invoiceLocals.where().count(),
        'Paiments': await isar.paymentLocals.where().count(),
        'Transactions': await isar.transactionLocals.where().count(),
        'Dépenses': await isar.expenseLocals.where().count(),
        'File d\'attente': await isar.syncQueueItems.where().count(),
      };

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerSync() async {
    setState(() => _isSyncing = true);
    try {
      await SyncEngine.instance.syncPending();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synchronisation terminée'), backgroundColor: Colors.green),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildStatusCard(),
                        const SizedBox(height: 16),
                        _buildSyncCard(),
                        const SizedBox(height: 16),
                        _buildCollectionCard(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.gold, width: 1.2),
            ),
            child: const Icon(Icons.monitor_heart_rounded, color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Santé du système',
                  style: GoogleFonts.playfairDisplay(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Diagnostic & synchronisation',
                  style: GoogleFonts.raleway(
                      color: AppColors.gold, fontSize: 11, letterSpacing: 0.8)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.backup_rounded, color: AppColors.gold, size: 18),
            onPressed: () async {
              try {
                final path = await BackupService.instance.exportToJson();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sauvegarde créée: $path'), backgroundColor: Colors.green),
                  );
                }
                await BackupService.instance.shareBackup();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            tooltip: 'Exporter la base locale',
          ),
          IconButton(
            icon: const Icon(Icons.restore_rounded, color: Colors.greenAccent, size: 18),
            onPressed: () async {
              final result = await BackupService.instance.restoreFromJson();
              if (!mounted) return;
              if (result['success'] != true) {
                final error = result['error'] as String? ?? '';
                final msg = error == 'no_file_selected'
                    ? S.t('no_file_selected')
                    : error == 'invalid_backup_format'
                        ? S.t('invalid_backup_format')
                        : 'Erreur: $error';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg), backgroundColor: Colors.orange),
                );
                return;
              }
              final preview = result['preview'] as Map<String, dynamic>;
              final count = preview['record_count'] as int? ?? 0;
              final confirm = await ConfirmDialog.show(
                context: context,
                title: S.t('restore_backup'),
                message: '${S.t('restore_confirm')}\n\n${preview['exported_at']}\n$count enregistrements',
                confirmColor: Colors.orange,
              );
              if (confirm != true || !mounted) return;
              final applyResult = await BackupService.instance.applyRestore(result['data'] as Map<String, dynamic>);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(applyResult['success'] == true ? S.t('restore_success') : 'Erreur: ${applyResult['error']}'),
                    backgroundColor: applyResult['success'] == true ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            tooltip: S.t('restore_backup'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18),
            onPressed: _refresh,
            tooltip: 'Actualiser',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATUT SYSTÈME',
              style: GoogleFonts.raleway(
                  color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          _statusRow(
            Icons.wifi,
            'Connexion',
            _isOnline ? 'En ligne' : 'Hors ligne',
            _isOnline ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(height: 12),
          _statusRow(
            Icons.sync,
            'Mode',
            AppSession.isOfflineMode ? 'Hors ligne (forcé)' : 'En ligne',
            AppSession.isOfflineMode ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(height: 12),
          _statusRow(
            Icons.person,
            'Utilisateur',
            AppSession.currentUserId ?? 'Non connecté',
            AppColors.info,
          ),
          const SizedBox(height: 12),
          _statusRow(
            Icons.store,
            'Magasin',
            AppSession.currentStoreId ?? 'Aucun',
            AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildSyncCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SYNCHRONISATION',
                  style: GoogleFonts.raleway(
                      color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _triggerSync,
                  icon: _isSyncing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync_rounded, size: 14),
                  label: Text(_isSyncing ? 'En cours...' : 'Sync', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _statusRow(
            Icons.access_time,
            'Dernière sync',
            _lastSyncAt != null ? timeago.format(_lastSyncAt!, locale: 'fr') : 'Jamais',
            _lastSyncAt != null ? AppColors.info : AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          _statusRow(
            Icons.hourglass_empty,
            'En attente',
            '$_pendingCount opérations',
            _pendingCount > 0 ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(height: 12),
          _statusRow(
            Icons.error_outline,
            'Échouées',
            '$_failedCount opérations',
            _failedCount > 0 ? AppColors.danger : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BASE LOCALE (ISAR)',
              style: GoogleFonts.raleway(
                  color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          ..._collectionCounts.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _statusRow(
              Icons.storage,
              e.key,
              '${e.value} entrées',
              AppColors.teal,
            ),
          )),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: GoogleFonts.raleway(
                  color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Text(value,
            style: GoogleFonts.raleway(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
