import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class VariantFormData {
  String size = '';
  String color = '';
  String barcode = '';
  String buyPrice = '';
  String sellPrice = '';
}

class AjouterProduitScreen extends StatefulWidget {
  const AjouterProduitScreen({super.key});

  @override
  State<AjouterProduitScreen> createState() => _AjouterProduitScreenState();
}

class _AjouterProduitScreenState extends State<AjouterProduitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  List<dynamic> _suppliers = [];
  String? _selectedSupplierId;

  List<dynamic> _stores = [];
  String? _selectedStoreId;

  String? _userRole;
  String? _userStoreId;

  final List<VariantFormData> _variants = [VariantFormData()]; 
  
  File? _imageFile;
  Uint8List? _imageBytes; 
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Fetch user role and store_id
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('role, store_id')
            .eq('id', user.id)
            .single();
        _userRole = profile['role'];
        _userStoreId = profile['store_id'];
      }

      final futures = await Future.wait([
        Supabase.instance.client.from('suppliers').select().eq('is_active', true),
        Supabase.instance.client.from('stores').select().eq('is_active', true),
      ]);
      
      if (mounted) {
        setState(() {
          _suppliers = futures[0];
          _stores = futures[1];
          // Employee: lock to their store; Owner: default to first store
          if (_userRole == 'employee' && _userStoreId != null) {
            _selectedStoreId = _userStoreId;
          } else if (_stores.isNotEmpty) {
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
          setState(() {
            _imageFile = File(image.path);
            _imageBytes = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
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

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    
    for (var v in _variants) {
      if (v.size.isEmpty || v.color.isEmpty || v.barcode.isEmpty || v.sellPrice.isEmpty || v.buyPrice.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez remplir tous les champs des variantes (y compris les prix).'), backgroundColor: Colors.red),
        );
        return;
      }
      if (double.tryParse(v.sellPrice) == null || double.tryParse(v.buyPrice) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez entrer des prix valides.'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    if (_selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un magasin.'), backgroundColor: Colors.red),
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
        'is_active': true, 
      }).select('id').single();

      final productId = productRes['id'];

      
      for (var variant in _variants) {
        final variantRes = await Supabase.instance.client.from('product_variants').insert({
          'product_id': productId,
          'size': variant.size.trim(),
          'color': variant.color.trim(),
          'barcode': variant.barcode.trim(),
          'buy_price': double.tryParse(variant.buyPrice) ?? 0.0,
          'sell_price': double.tryParse(variant.sellPrice) ?? 0.0,
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
          const SnackBar(content: Text('Produit ajouté avec succès !'), backgroundColor: Colors.green),
        );
       
        _formKey.currentState!.reset();
        _nameController.clear();
        _descController.clear();
        setState(() {
          _imageFile = null;
          _imageBytes = null;
          _variants.clear();
          _variants.add(VariantFormData());
        });
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

  void _addVariant() {
    setState(() {
      _variants.add(VariantFormData());
    });
  }

  void _removeVariant(int index) {
    if (_variants.length > 1) {
      setState(() {
        _variants.removeAt(index);
      });
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
        title: const Text('Ajouter un Produit (Chaussure)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
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
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Ajouter une photo', style: TextStyle(color: Colors.grey)),
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
                              decoration: const InputDecoration(labelText: 'Nom du Produit', border: OutlineInputBorder()),
                              validator: (v) => v!.isEmpty ? 'Requis' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descController,
                              maxLines: 3,
                              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(labelText: 'Fournisseur', border: OutlineInputBorder()),
                                    value: _selectedSupplierId,
                                    items: _suppliers.map((s) => DropdownMenuItem<String>(
                                      value: s['id'],
                                      child: Text(s['company_name']),
                                    )).toList(),
                                    onChanged: (val) => setState(() => _selectedSupplierId = val),
                                    hint: const Text('Sélectionnez...'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _userRole == 'employee'
                                    ? TextFormField(
                                        readOnly: true,
                                        decoration: const InputDecoration(labelText: 'Magasin', border: OutlineInputBorder()),
                                        initialValue: _stores.where((s) => s['id'] == _userStoreId).isNotEmpty
                                            ? _stores.firstWhere((s) => s['id'] == _userStoreId)['name']
                                            : 'Mon magasin',
                                      )
                                    : DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(labelText: 'Magasin', border: OutlineInputBorder()),
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
                        label: const Text('Ajouter une Variante'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[50], foregroundColor: Colors.teal),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  ..._variants.asMap().entries.map((entry) {
                    int index = entry.key;
                    VariantFormData v = entry.value;
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
                                    initialValue: v.size,
                                    decoration: const InputDecoration(labelText: 'Pointure (ex: 42)', isDense: true),
                                    onChanged: (val) => v.size = val,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: v.color,
                                    decoration: const InputDecoration(labelText: 'Couleur', isDense: true),
                                    onChanged: (val) => v.color = val,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: v.barcode,
                                    decoration: const InputDecoration(labelText: 'Code-barres', isDense: true),
                                    onChanged: (val) => v.barcode = val,
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
                                    initialValue: v.buyPrice,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: "Prix d'achat (DA)",
                                      isDense: true,
                                      prefixIcon: const Icon(Icons.arrow_downward, color: Colors.orange, size: 18),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange[200]!)),
                                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                                    ),
                                    onChanged: (val) => v.buyPrice = val,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: v.sellPrice,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Prix de vente (DA)',
                                      isDense: true,
                                      prefixIcon: const Icon(Icons.arrow_upward, color: Colors.green, size: 18),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green[200]!)),
                                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                                    ),
                                    onChanged: (val) => v.sellPrice = val,
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
                      child: const Text('Enregistrer le produit et les variantes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}