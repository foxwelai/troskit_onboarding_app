import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';

class ShopDetailPage extends StatefulWidget {
  final String shopUuid;
  const ShopDetailPage({super.key, required this.shopUuid});

  @override
  State<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends State<ShopDetailPage> {
  late Future<Map<String, dynamic>> _shopFuture;
  late Future<List<dynamic>> _productsFuture;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _productStatusFilter = 'all'; // all | pending | approved | rejected

  @override
  void initState() {
    super.initState();
    _shopFuture = OnboardingApi.getShop(widget.shopUuid);
    _productsFuture = OnboardingApi.listProducts(widget.shopUuid);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload({bool forceRefresh = true}) {
    setState(() {
      _shopFuture = OnboardingApi.getShop(widget.shopUuid, forceRefresh: forceRefresh);
      _productsFuture = OnboardingApi.listProducts(widget.shopUuid, forceRefresh: forceRefresh);
    });
  }

  Future<void> _showAddProductBottomSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 16),
                const Text(
                  'Add New Product',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppTheme.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select how this item will be cataloged & sold in POS.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12.5, height: 1.3),
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppTheme.line),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'With Barcode',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.2),
                  ),
                  subtitle: const Text(
                    'Scan or type barcode · Troskit catalog autofill',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.muted, height: 1.3),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(
                      '/shops/${widget.shopUuid}/products/new?hasBarcode=true',
                    ).then((_) => _reload());
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppTheme.line),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.canvas,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Without Barcode',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.2),
                  ),
                  subtitle: const Text(
                    'Fixed Qty · Variable Qty · No Fixed Price',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.muted, height: 1.3),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(
                      '/shops/${widget.shopUuid}/products/new?hasBarcode=false',
                    ).then((_) => _reload());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoreInfoEcomCard(Map<String, dynamic> shop) {
    final listing = (shop['ecom_listing_status'] ?? 'none').toString().toLowerCase();
    final isApproved = listing == 'approved';
    final isPending = listing == 'pending';

    final statusLabel = isApproved
        ? 'APPROVED'
        : isPending
            ? 'PENDING'
            : 'REQUEST ECOM';
    final statusBg = isApproved
        ? const Color(0xFFDCFCE7)
        : isPending
            ? const Color(0xFFFEF3C7)
            : AppTheme.primarySoft;
    final statusFg = isApproved
        ? const Color(0xFF15803D)
        : isPending
            ? const Color(0xFFB45309)
            : AppTheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/shops/${widget.shopUuid}/store-details'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Store Info & ECOM Settings',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Payout details, GPS & web listing status',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.muted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusFg,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('My Shops'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset > 0 ? 4 : 0),
        child: FloatingActionButton(
          heroTag: 'fab-products',
          onPressed: _showAddProductBottomSheet,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => _reload(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            bottomInset > 0 ? bottomInset + 88 : 96,
          ),
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _shopFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SkeletonCard(height: 150);
                }
                if (snap.hasError) {
                  return EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load store header',
                    subtitle: OnboardingApi.toUserMessage(snap.error),
                  );
                }
                final shop = snap.data ?? {};
                return FutureBuilder<List<dynamic>>(
                  future: _productsFuture,
                  builder: (context, pSnap) {
                    final fromApi = int.tryParse(
                      '${shop['product_count'] ?? shop['products_count'] ?? ''}',
                    );
                    final itemCount =
                        pSnap.hasData ? pSnap.data!.length : (fromApi ?? 0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildShopBanner(shop, itemCount: itemCount),
                        const SizedBox(height: 12),
                        _buildStoreInfoEcomCard(shop),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 4),
            SearchInputField(
              hint: 'Search by Product Name',
              controller: _searchCtrl,
              onChanged: (q) =>
                  setState(() => _searchQuery = q.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<dynamic>>(
              future: _productsFuture,
              builder: (context, snap) {
                final items = snap.data ?? [];
                final pendingCount = items
                    .where((p) =>
                        (p['verification_status'] ?? '')
                            .toString()
                            .toLowerCase() ==
                        'pending')
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All (${items.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'pending',
                            'Pending ($pendingCount)',
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip('processing', 'Processing'),
                          const SizedBox(width: 8),
                          _buildFilterChip('shipped', 'Shipped'),
                          const SizedBox(width: 8),
                          _buildFilterChip('delivered', 'Delivered'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (snap.connectionState != ConnectionState.done)
                      const SkeletonListLoader(count: 4, itemHeight: 80)
                    else if (snap.hasError)
                      EmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load products',
                        subtitle: OnboardingApi.toUserMessage(snap.error),
                        action: ElevatedButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      )
                    else ...[
                      Builder(
                        builder: (context) {
                          final filtered = items.where((raw) {
                            final p = raw as Map<String, dynamic>;
                            final status = (p['verification_status'] ?? 'pending')
                                .toString()
                                .toLowerCase();
                            if (_productStatusFilter != 'all' &&
                                status != _productStatusFilter) {
                              return false;
                            }
                            if (_searchQuery.isEmpty) return true;
                            final name =
                                (p['item_name'] ?? '').toString().toLowerCase();
                            final brand =
                                (p['brand_name'] ?? p['product_brand'] ?? '')
                                    .toString()
                                    .toLowerCase();
                            final barcode =
                                (p['barcode']?.toString() ?? '').toLowerCase();
                            return name.contains(_searchQuery) ||
                                brand.contains(_searchQuery) ||
                                barcode.contains(_searchQuery);
                          }).toList();

                          if (items.isEmpty) {
                            return EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: "Catalog this shop's products",
                              subtitle:
                                  'Assigned shops start empty. Add barcoded or non-barcoded items so POS / ECOM can sell them.',
                              action: PrimaryButton(
                                label: 'Add First Product',
                                icon: Icons.add_rounded,
                                onPressed: _showAddProductBottomSheet,
                              ),
                            );
                          }

                          if (filtered.isEmpty) {
                            return const EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No matching items',
                              subtitle:
                                  'No product matches the selected filter & search.',
                            );
                          }

                          return Column(
                            children: [
                              for (final raw in filtered) ...[
                                _buildProductCard(
                                  raw as Map<String, dynamic>,
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopBanner(Map<String, dynamic> shop, {required int itemCount}) {
    final shopName = shop['shop_name']?.toString() ?? 'Store';
    final owner = shop['owner_name']?.toString() ?? '—';
    final phone = shop['phone_no']?.toString() ?? '';
    final status = (shop['verification_status'] ?? 'pending').toString();
    final itemsLabel = itemCount == 1 ? '1 Item' : '$itemCount Items';

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFFFFF0F2),
          image: const DecorationImage(
            image: AssetImage('assets/images/shop-banner.png'),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shopName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$owner • +233 $phone',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        itemsLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      StatusChip(status, compact: true, showBg: false),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Image.asset(
              'assets/images/shop.png',
              width: 86,
              height: 86,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => const Shop3DArtworkWidget(width: 86, height: 86),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _productStatusFilter == key;
    return Material(
      color: selected ? AppTheme.primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _productStatusFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final urls = p['image_urls'];
    final image = (urls is List && urls.isNotEmpty
            ? urls.first?.toString()
            : null) ??
        p['product_image']?.toString();
    final productUuid = p['uuid']?.toString();
    final barcode = (p['barcode']?.toString() ?? '').trim();
    final hasBarcode = barcode.isNotEmpty;
    final itemName = p['item_name']?.toString() ?? 'Product Item';
    final brand = (p['brand_name'] ?? p['product_brand'])?.toString();
    final category = p['category'] is Map
        ? (p['category']['category_name'] ?? '').toString()
        : (p['category_name'] ?? '').toString();
    final price = p['selling_price'] ?? 0;
    final status = (p['verification_status'] ?? 'pending').toString();
    final subtitleParts = <String>[
      if (brand != null && brand.trim().isNotEmpty) brand.trim(),
      if (category.trim().isNotEmpty) category.trim(),
    ];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: productUuid == null || productUuid.isEmpty
            ? null
            : () async {
                await context.push(
                  '/shops/${widget.shopUuid}/products/$productUuid/edit'
                  '?hasBarcode=${hasBarcode ? 'true' : 'false'}',
                );
                _reload();
              },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: image != null && image.isNotEmpty
                    ? Image.network(
                        image,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallbackImage(),
                      )
                    : _fallbackImage(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.ink,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleParts.join(' • '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₵ ${_formatPrice(price)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusChip(status, compact: true, showBg: false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    final n = double.tryParse(price.toString());
    if (n == null) return price.toString();
    return n.toStringAsFixed(2);
  }

  Widget _fallbackImage() {
    return Container(
      width: 64,
      height: 64,
      color: AppTheme.primarySoft.withValues(alpha: 0.4),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppTheme.primary,
        size: 24,
      ),
    );
  }
}
