import 'dart:async';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/user_profile_local.dart';
import '../../widgets/offline_banner.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN SYSTEM (Dark Gold/Blue — aligned with SalesHistoryScreen reference)
// ═══════════════════════════════════════════════════════════════════════════════
class _T {
  static const white       = Color(0xFFEEEEFF); // textPrimary
  static const bg          = Color(0xFF0A0A14); // bgPage
  static const surface     = Color(0xFF13131F); // bgCard
  static const border      = Color(0xFF1E1E35); // borderColor
  static const ink         = Color(0xFFEEEEFF); // textPrimary
  static const inkMid      = Color(0xFF8888AA); // textSecondary
  static const inkLight    = Color(0xFF555570); // textMuted
  static const brand       = Color(0xFFFFC107); // accentGold (primary actions)
  static const brandBg     = Color(0xFF1A1400); // gold-tinted dark bg
  static const active      = Color(0xFF4ADE80); // statusPaidText
  static const activeBg    = Color(0xFF0D2B1A); // statusPaidBg
  static const suspended   = Color(0xFFFBBF24); // statusRefundedText
  static const suspendedBg = Color(0xFF2B1A0D); // statusRefundedBg
  static const archived    = Color(0xFF8888AA); // textSecondary
  static const archivedBg  = Color(0xFF111120); // bgTableRowAlt
  static const danger      = Color(0xFFF87171); // statusUnpaidText
  static const sidebarBg   = Color(0xFF0F0F1C); // bgAppBar
  static const sidebarHov  = Color(0xFF1E1E35); // bgTableHover
  static const sidebarText = Color(0xFF8888AA); // textSecondary
  static const sidebarHead = Color(0xFFEEEEFF); // textPrimary
  static const accentBlue  = Color(0xFF58A6FF); // secondary accent
}

final _avatarPalettes = [
  Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFF8B5CF6), Color(0xFFF59E0B),
  Color(0xFFEF4444), Color(0xFF06B6D4), Color(0xFF84CC16), Color(0xFFF97316),
];

Color _pal(String name) {
  final i = name.isEmpty ? 0 : name.codeUnitAt(0) % _avatarPalettes.length;
  return _avatarPalettes[i];
}

InputDecoration _fieldDec(String label, {bool enabled = true, String? hint, Widget? suffix}) =>
    InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: const TextStyle(fontSize: 13, color: _T.inkLight),
      hintStyle: const TextStyle(fontSize: 13, color: _T.inkLight),
      filled: true, fillColor: enabled ? _T.surface : _T.bg, isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _T.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _T.border)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _T.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _T.brand, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _T.danger)),
    );

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class GestionEmployesScreen extends StatefulWidget {
  const GestionEmployesScreen({super.key});
  @override
  State<GestionEmployesScreen> createState() => _GestionEmployesScreenState();
}

