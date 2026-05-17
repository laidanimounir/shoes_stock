import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';

const Color kPrimaryColor = Color(0xFF1B4F72);
const Color kAccentGreen = Color(0xFF2ECC71);
const Color kWarningOrange = Color(0xFFE67E22);
const Color kBackgroundColor = Color(0xFFF5F7FA);
const double kBorderRadius = 12.0;

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
  int _currentStep = 0;

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

  // ─── Helpers ───────────────────────────────────────────────

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  double get _marginAmount => _unifiedSellPrice - _unifiedBuyPrice;
  double get _marginPercent =>
    _unifiedBuyPrice > 0 ? (_marginAmount / _unifiedBuyPrice * 100) : 0;

  double get _avgBuyPrice {
    if (_variants.isEmpty) return 0;
    final sum = _variants.fold<double>(
      0, (s, v) => s + (double.tryParse(v['buy_price'].toString()) ?? 0));
    return sum / _variants.length;
  }

  double get _avgSellPrice {
    if (_variants.isEmpty) return 0;
    final sum = _variants.fold<double>(
      0, (s, v) => s + (double.tryParse(v['sell_price'].toString()) ?? 0));
    return sum / _variants.length;
  }

  bool get _canGoToStep2 => _nameController.text.trim().isNotEmpty;

  bool get _canGoToStep3 =>
    _selectedSizes.isNotEmpty &&
    _selectedColors.isNotEmpty &&
    _variants.isNotEmpty;

  bool get _canSave {
    if (_variants.isEmpty) return false;
    for (var v in _variants) {
      final buy = double.tryParse(v['buy_price'].toString()) ?? 0;
      final sell = double.tryParse(v['sell_price'].toString()) ?? 0;
      if (buy <= 0 || sell <= buy) return false;
    }
    return true;
  }

  TextStyle get _titleStyle =>
    GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryColor);

  TextStyle get _sectionStyle =>
    GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600, color: kPrimaryColor);

  TextStyle get _labelStyle =>
    GoogleFonts.raleway(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]);

  // ─── Step Indicator ────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
      ),
      child: Center(
        child: SizedBox(
          width: 400,
          child: Row(
            children: List.generate(3, (i) {
              final isCompleted = _currentStep > i;
              final isCurrent = _currentStep == i;
              return Expanded(
                child: Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted || isCurrent
                              ? kPrimaryColor
                              : Colors.grey[300],
                        ),
                      ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? kAccentGreen
                            : isCurrent
                                ? kPrimaryColor
                                : Colors.transparent,
                        border: Border.all(
                          color: isCompleted || isCurrent
                              ? (isCompleted ? kAccentGreen : kPrimaryColor)
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: isCurrent ? Colors.white : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    if (i < 2)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted
                              ? kAccentGreen
                              : Colors.grey[300],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ─── STEP 1 ────────────────────────────────────────────────

  Widget _buildStep1() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(kBorderRadius),
                        border: Border.all(
                          color: _imageFile != null || _imageBytes != null
                              ? Colors.transparent
                              : Colors.grey[400]!,
                          width: 2,
                          style: _imageFile != null || _imageBytes != null
                              ? BorderStyle.solid
                              : BorderStyle.solid,
                        ),
                      ),
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(kBorderRadius),
                              child: Image.file(_imageFile!, fit: BoxFit.cover),
                            )
                          : _imageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(kBorderRadius),
                                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, size: 36, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text('Ajouter\nune photo',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                    ),
                                  ],
                                ),
                    ),
                    if (_imageFile != null || _imageBytes != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 12),
                              SizedBox(width: 2),
                              Text('Compressée ✓',
                                style: TextStyle(color: Colors.white, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Général
            Text('Informations générales', style: _sectionStyle),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '${S.t('prod_name')} *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) => v!.isEmpty ? S.t('msg_required') : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: S.t('label_description'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Catégorie
            Text('Catégorie', style: _sectionStyle),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildCategoryButton('homme', '👨 Homme'),
                const SizedBox(width: 12),
                _buildCategoryButton('femme', '👩 Femme'),
                const SizedBox(width: 12),
                _buildCategoryButton('enfant', '👶 Enfant'),
              ],
            ),
            const SizedBox(height: 24),

            // Magasin
            Text('Magasin', style: _sectionStyle),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: S.t('label_store'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
                filled: true,
                fillColor: Colors.white,
              ),
              value: _selectedStoreId,
              items: _stores.map((s) => DropdownMenuItem<String>(
                value: s['id'],
                child: Text(s['name'] ?? ''),
              )).toList(),
              onChanged: (val) => setState(() => _selectedStoreId = val),
            ),
            const SizedBox(height: 24),

            // Template
            OutlinedButton.icon(
              onPressed: _copyFromExistingProduct,
              icon: const Icon(Icons.content_copy, size: 18),
              label: Text('📋 Copier depuis un produit existant',
                style: GoogleFonts.raleway(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryColor,
                side: BorderSide(color: kPrimaryColor.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),

            const Spacer(),
            // Navigation
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canGoToStep2
                    ? () => setState(() => _currentStep = 1)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
                  elevation: 2,
                ),
                child: Text('Suivant  →',
                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String value, String label) {
    final selected = _selectedCategory == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = value;
            _selectedSizes.clear();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? kPrimaryColor : Colors.white,
            borderRadius: BorderRadius.circular(kBorderRadius),
            border: Border.all(
              color: selected ? kPrimaryColor : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  // ─── STEP 2 ────────────────────────────────────────────────

  Widget _buildStep2() {
    final sizes = kSizesByCategory[_selectedCategory] ?? [];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pointures
              Text('Sélectionner les pointures', style: _sectionStyle),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...sizes.map((s) => FilterChip(
                    label: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
                    selected: _selectedSizes.contains(s),
                    onSelected: (_) => _toggleSize(s),
                    selectedColor: kPrimaryColor,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: _selectedSizes.contains(s) ? Colors.white : Colors.grey[700],
                    ),
                    side: BorderSide(
                      color: _selectedSizes.contains(s) ? kPrimaryColor : Colors.grey[300]!,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  )),
                  ..._selectedSizes
                    .where((s) => !sizes.contains(s))
                    .map((s) => Chip(
                      label: Text(s, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                      backgroundColor: kPrimaryColor,
                      deleteIcon: const Icon(Icons.close, color: Colors.white, size: 16),
                      onDeleted: () => _toggleSize(s),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    )),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Pointure personnalisée',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (val) {
                        if (val.isNotEmpty) _addCustomSize(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: kPrimaryColor),
                    onPressed: () {
                      // simple approach: we use a small dialog
                      final ctrl = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Ajouter une pointure'),
                          content: TextField(
                            controller: ctrl,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Ex: 47, 48...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(S.t('action_cancel')),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _addCustomSize(ctrl.text.trim());
                                Navigator.pop(ctx);
                              },
                              child: const Text('Ajouter'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Couleurs
              Text('Sélectionner les couleurs', style: _sectionStyle),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...kShoeColors.map((c) {
                    final name = c['name'] as String;
                    final hex = c['hex'] as String;
                    final isSelected = _selectedColors.contains(name);
                    return GestureDetector(
                      onTap: () => _toggleColor(name),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _hexToColor(hex),
                          border: Border.all(
                            color: isSelected ? kPrimaryColor : Colors.grey[300]!,
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 6)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }),
                  ..._selectedColors
                    .where((name) => !kShoeColors.any((c) => c['name'] == name))
                    .map((name) => Chip(
                      label: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      backgroundColor: Colors.grey[200],
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _toggleColor(name),
                    )),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Couleur personnalisée',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (val) {
                        if (val.isNotEmpty) _toggleColor(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: kPrimaryColor),
                    onPressed: () {
                      final ctrl = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Ajouter une couleur'),
                          content: TextField(
                            controller: ctrl,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Nom de la couleur',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(S.t('action_cancel')),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final val = ctrl.text.trim();
                                if (val.isNotEmpty) _toggleColor(val);
                                Navigator.pop(ctx);
                              },
                              child: const Text('Ajouter'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Unité
              Text('Unité de stock', style: _sectionStyle),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildUnitButton('piece', '📦 Pièce')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildUnitButton('carton', '🗃️ Carton')),
                ],
              ),
              if (_unitType == 'carton') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Pièces par carton:'),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        controller: TextEditingController(text: '$_unitsPerCarton'),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed > 0) {
                            setState(() => _unitsPerCarton = parsed);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Compteur
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(kBorderRadius),
                  border: Border.all(color: kPrimaryColor.withOpacity(0.15)),
                ),
                child: Text(
                  '${_selectedSizes.length} pointure${_selectedSizes.length > 1 ? 's' : ''} × '
                  '${_selectedColors.length} couleur${_selectedColors.length > 1 ? 's' : ''} = '
                  '${_selectedSizes.length * _selectedColors.length} variantes',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600, color: kPrimaryColor),
                ),
              ),
              const SizedBox(height: 16),

              // Générer
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_selectedSizes.isEmpty || _selectedColors.isEmpty)
                      ? null
                      : _generateVariants,
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text('✨ Générer les variantes',
                    style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
                    elevation: 2,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Navigation
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep = 0),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
                        ),
                        child: const Text('← Retour',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _canGoToStep3
                            ? () => setState(() => _currentStep = 2)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
                          elevation: 2,
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: Text('Suivant  →',
                          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitButton(String value, String label) {
    final selected = _unitType == value;
    return GestureDetector(
      onTap: () => setState(() => _unitType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? kPrimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(kBorderRadius),
          border: Border.all(
            color: selected ? kPrimaryColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  // ─── STEP 3 ────────────────────────────────────────────────

  Widget _buildStep3() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Prix uniforme
              Text('Prix uniforme', style: _sectionStyle),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '💰 Prix d\'achat (DA)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              controller: TextEditingController(
                                text: _unifiedBuyPrice > 0 ? _unifiedBuyPrice.toString() : '',
                              ),
                              onChanged: (val) {
                                final parsed = double.tryParse(val);
                                if (parsed != null) _unifiedBuyPrice = parsed;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '🏷️ Prix de vente (DA)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              controller: TextEditingController(
                                text: _unifiedSellPrice > 0 ? _unifiedSellPrice.toString() : '',
                              ),
                              onChanged: (val) {
                                final parsed = double.tryParse(val);
                                if (parsed != null) _unifiedSellPrice = parsed;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _applyUnifiedPrice,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kPrimaryColor,
                              side: BorderSide(color: kPrimaryColor.withOpacity(0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Appliquer à toutes les variantes',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          const Spacer(),
                          if (_unifiedBuyPrice > 0 && _unifiedSellPrice > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: kAccentGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Marge: +${_marginAmount.toStringAsFixed(0)} DA (+${_marginPercent.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  color: kAccentGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tableau des variantes
              Text('Tableau des variantes', style: _sectionStyle),
              const SizedBox(height: 12),
              if (_variants.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(kBorderRadius),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Générez d\'abord les variantes (étape 2)',
                        style: TextStyle(color: Colors.grey[500], fontSize: 15),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(kBorderRadius),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          color: kPrimaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Expanded(flex: 2, child: Text('Code-barres',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              const Expanded(flex: 1, child: Text('Pointure',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              const Expanded(flex: 1, child: Text('Couleur',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              const Expanded(flex: 1, child: Text('Achat',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              const Expanded(flex: 1, child: Text('Vente',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                        // Rows
                        ...List.generate(_variants.length, (i) {
                          final v = _variants[i];
                          final buy = double.tryParse(v['buy_price'].toString()) ?? 0;
                          final sell = double.tryParse(v['sell_price'].toString()) ?? 0;
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text('Auto',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontStyle: FontStyle.italic,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(v['size'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _getColorForName(v['color'] as String),
                                            border: Border.all(color: Colors.grey[300]!),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(v['color'] as String,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: SizedBox(
                                      height: 32,
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        controller: TextEditingController(text: buy > 0 ? buy.toString() : ''),
                                        onChanged: (val) => v['buy_price'] = val,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: SizedBox(
                                      height: 32,
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        controller: TextEditingController(text: sell > 0 ? sell.toString() : ''),
                                        onChanged: (val) => v['sell_price'] = val,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    onPressed: () => _removeVariant(i),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        // Margin summary footer
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.grey[50],
                          child: Row(
                            children: [
                              const Spacer(),
                              Text(
                                'Marge totale: ${_variants.fold<double>(0, (s, v) {
                                  final b = double.tryParse(v['buy_price'].toString()) ?? 0;
                                  final sl = double.tryParse(v['sell_price'].toString()) ?? 0;
                                  return s + (sl - b);
                                }).toStringAsFixed(0)} DA',
                                style: TextStyle(
                                  color: kAccentGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Résumé
              if (_variants.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(kBorderRadius),
                    border: Border.all(color: kPrimaryColor.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('📦', '${_variants.length} variantes'),
                      _buildSummaryItem('🎨', '${_selectedColors.length} couleurs'),
                      _buildSummaryItem('👟', '${_selectedSizes.length} pointures'),
                      _buildSummaryItem('💰', '${_avgBuyPrice.toStringAsFixed(0)} DA / ${_avgSellPrice.toStringAsFixed(0)} DA'),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // Save
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveProduct,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isLoading ? 'Enregistrement...' : '💾 Enregistrer le produit',
                    style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
                    elevation: 4,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Navigation retour
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[400]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
                  ),
                  child: const Text('← Retour',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String emoji, String text) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(text,
          style: GoogleFonts.raleway(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kPrimaryColor,
          ),
        ),
      ],
    );
  }

  Color _getColorForName(String name) {
    for (final c in kShoeColors) {
      if (c['name'] == name) return _hexToColor(c['hex'] as String);
    }
    return Colors.grey;
  }

  // ─── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.t('prod_add_title'),
              style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Étape ${_currentStep + 1} / 3',
              style: GoogleFonts.raleway(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: _blocked
        ? const SizedBox.shrink()
        : Column(
            children: [
              _buildStepIndicator(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : IndexedStack(
                        index: _currentStep,
                        children: [
                          _buildStep1(),
                          _buildStep2(),
                          _buildStep3(),
                        ],
                      ),
              ),
            ],
          ),
    );
  }
}
