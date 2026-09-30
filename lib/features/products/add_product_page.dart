import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import 'ai_enhancer_sheets.dart';

class _ProductColorOpt {
  String name;
  String hex;
  String? imageUrl;

  _ProductColorOpt({
    required this.name,
    required this.hex,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'hex': hex,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      };
}

List<_ProductColorOpt> _parseColors(dynamic raw) {
  if (raw is! List) return [];
  final out = <_ProductColorOpt>[];
  final seen = <String>{};
  for (final entry in raw) {
    String name = '';
    String hex = '#cccccc';
    String? imageUrl;
    if (entry is String) {
      name = entry.trim();
    } else if (entry is Map) {
      final o = Map<String, dynamic>.from(entry);
      name = (o['name'] ?? o['label'] ?? o['color'] ?? '').toString().trim();
      hex = (o['hex'] ?? o['value'] ?? o['code'] ?? '#cccccc').toString().trim();
      final img = (o['imageUrl'] ?? o['image'] ?? o['image_url'])?.toString().trim();
      imageUrl = (img != null && img.isNotEmpty) ? img : null;
    }
    if (name.isEmpty) continue;
    final key = name.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    out.add(_ProductColorOpt(name: name, hex: hex, imageUrl: imageUrl));
  }
  return out;
}



class AddProductPage extends StatefulWidget {
  final String shopUuid;
  final String? productUuid;
  final bool hasBarcode;

  const AddProductPage({
    super.key,
    required this.shopUuid,
    this.productUuid,
    this.hasBarcode = true,
  });

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _product = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _barcode = TextEditingController();
  final _avgPrice = TextEditingController();
  final _shopPrice = TextEditingController();
  final _stock = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  String? _categoryUuid;
  String _taxStatus = 'taxable';
  String _pricingType = 'fixed';
  late bool _hasBarcode;
  final List<File> _newImages = [];
  final List<String> _existingImageUrls = [];
  final List<_ProductColorOpt> _colors = [];
  final Map<int, String> _photoColorNames = {};

  String? _originalStock;
  bool _busy = false;
  bool _loadingCats = true;
  bool _loadingProduct = false;
  String? _error;
  String? _catalogHint;
  bool _lookingUp = false;

  bool get _isEdit =>
      widget.productUuid != null && widget.productUuid!.isNotEmpty;

  String get _categoryDisplayName {
    for (final c in _categories) {
      if (c['uuid']?.toString() == _categoryUuid) {
        return c['category_name']?.toString() ?? 'Selected Category';
      }
    }
    return 'Select Category';
  }