class _GestionEmployesScreenState extends State<GestionEmployesScreen>
    with SingleTickerProviderStateMixin {

  bool _blocked = false;
  late TabController _tab;
  final _search = TextEditingController();
  Timer? _debounce;

  List<dynamic> _employees = [];
  bool _loading = false, _hasMore = true;
  int _page = 0;
  static const _pageSize = 20;
  final Map<int, ScrollController> _sc = {};

  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _employeePerformance;
  bool _creating = false, _editing = false;
  List<dynamic> _stores = [];

  final _createKey = GlobalKey<FormState>();
  final _fn = TextEditingController(), _ln = TextEditingController(),
        _em = TextEditingController(), _ph = TextEditingController(),
        _ad = TextEditingController(), _jt = TextEditingController(),
        _pw = TextEditingController();
  String? _storeCreate; DateTime? _hiredCreate;
  bool _hidePw = true, _saving = false;

  final _editKey = GlobalKey<FormState>();
  final _efn = TextEditingController(), _eln = TextEditingController(),
        _eph = TextEditingController(), _ead = TextEditingController(),
        _ejt = TextEditingController(), _epw = TextEditingController(),
        _ecommission = TextEditingController();
  String? _storeEdit; DateTime? _hiredEdit;
  bool _hideEditPw = true, _updating = false;

  bool get _online => !AppSession.isOfflineMode;

  @override
  void initState() {
    super.initState();
    if (AppSession.isEmployee) {
      _blocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { _snack(S.t('emp_no_permission'), _T.danger); Navigator.of(context).pop(); }
      });
      return;
    }
    _tab = TabController(length: 3, vsync: this)..addListener(_onTabChange);
    _loadStores(); _loadEmployees();
  }

  void _onTabChange() {
    if (_tab.indexIsChanging) return;
    setState(() { _selected = null; _creating = false; _editing = false; _page = 0; _employees = []; _hasMore = true; });
    _loadEmployees();
  }

  ScrollController _scFor(int t) {
    _sc.putIfAbsent(t, () {
      final c = ScrollController();
      c.addListener(() { if (c.position.pixels >= c.position.maxScrollExtent - 200 && _hasMore && !_loading) _loadEmployees(); });
      return c;
    });
    return _sc[t]!;
  }

  Future<void> _loadStores() async {
    try {
      final r = await Supabase.instance.client.from('stores').select('id, name').order('name');
      if (mounted) setState(() => _stores = r);
    } catch (e) { debugPrint('$e'); }
  }

  Future<void> _loadEmployees({String? query}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (AppSession.isOfflineMode) { await _loadLocal(query); return; }
      final from = _page * _pageSize;
      var req = Supabase.instance.client.from('user_profiles').select('*, stores(name)').eq('role', 'employee');
      final q = (query ?? _search.text).trim();
      if (q.isNotEmpty) { final p = '%$q%'; req = req.or('first_name.ilike.$p,last_name.ilike.$p,full_name.ilike.$p'); }
      switch (_tab.index) {
        case 0: req = req.eq('is_active', true).eq('is_permanently_deleted', false); break;
        case 1: req = req.eq('is_active', false).eq('is_permanently_deleted', false); break;
        default: req = req.eq('is_permanently_deleted', true);
      }
      final res = await req.order('created_at', ascending: false).range(from, from + _pageSize - 1);
      if (mounted) setState(() { _employees.addAll(res); _hasMore = res.length >= _pageSize; _page++; _loading = false; });
    } catch (e) { if (mounted) { setState(() => _loading = false); _snack(S.t('msg_load_error'), _T.danger); } }
  }

  Future<void> _loadLocal(String? query) async {
    try {
      final isar = await IsarService.getInstance();
      final q = (query ?? _search.text).trim().toLowerCase();
      final all = await isar.userProfileLocals.where().findAll();
      var list = all.where((e) { if (_tab.index == 0) return e.isActive && !e.isPermanentlyDeleted; if (_tab.index == 1) return !e.isActive && !e.isPermanentlyDeleted; return e.isPermanentlyDeleted; });
      if (q.isNotEmpty) list = list.where((e) => (e.firstName?.toLowerCase().contains(q) ?? false) || (e.lastName?.toLowerCase().contains(q) ?? false) || e.fullName.toLowerCase().contains(q));
      if (mounted) setState(() { _employees = list.map(_lm).toList(); _hasMore = false; _loading = false; });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  Map<String, dynamic> _lm(UserProfileLocal e) => { 'id': e.supabaseId, 'full_name': e.fullName, 'first_name': e.firstName, 'last_name': e.lastName, 'role': e.role, 'store_id': e.storeId, 'phone': e.phone, 'address': e.address, 'job_title': e.jobTitle, 'hired_at': e.hiredAt?.toIso8601String(), 'is_active': e.isActive, 'is_permanently_deleted': e.isPermanentlyDeleted, 'created_at': e.createdAt?.toIso8601String(), 'stores': e.storeId != null ? {'name': null} : null, 'commission_rate': e.commissionRate, 'login_at': e.loginAt?.toIso8601String() };

  void _onSearch(String v) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 380), () { if (mounted) { setState(() { _page = 0; _employees = []; _hasMore = true; }); _loadEmployees(query: v); } }); }

  Future<void> _create() async {
    if (!_createKey.currentState!.validate()) return;
    if (_storeCreate == null) { _snack(S.t('pos_select_store'), _T.danger); return; }
    setState(() => _saving = true);
    try {
      final res = await Supabase.instance.client.functions.invoke('create_employee', body: { 'email': _em.text.trim(), 'password': _pw.text, 'first_name': _fn.text.trim(), 'last_name': _ln.text.trim(), 'phone': _ph.text.trim().isEmpty ? null : _ph.text.trim(), 'address': _ad.text.trim().isEmpty ? null : _ad.text.trim(), 'job_title': _jt.text.trim().isEmpty ? null : _jt.text.trim(), 'store_id': _storeCreate, 'hired_at': _hiredCreate?.toIso8601String().split('T')[0] });
      if (res.status == 200 && res.data['success'] == true) { _snack(S.t('emp_created'), _T.active); _clearCreate(); setState(() { _creating = false; _page = 0; _employees = []; _hasMore = true; }); _loadEmployees(); }
      else { final err = res.data['error']?.toString().toLowerCase() ?? ''; throw Exception(err.contains('already') ? 'already_exists' : err); }
    } catch (e) { _snack(e.toString().contains('already_exists') ? S.t('auth_email_exists') : '${S.t('msg_error')}: $e', _T.danger); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _update() async {
    if (!_editKey.currentState!.validate()) return;
    if (_storeEdit == null) { _snack(S.t('pos_select_store'), _T.danger); return; }
    setState(() => _updating = true);
    try {
      final body = <String, dynamic>{ 'employee_id': _selected!['id'], 'first_name': _efn.text.trim(), 'last_name': _eln.text.trim(), 'phone': _eph.text.trim().isEmpty ? null : _eph.text.trim(), 'address': _ead.text.trim().isEmpty ? null : _ead.text.trim(), 'job_title': _ejt.text.trim().isEmpty ? null : _ejt.text.trim(), 'store_id': _storeEdit, 'hired_at': _hiredEdit?.toIso8601String().split('T')[0], 'commission_rate': double.tryParse(_ecommission.text.trim()) ?? 0 };
      if (_epw.text.trim().isNotEmpty) body['new_password'] = _epw.text.trim();
      final res = await Supabase.instance.client.functions.invoke('update_employee', body: body);
      if (res.status == 200 && res.data['success'] == true) { _snack(S.t('emp_updated'), _T.active); setState(() { _editing = false; _selected = res.data['profile'] as Map<String, dynamic>?; _page = 0; _employees = []; _hasMore = true; }); _loadEmployees(); }
      else { throw Exception(res.data['error'] ?? 'Erreur'); }
    } catch (e) { _snack('${S.t('msg_error')}: $e', _T.danger); }
    finally { if (mounted) setState(() => _updating = false); }
  }

  Future<void> _toggle(String id, String action) async {
    if (action != 'reactivate') {
      final ok = await showDialog<bool>(context: context, barrierColor: Colors.black54, builder: (_) => _ConfirmDialog(title: action == 'suspend' ? S.t('emp_confirm_suspend') : S.t('emp_confirm_archive'), body: action == 'suspend' ? S.t('emp_confirm_suspend_msg') : S.t('emp_confirm_archive_msg'), confirmColor: action == 'suspend' ? _T.suspended : _T.danger, confirmLabel: S.t('action_confirm'), cancelLabel: S.t('action_cancel')));
      if (ok != true) return;
    }
    try {
      final res = await Supabase.instance.client.functions.invoke('toggle_employee_status', body: {'employee_id': id, 'action': action});
      if (res.status == 200 && res.data['success'] == true) { _snack(action == 'suspend' ? S.t('emp_suspended') : action == 'reactivate' ? S.t('emp_reactivated') : S.t('emp_archived'), _T.active); setState(() { _selected = res.data['profile'] as Map<String, dynamic>?; _page = 0; _employees = []; _hasMore = true; }); _loadEmployees(); }
      else { throw Exception(res.data['error']); }
    } catch (e) { _snack('${S.t('msg_error')}: $e', _T.danger); }
  }

  DateTime? _dt(dynamic v) { if (v == null) return null; if (v is DateTime) return v; if (v is String) return DateTime.tryParse(v); return null; }

  Future<void> _fetchPerformance(String userId) async {
    try {
      final res = await Supabase.instance.client.rpc('get_employee_performance', params: {
        'p_store_id': _selected?['store_id'],
        'p_period': 'month',
      });
      final list = List<Map<String, dynamic>>.from(res ?? []);
      final myPerf = list.cast<Map<String, dynamic>?>().firstWhere(
        (p) => p?['user_id'] == userId,
        orElse: () => null,
      );
      if (mounted) setState(() => _employeePerformance = myPerf);
    } catch (e) {
      if (mounted) setState(() => _employeePerformance = null);
    }
  }

  void _pick(Map<String, dynamic> e) {
    setState(() { _selected = e; _creating = false; _editing = false; _employeePerformance = null; });
    _fetchPerformance(e['id']);
  }
  void _beginCreate() { _clearCreate(); setState(() { _creating = true; _editing = false; _selected = null; }); }
  void _beginEdit(Map<String, dynamic> e) { _efn.text = e['first_name'] as String? ?? ''; _eln.text = e['last_name'] as String? ?? ''; _eph.text = e['phone'] as String? ?? ''; _ead.text = e['address'] as String? ?? ''; _ejt.text = e['job_title'] as String? ?? ''; _epw.clear(); _storeEdit = e['store_id'] as String?; _hiredEdit = _dt(e['hired_at']); _ecommission.text = (e['commission_rate'] as num?)?.toString() ?? '0'; setState(() { _editing = true; _creating = false; }); }
  void _cancel() => setState(() { _creating = false; _editing = false; _clearCreate(); });
  void _clearCreate() { for (final c in [_fn,_ln,_em,_ph,_ad,_jt,_pw]) c.clear(); _storeCreate = _stores.isNotEmpty ? _stores.first['id'] as String? : null; _hiredCreate = DateTime.now(); _createKey.currentState?.reset(); }
  void _snack(String msg, Color bg) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: _T.bg)), backgroundColor: bg, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), margin: const EdgeInsets.fromLTRB(16, 0, 16, 20))); }

  @override
  void dispose() { _tab.dispose(); _search.dispose(); _debounce?.cancel(); for (final c in _sc.values) c.dispose(); for (final c in [_fn,_ln,_em,_ph,_ad,_jt,_pw,_efn,_eln,_eph,_ead,_ejt,_epw]) c.dispose(); super.dispose(); }

  // ─── BUILD ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_blocked) return const SizedBox.shrink();
    return Column(children: [
      const OfflineBanner(),
      Expanded(child: Row(children: [
        _buildSidebar(),
        Expanded(child: Container(color: _T.bg, child: _buildContent())),
      ])),
    ]);
  }

  // ── Sidebar ──────────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 264,
      color: _T.sidebarBg,
      child: Column(children: [
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _T.brand.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.people_rounded, color: _T.brand, size: 15)),
            const SizedBox(width: 9),
            Text(S.t('emp_role_label'), style: const TextStyle(color: _T.sidebarHead, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: TextField(
            controller: _search, onChanged: _onSearch,
            style: const TextStyle(fontSize: 13, color: _T.sidebarHead),
            decoration: InputDecoration(
              hintText: S.t('emp_search_hint'),
              hintStyle: const TextStyle(fontSize: 13, color: _T.inkLight),
              prefixIcon: const Icon(Icons.search_rounded, size: 15, color: _T.inkLight),
              filled: true, fillColor: _T.sidebarHov, isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _T.brand, width: 1.5)),
            ),
          ),
        ),
        // Tabs
        TabBar(
          controller: _tab,
          labelColor: _T.white, unselectedLabelColor: _T.sidebarText,
          labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
          indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: _T.brand, width: 2.5), insets: EdgeInsets.zero),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: _T.sidebarHov,
          tabs: [Tab(text: S.t('emp_active_tab')), Tab(text: S.t('emp_suspended_tab')), Tab(text: S.t('emp_archived_tab'))],
        ),
        // List
        Expanded(child: _buildList()),
        // Add button
        Container(color: _T.sidebarBg, padding: const EdgeInsets.all(10),
          child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _online ? _beginCreate : null,
            icon: const Icon(Icons.add_rounded, size: 15),
            label: Text(S.t('emp_add'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: _T.brand, foregroundColor: _T.bg, disabledBackgroundColor: _T.sidebarHov, disabledForegroundColor: _T.inkLight, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          )),
        ),
      ]),
    );
  }

  Widget _buildList() {
    if (_loading && _employees.isEmpty) return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _T.brand)));
    if (_employees.isEmpty) return Center(child: Text(S.t('emp_no_results'), style: const TextStyle(fontSize: 12.5, color: _T.inkLight)));
    return ListView.builder(
      controller: _scFor(_tab.index),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _employees.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _employees.length) return const Padding(padding: EdgeInsets.all(10), child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _T.brand))));
        return _EmpTile(emp: _employees[i], selected: _selected, onTap: _pick);
      },
    );
  }

  // ── Content ──────────────────────────────────────────────────────────────────
  Widget _buildContent() {
    if (_creating) return _buildCreateForm();
    if (_editing && _selected != null) return _buildEditForm();
    if (_selected != null) return _buildDetail();
    return _buildEmpty();
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 68, height: 68, decoration: BoxDecoration(color: _T.brandBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _T.border)),
        child: const Icon(Icons.people_alt_outlined, size: 32, color: _T.brand)),
    const SizedBox(height: 14),
    Text(S.t('emp_select_hint'), style: const TextStyle(fontSize: 14, color: _T.inkMid, fontWeight: FontWeight.w500)),
  ]));

  // ── Detail ───────────────────────────────────────────────────────────────────
  Widget _buildDetail() {
    final e = _selected!;
    final fn = e['first_name'] as String? ?? '';
    final ln = e['last_name']  as String? ?? '';
    final name = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : (e['full_name'] as String? ?? '?');
    final letter   = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final palColor = _pal(letter);
    final jobTitle = e['job_title'] as String? ?? '';
    final email    = e['email']     as String? ?? '';
    final phone    = e['phone']     as String? ?? '';
    final address  = e['address']   as String? ?? '';
    final store    = e['stores']?['name'] as String? ?? '';
    final hired    = (e['hired_at'] as String?)?.split('T')[0] ?? '';
    final loginAt  = (e['login_at'] as String?)?.split('T')[0] ?? '';
    final isActive = (e['is_active'] as bool?) ?? true;
    final isDeleted= (e['is_permanently_deleted'] as bool?) ?? false;
    final na       = S.t('misc_not_available');

    final statusLabel = isDeleted ? S.t('emp_status_archived') : (!isActive ? S.t('emp_status_suspended') : S.t('emp_status_active'));
    final statusColor = isDeleted ? _T.archived : (!isActive ? _T.suspended : _T.active);
    final statusBg    = isDeleted ? _T.archivedBg : (!isActive ? _T.suspendedBg : _T.activeBg);

    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header card
      Container(color: _T.surface, padding: const EdgeInsets.fromLTRB(32, 28, 32, 24), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(color: palColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center,
            child: Text(letter, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: palColor))),
        const SizedBox(width: 18),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _T.ink, letterSpacing: -0.3)),
          if (jobTitle.isNotEmpty) ...[const SizedBox(height: 3), Text(jobTitle, style: const TextStyle(fontSize: 13, color: _T.inkMid))],
          const SizedBox(height: 9),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)), const SizedBox(width: 5), Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w700))])),
        ])),
        if (!isDeleted && _online) Row(children: [
          _buildActionBtn(S.t('action_edit'), Icons.edit_outlined, _T.brand, () => _beginEdit(e)),
          const SizedBox(width: 8),
          if (isActive) _buildActionBtn(S.t('emp_suspend_btn'), Icons.pause_circle_outline, _T.suspended, () => _toggle(e['id'], 'suspend')),
          if (!isActive) ...[
            _buildActionBtn(S.t('emp_reactivate_btn'), Icons.play_circle_outline, _T.active, () => _toggle(e['id'], 'reactivate')),
            const SizedBox(width: 8),
            _buildActionBtn(S.t('emp_archive_btn'), Icons.archive_outlined, _T.danger, () => _toggle(e['id'], 'permanent_delete')),
          ],
        ]),
      ])),

      // Hired strip
      if (hired.isNotEmpty) Container(color: _T.brandBg, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 9), child: Row(children: [const Icon(Icons.calendar_today_outlined, size: 13, color: _T.brand), const SizedBox(width: 7), Text('${S.t('emp_since_date')} $hired', style: const TextStyle(fontSize: 12.5, color: _T.brand, fontWeight: FontWeight.w600))])),

      // Info grid
      Padding(padding: const EdgeInsets.all(24), child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _InfoCard(title: S.t('emp_email'), rows: [
          if (email.isNotEmpty) _InfoRow(icon: Icons.email_outlined, label: 'E-mail', value: email),
          _InfoRow(icon: Icons.phone_outlined, label: S.t('emp_phone'), value: phone.isEmpty ? na : phone),
          _InfoRow(icon: Icons.location_on_outlined, label: S.t('emp_address'), value: address.isEmpty ? na : address),
        ])),
        const SizedBox(width: 16),
        Expanded(child: _InfoCard(title: S.t('label_role'), rows: [
          _InfoRow(icon: Icons.store_outlined, label: S.t('emp_assign_store'), value: store.isEmpty ? na : store),
          _InfoRow(icon: Icons.badge_outlined, label: S.t('label_role'), value: S.t('emp_role_label')),
          if (hired.isNotEmpty) _InfoRow(icon: Icons.work_history_outlined, label: S.t('emp_hired_at'), value: hired),
          if (loginAt.isNotEmpty) _InfoRow(icon: Icons.login_rounded, label: 'Dernière connexion', value: loginAt),
        ])),
      ]))),
      _buildCommissionCard(e),
      if (_employeePerformance != null) ...[
        const SizedBox(height: 16),
        _buildPerformanceCard(),
      ],
    ]));
  }

  Widget _buildCommissionCard(Map<String, dynamic> e) {
    final rate = (e['commission_rate'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monetization_on_rounded, size: 16, color: _T.brand),
                const SizedBox(width: 8),
                const Text('COMMISSION',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _T.inkLight, letterSpacing: 1.0)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _perfMetric('Taux de commission', '$rate%', _T.brand),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final p = _employeePerformance!;
    final sales = (p['total_sales'] as num?)?.toDouble() ?? 0;
    final refunds = (p['total_refunds'] as num?)?.toDouble() ?? 0;
    final discount = (p['total_discount_given'] as num?)?.toDouble() ?? 0;
    final count = (p['transactions_count'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded, size: 16, color: _T.brand),
                const SizedBox(width: 8),
                const Text('PERFORMANCE (30 JOURS)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _T.inkLight, letterSpacing: 1.0)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _perfMetric('Ventes', '${sales.toStringAsFixed(0)} ${S.t('misc_currency')}', _T.active),
                const SizedBox(width: 24),
                _perfMetric('Transactions', '$count', _T.brand),
                const SizedBox(width: 24),
                _perfMetric('Remboursements', '${refunds.toStringAsFixed(0)} ${S.t('misc_currency')}', _T.danger),
                const SizedBox(width: 24),
                _perfMetric('Remises', '${discount.toStringAsFixed(0)} ${S.t('misc_currency')}', _T.suspended),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _perfMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _T.inkLight, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback onTap) =>
      OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 14), label: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withValues(alpha: 0.35)), backgroundColor: color.withValues(alpha: 0.08), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));

  // ── Forms ────────────────────────────────────────────────────────────────────
  Widget _buildCreateForm() => _FormShell(
    title: S.t('emp_add'), subtitle: '', formKey: _createKey, saving: _saving,
    saveLabel: S.t('emp_add_btn'), onSave: _create, onCancel: _cancel,
    sections: [
      _FCard(title: S.t('emp_first_name'), children: [
        Row(children: [Expanded(child: _Fld(ctl: _fn, label: S.t('emp_first_name'), required: true)), const SizedBox(width: 12), Expanded(child: _Fld(ctl: _ln, label: S.t('emp_last_name'), required: true))]),
        const SizedBox(height: 12),
        _Fld(ctl: _em, label: S.t('emp_email'), required: true, type: TextInputType.emailAddress, validator: (v) => v!.isEmpty || !v.contains('@') ? S.t('auth_error_email') : null),
      ]),
      const SizedBox(height: 14),
      _FCard(title: S.t('emp_phone'), children: [
        _Fld(ctl: _ph, label: S.t('emp_phone'), type: TextInputType.phone), const SizedBox(height: 12),
        _Fld(ctl: _ad, label: S.t('emp_address')), const SizedBox(height: 12),
        _Fld(ctl: _jt, label: S.t('emp_job_title')),
      ]),
      const SizedBox(height: 14),
      _FCard(title: S.t('emp_assign_store'), children: [
        _StoreDD(stores: _stores, value: _storeCreate, onChanged: (v) => setState(() => _storeCreate = v)), const SizedBox(height: 12),
        _DateFld(label: S.t('emp_hired_at'), value: _hiredCreate, required: true, onPicked: (d) => setState(() => _hiredCreate = d), ctx: context), const SizedBox(height: 12),
        _PwFld(ctl: _pw, label: S.t('emp_password'), hide: _hidePw, onToggle: () => setState(() => _hidePw = !_hidePw), required: true),
      ]),
    ],
  );

  Widget _buildEditForm() => _FormShell(
    title: S.t('emp_edit'), subtitle: _selected!['full_name'] as String? ?? '', formKey: _editKey, saving: _updating,
    saveLabel: S.t('emp_edit_btn'), onSave: _update, onCancel: _cancel,
    sections: [
      _FCard(title: S.t('emp_first_name'), children: [
        Row(children: [Expanded(child: _Fld(ctl: _efn, label: S.t('emp_first_name'), required: true)), const SizedBox(width: 12), Expanded(child: _Fld(ctl: _eln, label: S.t('emp_last_name'), required: true))]),
        const SizedBox(height: 12),
        _Fld(ctl: TextEditingController(text: _selected!['email'] as String? ?? ''), label: S.t('emp_email'), enabled: false),
      ]),
      const SizedBox(height: 14),
      _FCard(title: S.t('emp_phone'), children: [
        _Fld(ctl: _eph, label: S.t('emp_phone'), type: TextInputType.phone), const SizedBox(height: 12),
        _Fld(ctl: _ead, label: S.t('emp_address')), const SizedBox(height: 12),
        _Fld(ctl: _ejt, label: S.t('emp_job_title')),
      ]),
      const SizedBox(height: 14),
      _FCard(title: 'COMMISSION', children: [
        _Fld(ctl: _ecommission, label: 'Taux commission (%)', type: TextInputType.number),
      ]),
      const SizedBox(height: 14),
      _FCard(title: S.t('emp_assign_store'), children: [
        _StoreDD(stores: _stores, value: _storeEdit, onChanged: (v) => setState(() => _storeEdit = v)), const SizedBox(height: 12),
        _DateFld(label: S.t('emp_hired_at'), value: _hiredEdit, required: true, onPicked: (d) => setState(() => _hiredEdit = d), ctx: context), const SizedBox(height: 12),
        _PwFld(ctl: _epw, label: S.t('emp_password'), hide: _hideEditPw, onToggle: () => setState(() => _hideEditPw = !_hideEditPw), required: false, hint: S.t('emp_password_optional')),
      ]),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXTRACTED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _EmpTile extends StatefulWidget {
  final Map<String, dynamic> emp;
  final Map<String, dynamic>? selected;
  final void Function(Map<String, dynamic>) onTap;
  const _EmpTile({required this.emp, required this.selected, required this.onTap});
  @override State<_EmpTile> createState() => _EmpTileState();
}

class _EmpTileState extends State<_EmpTile> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final e = widget.emp;
    final isSel = widget.selected?['id'] == e['id'];
    final fn = e['first_name'] as String? ?? '';
    final ln = e['last_name']  as String? ?? '';
    final name = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : (e['full_name'] as String? ?? '?');
    final letter   = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final palColor = _pal(letter);
    final isActive = (e['is_active'] as bool?) ?? true;
    final isDeleted= (e['is_permanently_deleted'] as bool?) ?? false;
    final store    = e['stores']?['name'] as String?;
    final dot      = isDeleted ? _T.archived : (!isActive ? _T.suspended : _T.active);

    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onTap(e),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? _T.brand : (_hov ? _T.sidebarHov : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(color: isSel ? _T.bg.withValues(alpha: 0.2) : palColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(7)),
              alignment: Alignment.center,
              child: Text(letter, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isSel ? _T.bg : palColor)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSel ? _T.bg : _T.sidebarHead), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Container(width: 5, height: 5, decoration: BoxDecoration(color: isSel ? _T.bg.withValues(alpha: 0.6) : dot, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Expanded(child: Text(store ?? (isDeleted ? S.t('emp_status_archived') : S.t('misc_no_store')),
                    style: TextStyle(fontSize: 11, color: isSel ? _T.bg.withValues(alpha: 0.7) : _T.sidebarText), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title; final List<Widget> rows;
  const _InfoCard({required this.title, required this.rows});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: _T.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _T.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _T.inkLight, letterSpacing: 1.0)),
      const SizedBox(height: 14),
      ...rows,
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 14, color: _T.inkLight), const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10.5, color: _T.inkLight, height: 1)),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontSize: 13.5, color: _T.ink, fontWeight: FontWeight.w500, height: 1.3)),
    ])),
  ]));
}

