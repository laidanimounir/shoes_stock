import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/app_strings.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});
  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String? _actionFilter;
  final List<Map<String, String>> _actions = [
    {'value': 'add_customer', 'label': 'Ajout client'}, {'value': 'add_supplier', 'label': 'Ajout fournisseur'},
    {'value': 'add_product', 'label': 'Ajout produit'}, {'value': 'refund', 'label': 'Remboursement'},
    {'value': 'debt_payment', 'label': 'Paiement dette'}, {'value': 'sale', 'label': 'Vente'},
  ];
  int _page = 0;
  bool _hasMore = true;
  final _scrollCtrl = ScrollController();

  @override
  void initState() { super.initState(); timeago.setLocaleMessages('fr', timeago.FrMessages()); _fetch(); _scrollCtrl.addListener(() { if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 && _hasMore && !_isLoading) { _page++; _fetch(); } }); }
  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    if (_page == 0) setState(() => _isLoading = true);
    try {
      var qb = Supabase.instance.client.from('activity_logs').select('*, user_profiles(full_name)');
      if (_actionFilter != null) qb = qb.eq('action_type', _actionFilter!);
      final res = await qb.order('created_at', ascending: false).range(_page * 30, (_page + 1) * 30 - 1);
      if (mounted) setState(() { if (_page == 0) { _logs = res; } else { _logs.addAll(res); } _hasMore = res.length >= 30; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t('nav_activity_logs')), backgroundColor: Colors.indigo[900], foregroundColor: Colors.white),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(8), color: Colors.white,
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            FilterChip(label: Text(S.t('filter_all')), selected: _actionFilter == null, onSelected: (_) { setState(() { _actionFilter = null; _page = 0; }); _fetch(); }),
            const SizedBox(width: 4),
            ..._actions.map((a) => Padding(padding: const EdgeInsets.only(right: 4), child: FilterChip(
              label: Text(a['label']!, style: const TextStyle(fontSize: 11)),
              selected: _actionFilter == a['value'],
              onSelected: (_) { setState(() { _actionFilter = _actionFilter == a['value'] ? null : a['value']; _page = 0; }); _fetch(); },
              visualDensity: VisualDensity.compact,
            ))),
          ])),
        ),
        Expanded(child: _isLoading && _logs.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _logs.isEmpty ? Center(child: Text(S.t('label_no_data')))
            : RefreshIndicator(onRefresh: () async { _page = 0; await _fetch(); }, child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length + (_hasMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= _logs.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                  final log = _logs[i];
                  final date = DateTime.tryParse(log['created_at'] ?? '');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(radius: 14, backgroundColor: Colors.indigo[50], child: const Icon(Icons.notifications_none, size: 16, color: Colors.indigo)),
                      title: Text(log['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      subtitle: Text('${log['user_profiles']?['full_name'] ?? ''} • ${date != null ? timeago.format(date, locale: 'fr') : ''}', style: const TextStyle(fontSize: 10)),
                    ),
                  );
                },
              )),
        ),
      ]),
    );
  }
}
