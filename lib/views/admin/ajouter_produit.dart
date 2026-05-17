import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';

const List<Map<String, dynamic>> kShoeColors = [
  {'name': 'Noir', 'hex': '#000000'},
  {'name': 'Blanc', 'hex': '#FFFFFF'},
  {'name': 'Marron', 'hex': '#8B4513'},
  {'name': 'Beige', 'hex': '#F5F0DC'},
  {'name': 'Rouge', 'hex': '#E53935'},
  {'name': 'Bleu', 'hex': '#1E88E5'},
  {'name': 'Bleu Marine', 'hex': '#1A237E'},
  {'name': 'Vert', 'hex': '#43A047'},
  {'name': 'Gris', 'hex': '#757575'},
  {'name': 'Or', 'hex': '#FFD700'},
  {'name': 'Argent', 'hex': '#C0C0C0'},
  {'name': 'Rose', 'hex': '#E91E8C'},
];

const Map<String, List<String>> kSizesByCategory = {
  'homme': ['38','39','40','41','42','43','44','45','46'],
  'femme': ['35','36','37','38','39','40','41','42'],
  'enfant': ['20','21','22','23','24','25','26','27','28',
             '29','30','31','32','33','34','35'],
};

class AjouterProduitScreen extends StatefulWidget {
  const AjouterProduitScreen({super.key});

  @override
  State<AjouterProduitScreen> createState() => _AjouterProduitScreenState();
}

class _AjouterProduitScreenState extends State<AjouterProduitScreen> {
  bool _blocked = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  List<dynamic> _suppliers = [];
  String? _selectedSupplierId;

  List<dynamic> _stores = [];
  String? _selectedStoreId;

  List<Map<String, dynamic>> _variants = [];

  File? _imageFile;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  String _selectedCategory = 'homme';
  List<String> _selectedColors = [];
  String? _customColorName;
  List<String> _selectedSizes = [];
  String? _customSize;
  String _unitType = 'piece';
  int _unitsPerCarton = 1;
  double _unifiedBuyPrice = 0;
  double _unifiedSellPrice = 0;

  @override
  void initState() {
    super.initState();
    if (AppSession.isEmployee) {
      _blocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.t('prod_no_permission')), backgroundColor: Colors.red),
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final futures = await Future.wait([
        Supabase.instance.client.from('suppliers').select().eq('is_active', true),
        Supabase.instance.client.from('stores').select().eq('is_active', true),
      ]);

      if (mounted) {
        setState(() {
          _suppliers = futures[0];
          _stores = futures[1];
          if (_stores.isNotEmpty) {
            _selectedStoreId = _stores.first['id'];
          }
          if (_suppliers.isNotEmpty) _selectedSupplierId = _suppliers.first['id'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching metadata: $e");
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _imageFile = null;
          });
        } else {
          final file = File(image.path);
          final compressed = await _compressImage(file);
          setState(() {
            _imageFile = compressed;
            _imageBytes = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 800,
        minHeight: 800,
      );
      if (result != null) return File(result.path);
    } catch (e) {
      debugPrint("Error compressing image: $e");
    }
    return file;
  }


  Future<String?> _uploadImage() async {
    if (_imageFile == null && _imageBytes == null) return null;

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'products/$fileName';

      if (kIsWeb && _imageBytes != null) {
        await Supabase.instance.client.storage
          .from('shoes-images')
          .uploadBinary(path, _imageBytes!);
      } else if (_imageFile != null) {
        await Supabase.instance.client.storage
          .from('shoes-images')
          .upload(path, _imageFile!);
      }

      final imageUrl = Supabase.instance.client.storage
          .from('shoes-images')
          .getPublicUrl(path);

      return imageUrl;
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return null;
    }
  }

  Map<String, dynamic> _emptyVariant() => {
    'size': '',
    'color': '',
    'barcode': null,
    'buy_price': _unifiedBuyPrice.toString(),
    'sell_price': _unifiedSellPrice.toString(),
    'unit_type': _unitType,
    'units_per_carton': _unitType == 'carton' ? _unitsPerCarton : null,
  };

  void _addVariant() {
    setState(() {
      _variants.add(_emptyVariant());
    });
  }

  void _removeVariant(int index) {
    if (_variants.length > 1) {
      setState(() {
        _variants.removeAt(index);
      });
    }
  }