class _FormShell extends StatelessWidget {
  final String title, subtitle, saveLabel;
  final GlobalKey<FormState> formKey;
  final bool saving;
  final VoidCallback onSave, onCancel;
  final List<Widget> sections;
  const _FormShell({required this.title, required this.subtitle, required this.formKey, required this.saving, required this.saveLabel, required this.onSave, required this.onCancel, required this.sections});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(color: _T.surface, padding: const EdgeInsets.fromLTRB(32, 22, 32, 18), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _T.ink, letterSpacing: -0.3)),
        if (subtitle.isNotEmpty) ...[const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 13, color: _T.inkMid))],
      ])),
      Row(children: [
        ElevatedButton(onPressed: saving ? null : onSave,
            style: ElevatedButton.styleFrom(backgroundColor: _T.brand, foregroundColor: _T.bg, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _T.bg, strokeWidth: 2)) : Text(saveLabel)),
        const SizedBox(width: 8),
        TextButton(onPressed: onCancel, style: TextButton.styleFrom(foregroundColor: _T.inkMid, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)), child: Text(S.t('action_cancel'), style: const TextStyle(fontSize: 13.5))),
      ]),
    ])),
    Padding(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 580), child: Form(key: formKey, child: Column(children: sections)))),
  ]));
}

class _FCard extends StatelessWidget {
  final String title; final List<Widget> children;
  const _FCard({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _T.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _T.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _T.inkLight, letterSpacing: 1.0)),
        const SizedBox(height: 12), ...children,
      ]));
}

