import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});
  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  List<dynamic> _promotions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  Future<void> _fetchPromotions() async {
    setState(() => _isLoading = true);
    try {
      final storeId = AppSession.currentStoreId;
      if (storeId == null) return;
      final res = await Supabase.instance.client
          .from('promotions')
          .select()
          .eq('store_id', storeId)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _promotions = res);
    } catch (e) {
      debugPrint('Error fetching promotions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePromotion(Map<String, dynamic> data, {String? id}) async {
    try {
      if (id != null) {
        await Supabase.instance.client.from('promotions').update(data).eq('id', id);
      } else {
        await Supabase.instance.client.from('promotions').insert(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('promo_saved')), backgroundColor: Colors.green));
      }
      _fetchPromotions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deletePromotion(String id) async {
    try {
      await Supabase.instance.client.from('promotions').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('promo_deleted')), backgroundColor: Colors.orange));
      }
      _fetchPromotions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showForm(Map<String, dynamic>? promo) {
    final nameCtrl = TextEditingController(text: promo?['name'] ?? '');
    final discCtrl = TextEditingController(text: promo?['discount_percent']?.toString() ?? '');
    DateTime? startDate = promo?['start_date'] != null ? DateTime.tryParse(promo!['start_date']) : null;
    DateTime? endDate = promo?['end_date'] != null ? DateTime.tryParse(promo!['end_date']) : null;
    String appliesTo = promo?['applies_to'] ?? 'all';
    String? category = promo?['category'];
    bool isActive = promo?['is_active'] ?? true;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(promo != null ? S.t('promo_edit') : S.t('promo_add')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: S.t('promo_name'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: discCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: S.t('promo_discount_percent'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(startDate != null ? startDate!.toIso8601String().substring(0, 10) : S.t('promo_start')),
                onPressed: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (picked != null) setDialogState(() => startDate = picked);
                },
              )),
              const SizedBox(width: 8),
              Expanded(child: TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(endDate != null ? endDate!.toIso8601String().substring(0, 10) : S.t('promo_end')),
                onPressed: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: endDate ?? DateTime.now().add(const Duration(days: 30)), firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (picked != null) setDialogState(() => endDate = picked);
                },
              )),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: appliesTo,
              decoration: InputDecoration(labelText: S.t('promo_applies_to'), border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: 'all', child: Text(S.t('promo_all'))),
                DropdownMenuItem(value: 'homme', child: Text(S.t('filter_men'))),
                DropdownMenuItem(value: 'femme', child: Text(S.t('filter_women'))),
                DropdownMenuItem(value: 'enfant', child: Text(S.t('filter_kid'))),
              ],
              onChanged: (v) => setDialogState(() => appliesTo = v ?? 'all'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text(isActive ? S.t('promo_active') : S.t('promo_inactive')),
              value: isActive,
              onChanged: (v) => setDialogState(() => isActive = v),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
          ElevatedButton(onPressed: () {
            if (nameCtrl.text.isEmpty || discCtrl.text.isEmpty || startDate == null || endDate == null) return;
            final storeId = AppSession.currentStoreId;
            if (storeId == null) return;
            final data = {
              'store_id': storeId,
              'name': nameCtrl.text,
              'discount_percent': double.tryParse(discCtrl.text) ?? 0,
              'start_date': startDate!.toIso8601String().substring(0, 10),
              'end_date': endDate!.toIso8601String().substring(0, 10),
              'applies_to': appliesTo,
              'category': appliesTo == 'all' ? null : appliesTo,
              'is_active': isActive,
            };
            Navigator.pop(ctx);
            _savePromotion(data, id: promo?['id']);
          }, child: Text(S.t('promo_save'))),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('promo_title')),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showForm(null),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _promotions.isEmpty
              ? Center(child: Text(S.t('promo_no_promos'), style: const TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _promotions.length,
                  itemBuilder: (_, i) {
                    final p = _promotions[i];
                    final isActive = p['is_active'] ?? true;
                    final start = DateTime.tryParse(p['start_date'] ?? '');
                    final end = DateTime.tryParse(p['end_date'] ?? '');
                    final now = DateTime.now();
                    final isCurrent = isActive && start != null && end != null && now.isAfter(start.subtract(const Duration(days: 1))) && now.isBefore(end.add(const Duration(days: 1)));
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrent ? Colors.green[100] : Colors.grey[100],
                          child: Icon(Icons.local_offer, color: isCurrent ? Colors.green : Colors.grey),
                        ),
                        title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('-${p['discount_percent']}%  |  ${p['start_date']} → ${p['end_date']}  |  ${p['applies_to'] ?? 'all'}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                              child: Text(S.t('promo_active'), style: TextStyle(fontSize: 11, color: Colors.green[800], fontWeight: FontWeight.bold)),
                            ),
                          IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showForm(p)),
                          IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _deletePromotion(p['id'])),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
