import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';

class _T {
  _T._();
  static const bgPage = Color(0xFF0A0A14);
  static const bgAppBar = Color(0xFF0F0F1C);
  static const bgCard = Color(0xFF13131F);
  static const bgTable = Color(0xFF0D0D1A);
  static const bgTableHeader = Color(0xFF1A1400);
  static const bgTableRowAlt = Color(0xFF111120);
  static const bgTableHover = Color(0xFF1E1E35);
  static const accentGold = Color(0xFFFFC107);
  static const accentBlue = Color(0xFF58A6FF);
  static const textPrimary = Color(0xFFEEEEFF);
  static const textSecondary = Color(0xFF8888AA);
  static const textMuted = Color(0xFF555570);
  static const borderColor = Color(0xFF1E1E35);
  static const statusPaidBg = Color(0xFF0D2B1A);
  static const statusPaidText = Color(0xFF4ADE80);
  static const statusRefundedBg = Color(0xFF2B1A0D);
  static const statusRefundedText = Color(0xFFFBBF24);
  static const statusUnpaidBg = Color(0xFF2B0D0D);
  static const statusUnpaidText = Color(0xFFF87171);
  static const statusPartialBg = Color(0xFF1A1A0D);
  static const statusPartialText = Color(0xFFFDE68A);
  static const shimmerColor = Color(0xFF252538);
}

class GestionStoresScreen extends StatefulWidget {
  const GestionStoresScreen({super.key});

  @override
  State<GestionStoresScreen> createState() => _GestionStoresScreenState();
}

class _GestionStoresScreenState extends State<GestionStoresScreen> {
  List<dynamic> _stores = [];
  bool _isLoading = true;

  String? _userRole;

  @override
  void initState() {
    super.initState();
    _initRoleAndFetch();
  }