class _Fld extends StatelessWidget {
  final TextEditingController ctl; final String label; final bool required, enabled; final TextInputType? type; final String? Function(String?)? validator;
  const _Fld({required this.ctl, required this.label, this.required = false, this.enabled = true, this.type, this.validator});
  @override
  Widget build(BuildContext context) => TextFormField(controller: ctl, enabled: enabled, keyboardType: type, style: const TextStyle(fontSize: 13.5, color: _T.ink), decoration: _fieldDec('$label${required ? ' *' : ''}', enabled: enabled), validator: validator ?? (required ? (v) => v!.isEmpty ? S.t('msg_required') : null : null));
}

class _StoreDD extends StatelessWidget {
  final List<dynamic> stores; final String? value; final void Function(String?) onChanged;
  const _StoreDD({required this.stores, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) return const SizedBox(height: 44, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _T.brand))));
    return DropdownButtonFormField<String>(value: value ?? (stores.isNotEmpty ? stores.first['id'] as String? : null), isExpanded: true, dropdownColor: _T.surface, style: const TextStyle(fontSize: 13.5, color: _T.ink), decoration: _fieldDec('${S.t('emp_assign_store')} *'), items: stores.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s['id'] as String?, child: Text(s['name'] as String? ?? ''))).toList(), onChanged: onChanged, validator: (v) => v == null ? S.t('msg_required') : null);
  }
}