  @override
  void initState() {
    super.initState();
    _hasBarcode = widget.hasBarcode;
    if (_isEdit) {
      _loadingProduct = true;
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _product.dispose();
    _name.dispose();
    _description.dispose();
    _barcode.dispose();
    _avgPrice.dispose();
    _shopPrice.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_isEdit) {
      try {
        await Future.wait([
          _loadCategories(),
          _loadProduct(),
        ]);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = OnboardingApi.toUserMessage(e);
        });
      } finally {
        if (mounted) {
          setState(() {
            _loadingProduct = false;
          });
        }
      }
    } else {
      await _loadCategories();
    }
  }

  Future<void> _loadProduct() async {
    final p = await OnboardingApi.getProduct(
      shopUuid: widget.shopUuid,
      productUuid: widget.productUuid!,
    );
    if (!mounted) return;
    final catUuid = (p['category_uuid'] ??
            (p['category'] is Map ? p['category']['uuid'] : null))
        ?.toString();
    final avg = p['average_selling_price'] ?? p['compare_at_price'];
    final tax = (p['tax_status'] ?? '').toString().toLowerCase();
    final stockVal = (p['stock_quantity'] ?? 0).toString();
    final urls = _parseImageUrlList(p);

    setState(() {
      _product.text =
          (p['brand_name'] ?? p['product_brand'] ?? '').toString();
      _name.text = (p['item_name'] ?? '').toString();
      _description.text = (p['description'] ?? '').toString();
      _barcode.text = (p['barcode'] ?? '').toString();
      _avgPrice.text =
          avg == null || avg.toString() == 'null' ? '' : avg.toString();
      _shopPrice.text = (p['selling_price'] ?? '').toString();
      _originalStock = stockVal;
      _stock.text = ''; // Empty by default on edit to preserve existing stock unless typed
      _taxStatus = tax == 'exempt' ? 'exempt' : 'taxable';
      final pt = (p['pricing_type'] ?? 'fixed').toString().toLowerCase();
      _pricingType = ['fixed', 'variable', 'dynamic'].contains(pt) ? pt : 'fixed';
      final hb = p['has_barcode'];
      if (hb is bool) {
        _hasBarcode = hb;
      } else {
        _hasBarcode = _barcode.text.trim().isNotEmpty;
      }
      if (catUuid != null && catUuid.isNotEmpty) {
        _categoryUuid = catUuid;
      }
      _existingImageUrls
        ..clear()
        ..addAll(urls);
      _newImages.clear();
      _colors
        ..clear()
        ..addAll(_parseColors(p['colors']));
      _photoColorNames.clear();
      for (final c in _colors) {
        final u = c.imageUrl;
        if (u != null) {
          final idx = _existingImageUrls.indexOf(u);
          if (idx >= 0) {
            _photoColorNames[idx] = c.name;
          }
        }
      }

      _catalogHint = 'Edit catalog item and save changes.';
    });

    if (catUuid != null &&
        catUuid.isNotEmpty &&
        !_categories.any((c) => c['uuid']?.toString() == catUuid)) {
      await _loadCategories(selectUuid: catUuid);
    }
  }

  Future<void> _loadCategories({String? selectUuid}) async {
    setState(() {
      _loadingCats = true;
      _error = null;
    });
    try {
      final rows = await OnboardingApi.listCategories();
      final mapped = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      setState(() {
        _categories = mapped;
        _categoryUuid = selectUuid ??
            (_categoryUuid != null &&
                    mapped.any((c) => c['uuid']?.toString() == _categoryUuid)
                ? _categoryUuid
                : mapped.isNotEmpty
                    ? mapped.first['uuid']?.toString()
                    : null);
        _loadingCats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCats = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openCategorySheet() async {
    if (_categories.isEmpty) return;
    final picked = await showCategoryPickerBottomSheet(
      context: context,
      categories: _categories,
      selectedUuid: _categoryUuid,
    );
    if (picked != null && mounted) {
      setState(() => _categoryUuid = picked);
    }
  }

  Future<void> _showCreateCategoryDialog() async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const _CreateCategoryDialog(),
    );

    if (created == null || !mounted) return;

    final uuid = created['uuid']?.toString();
    final name = (created['category_name'] ?? '').toString();

    // Optimistically select the new category so the form updates immediately.
    setState(() {
      final exists = _categories.any((c) => c['uuid']?.toString() == uuid);
      if (!exists && uuid != null && uuid.isNotEmpty) {
        _categories = [
          ..._categories,
          {
            'uuid': uuid,
            'category_name': name,
            'slug': created['slug'],
            'description': created['description'],
            'image_url': created['image_url'],
          },
        ];
      }
      if (uuid != null && uuid.isNotEmpty) {
        _categoryUuid = uuid;
      }
      _error = null;
    });

    // Refresh from server in the background (no full-screen loading flicker).
    try {
      final rows = await OnboardingApi.listCategories(forceRefresh: true);
      if (!mounted) return;
      final mapped =
          rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _categories = mapped;
        if (uuid != null &&
            uuid.isNotEmpty &&
            mapped.any((c) => c['uuid']?.toString() == uuid)) {
          _categoryUuid = uuid;
        }
      });
    } catch (_) {
      // Keep optimistic local list; category was already created.
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          name.isEmpty
              ? 'Category created successfully'
              : 'Category "$name" created successfully',
        ),
        backgroundColor: const Color(0xFF15803D),
      ),
    );
  }

  List<String> _parseImageUrlList(Map<String, dynamic> source) {
    final out = <String>[];
    void push(dynamic v) {
      final s = v?.toString().trim() ?? '';
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
    }

    final urls = source['image_urls'] ?? source['imageUrls'];
    if (urls is List) {
      for (final u in urls) {
        push(u);
      }
    } else if (urls is String && urls.trim().isNotEmpty) {
      final raw = urls.trim();
      if (raw.startsWith('[')) {
        try {
          // Lightweight JSON array parse without dart:convert dependency here —
          // urls from API are usually List; string path is rare.
          final cleaned = raw.substring(1, raw.length - 1);
          for (final part in cleaned.split(',')) {
            push(part.replaceAll('"', '').replaceAll("'", '').trim());
          }
        } catch (_) {
          push(raw);
        }
      } else {
        push(raw);
      }
    }
    push(source['product_image'] ?? source['image_url']);
    return out;
  }

  Future<void> _applyCatalogLookup(String code) async {
    setState(() {
      _lookingUp = true;
      _catalogHint = 'Searching barcode in Troskit catalog…';
    });
    try {
      final hit = await OnboardingApi.lookupCatalog(
        shopUuid: widget.shopUuid,
        barcode: code,
      );
      if (!mounted) return;

      final autofill = hit['autofill'] is Map
          ? Map<String, dynamic>.from(hit['autofill'] as Map)
          : null;
      final master = hit['master_product'] is Map
          ? Map<String, dynamic>.from(hit['master_product'] as Map)
          : null;
      final shopProduct = hit['shop_product'] is Map
          ? Map<String, dynamic>.from(hit['shop_product'] as Map)
          : null;
      final source = autofill ?? master;

      if (source != null || shopProduct != null) {
        final name = (source?['item_name'] ?? shopProduct?['item_name'] ?? '')
            .toString();
        final productLabel = (source?['brand_name'] ??
                source?['product'] ??
                source?['brand'] ??
                shopProduct?['brand_name'] ??
                shopProduct?['product_brand'] ??
                '')
            .toString();
        final avg = source?['average_selling_price'] ??
            master?['average_selling_price'] ??
            shopProduct?['average_selling_price'];
        final tax = (source?['tax_status'] ??
                master?['tax_status'] ??
                shopProduct?['tax_status'] ??
                '')
            .toString()
            .toLowerCase();
        final catUuid = (source?['category_uuid'] ??
                shopProduct?['category_uuid'] ??
                hit['suggested_category_uuid'])
            ?.toString();
        final photoSource = shopProduct ?? source ?? <String, dynamic>{};
        final urls = _parseImageUrlList(photoSource);

        setState(() {
          if (name.isNotEmpty) _name.text = name;
          if (productLabel.isNotEmpty) _product.text = productLabel;
          if (avg != null && avg.toString().isNotEmpty && avg.toString() != 'null') {
            _avgPrice.text = avg.toString();
          }
          if (!_isEdit) {
            _shopPrice.clear();
          }
          if (tax == 'exempt') {
            _taxStatus = 'exempt';
          } else if (tax.isNotEmpty) {
            _taxStatus = 'taxable';
          }
          if (catUuid != null &&
              catUuid.isNotEmpty &&
              _categories.any((c) => c['uuid']?.toString() == catUuid)) {
            _categoryUuid = catUuid;
          }
          if (urls.isNotEmpty) {
            _existingImageUrls
              ..clear()
              ..addAll(urls);
          }
          final shopDesc = (shopProduct?['description'] ??
                  source?['description'] ??
                  master?['description'] ??
                  '')
              .toString()
              .trim();
          if (shopDesc.isNotEmpty && _description.text.trim().isEmpty) {
            _description.text = shopDesc;
          }
          final shopColors = _parseColors(shopProduct?['colors']);
          if (shopColors.isNotEmpty && _colors.isEmpty) {
            _colors
              ..clear()
              ..addAll(shopColors);
          }

          _catalogHint = hit['message']?.toString();
          _lookingUp = false;
        });
      } else {
        setState(() {
          if (!_isEdit) {
            _shopPrice.clear();
          }
          _catalogHint = hit['message']?.toString() ??
              'New barcode — enter item details for this shop.';
          _lookingUp = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lookingUp = false;
        _catalogHint = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _scanBarcode() async {
    final code = await context.push<String>('/scanner');
    if (code != null && code.isNotEmpty && mounted) {
      setState(() => _barcode.text = code);
      await _applyCatalogLookup(code);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final List<XFile> pickedFiles = [];
    if (source == ImageSource.gallery) {
      final xs = await ImagePicker().pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (xs.isEmpty) return;
      pickedFiles.addAll(xs);
    } else {
      final x = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (x != null) pickedFiles.add(x);
    }

    if (pickedFiles.isEmpty) return;

    for (final x in pickedFiles) {
      var newFile = File(x.path);
      if (!mounted) return;
      final ai = await showAiEnhancerSheet(
        context: context,
        originalFile: newFile,
      );
      newFile = ai.file;
      if (!mounted) return;
      setState(() {
        _newImages.add(newFile);
      });
      final photoIndex = _existingImageUrls.length + _newImages.length - 1;
      await _promptColorForPhoto(photoIndex: photoIndex, localFile: newFile);
    }
  }

  /// AI Enhancer from an existing gallery thumb (edit later).
  Future<void> _enhanceGalleryPhoto(int photoIndex) async {
    final isExisting = photoIndex < _existingImageUrls.length;
    late File sourceFile;
    String? remoteUrl;

    if (isExisting) {
      remoteUrl = _existingImageUrls[photoIndex];
      try {
        sourceFile = await OnboardingApi.downloadImageToTemp(remoteUrl);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        return;
      }
    } else {
      sourceFile = _newImages[photoIndex - _existingImageUrls.length];
    }

    if (!mounted) return;
    final result = await showAiEnhancerSheet(
      context: context,
      originalFile: sourceFile,
      remotePreviewUrl: remoteUrl,
    );
    if (!mounted) return;

    // Existing remote: only swap when user picked the AI image.
    if (isExisting) {
      if (!result.usedAi) return;
      setState(() {
        final colorName = _photoColorNames.remove(photoIndex);
        _existingImageUrls.removeAt(photoIndex);
        // Shift color keys for remaining existing thumbs after this index.
        final shifted = <int, String>{};
        _photoColorNames.forEach((k, v) {
          if (k < photoIndex) {
            shifted[k] = v;
          } else if (k > photoIndex) {
            // existing after removal: index - 1; new images later shift by -1 then +1 at end → net 0 for new?
            // After removeAt, indices above photoIndex decrease by 1.
            shifted[k - 1] = v;
          }
        });
        _photoColorNames
          ..clear()
          ..addAll(shifted);
        _newImages.add(result.file);
        final newIndex = _existingImageUrls.length + _newImages.length - 1;
        if (colorName != null) _photoColorNames[newIndex] = colorName;
      });
      return;
    }

    // Local new image: replace in place (AI or re-confirmed original).
    final localIdx = photoIndex - _existingImageUrls.length;
    setState(() {
      _newImages[localIdx] = result.file;
    });
  }

  Future<void> _showImagePickerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Add Product Photos',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                    color: AppTheme.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Existing photos are kept. New photos are added to the gallery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                const SizedBox(height: 14),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppTheme.line),
                  ),
                  leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                  title: const Text('Choose from Photo Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppTheme.line),
                  ),
                  leading: const Icon(Icons.photo_camera_outlined, color: AppTheme.primary),
                  title: const Text('Take Photo with Camera'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Product name is required');
      return;
    }
    if (_hasBarcode && _barcode.text.trim().isEmpty) {
      setState(() => _error = 'Barcode is required for barcoded products');
      return;
    }
    if (_pricingType != 'dynamic' && _shopPrice.text.trim().isEmpty) {
      setState(() => _error = 'Shop selling price is required');
      return;
    }
    if (_categoryUuid == null) {
      setState(() => _error = 'Please select a category');
      return;
    }
    final desc = _description.text.trim();
    if (desc.isNotEmpty && desc.length < 10) {
      setState(() => _error = 'Description must be at least 10 characters');
      return;
    }

    // Determine final stock: optional on edit (preserves old stock if empty)
    final rawStock = _stock.text.trim();
    final finalStock = _isEdit
        ? (rawStock.isNotEmpty ? rawStock : (_originalStock ?? '0'))
        : (rawStock.isNotEmpty ? rawStock : '0');

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Upload new local photos first so colour→image mapping can use real URLs.
      final galleryUrls = List<String>.from(_existingImageUrls);
      String? uploadWarn;
      for (var i = 0; i < _newImages.length; i++) {
        final file = _newImages[i];
        final photoIndex = _existingImageUrls.length + i;
        try {
          final url = await OnboardingApi.uploadProductImage(file);
          galleryUrls.add(url);
          final colorName = _photoColorNames[photoIndex];
          if (colorName != null) {
            for (final c in _colors) {
              if (c.name.toLowerCase() == colorName.toLowerCase()) {
                c.imageUrl = url;
              }
            }
          }
        } catch (e) {
          uploadWarn = OnboardingApi.toUserMessage(e);
          break;
        }
      }

      for (var i = 0; i < _existingImageUrls.length; i++) {
        final colorName = _photoColorNames[i];
        if (colorName != null) {
          for (final c in _colors) {
            if (c.name.toLowerCase() == colorName.toLowerCase()) {
              c.imageUrl = _existingImageUrls[i];
            }
          }
        }
      }

      if (uploadWarn != null &&
          galleryUrls.length == _existingImageUrls.length &&
          _newImages.isNotEmpty) {
        final fields = _productFields(
          finalStock: finalStock,
          keepUrls: _existingImageUrls,
          description: desc,
          colors: _colors.map((c) => c.toJson()).toList(),
        );
        final saved = await _persistProduct(fields, imageFiles: _newImages);
        if (!mounted) return;
        _showSavedSnack(saved, uploadWarnOverride: uploadWarn);
        context.pop();
        return;
      }

      final fields = _productFields(
        finalStock: finalStock,
        keepUrls: galleryUrls,
        description: desc,
        colors: _colors.map((c) => c.toJson()).toList(),
      );

      final saved = await _persistProduct(fields, imageFiles: const []);
      if (!mounted) return;
      setState(() {
        _existingImageUrls
          ..clear()
          ..addAll(galleryUrls);
        _newImages.clear();
      });
      _showSavedSnack(saved, uploadWarnOverride: uploadWarn);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = OnboardingApi.toUserMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeGalleryAt({required bool existing, required int index}) {
    setState(() {
      final absoluteIndex = existing ? index : (_existingImageUrls.length + index);
      _photoColorNames.remove(absoluteIndex);
      if (existing) {
        _existingImageUrls.removeAt(index);
      } else {
        _newImages.removeAt(index);
      }
    });
  }

  Map<String, String> _productFields({
    required String finalStock,
    required List<String> keepUrls,
    required String description,
    required List<Map<String, dynamic>> colors,
  }) {
    return {
      'brand_name': _product.text.trim(),
        'product': _product.text.trim(),
        'item_name': _name.text.trim(),
      'description': description,
        'barcode': _hasBarcode ? _barcode.text.trim() : '',
        'has_barcode': _hasBarcode ? 'true' : 'false',
        'pricing_type': _hasBarcode ? 'fixed' : _pricingType,
        'category_uuid': _categoryUuid!,
        'tax_status': _taxStatus,
        'average_selling_price': _avgPrice.text.trim(),
      'shop_selling_price':
          _pricingType == 'dynamic' ? '0' : _shopPrice.text.trim(),
      'selling_price':
          _pricingType == 'dynamic' ? '0' : _shopPrice.text.trim(),
        'gst_percent': _taxStatus == 'taxable' ? '20' : '0',
        'stock_qty': finalStock,
      'keep_image_urls': jsonEncode(keepUrls),
      'colors': jsonEncode(colors),
    };
  }

  Future<Map<String, dynamic>> _persistProduct(
    Map<String, String> fields, {
    required List<File> imageFiles,
  }) {
    return _isEdit
        ? OnboardingApi.updateProduct(
              shopUuid: widget.shopUuid,
              productUuid: widget.productUuid!,
              fields: fields,
            imageFiles: imageFiles,
            )
        : OnboardingApi.addProduct(
              shopUuid: widget.shopUuid,
              fields: fields,
            imageFiles: imageFiles,
          );
  }

  void _showSavedSnack(
    Map<String, dynamic> saved, {
    String? uploadWarnOverride,
  }) {
    final warn =
        uploadWarnOverride ?? saved['image_upload_warning']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            warn == null || warn.isEmpty
                ? (_isEdit
                    ? 'Product updated — pending admin verification'
                    : 'Product submitted — pending admin verification')
                : (_isEdit
                    ? 'Product saved, but image upload failed'
                    : 'Product submitted, but image upload failed'),
          ),
          backgroundColor: warn == null || warn.isEmpty
              ? const Color(0xFF15803D)
              : const Color(0xFFC2410C),
        ),
      );
  }

  Widget _photoThumb({
    required Widget child,
    required int photoIndex,
    required VoidCallback onRemove,
  }) {
    final assignedColor = _photoColorNames[photoIndex];
    final colorObj = assignedColor != null
        ? _colors.firstWhere(
            (c) => c.name.toLowerCase() == assignedColor.toLowerCase(),
            orElse: () => _ProductColorOpt(name: assignedColor, hex: '#3B82F6'),
          )
        : null;
    final colorVal = colorObj != null ? _parseColorFromHex(colorObj.hex) : null;
    final isLight = colorVal != null && colorVal.computeLuminance() > 0.8;

    return Stack(
      children: [
        GestureDetector(
          onTap: () => _promptColorForPhoto(photoIndex: photoIndex),
          child: Container(
            width: 110,
            height: 118,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
        Positioned(
          left: 4,
          right: 4,
          bottom: 4,
          child: GestureDetector(
            onTap: () => _promptColorForPhoto(photoIndex: photoIndex),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (colorVal != null) ...[
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: colorVal,
                        shape: BoxShape.circle,
                        border: isLight ? Border.all(color: Colors.white, width: 0.8) : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      assignedColor ?? '+ Color',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: assignedColor != null ? Colors.white : AppTheme.primarySoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: Material(
            color: Colors.black.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _enhanceGalleryPhoto(photoIndex),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.auto_awesome, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _noColorChip({required VoidCallback onTap, bool isSelected = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySoft : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.line,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block_rounded, size: 12, color: isSelected ? AppTheme.primary : AppTheme.muted),
              const SizedBox(width: 4),
              Text(
                'No Color',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppTheme.primary : AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineColorPalette({
    required String selectedHex,
    required ValueChanged<String> onSelectHex,
    required VoidCallback onOpenFullMixer,
  }) {
    final palette = const [
      '#EF4444', // Red
      '#F97316', // Orange
      '#EAB308', // Yellow
      '#10B981', // Emerald
      '#06B6D4', // Cyan
      '#3B82F6', // Blue
      '#6366F1', // Indigo
      '#A855F7', // Purple
      '#EC4899', // Pink
      '#78350F', // Brown
      '#18181B', // Dark
      '#FFFFFF', // White
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Custom Color Swatches',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.muted),
              ),
              GestureDetector(
                onTap: onOpenFullMixer,
                child: const Row(
                  children: [
                    Text(
                      'Full Mixer',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 14, color: AppTheme.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...palette.map((hex) {
                  final isSelected = selectedHex.toLowerCase() == hex.toLowerCase();
                  final c = _parseColorFromHex(hex);
                  final isLight = c.computeLuminance() > 0.8;
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: GestureDetector(
                      onTap: () => onSelectHex(hex),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : (isLight ? AppTheme.line : Colors.transparent),
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: isLight ? Colors.black : Colors.white,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: onOpenFullMixer,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary, width: 1.5),
                    ),
                    child: const Icon(Icons.palette_outlined, size: 15, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alignedColorGrid(List<Widget> chips, {int columns = 3}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
        );
      },
    );
  }

  Future<void> _promptColorForPhoto({
    required int photoIndex,
    File? localFile,
  }) async {
    final existingRemoteUrl =
        (photoIndex < _existingImageUrls.length) ? _existingImageUrls[photoIndex] : null;
    final file = localFile ??
        ((photoIndex >= _existingImageUrls.length)
            ? _newImages[photoIndex - _existingImageUrls.length]
            : null);

    final sheetCustomCtrl = TextEditingController();
    String sheetCustomHex = '#3B82F6';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void selectColor(String name, String hex) {
              setState(() {
                if (name == 'NO_COLOR') {
                  _photoColorNames.remove(photoIndex);
                } else {
                  // One photo → one color: simply overwrite
                  _photoColorNames[photoIndex] = name;

                  // Upsert into _colors list
                  final idx = _colors.indexWhere((c) => c.name.toLowerCase() == name.toLowerCase());
                  if (idx != -1) {
                    _colors[idx] = _ProductColorOpt(name: name, hex: hex);
                  } else {
                    _colors.add(_ProductColorOpt(name: name, hex: hex));
                  }
                }

                // Prune: remove any color that is no longer assigned to any photo
                final assignedNames = _photoColorNames.values
                    .map((n) => n.toLowerCase())
                    .toSet();
                _colors.removeWhere(
                  (c) => !assignedNames.contains(c.name.toLowerCase()),
                );
              });
              Navigator.pop(ctx);
            }

            void addCustomFromSheet() {
              final text = sheetCustomCtrl.text.trim();
              if (text.isNotEmpty) {
                selectColor(text, sheetCustomHex);
              }
            }

            final currentPhotoColor = _photoColorNames[photoIndex];

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.canvas,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.line),
                              ),
                              child: file != null
                                  ? Image.file(file, fit: BoxFit.cover)
                                  : (existingRemoteUrl != null
                                      ? Image.network(existingRemoteUrl, fit: BoxFit.cover)
                                      : const Icon(Icons.image, color: AppTheme.muted)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Color for Photo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentPhotoColor != null
                                      ? 'Current color: $currentPhotoColor'
                                      : 'Assign color variant to Photo #${photoIndex + 1}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _enhanceGalleryPhoto(photoIndex);
                          },
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text(
                            'Enhance with AI',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_colors.isNotEmpty) ...[
                        const Text(
                          'Existing Product Colors (Tap to assign)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _alignedColorGrid(
                          _colors.map((c) {
                            final colorVal = _parseColorFromHex(c.hex);
                            final isSelected = currentPhotoColor?.toLowerCase() == c.name.toLowerCase();
                            return InkWell(
                              onTap: () => selectColor(c.name, c.hex),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primarySoft : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primary : AppTheme.line,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: colorVal,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? AppTheme.primary : AppTheme.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          columns: 3,
                        ),
                        const SizedBox(height: 14),
                      ],

                      const Text(
                        'Quick Colors',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _alignedColorGrid(
                        [
                          _presetColorSheetChip(ctx, 'Red', '#EF4444', selectColor),
                          _presetColorSheetChip(ctx, 'Blue', '#3B82F6', selectColor),
                          _presetColorSheetChip(ctx, 'Black', '#18181B', selectColor),
                          _presetColorSheetChip(ctx, 'White', '#FFFFFF', selectColor),
                          _presetColorSheetChip(ctx, 'Green', '#22C55E', selectColor),
                          _presetColorSheetChip(ctx, 'Yellow', '#EAB308', selectColor),
                          _presetColorSheetChip(ctx, 'Orange', '#F97316', selectColor),
                          _presetColorSheetChip(ctx, 'Purple', '#A855F7', selectColor),
                          _presetColorSheetChip(ctx, 'Grey', '#6B7280', selectColor),
                          _presetColorSheetChip(ctx, 'Gold', '#D97706', selectColor),
                          _presetColorSheetChip(ctx, 'Silver', '#9CA3AF', selectColor),
                          _noColorChip(
                            onTap: () => selectColor('NO_COLOR', ''),
                            isSelected: currentPhotoColor == null,
                          ),
                        ],
                        columns: 3,
                      ),
                      const SizedBox(height: 14),

                      // Custom Color Palette & Name Row
                      const Text(
                        'Custom Color Palette & Name',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInlineColorPalette(
                        selectedHex: sheetCustomHex,
                        onSelectHex: (hex) {
                          setModalState(() {
                            sheetCustomHex = hex;
                          });
                        },
                        onOpenFullMixer: () => _showColorMixerDialog(
                          initialHex: sheetCustomHex,
                          onColorPicked: (hex) {
                            setModalState(() {
                              sheetCustomHex = hex;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Builder(
                            builder: (_) {
                              final sheetColorVal = _parseColorFromHex(sheetCustomHex);
                              final isSheetCustomLight = sheetColorVal.computeLuminance() > 0.8;
                              return GestureDetector(
                                onTap: () => _showColorMixerDialog(
                                  initialHex: sheetCustomHex,
                                  onColorPicked: (hex) {
                                    setModalState(() {
                                      sheetCustomHex = hex;
                                    });
                                  },
                                ),
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: sheetColorVal,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSheetCustomLight ? AppTheme.line : sheetColorVal,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.palette_outlined,
                                    size: 20,
                                    color: isSheetCustomLight ? Colors.black87 : Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: sheetCustomCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                hintText: 'Custom color name (e.g. Navy Blue)…',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onSubmitted: (_) => addCustomFromSheet(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: addCustomFromSheet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Assign', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (currentPhotoColor != null)
                            TextButton.icon(
                              onPressed: () => selectColor('NO_COLOR', ''),
                              icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.muted),
                              label: const Text('Clear Color', style: TextStyle(color: AppTheme.muted)),
                            )
                          else
                            const SizedBox.shrink(),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Done / Skip'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _presetColorSheetChip(
    BuildContext ctx,
    String name,
    String hex,
    Function(String, String) onSelect,
  ) {
    final colorVal = _parseColorFromHex(hex);
    final isLight = colorVal.computeLuminance() > 0.8;
    return InkWell(
      onTap: () => onSelect(name, hex),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.line),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colorVal,
                  shape: BoxShape.circle,
                  border: isLight ? Border.all(color: AppTheme.line) : null,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _taxToggleCard({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final selected = _taxStatus == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _taxStatus = value),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primarySoft.withValues(alpha: 0.45) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                color: selected ? AppTheme.primary : AppTheme.muted,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: selected ? AppTheme.primary : AppTheme.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Color _parseColorFromHex(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    } else if (clean.length == 3) {
      final r = clean[0], g = clean[1], b = clean[2];
      return Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
    }
    return const Color(0xFF3B82F6);
  }

  Future<void> _showColorMixerDialog({
    required String initialHex,
    required ValueChanged<String> onColorPicked,
  }) async {
    String selectedHex = initialHex;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SingleChildScrollView(
              child: GoogleStyleColorPicker(
                initialHex: initialHex,
                onColorPicked: (hex) {
                  selectedHex = hex;
                },
                onCancel: () => Navigator.pop(ctx),
                onSelect: () {
                  onColorPicked(selectedHex);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ),
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (_loadingProduct) {
      return Scaffold(
        backgroundColor: AppTheme.canvas,
        appBar: AppBar(
          title: Text(_isEdit ? 'Edit Product' : 'Add Product'),
        ),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonListLoader(count: 3, itemHeight: 120),
        ),
      );
    }

    final hasPreview =
        _existingImageUrls.isNotEmpty || _newImages.isNotEmpty;

    final stockHint = _isEdit && _originalStock != null
        ? 'Current stock: $_originalStock (leave empty to keep)'
        : '0';

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(
          _isEdit
              ? 'Edit Product'
              : (_hasBarcode ? 'Add with Barcode' : 'Add without Barcode'),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset > 0 ? bottomInset + 32 : 36),
        children: [
          // 1. Photo Gallery Card
          SectionCard(
            title: 'Product Photos',
            subtitle: 'Add product photos for the shop catalog. Tap ✦ to enhance with AI.',
            children: [
              SizedBox(
                height: 122,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                          children: [
                    for (var i = 0; i < _existingImageUrls.length; i++) ...[
                      _photoThumb(
                        photoIndex: i,
                        child: Image.network(
                          _existingImageUrls[i],
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ),
                        onRemove: () =>
                            _removeGalleryAt(existing: true, index: i),
                      ),
                      const SizedBox(width: 10),
                    ],
                    for (var i = 0; i < _newImages.length; i++) ...[
                      _photoThumb(
                        photoIndex: _existingImageUrls.length + i,
                        child: Image.file(_newImages[i], fit: BoxFit.cover),
                        onRemove: () =>
                            _removeGalleryAt(existing: false, index: i),
                      ),
                      const SizedBox(width: 10),
                    ],
                    GestureDetector(
                      onTap: _showImagePickerSheet,
                      child: Container(
                        width: 110,
                        decoration: BoxDecoration(
                          color: AppTheme.canvas,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasPreview ? AppTheme.primary : AppTheme.line,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined,
                                color: AppTheme.primary, size: 28),
                            SizedBox(height: 6),
                            Text(
                              'Add photo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Barcode Scan OR Pricing Mode Card
          if (_hasBarcode)
            SectionCard(
              title: 'Barcode Scan & Lookup',
              subtitle: 'Scan barcode to autofill from Troskit catalog.',
              children: [
                const FieldLabel('Barcode', required: true),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcode,
                        decoration: const InputDecoration(
                          hintText: 'Enter or scan barcode',
                          prefixIcon: Icon(Icons.qr_code_2_rounded),
                        ),
                        onSubmitted: (v) {
                          final code = v.trim();
                          if (code.isNotEmpty) _applyCatalogLookup(code);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onPressed: _busy || _lookingUp ? null : _scanBarcode,
                      child: _lookingUp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    ),
                  ],
                ),
                if (_catalogHint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _catalogHint!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ],
            )
          else
            SectionCard(
              title: 'Pricing Mode',
              subtitle: 'Pricing rules for non-barcoded items.',
              children: [
                BottomSheetSelectField<String>(
                  title: 'Pricing Mode',
                  hint: 'Select pricing mode',
                  value: _pricingType,
                  options: const [
                    SheetOption(
                      value: 'fixed',
                      label: 'Fixed Qty',
                      subtitle: 'Sold at a fixed unit price',
                      icon: Icons.sell_outlined,
                    ),
                    SheetOption(
                      value: 'variable',
                      label: 'Variable Qty',
                      subtitle: 'Price set; quantity varies (e.g. per kg)',
                      icon: Icons.scale_outlined,
                    ),
                    SheetOption(
                      value: 'dynamic',
                      label: 'No Fixed Price',
                      subtitle: 'Price entered at checkout',
                      icon: Icons.edit_note_rounded,
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _pricingType = v;
                    if (_pricingType == 'dynamic') {
                      _shopPrice.text = '0';
                    }
                  }),
                ),
              ],
            ),
          const SizedBox(height: 14),

          // 3. Basic Item Details Card
          SectionCard(
            title: 'Basic Item Details',
            subtitle: 'Product brand, name, and category.',
            children: [
              const FieldLabel('Brand Name'),
              TextField(
                controller: _product,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Nestlé',
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Product item name', required: true),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Ideal Milk Evaporated 170g',
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Description'),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:
                      'Describe the product for the website (features, size, what buyers should know)…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Optional for POS. Recommended for website / ECOM — at least 10 characters if filled.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.muted, height: 1.3),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Category', required: true),
              if (_loadingCats)
                const SkeletonCard(height: 48)
              else ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _openCategorySheet,
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _categoryUuid != null ? AppTheme.primary : AppTheme.line,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _categoryDisplayName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _categoryUuid != null ? FontWeight.w600 : FontWeight.w400,
                                color: _categoryUuid != null ? AppTheme.ink : AppTheme.muted,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _showCreateCategoryDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New Category'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // 4. Price & Ghana Tax Card
          SectionCard(
            title: 'Price & Ghana Tax',
            subtitle: 'Selling price and VAT/levies configuration.',
            children: [
              const FieldLabel('Ghana Tax Status', required: true),
              const Text(
                'Ghana taxable goods carry standard ~20% total tax (VAT & levies).',
                style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _taxToggleCard(
                    value: 'taxable',
                    title: 'Taxable',
                    subtitle: '~20% Ghana tax',
                  ),
                  const SizedBox(width: 8),
                  _taxToggleCard(
                    value: 'exempt',
                    title: 'Tax Exempt',
                    subtitle: 'No tax applied',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const FieldLabel('Average market price (GHS)'),
              TextField(
                controller: _avgPrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: 'Master catalog average reference price',
                  prefixText: '₵  ',
                ),
              ),
              if (_pricingType != 'dynamic') ...[
                const SizedBox(height: 14),
                const FieldLabel('Shop selling price (GHS)', required: true),
                TextField(
                  controller: _shopPrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Selling price for this store',
                    prefixText: '₵  ',
                  ),
                ),
              ],
            ],
          ),


          const SizedBox(height: 14),

          // 5. Inventory & Stock Card
          SectionCard(
            title: 'Inventory & Stock',
            subtitle: _isEdit
                ? 'Optional — leave blank to keep existing stock count ($_originalStock).'
                : 'Initial stock level for store inventory.',
            children: [
              const FieldLabel('Stock quantity'),
              TextField(
                controller: _stock,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: stockHint,
                ),
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: _isEdit ? 'Save Changes' : 'Submit Product',
            loading: _busy,
            icon: Icons.check_circle_outline,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class GoogleStyleColorPicker extends StatefulWidget {
  final String initialHex;
  final ValueChanged<String> onColorPicked;
  final VoidCallback? onCancel;
  final VoidCallback? onSelect;

  const GoogleStyleColorPicker({
    super.key,
    required this.initialHex,
    required this.onColorPicked,
    this.onCancel,
    this.onSelect,
  });

  @override
  State<GoogleStyleColorPicker> createState() => _GoogleStyleColorPickerState();
}

class _GoogleStyleColorPickerState extends State<GoogleStyleColorPicker> {
  late double _hue;
  late double _saturation;
  late double _value;
  late TextEditingController _hexController;
  late TextEditingController _rController;
  late TextEditingController _gController;
  late TextEditingController _bController;

  @override
  void initState() {
    super.initState();
    final color = _parseColorFromHex(widget.initialHex);
    final hsv = HSVColor.fromColor(color);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;

    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);

    _hexController = TextEditingController(text: _formatHex(color));
    _rController = TextEditingController(text: '$r');
    _gController = TextEditingController(text: '$g');
    _bController = TextEditingController(text: '$b');
  }

  @override
  void dispose() {
    _hexController.dispose();
    _rController.dispose();
    _gController.dispose();
    _bController.dispose();
    super.dispose();
  }

  Color get _currentColor => HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();

  String _formatHex(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }

  Color _parseColorFromHex(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    } else if (clean.length == 3) {
      final r = clean[0], g = clean[1], b = clean[2];
      return Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
    }
    return const Color(0xFFEF4444);
  }

  void _updateFromHSV() {
    final newColor = _currentColor;
    final formatted = _formatHex(newColor);
    final r = (newColor.r * 255.0).round().clamp(0, 255);
    final g = (newColor.g * 255.0).round().clamp(0, 255);
    final b = (newColor.b * 255.0).round().clamp(0, 255);

    _hexController.text = formatted;
    _rController.text = '$r';
    _gController.text = '$g';
    _bController.text = '$b';
    widget.onColorPicked(formatted);
  }

  void _onHexInputChanged(String val) {
    final parsed = _parseColorFromHex(val);
    final hsv = HSVColor.fromColor(parsed);
    final r = (parsed.r * 255.0).round().clamp(0, 255);
    final g = (parsed.g * 255.0).round().clamp(0, 255);
    final b = (parsed.b * 255.0).round().clamp(0, 255);

    setState(() {
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
      _rController.text = '$r';
      _gController.text = '$g';
      _bController.text = '$b';
    });
    widget.onColorPicked(_formatHex(parsed));
  }

  void _onRgbInputsChanged() {
    final r = (int.tryParse(_rController.text) ?? 0).clamp(0, 255);
    final g = (int.tryParse(_gController.text) ?? 0).clamp(0, 255);
    final b = (int.tryParse(_bController.text) ?? 0).clamp(0, 255);

    final color = Color.fromRGBO(r, g, b, 1.0);
    final hsv = HSVColor.fromColor(color);
    final formatted = _formatHex(color);

    setState(() {
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
      _hexController.text = formatted;
    });
    widget.onColorPicked(formatted);
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _currentColor;
    final hexString = _formatHex(currentColor);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Colour picker',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppTheme.muted, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: hexString));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied $hexString to clipboard'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 2D Gradient Box + Solid Preview Box
          Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                // Solid Color Preview (Left)
                Expanded(
                  flex: 35,
                  child: Container(
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                  ),
                ),

                // 2D Saturation / Value Gradient Box (Right)
                Expanded(
                  flex: 65,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final boxWidth = constraints.maxWidth;
                      final boxHeight = constraints.maxHeight;
                      final pureHueColor = HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor();

                      return GestureDetector(
                        onPanStart: (details) => _handle2DDrag(details.localPosition, boxWidth, boxHeight),
                        onPanUpdate: (details) => _handle2DDrag(details.localPosition, boxWidth, boxHeight),
                        onTapDown: (details) => _handle2DDrag(details.localPosition, boxWidth, boxHeight),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: pureHueColor,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [Colors.white, Color(0x00FFFFFF)],
                                ),
                              ),
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0x00000000), Colors.black],
                                ),
                              ),
                            ),
                            Positioned(
                              left: (_saturation * boxWidth).clamp(0.0, boxWidth) - 12,
                              top: ((1.0 - _value) * boxHeight).clamp(0.0, boxHeight) - 12,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black45, blurRadius: 4, spreadRadius: 1),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Rainbow Hue Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sliderWidth = constraints.maxWidth;

                return GestureDetector(
                  onPanStart: (details) => _handleHueDrag(details.localPosition.dx, sliderWidth),
                  onPanUpdate: (details) => _handleHueDrag(details.localPosition.dx, sliderWidth),
                  onTapDown: (details) => _handleHueDrag(details.localPosition.dx, sliderWidth),
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: ((_hue / 360.0) * sliderWidth).clamp(0.0, sliderWidth) - 10,
                          top: -3,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor(),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          // Editable HEX & Editable RGB Section Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Editable HEX Input Field
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'HEX',
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: hexString));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Copied $hexString to clipboard'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: const Icon(Icons.copy_rounded, color: AppTheme.muted, size: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          alignment: Alignment.center,
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              inputDecorationTheme: const InputDecorationTheme(
                                fillColor: Colors.white,
                                filled: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              textSelectionTheme: const TextSelectionThemeData(
                                cursorColor: AppTheme.primary,
                                selectionColor: Color(0xFFBFDBFE),
                              ),
                            ),
                            child: TextField(
                              controller: _hexController,
                              style: const TextStyle(
                                color: AppTheme.ink,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              onChanged: _onHexInputChanged,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Editable RGB Unit Inputs (R, G, B)
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RGB (R , G , B)',
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _buildRgbUnitInput(_rController, 'R')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildRgbUnitInput(_gController, 'G')),
                            const SizedBox(width: 4),
                            Expanded(child: _buildRgbUnitInput(_bController, 'B')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (widget.onCancel != null || widget.onSelect != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onCancel != null)
                    TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.ink,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  if (widget.onSelect != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: widget.onSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: const Text('Select Color', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRgbUnitInput(TextEditingController ctrl, String label) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      alignment: Alignment.center,
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            fillColor: Colors.white,
            filled: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: AppTheme.primary,
            selectionColor: Color(0xFFBFDBFE),
          ),
        ),
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            hintText: label,
            hintStyle: const TextStyle(color: AppTheme.muted, fontSize: 11),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (_) => _onRgbInputsChanged(),
        ),
      ),
    );
  }

  void _handle2DDrag(Offset localPos, double width, double height) {
    setState(() {
      _saturation = (localPos.dx / width).clamp(0.0, 1.0);
      _value = (1.0 - (localPos.dy / height)).clamp(0.0, 1.0);
    });
    _updateFromHSV();
  }

  void _handleHueDrag(double dx, double width) {
    setState(() {
      _hue = ((dx / width) * 360.0).clamp(0.0, 360.0);
    });
    _updateFromHSV();
  }
}

/// Owns its text controllers so they are not disposed while the dialog
/// exit animation is still reading them (that caused the red error screen).
class _CreateCategoryDialog extends StatefulWidget {
  const _CreateCategoryDialog();

  @override
  State<_CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<_CreateCategoryDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a category name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final row = await OnboardingApi.createCategory(
        categoryName: name,
        description: _descCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, row);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = OnboardingApi.toUserMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Create New Category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Category name',
              hintText: 'e.g. Beverages',
            ),
            autofocus: true,
            enabled: !_saving,
            onSubmitted: (_) => _saving ? null : _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12.5),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