  void _toggleColor(String colorName) {
    setState(() {
      if (_selectedColors.contains(colorName)) {
        _selectedColors.remove(colorName);
      } else {
        _selectedColors.add(colorName);
      }
    });
  }

  void _toggleSize(String size) {
    setState(() {
      if (_selectedSizes.contains(size)) {
        _selectedSizes.remove(size);
      } else {
        _selectedSizes.add(size);
      }
    });
  }

  void _addCustomSize(String size) {
    if (size.isNotEmpty && !_selectedSizes.contains(size)) {
      setState(() => _selectedSizes.add(size));
    }
  }

  int get _totalUnits =>
    _unitType == 'carton'
      ? _quantityInput * _unitsPerCarton
      : _quantityInput;

  int _quantityInput = 0;

  void _generateVariants() {
    if (_selectedSizes.isEmpty || _selectedColors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('auth_fill_fields')), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _variants.clear();
      for (final size in _selectedSizes) {
        for (final color in _selectedColors) {
          _variants.add({
            'size': size,
            'color': color,
            'barcode': null,
            'buy_price': _unifiedBuyPrice,
            'sell_price': _unifiedSellPrice,
            'unit_type': _unitType,
            'units_per_carton': _unitType == 'carton' ? _unitsPerCarton : null,
          });
        }
      }
    });
  }

  void _applyUnifiedPrice() {
    setState(() {
      for (final v in _variants) {
        v['buy_price'] = _unifiedBuyPrice.toString();
        v['sell_price'] = _unifiedSellPrice.toString();
      }
    });
  }

  String _generateLocalBarcode() {
    final random = Random();
    final number = 100000 + random.nextInt(900000);
    return 'SHO-$number';
  }

  Future<void> _copyFromExistingProduct() async {
    try {
      final products = await Supabase.instance.client
          .from('products')
          .select('id, name, category, product_variants(size, color)')
          .eq('is_active', true)
          .order('name');

      if (!mounted) return;

      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) {
          final searchCtrl = TextEditingController();
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final filtered = products.where((p) {
                final q = searchCtrl.text.toLowerCase();
                return q.isEmpty || (p['name'] as String).toLowerCase().contains(q);
              }).toList();

              return AlertDialog(
                title: Text(S.t('prod_copy_from')),
                content: SizedBox(
                  width: 400,
                  height: 400,
                  child: Column(
                    children: [
                      TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Rechercher...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final p = filtered[i];
                            final variants = (p['product_variants'] as List<dynamic>?) ?? [];
                            final colors = variants.map((v) => v['color'] as String).toSet().toList();
                            return ListTile(
                              title: Text(p['name'] ?? ''),
                              subtitle: Text('${p['category'] ?? 'homme'} · ${colors.join(', ')}'),
                              onTap: () => Navigator.pop(ctx, p),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (selected != null && mounted) {
        _nameController.text = selected['name'] ?? '';
        final existingVariants = (selected['product_variants'] as List<dynamic>?) ?? [];
        final colors = existingVariants.map((v) => v['color'] as String).where((c) => c.isNotEmpty).toSet().toList();
        final sizes = existingVariants.map((v) => v['size'] as String).where((s) => s.isNotEmpty).toSet().toList();
        setState(() {
          _selectedCategory = selected['category'] ?? 'homme';
          _selectedColors = colors;
          _selectedSizes = sizes;
        });
      }
    } catch (e) {
      debugPrint("Error copying product: $e");
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    for (var v in _variants) {
      final sellPriceStr = v['sell_price'].toString();
      final buyPriceStr = v['buy_price'].toString();
      if ((v['size'] as String).isEmpty || (v['color'] as String).isEmpty ||
          sellPriceStr.isEmpty || buyPriceStr.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('auth_fill_fields')), backgroundColor: Colors.red),
        );
        return;
      }
      if (double.tryParse(sellPriceStr) == null || double.tryParse(buyPriceStr) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('msg_invalid')), backgroundColor: Colors.red),
        );
        return;
      }
    }

    if (_selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('pos_select_store')), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imageUrl = await _uploadImage();

      final productRes = await Supabase.instance.client.from('products').insert({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'supplier_id': _selectedSupplierId,
        'image_url': imageUrl,
        'category': _selectedCategory,
        'is_active': true,
      }).select('id').single();

      final productId = productRes['id'];

      for (var variant in _variants) {
        final variantRes = await Supabase.instance.client.from('product_variants').insert({
          'product_id': productId,
          'size': variant['size'].toString().trim(),
          'color': variant['color'].toString().trim(),
          'barcode': null,
          'buy_price': double.tryParse(variant['buy_price'].toString()) ?? 0.0,
          'sell_price': double.tryParse(variant['sell_price'].toString()) ?? 0.0,
          'unit_type': variant['unit_type'] ?? 'piece',
          'units_per_carton': variant['units_per_carton'],
          'is_active': true,
        }).select('id').single();

        final variantId = variantRes['id'];

        await Supabase.instance.client.from('inventory').insert({
          'variant_id': variantId,
          'store_id': _selectedStoreId,
          'quantity': 0,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('prod_add_product_success')), backgroundColor: Colors.green),
        );

        _formKey.currentState!.reset();
        _nameController.clear();
        _descController.clear();
        setState(() {
          _imageFile = null;
          _imageBytes = null;
          _variants.clear();
          _selectedCategory = 'homme';
          _selectedColors = [];
          _selectedSizes = [];
          _unitType = 'piece';
          _unifiedBuyPrice = 0;
          _unifiedSellPrice = 0;
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.code == '42501' ? S.t('msg_access_denied') : '${S.t('msg_error')}: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(S.t('prod_add_title')),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _blocked
        ? const SizedBox.shrink()
        : _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _imageFile != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_imageFile!, fit: BoxFit.cover))
                            : _imageBytes != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    Text(S.t('prod_image'), style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 32),

                      Expanded(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(labelText: S.t('prod_name'), border: const OutlineInputBorder()),
                              validator: (v) => v!.isEmpty ? S.t('msg_required') : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descController,
                              maxLines: 3,
                                decoration: InputDecoration(labelText: S.t('label_description'), border: const OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration: InputDecoration(labelText: S.t('label_supplier'), border: const OutlineInputBorder()),
                                    value: _selectedSupplierId,
                                    items: _suppliers.map((s) => DropdownMenuItem<String>(
                                      value: s['id'],
                                      child: Text(s['company_name']),
                                    )).toList(),
                                    onChanged: (val) => setState(() => _selectedSupplierId = val),
                                    hint: Text(S.t('misc_loading')),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration: InputDecoration(labelText: S.t('label_store'), border: const OutlineInputBorder()),
                                    value: _selectedStoreId,
                                    items: _stores.map((s) => DropdownMenuItem<String>(
                                      value: s['id'],
                                      child: Text(s['name']),
                                    )).toList(),
                                    onChanged: (val) => setState(() => _selectedStoreId = val),
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // --- VARIANTS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Variantes (Pointures & Couleurs)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        onPressed: _addVariant,
                        icon: const Icon(Icons.add),
                        label: Text(S.t('prod_add_variant_btn')),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[50], foregroundColor: Colors.teal),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),

                  ..._variants.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> v = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: v['size'] as String,
                                    decoration: InputDecoration(labelText: S.t('prod_size'), isDense: true),
                                    onChanged: (val) => v['size'] = val,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: v['color'] as String,
                                    decoration: InputDecoration(labelText: S.t('prod_color'), isDense: true),
                                    onChanged: (val) => v['color'] = val,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: v['barcode'] as String?,
                                    decoration: InputDecoration(
                                      labelText: S.t('prod_barcode'),
                                      isDense: true,
                                      hintText: 'Auto',
                                      hintStyle: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                    ),
                                    onChanged: (val) => v['barcode'] = val,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: _variants.length > 1 ? () => _removeVariant(index) : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(width: 32),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: v['buy_price'].toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: S.t('prod_buy_price'),
                                      isDense: true,
                                      prefixIcon: const Icon(Icons.arrow_downward, color: Colors.orange, size: 18),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange[200]!)),
                                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                                    ),
                                    onChanged: (val) => v['buy_price'] = val,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: v['sell_price'].toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: S.t('prod_sell_price'),
                                      isDense: true,
                                      prefixIcon: const Icon(Icons.arrow_upward, color: Colors.green, size: 18),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green[200]!)),
                                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                                    ),
                                    onChanged: (val) => v['sell_price'] = val,
                                  ),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveProduct,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      child: Text(S.t('action_save'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