  Future<void> _initRoleAndFetch() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('role')
            .eq('id', user.id)
            .single();
        _userRole = profile['role'];
      }
    } catch (e, s) {
      debugPrint('[GestionStores] initRole error: $e\n$s');
    }
    if (mounted) setState(() {});
    await _fetchStores();
  }

  Future<void> _fetchStores() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('stores')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _stores = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching stores: $e");
    }
  }

  // ── Add / Edit Dialog ────────────────────────────────────
  void _showAddEditDialog([Map<String, dynamic>? store]) {
    final isEdit = store != null;
    final nameCtrl = TextEditingController(text: store?['name'] ?? '');
    final maxDiscCtrl = TextEditingController(
        text: store?['max_discount_percent']?.toString() ?? '30');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isEdit ? Icons.edit_rounded : Icons.add_business_rounded,
                          color: _T.accentGold, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        isEdit ? S.t('store_edit') : S.t('store_add'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _T.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _themedField(
                    controller: nameCtrl,
                    label: S.t('store_name'),
                    icon: Icons.warehouse_rounded,
                    autofocus: true,
                    validator: (v) =>
                        v!.trim().isEmpty ? S.t('msg_required') : null,
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 14),
                    _themedField(
                      controller: maxDiscCtrl,
                      label: S.t('store_max_discount'),
                      icon: Icons.percent_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(S.t('action_cancel'),
                            style: const TextStyle(color: _T.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(ctx);
                          try {
                            final data = <String, dynamic>{
                              'name': nameCtrl.text.trim()
                            };
                            if (isEdit) {
                              final maxDisc = double.tryParse(maxDiscCtrl.text);
                              if (maxDisc != null) {
                                data['max_discount_percent'] = maxDisc;
                              }
                              await Supabase.instance.client
                                  .from('stores')
                                  .update(data)
                                  .eq('id', store['id']);
                            } else {
                              await Supabase.instance.client
                                  .from('stores')
                                  .insert(data);
                            }
                            _fetchStores();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(isEdit
                                    ? S.t('store_updated')
                                    : S.t('store_created')),
                                backgroundColor: _T.statusPaidBg,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ));
                            }
                          } on PostgrestException catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(e.code == '42501'
                                    ? S.t('msg_access_denied')
                                    : '${S.t('msg_error')}: ${e.message}'),
                                backgroundColor: _T.statusUnpaidBg,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('${S.t('msg_error')}: $e'),
                                backgroundColor: _T.statusUnpaidBg,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ));
                            }
                          }
                        },
                        icon: Icon(isEdit ? Icons.save_rounded : Icons.add_rounded,
                            size: 18, color: _T.bgPage),
                        label: Text(
                          isEdit ? S.t('action_save') : S.t('action_add'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: _T.bgPage),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _T.accentGold,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _themedField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool autofocus = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: _T.textPrimary, fontSize: 14),
      cursorColor: _T.accentGold,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _T.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: _T.textMuted, size: 18),
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _T.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _T.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _T.accentGold),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _T.statusUnpaidText),
        ),
      ),
    );
  }

  // ── Delete ───────────────────────────────────────────────
  Future<void> _deleteStore(Map<String, dynamic> store) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _T.statusUnpaidText),
            const SizedBox(width: 12),
            Text(S.t('action_confirm_delete'),
                style: const TextStyle(
                    color: _T.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Text(
          S.t('store_delete_msg').replaceAll('{name}', store['name']),
          style: const TextStyle(color: _T.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.t('action_cancel'),
                style: const TextStyle(color: _T.textSecondary)),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8, bottom: 4),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(S.t('action_delete')),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.from('stores').delete().eq('id', store['id']);
      _fetchStores();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.t('store_deleted')),
          backgroundColor: _T.statusPaidBg,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.code == '42501'
              ? S.t('msg_access_denied')
              : '${S.t('msg_error')}: ${e.message}'),
          backgroundColor: _T.statusUnpaidBg,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${S.t('store_delete_error')} $e"),
          backgroundColor: _T.statusUnpaidBg,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  Future<Map<String, int>> _getStoreStats(String storeId) async {
    try {
      final employeesRes = await Supabase.instance.client
          .from('user_profiles')
          .select('id')
          .eq('store_id', storeId)
          .eq('role', 'employee');

      final inventoryRes = await Supabase.instance.client
          .from('inventory')
          .select('quantity')
          .eq('store_id', storeId);

      int totalStock = 0;
      for (var inv in inventoryRes) {
        totalStock += (inv['quantity'] as int?) ?? 0;
      }

      return {
        'employees': employeesRes.length,
        'totalStock': totalStock,
      };
    } catch (e) {
      return {'employees': 0, 'totalStock': 0};
    }
  }

  // ═════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bgPage,
      appBar: AppBar(
        backgroundColor: _T.bgAppBar,
        elevation: 0,
        titleSpacing: 20,
        title: Text(
          S.t('store_title'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _T.textPrimary,
          ),
        ),
        actions: [
          if (_userRole == 'owner')
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: Icon(Icons.add_business_rounded, size: 18, color: _T.bgPage),
                label: Text(
                  S.t('store_add'),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _T.bgPage),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _T.accentGold,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _T.accentGold))
          : _stores.isEmpty
              ? _buildEmptyState()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: _stores.length,
                    itemBuilder: (context, index) {
                      final store = _stores[index];
                      return FutureBuilder<Map<String, int>>(
                        future: _getStoreStats(store['id']),
                        builder: (context, snapshot) {
                          final stats =
                              snapshot.data ?? {'employees': 0, 'totalStock': 0};
                          return _buildStoreCard(store, stats);
                        },
                      );
                    },
                  ),
                ),
    );
  }

  // ── Empty State ──────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warehouse_outlined, size: 48, color: _T.textMuted),
          const SizedBox(height: 14),
          Text(
            S.t('store_no_results_yet'),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: _T.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            S.t('store_add_first'),
            style: const TextStyle(fontSize: 13, color: _T.textMuted),
          ),
          if (_userRole == 'owner') ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: Icon(Icons.add_business_rounded, color: _T.bgPage),
              label: Text(
                S.t('store_add_btn'),
                style: const TextStyle(fontWeight: FontWeight.w700, color: _T.bgPage),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.accentGold,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Store Card ───────────────────────────────────────────
  Widget _buildStoreCard(Map<String, dynamic> store, Map<String, int> stats) {
    return Container(
      decoration: BoxDecoration(
        color: _T.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _T.bgTableHeader,
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(
                        left: BorderSide(color: _T.accentGold, width: 3)),
                  ),
                  child: const Icon(Icons.warehouse_rounded,
                      color: _T.accentGold, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    store['name'] as String? ?? '—',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _T.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_userRole == 'owner')
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: _T.textMuted, size: 20),
                    color: _T.bgTableHeader,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    onSelected: (val) {
                      if (val == 'edit') _showAddEditDialog(store);
                      if (val == 'delete') _deleteStore(store);
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          const Icon(Icons.edit_rounded,
                              color: _T.accentBlue, size: 18),
                          const SizedBox(width: 10),
                          Text(S.t('action_edit'),
                              style: const TextStyle(color: _T.textPrimary)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete_rounded,
                              color: _T.statusUnpaidText, size: 18),
                          const SizedBox(width: 10),
                          Text(S.t('action_delete'),
                              style: const TextStyle(color: _T.textPrimary)),
                        ]),
                      ),
                    ],
                  ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                _buildStatBadge(
                  Icons.people_rounded,
                  '${stats['employees']} ${S.t('store_employees')}',
                  _T.accentBlue,
                  const Color(0x1858A6FF),
                ),
                const SizedBox(width: 10),
                _buildStatBadge(
                  Icons.inventory_2_rounded,
                  '${stats['totalStock']} ${S.t('store_units')}',
                  _T.statusPaidText,
                  const Color(0x184ADE80),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}