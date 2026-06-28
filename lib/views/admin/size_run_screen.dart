import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../core/app_strings.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/size_run_local.dart';
import '../../local_db/collections/product_local.dart';

class SizeRunScreen extends StatefulWidget {
  const SizeRunScreen({super.key});

  @override
  State<SizeRunScreen> createState() => _SizeRunScreenState();
}

class _SizeRunScreenState extends State<SizeRunScreen> {
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _selectedProduct;
  List<SizeRunLocal> _sizeRuns = [];
  List<String> _colors = [];
  String? _selectedColor;
  Map<String, int> _editedSizes = {};
  bool _isLoading = true;
  bool _isSaving = false;

  static const _defaultSizes = [
    '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46'
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final isar = await IsarService.getInstance();
      final local = await isar.productLocals.where().findAll();
      if (local.isNotEmpty) {
        _products = local
            .map((p) => {'id': p.supabaseId, 'name': p.name, 'category': p.category})
            .toList();
        setState(() => _isLoading = false);
        return;
      }
    } catch (e, s) { debugPrint('[SizeRunScreen] loadLocal error: $e\n$s'); }

    try {
      final rows = await Supabase.instance.client
          .from('products')
          .select('id, name, category')
          .eq('is_active', true);
      _products = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e, s) { debugPrint('[SizeRunScreen] loadOnline error: $e\n$s'); }
    setState(() => _isLoading = false);
  }

  Future<void> _loadSizeRuns() async {
    if (_selectedProduct == null) return;
    setState(() => _isLoading = true);

    try {
      final isar = await IsarService.getInstance();
      _sizeRuns = await isar.sizeRunLocals
          .filter()
          .productIdEqualTo(_selectedProduct!['id'] as String)
          .findAll();
    } catch (_) {
      _sizeRuns = [];
    }

    _colors = _sizeRuns
        .map((s) => s.color ?? 'default')
        .toSet()
        .toList();

    if (_sizeRuns.isEmpty) {
      _colors = ['default'];
    }

    if (_selectedColor != null && _colors.contains(_selectedColor)) {
      _applyColor(_selectedColor!);
    } else if (_colors.isNotEmpty) {
      _applyColor(_colors.first);
    } else {
      _editedSizes = {};
      _selectedColor = null;
    }

    setState(() => _isLoading = false);
  }

  void _applyColor(String color) {
    _selectedColor = color;
    final existing = _sizeRuns.firstWhere(
      (s) => (s.color ?? 'default') == color,
      orElse: () => SizeRunLocal()
        ..supabaseId = ''
        ..productId = _selectedProduct!['id'] as String
        ..color = color == 'default' ? null : color
        ..storeId = AppSession.currentStoreId ?? ''
        ..sizesJson = '{}',
    );
    _editedSizes = Map<String, int>.from(existing.sizes);
    for (final size in _defaultSizes) {
      _editedSizes.putIfAbsent(size, () => 0);
    }
  }

  Future<void> _saveSizeRuns() async {
    if (_selectedProduct == null || _selectedColor == null) return;
    setState(() => _isSaving = true);

    final cleanSizes = Map<String, int>.from(
      _editedSizes..removeWhere((_, v) => v <= 0),
    );

    try {
      final storeId = AppSession.currentStoreId ?? '';

      if (!AppSession.isOfflineMode) {
        final existing = _sizeRuns.firstWhere(
          (s) => (s.color ?? 'default') == _selectedColor,
          orElse: () => SizeRunLocal()
            ..supabaseId = ''
            ..productId = ''
            ..storeId = '',
        );

        if (existing.supabaseId.isEmpty) {
          final res = await Supabase.instance.client
              .from('size_runs')
              .insert({
                'product_id': _selectedProduct!['id'],
                'color': _selectedColor == 'default' ? null : _selectedColor,
                'sizes': cleanSizes,
                'store_id': storeId,
              })
              .select('id')
              .single();
          existing.supabaseId = res['id'] as String;
        } else {
          await Supabase.instance.client
              .from('size_runs')
              .update({'sizes': cleanSizes})
              .eq('id', existing.supabaseId);
        }
      }

      final isar = await IsarService.getInstance();
      final existing = _sizeRuns.firstWhere(
        (s) => (s.color ?? 'default') == _selectedColor,
        orElse: () => SizeRunLocal()
          ..supabaseId = ''
          ..productId = ''
          ..storeId = '',
      );

      await isar.writeTxn(() async {
        existing.updateSizes(cleanSizes);
        existing.updatedAt = DateTime.now();
        await isar.sizeRunLocals.put(existing);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A14),
      appBar: AppBar(
        title: Text(S.t('size_run_title')),
        backgroundColor: Color(0xFF13131F),
        actions: [
          if (_selectedProduct != null)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveSizeRuns,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(S.t('action_save')),
            ),
        ],
      ),
      body: Row(
        children: [
          // Product list panel
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Color(0xFF13131F),
              border: Border(right: BorderSide(color: Color(0xFF1E1E35))),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) {
                      final p = _products[i];
                      final isSelected = _selectedProduct?['id'] == p['id'];
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Color(0xFFF0A500).withValues(alpha: 0.1),
                        title: Text(p['name'] ?? '', style: const TextStyle(fontSize: 13)),
                        subtitle: Text(p['category'] ?? '', style: const TextStyle(fontSize: 11)),
                        onTap: () {
                          setState(() => _selectedProduct = p);
                          _loadSizeRuns();
                        },
                      );
                    },
                  ),
          ),
          // Size run editor panel
          Expanded(
            child: _selectedProduct == null
                ? Center(child: Text(S.t('size_run_select_product')))
                : _buildEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedProduct!['name']}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          // Color selector
          Row(
            children: [
              Text('${S.t('product_color')}: ', style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedColor,
                items: _colors.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c == 'default' ? S.t('size_run_default_color') : c),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _applyColor(v));
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Size grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                childAspectRatio: 1.3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _defaultSizes.length,
              itemBuilder: (ctx, i) {
                final size = _defaultSizes[i];
                final qty = _editedSizes[size] ?? 0;
                return _buildSizeCard(size, qty);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeCard(String size, int qty) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF13131F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF1E1E35)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(size, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _editedSizes[size] = (qty - 1).clamp(0, 9999);
                  });
                },
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$qty',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _editedSizes[size] = (qty + 1).clamp(0, 9999);
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
