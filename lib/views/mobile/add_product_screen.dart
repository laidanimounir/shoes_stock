import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../core/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../core/app_session.dart';
import '../../theme/app_colors.dart';
import '../../shared/constants/shoe_constants.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  int _step = 0;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<dynamic> _suppliers = [];
  List<dynamic> _stores = [];
  String? _supplierId;
  String? _storeId;
  File? _imageFile;
  Uint8List? _imageBytes;
  final _picker = ImagePicker();
  bool _saving = false;

  String _category = 'homme';
  List<String> _colors = [];
  List<String> _sizes = [];
  double _buyPrice = 0;
  double _sellPrice = 0;

  @override
  void initState() {
    super.initState();
    if (AppSession.isEmployee) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.t('prod_no_permission')), backgroundColor: AppColors.danger),
          );
          Navigator.pop(context);
        }
      });
      return;
    }
    _fetchMetadata();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMetadata() async {
    try {
      final res = await Future.wait([
        Supabase.instance.client.from('suppliers').select().eq('is_active', true),
        Supabase.instance.client.from('stores').select().eq('is_active', true),
      ]);
      if (mounted) setState(() {
        _suppliers = res[0];
        _stores = res[1];
        if (_stores.isNotEmpty) _storeId = _stores.first['id'];
        if (_suppliers.isNotEmpty) _supplierId = _suppliers.first['id'];
      });
    } catch (e, s) { debugPrint('[AddProductScreen] error: $e\n$s'); }
  }

  Future<void> _pickImage() async {
    try {
      final img = await _picker.pickImage(source: ImageSource.gallery);
      if (img != null) {
        if (kIsWeb) {
          _imageBytes = await img.readAsBytes();
        } else {
          final file = File(img.path);
          final dir = Directory.systemTemp;
          final target = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
          final compressed = await FlutterImageCompress.compressAndGetFile(file.path, target, quality: 70, minWidth: 600, minHeight: 600);
          _imageFile = compressed != null ? File(compressed.path) : file;
        }
        setState(() {});
      }
    } catch (e, s) { debugPrint('[AddProductScreen] error: $e\n$s'); }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null && _imageBytes == null) return null;
    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'products/$name';
      if (kIsWeb && _imageBytes != null) {
        await Supabase.instance.client.storage.from('shoes-images').uploadBinary(path, _imageBytes!);
      } else if (_imageFile != null) {
        await Supabase.instance.client.storage.from('shoes-images').upload(path, _imageFile!);
      }
      return Supabase.instance.client.storage.from('shoes-images').getPublicUrl(path);
    } catch (_) { return null; }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _storeId == null) return;
    if (_sizes.isEmpty || _colors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('auth_fill_fields')), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _saving = true);
    try {
      final imageUrl = await _uploadImage();
      final productRes = await Supabase.instance.client.from('products').insert({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'supplier_id': _supplierId,
        'image_url': imageUrl,
        'category': _category,
        'is_active': true,
      }).select('id').single();
      final productId = productRes['id'];

      final variants = [
        for (final size in _sizes)
          for (final color in _colors)
            {
              'size': size, 'color': color,
              'buy_price': _buyPrice, 'sell_price': _sellPrice, 'is_active': true,
            }
      ];
      await Supabase.instance.client.rpc('insert_variants_batch', params: {
        'p_product_id': productId,
        'p_variants': variants,
        'p_store_id': _storeId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('prod_add_product_success')), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AppSession.isEmployee) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: Text('${S.t('prod_add_btn')} (${_step + 1}/3)'),
        backgroundColor: AppColors.mobileBackground,
        foregroundColor: Colors.white,
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Step indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: List.generate(3, (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _step ? AppColors.mobileBackground : AppColors.mobileBorderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                  ),
                ),
                Expanded(child: _buildStep()),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  child: Text(S.t('action_back')),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mobileBackground,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _step < 2 ? () => setState(() => _step++) : _save,
                child: Text(_step < 2 ? S.t('action_next') : S.t('action_save')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _stepInfo();
      case 1: return _stepSizesColors();
      case 2: return _stepPrices();
      default: return const SizedBox.shrink();
    }
  }

  Widget _stepInfo() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Image
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: AppColors.mobileBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.mobileBorderStrong!),
              ),
              child: _imageFile != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_imageFile!, fit: BoxFit.cover))
                  : _imageBytes != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40, color: AppColors.mobileTextMuted),
                            const SizedBox(height: 4),
                            Text(S.t('prod_add_image'), style: TextStyle(fontSize: 12, color: AppColors.mobileTextSecondary)),
                          ],
                        ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Nom du produit', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description (optionnelle)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _supplierId,
          decoration: const InputDecoration(labelText: 'Fournisseur', border: OutlineInputBorder()),
          items: _suppliers.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s['id'], child: Text(s['company_name'] ?? s['full_name'] ?? ''))).toList(),
          onChanged: (v) => setState(() => _supplierId = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _storeId,
          decoration: const InputDecoration(labelText: 'Magasin', border: OutlineInputBorder()),
          items: _stores.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s['id'], child: Text(s['name'] ?? ''))).toList(),
          onChanged: (v) => setState(() => _storeId = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder()),
          items: ['homme', 'femme', 'enfant'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() { _category = v!; _sizes.clear(); }),
        ),
      ],
    );
  }

  Widget _stepSizesColors() {
    final availableSizes = kSizesByCategory[_category] ?? [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(S.t('prod_select_colors'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: kShoeColors.map((c) {
            final name = c['name'] as String;
            final selected = _colors.contains(name);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) { _colors.remove(name); } else { _colors.add(name); }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.mobileSurfaceElevated : AppColors.mobileSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? AppColors.mobilePrimary : AppColors.mobileBorderStrong!),
                ),
                child: Text(name, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? AppColors.mobileBackground : Colors.grey[700])),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text(S.t('prod_select_sizes'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: availableSizes.map((s) {
            final selected = _sizes.contains(s);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) { _sizes.remove(s); } else { _sizes.add(s); }
              }),
              child: Container(
                width: 52, height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.mobileSurfaceElevated : AppColors.mobileSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? AppColors.mobilePrimary : AppColors.mobileBorderStrong!),
                ),
                child: Text(s, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? AppColors.mobileBackground : Colors.grey[700])),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _stepPrices() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(S.t('prod_configure_prices'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 24),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '${S.t('prod_buy_price')} (${S.t('misc_currency')})',
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => _buyPrice = double.tryParse(v) ?? 0,
        ),
        const SizedBox(height: 16),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '${S.t('prod_sell_price')} (${S.t('misc_currency')})',
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => _sellPrice = double.tryParse(v) ?? 0,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.mobileSurfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text('${_colors.length} couleurs × ${_sizes.length} pointures = ${_colors.length * _sizes.length} variantes',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${S.t('prod_buy_price')}: $_buyPrice  |  ${S.t('prod_sell_price')}: $_sellPrice',
                  style: TextStyle(color: AppColors.mobileTextSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