class _DateFld extends StatelessWidget {
  final String label; final DateTime? value; final bool required; final void Function(DateTime) onPicked; final BuildContext ctx;
  const _DateFld({required this.label, required this.value, required this.required, required this.onPicked, required this.ctx});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async { final d = await showDatePicker(context: ctx, initialDate: value ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now(), builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.dark(primary: _T.brand, surface: _T.surface, onSurface: _T.ink)), child: child!)); if (d != null) onPicked(d); },
    borderRadius: BorderRadius.circular(8),
    child: InputDecorator(decoration: _fieldDec('$label${required ? ' *' : ''}', suffix: const Icon(Icons.calendar_today_outlined, size: 15, color: _T.inkLight)),
        child: Text(value != null ? '${value!.day.toString().padLeft(2,'0')}/${value!.month.toString().padLeft(2,'0')}/${value!.year}' : S.t('misc_not_available'), style: TextStyle(fontSize: 13.5, color: value != null ? _T.ink : _T.inkLight))),
  );
}

class _PwFld extends StatelessWidget {
  final TextEditingController ctl; final String label; final bool hide, required; final String? hint; final VoidCallback onToggle;
  const _PwFld({required this.ctl, required this.label, required this.hide, required this.onToggle, required this.required, this.hint});
  @override
  Widget build(BuildContext context) => TextFormField(controller: ctl, obscureText: hide, style: const TextStyle(fontSize: 13.5, color: _T.ink),
      decoration: _fieldDec(label, hint: hint, suffix: IconButton(icon: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16, color: _T.inkLight), onPressed: onToggle, splashRadius: 18)),
      validator: (v) { if (required && (v == null || v.isEmpty)) return S.t('msg_required'); if (!required && v != null && v.isNotEmpty && v.length < 4) return S.t('msg_min_4_chars'); return null; });
}

class _ConfirmDialog extends StatelessWidget {
  final String title, body, confirmLabel, cancelLabel; final Color confirmColor;
  const _ConfirmDialog({required this.title, required this.body, required this.confirmColor, required this.confirmLabel, required this.cancelLabel});
  @override
  Widget build(BuildContext context) => Dialog(backgroundColor: _T.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Container(width: 380, padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _T.ink)),
    const SizedBox(height: 10),
    Text(body, style: const TextStyle(fontSize: 13.5, color: _T.inkMid, height: 1.5)),
    const SizedBox(height: 24),
    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      TextButton(onPressed: () => Navigator.pop(context, false), style: TextButton.styleFrom(foregroundColor: _T.inkMid, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)), child: Text(cancelLabel, style: const TextStyle(fontSize: 13.5))),
      const SizedBox(width: 8),
      ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: _T.bg, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text(confirmLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
    ]),
  ])));
}