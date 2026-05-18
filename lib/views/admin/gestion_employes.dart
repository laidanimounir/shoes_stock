import 'dart:async';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/user_profile_local.dart';
import '../../widgets/offline_banner.dart';

class GestionEmployesScreen extends StatefulWidget {
  const GestionEmployesScreen({super.key});

  @override
  State<GestionEmployesScreen> createState() => _GestionEmployesScreenState();
}

class _GestionEmployesScreenState extends State<GestionEmployesScreen>
    with SingleTickerProviderStateMixin {
  bool _blocked = false;

  late TabController _tabController;

  final _searchController = TextEditingController();
  Timer? _debounce;

  List<dynamic> _employees = [];
  bool _isLoadingEmployees = false;
  bool _hasMore = true;
  int _page = 0;
  static const int _pageSize = 20;

  final Map<int, ScrollController> _scrollControllers = {};

  Map<String, dynamic>? _selectedEmployee;
  bool _isCreating = false;
  bool _isEditing = false;

  List<dynamic> _stores = [];

  final _createFormKey = GlobalKey<FormState>();
  final _firstNameCtl = TextEditingController();
  final _lastNameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _jobTitleCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  String? _selectedStoreIdCreate;
  DateTime? _hiredAtCreate;
  bool _obscurePassword = true;
  bool _submitting = false;

  final _editFormKey = GlobalKey<FormState>();
  final _editFirstNameCtl = TextEditingController();
  final _editLastNameCtl = TextEditingController();
  final _editPhoneCtl = TextEditingController();
  final _editAddressCtl = TextEditingController();
  final _editJobTitleCtl = TextEditingController();
  final _editPasswordCtl = TextEditingController();
  String? _selectedStoreIdEdit;
  DateTime? _hiredAtEdit;
  bool _obscureEditPassword = true;
  bool _editSubmitting = false;

  bool get _isOnline => !AppSession.isOfflineMode;

  @override
  void initState() {
    super.initState();
    if (AppSession.isEmployee) {
      _blocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.t('emp_no_permission')), backgroundColor: Colors.red),
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _fetchStores();
    _fetchEmployees();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedEmployee = null;
        _isCreating = false;
        _isEditing = false;
        _page = 0;
        _employees = [];
        _hasMore = true;
      });
      _fetchEmployees();
    }
  }

  ScrollController _scrollControllerFor(int tab) {
    if (!_scrollControllers.containsKey(tab)) {
      final c = ScrollController();
      c.addListener(() {
        if (c.position.pixels >= c.position.maxScrollExtent - 200 && _hasMore && !_isLoadingEmployees) {
          _fetchEmployees();
        }
      });
      _scrollControllers[tab] = c;
    }
    return _scrollControllers[tab]!;
  }

  Future<void> _fetchStores() async {
    try {
      final res = await Supabase.instance.client.from('stores').select('id, name').order('name');
      if (mounted) setState(() => _stores = res);
    } catch (e) {
      debugPrint('Error fetching stores: $e');
    }
  }

  Future<void> _fetchEmployees({String? query}) async {
    if (_isLoadingEmployees) return;
    setState(() => _isLoadingEmployees = true);

    try {
      if (AppSession.isOfflineMode) {
        await _fetchEmployeesLocal(query);
        return;
      }

      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      var req = Supabase.instance.client
          .from('user_profiles')
          .select('*, stores(name)')
          .eq('role', 'employee');

      final q = query?.trim() ?? _searchController.text.trim();
      if (q.isNotEmpty) {
        final pattern = '%$q%';
        req = req.or('first_name.ilike.$pattern,last_name.ilike.$pattern,full_name.ilike.$pattern');
      }

      final tab = _tabController.index;
      if (tab == 0) {
        req = req.eq('is_active', true).eq('is_permanently_deleted', false);
      } else if (tab == 1) {
        req = req.eq('is_active', false).eq('is_permanently_deleted', false);
      } else {
        req = req.eq('is_permanently_deleted', true);
      }

      final res = await req.order('created_at', ascending: false).range(from, to);

      if (mounted) {
        setState(() {
          _employees.addAll(res);
          _hasMore = res.length >= _pageSize;
          _page++;
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.t('msg_error')}: ${S.t('emp_no_results')}'), backgroundColor: Colors.red),
        );
      }
      debugPrint('Error fetching employees: $e');
    }
  }

  Future<void> _fetchEmployeesLocal(String? query) async {
    try {
      final isar = await IsarService.getInstance();
      final q = query?.trim() ?? _searchController.text.trim();
      final tab = _tabController.index;

      final allLocals = await isar.userProfileLocals.where().findAll();
      final filtered = allLocals.where((e) {
        if (tab == 0) return e.isActive && !e.isPermanentlyDeleted;
        if (tab == 1) return !e.isActive && !e.isPermanentlyDeleted;
        return e.isPermanentlyDeleted;
      });
      List<UserProfileLocal> searched;
      if (q.isNotEmpty) {
        final pattern = q.toLowerCase();
        searched = filtered.where((e) =>
            (e.firstName?.toLowerCase().contains(pattern) ?? false) ||
            (e.lastName?.toLowerCase().contains(pattern) ?? false) ||
            e.fullName.toLowerCase().contains(pattern)).toList();
      } else {
        searched = filtered.toList();
      }

      if (mounted) {
        setState(() {
          _employees = searched.map(_localToMap).toList();
          _hasMore = false;
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingEmployees = false);
      debugPrint('Error fetching employees local: $e');
    }
  }

  Map<String, dynamic> _localToMap(UserProfileLocal e) => <String, dynamic>{
    'id': e.supabaseId,
    'full_name': e.fullName,
    'first_name': e.firstName,
    'last_name': e.lastName,
    'role': e.role,
    'store_id': e.storeId,
    'phone': e.phone,
    'address': e.address,
    'job_title': e.jobTitle,
    'hired_at': e.hiredAt?.toIso8601String(),
    'is_active': e.isActive,
    'is_permanently_deleted': e.isPermanentlyDeleted,
    'created_at': e.createdAt?.toIso8601String(),
    'stores': e.storeId != null ? {'name': null} : null,
  };

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _page = 0;
          _employees = [];
          _hasMore = true;
        });
        _fetchEmployees(query: value);
      }
    });
  }

  Future<void> _createEmployee() async {
    if (!_createFormKey.currentState!.validate()) return;
    if (_selectedStoreIdCreate == null) {
      _showSnack(S.t('pos_select_store'), Colors.red);
      return;
    }

    setState(() => _submitting = true);
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final res = await Supabase.instance.client.functions.invoke(
        'create_employee',
        headers: {'Authorization': 'Bearer ${session?.accessToken}'},
        body: {
          'email': _emailCtl.text.trim(),
          'password': _passwordCtl.text,
          'first_name': _firstNameCtl.text.trim(),
          'last_name': _lastNameCtl.text.trim(),
          'phone': _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
          'address': _addressCtl.text.trim().isEmpty ? null : _addressCtl.text.trim(),
          'job_title': _jobTitleCtl.text.trim().isEmpty ? null : _jobTitleCtl.text.trim(),
          'store_id': _selectedStoreIdCreate,
          'hired_at': _hiredAtCreate?.toIso8601String().split('T')[0],
        },
      );

      if (res.status == 200 && res.data['success'] == true) {
        _showSnack(S.t('emp_created'), Colors.green);
        _resetCreateForm();
        if (!_isOnline) await _syncLocalCache();
        setState(() {
          _isCreating = false;
          _page = 0;
          _employees = [];
          _hasMore = true;
        });
        _fetchEmployees();
      } else {
        final err = res.data['error']?.toString().toLowerCase() ?? '';
        if (err.contains('already registered') || err.contains('email exists')) {
          throw Exception('already_exists');
        } else {
          throw Exception(err);
        }
      }
    } catch (e) {
      String msg = "${S.t('msg_error')}: $e";
      if (e.toString().contains('already_exists')) msg = S.t('auth_email_exists');
      _showSnack(msg, Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _updateEmployee() async {
    if (!_editFormKey.currentState!.validate()) return;
    if (_selectedStoreIdEdit == null) {
      _showSnack(S.t('pos_select_store'), Colors.red);
      return;
    }

    setState(() => _editSubmitting = true);
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final body = <String, dynamic>{
        'employee_id': _selectedEmployee!['id'],
        'first_name': _editFirstNameCtl.text.trim(),
        'last_name': _editLastNameCtl.text.trim(),
        'phone': _editPhoneCtl.text.trim().isEmpty ? null : _editPhoneCtl.text.trim(),
        'address': _editAddressCtl.text.trim().isEmpty ? null : _editAddressCtl.text.trim(),
        'job_title': _editJobTitleCtl.text.trim().isEmpty ? null : _editJobTitleCtl.text.trim(),
        'store_id': _selectedStoreIdEdit,
        'hired_at': _hiredAtEdit?.toIso8601String().split('T')[0],
      };

      final pw = _editPasswordCtl.text.trim();
      if (pw.isNotEmpty) body['new_password'] = pw;

      final res = await Supabase.instance.client.functions.invoke(
        'update_employee',
        headers: {'Authorization': 'Bearer ${session?.accessToken}'},
        body: body,
      );

      if (res.status == 200 && res.data['success'] == true) {
        _showSnack(S.t('emp_updated'), Colors.green);
        setState(() {
          _isEditing = false;
          _selectedEmployee = res.data['profile'] as Map<String, dynamic>?;
          _page = 0;
          _employees = [];
          _hasMore = true;
        });
        _fetchEmployees();
      } else {
        throw Exception(res.data['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      _showSnack('${S.t('msg_error')}: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _editSubmitting = false);
    }
  }

  Future<void> _toggleEmployeeStatus(String employeeId, String action) async {
    String confirmTitle;
    String confirmMsg;
    Color actionColor;

    switch (action) {
      case 'suspend':
        confirmTitle = S.t('emp_confirm_suspend');
        confirmMsg = S.t('emp_confirm_suspend_msg');
        actionColor = Colors.orange;
        break;
      case 'reactivate':
        confirmTitle = S.t('emp_confirm_suspend');
        confirmMsg = S.t('emp_confirm_suspend_msg');
        actionColor = Colors.green;
        break;
      case 'permanent_delete':
        confirmTitle = S.t('emp_confirm_archive');
        confirmMsg = S.t('emp_confirm_archive_msg');
        actionColor = Colors.red;
        break;
      default:
        return;
    }

    if (action != 'reactivate') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(confirmTitle),
          content: Text(confirmMsg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: actionColor, foregroundColor: Colors.white),
              child: Text(S.t('action_confirm')),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final res = await Supabase.instance.client.functions.invoke(
        'toggle_employee_status',
        headers: {'Authorization': 'Bearer ${session?.accessToken}'},
        body: {'employee_id': employeeId, 'action': action},
      );

      if (res.status == 200 && res.data['success'] == true) {
        String msg;
        switch (action) {
          case 'suspend':
            msg = S.t('emp_suspended');
            break;
          case 'reactivate':
            msg = S.t('emp_reactivated');
            break;
          case 'permanent_delete':
            msg = S.t('emp_archived');
            break;
          default:
            msg = S.t('msg_updated');
        }
        _showSnack(msg, Colors.green);
        setState(() {
          _selectedEmployee = res.data['profile'] as Map<String, dynamic>?;
          _page = 0;
          _employees = [];
          _hasMore = true;
        });
        _fetchEmployees();
      } else {
        throw Exception(res.data['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      _showSnack('${S.t('msg_error')}: $e', Colors.red);
    }
  }

  Future<void> _syncLocalCache() async {
    try {
      if (!AppSession.isOfflineMode) {
        final isar = await IsarService.getInstance();
        final remote = await Supabase.instance.client
            .from('user_profiles')
            .select()
            .eq('role', 'employee')
            .eq('is_active', true)
            .eq('is_permanently_deleted', false);
        await isar.writeTxn(() async {
          await isar.userProfileLocals.clear();
          for (final j in remote) {
            await isar.userProfileLocals.put(_mapToLocal(j));
          }
        });
      }
    } catch (e) {
      debugPrint('Error syncing local cache: $e');
    }
  }

  UserProfileLocal _mapToLocal(Map<String, dynamic> j) => UserProfileLocal()
    ..supabaseId = j['id'] as String
    ..fullName = (j['full_name'] as String?) ?? ''
    ..role = (j['role'] as String?) ?? 'employee'
    ..storeId = j['store_id'] as String?
    ..isActive = (j['is_active'] as bool?) ?? true
    ..createdAt = _parseDate(j['created_at'])
    ..updatedAt = _parseDate(j['updated_at'])
    ..firstName = j['first_name'] as String?
    ..lastName = j['last_name'] as String?
    ..phone = j['phone'] as String?
    ..address = j['address'] as String?
    ..jobTitle = j['job_title'] as String?
    ..hiredAt = _parseDate(j['hired_at'])
    ..isPermanentlyDeleted = (j['is_permanently_deleted'] as bool?) ?? false;

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  void _selectEmployee(Map<String, dynamic> emp) {
    setState(() {
      _selectedEmployee = emp;
      _isCreating = false;
      _isEditing = false;
    });
  }

  void _startCreate() {
    setState(() {
      _isCreating = true;
      _isEditing = false;
      _selectedEmployee = null;
    });
  }

  void _startEdit(Map<String, dynamic> emp) {
    _editFirstNameCtl.text = emp['first_name'] as String? ?? '';
    _editLastNameCtl.text = emp['last_name'] as String? ?? '';
    _editPhoneCtl.text = emp['phone'] as String? ?? '';
    _editAddressCtl.text = emp['address'] as String? ?? '';
    _editJobTitleCtl.text = emp['job_title'] as String? ?? '';
    _editPasswordCtl.clear();
    _selectedStoreIdEdit = emp['store_id'] as String?;
    _hiredAtEdit = _parseDate(emp['hired_at']);
    setState(() {
      _isEditing = true;
      _isCreating = false;
    });
  }

  void _cancelForm() {
    setState(() {
      _isCreating = false;
      _isEditing = false;
      _resetCreateForm();
    });
  }

  void _resetCreateForm() {
    _firstNameCtl.clear();
    _lastNameCtl.clear();
    _emailCtl.clear();
    _phoneCtl.clear();
    _addressCtl.clear();
    _jobTitleCtl.clear();
    _passwordCtl.clear();
    _selectedStoreIdCreate = _stores.isNotEmpty ? _stores.first['id'] : null;
    _hiredAtCreate = DateTime.now();
    _createFormKey.currentState?.reset();
  }

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    for (final c in _scrollControllers.values) {
      c.dispose();
    }
    _firstNameCtl.dispose();
    _lastNameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _jobTitleCtl.dispose();
    _passwordCtl.dispose();
    _editFirstNameCtl.dispose();
    _editLastNameCtl.dispose();
    _editPhoneCtl.dispose();
    _editAddressCtl.dispose();
    _editJobTitleCtl.dispose();
    _editPasswordCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked) return const SizedBox.shrink();
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeftPanel(),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: _buildMainPanel()),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // LEFT PANEL
  // ═══════════════════════════════════════
  Widget _buildLeftPanel() {
    return SizedBox(
      width: 300,
      child: Column(
        children: [
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(child: _buildEmployeeList()),
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: S.t('emp_search_hint'),
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.blueAccent,
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[700],
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: S.t('emp_active_tab')),
          Tab(text: S.t('emp_suspended_tab')),
          Tab(text: S.t('emp_archived_tab')),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    if (_isLoadingEmployees && _employees.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_employees.isEmpty) {
      return Center(child: Text(S.t('emp_no_results'), style: TextStyle(color: Colors.grey[500])));
    }
    return ListView.builder(
      controller: _scrollControllerFor(_tabController.index),
      itemCount: _employees.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _employees.length) {
          return const Center(child: Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
        }
        return _buildEmployeeCard(_employees[index]);
      },
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final isSelected = _selectedEmployee?['id'] == emp['id'];
    final firstName = emp['first_name'] as String?;
    final lastName = emp['last_name'] as String?;
    final fullName = emp['full_name'] as String?;
    final label = firstName != null ? '$firstName $lastName' : (fullName ?? S.t('emp_role_label'));
    final initials = firstName != null
        ? '${firstName.isNotEmpty ? firstName[0] : ''}${lastName?.isNotEmpty == true ? lastName![0] : ''}'.toUpperCase()
        : (fullName != null && fullName.isNotEmpty
            ? fullName.split(' ').map((s) => s.isNotEmpty ? s[0] : '').join('').toUpperCase()
            : '?');
    final storeName = emp['stores']?['name'] as String?;
    final hiredRaw = emp['hired_at'] as String?;
    final isActive = (emp['is_active'] as bool?) ?? true;
    final isDeleted = (emp['is_permanently_deleted'] as bool?) ?? false;

    Color dotColor;
    if (isDeleted) {
      dotColor = Colors.grey;
    } else if (!isActive) {
      dotColor = Colors.orange;
    } else {
      dotColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[50] : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: isSelected ? Colors.blueAccent : Colors.transparent,
            width: 3,
          ),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.blue[50],
          child: Text(initials.isNotEmpty ? initials.substring(0, 1) : '?',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 14)),
        ),
        title: Text(label.isNotEmpty ? label : S.t('misc_unknown'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (emp['job_title'] != null)
              Text(emp['job_title'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    storeName ?? (isDeleted ? S.t('emp_status_archived') : S.t('misc_no_store')),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (hiredRaw != null)
              Text('${S.t('emp_since_date')} ${hiredRaw.split('T')[0]}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[400])),
          ],
        ),
        isThreeLine: true,
        onTap: () => _selectEmployee(emp),
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton.icon(
          onPressed: _isOnline ? _startCreate : null,
          icon: const Icon(Icons.person_add),
          label: Text(S.t('emp_add')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // MAIN PANEL
  // ═══════════════════════════════════════
  Widget _buildMainPanel() {
    if (_isCreating) return _buildCreateForm();
    if (_isEditing && _selectedEmployee != null) return _buildEditForm();
    if (_selectedEmployee != null) return _buildDetailView();
    return _buildEmptyState();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(S.t('emp_select_hint'), style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // DETAIL VIEW
  // ═══════════════════════════════════════
  Widget _buildDetailView() {
    final emp = _selectedEmployee!;
    final firstName = emp['first_name'] as String?;
    final lastName = emp['last_name'] as String?;
    final fullName = emp['full_name'] as String?;
    final label = firstName != null ? '$firstName $lastName' : (fullName ?? S.t('emp_role_label'));
    final initials = firstName != null
        ? '${firstName.isNotEmpty ? firstName[0] : ''}${lastName?.isNotEmpty == true ? lastName![0] : ''}'.toUpperCase()
        : (fullName != null && fullName.isNotEmpty
            ? fullName.split(' ').map((s) => s.isNotEmpty ? s[0] : '').join('').toUpperCase()
            : '?');
    final isActive = (emp['is_active'] as bool?) ?? true;
    final isDeleted = (emp['is_permanently_deleted'] as bool?) ?? false;
    final storeName = emp['stores']?['name'] as String?;
    final hiredRaw = emp['hired_at'] as String?;
    final email = (emp['id'] as String?) ?? '';

    String statusLabel;
    Color statusColor;
    if (isDeleted) {
      statusLabel = S.t('emp_status_archived');
      statusColor = Colors.grey;
    } else if (!isActive) {
      statusLabel = S.t('emp_status_suspended');
      statusColor = Colors.orange;
    } else {
      statusLabel = S.t('emp_status_active');
      statusColor = Colors.green;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue[50],
                child: Text(initials.isNotEmpty ? initials : '?',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 28)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.isNotEmpty ? label : S.t('misc_unknown'),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    if (emp['job_title'] != null)
                      Text(emp['job_title'] as String,
                          style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    _buildStatusBadge(statusLabel, statusColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (hiredRaw != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${S.t('emp_since_date')} ${hiredRaw.split('T')[0]}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
          const Divider(),
          const SizedBox(height: 16),
          _buildInfoGrid(emp, storeName, email),
          const SizedBox(height: 32),
          _buildDetailActions(emp, isActive, isDeleted),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(Map<String, dynamic> emp, String? storeName, String email) {
    final fields = [
      _infoField(S.t('emp_email'), email, Icons.email),
      _infoField(S.t('emp_phone'), emp['phone'] as String? ?? S.t('misc_not_available'), Icons.phone),
      _infoField(S.t('emp_address'), emp['address'] as String? ?? S.t('misc_not_available'), Icons.location_on),
      _infoField(S.t('emp_assign_store'), storeName ?? S.t('misc_no_store'), Icons.store),
      _infoField(S.t('emp_hired_at'), emp['hired_at']?.toString().split('T')[0] ?? S.t('misc_not_available'), Icons.calendar_today),
      _infoField(S.t('label_role'), S.t('emp_role_label'), Icons.badge),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: fields.map((w) => SizedBox(width: 280, child: w)).toList(),
    );
  }

  Widget _infoField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailActions(Map<String, dynamic> emp, bool isActive, bool isDeleted) {
    if (isDeleted) return const SizedBox.shrink();

    return Row(
      children: [
        if (_isOnline)
          OutlinedButton.icon(
            onPressed: () => _startEdit(emp),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(S.t('action_edit')),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent),
          ),
        const SizedBox(width: 12),
        if (isActive && _isOnline)
          OutlinedButton.icon(
            onPressed: () => _toggleEmployeeStatus(emp['id'], 'suspend'),
            icon: const Icon(Icons.pause_circle_outline, size: 18),
            label: Text(S.t('emp_suspend_btn')),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          ),
        if (!isActive && _isOnline) ...[
          OutlinedButton.icon(
            onPressed: () => _toggleEmployeeStatus(emp['id'], 'reactivate'),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: Text(S.t('emp_reactivate_btn')),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => _toggleEmployeeStatus(emp['id'], 'permanent_delete'),
            icon: const Icon(Icons.archive, size: 18),
            label: Text(S.t('emp_archive_btn')),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════
  // CREATE FORM
  // ═══════════════════════════════════════
  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: SizedBox(
        width: 500,
        child: Form(
          key: _createFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.t('emp_add'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildTextField(_firstNameCtl, S.t('emp_first_name'), required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(_lastNameCtl, S.t('emp_last_name'), required: true)),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(_emailCtl, S.t('emp_email'),
                  required: true, keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty || !v.contains('@') ? S.t('auth_error_email') : null),
              const SizedBox(height: 16),
              _buildTextField(_phoneCtl, S.t('emp_phone'), keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildTextField(_addressCtl, S.t('emp_address')),
              const SizedBox(height: 16),
              _buildTextField(_jobTitleCtl, S.t('emp_job_title')),
              const SizedBox(height: 16),
              _buildStoreDropdown(createMode: true),
              const SizedBox(height: 16),
              _buildDatePicker(S.t('emp_hired_at'), _hiredAtCreate, (d) => _hiredAtCreate = d, required: true),
              const SizedBox(height: 16),
              _buildPasswordField(_passwordCtl, S.t('emp_password'), _obscurePassword, (v) => _obscurePassword = v, required: true),
              const SizedBox(height: 32),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _submitting ? null : _createEmployee,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(S.t('emp_add_btn')),
                  ),
                  const SizedBox(width: 12),
                  TextButton(onPressed: _cancelForm, child: Text(S.t('action_cancel'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // EDIT FORM
  // ═══════════════════════════════════════
  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: SizedBox(
        width: 500,
        child: Form(
          key: _editFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.t('emp_edit'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildTextField(_editFirstNameCtl, S.t('emp_first_name'), required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(_editLastNameCtl, S.t('emp_last_name'), required: true)),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(TextEditingController(text: _selectedEmployee!['full_name'] as String? ?? ''),
                  S.t('emp_email'), enabled: false),
              const SizedBox(height: 16),
              _buildTextField(_editPhoneCtl, S.t('emp_phone'), keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildTextField(_editAddressCtl, S.t('emp_address')),
              const SizedBox(height: 16),
              _buildTextField(_editJobTitleCtl, S.t('emp_job_title')),
              const SizedBox(height: 16),
              _buildStoreDropdown(createMode: false),
              const SizedBox(height: 16),
              _buildDatePicker(S.t('emp_hired_at'), _hiredAtEdit, (d) => _hiredAtEdit = d, required: true),
              const SizedBox(height: 16),
              _buildPasswordField(_editPasswordCtl, S.t('emp_password'), _obscureEditPassword, (v) => _obscureEditPassword = v,
                  required: false, hint: S.t('emp_password_optional')),
              const SizedBox(height: 32),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _editSubmitting ? null : _updateEmployee,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    child: _editSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(S.t('emp_edit_btn')),
                  ),
                  const SizedBox(width: 12),
                  TextButton(onPressed: _cancelForm, child: Text(S.t('action_cancel'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // SHARED FORM WIDGETS
  // ═══════════════════════════════════════
  Widget _buildTextField(TextEditingController ctl, String label,
      {bool required = false, bool enabled = true, TextInputType? keyboardType,
       String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctl,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: validator ?? (required ? (v) => v!.isEmpty ? S.t('msg_required') : null : null),
    );
  }

  Widget _buildStoreDropdown({required bool createMode}) {
    final currentValue = createMode ? _selectedStoreIdCreate : _selectedStoreIdEdit;
    if (_stores.isEmpty) return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    return DropdownButtonFormField<String>(
      initialValue: currentValue ?? (_stores.isNotEmpty ? _stores.first['id'] as String : null),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '${S.t('emp_assign_store')} *',
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: _stores.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s['id'] as String?, child: Text(s['name'] as String? ?? ''))).toList(),
      onChanged: (v) {
        setState(() {
          if (createMode) { _selectedStoreIdCreate = v; } else { _selectedStoreIdEdit = v; }
        });
      },
      validator: (v) => v == null ? S.t('msg_required') : null,
    );
  }

  Widget _buildDatePicker(String label, DateTime? current, Function(DateTime) onPicked, {bool required = false}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: current ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() => onPicked(picked));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '$label${required ? ' *' : ''}',
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          current != null
              ? '${current.day.toString().padLeft(2, '0')}/${current.month.toString().padLeft(2, '0')}/${current.year}'
              : S.t('misc_not_available'),
        ),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController ctl, String label, bool obscure, Function(bool) onToggle,
      {bool required = true, String? hint}) {
    return TextFormField(
      controller: ctl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: required ? label : label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18),
          onPressed: () => setState(() => onToggle(!obscure)),
        ),
      ),
      validator: (v) {
        if (required && (v == null || v.isEmpty)) return S.t('msg_required');
        if (!required && v != null && v.isNotEmpty && v.length < 4) return S.t('msg_min_4_chars');
        return null;
      },
    );
  }
}
