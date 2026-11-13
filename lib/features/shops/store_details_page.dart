import 'package:flutter/material.dart';
import '../../api.dart';
import '../../core/services/maintenance_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/store_map_preview.dart';
import '../../core/widgets/ui_kit.dart';

class StoreDetailsPage extends StatefulWidget {
  final String shopUuid;
  const StoreDetailsPage({super.key, required this.shopUuid});

  @override
  State<StoreDetailsPage> createState() => _StoreDetailsPageState();
}

class _StoreDetailsPageState extends State<StoreDetailsPage> {
  late Future<Map<String, dynamic>> _futureShop;

  @override
  void initState() {
    super.initState();
    _futureShop = OnboardingApi.getShop(widget.shopUuid);
  }

  void _reload({bool forceRefresh = true}) {
    if (forceRefresh) {
      MaintenanceService.instance.checkStatus();
    }
    setState(() {
      _futureShop = OnboardingApi.getShop(widget.shopUuid, forceRefresh: forceRefresh);
    });
  }

  Widget _infoRow(IconData icon, String label, String? value, {Color? iconColor}) {
    final display = (value == null || value.trim().isEmpty) ? 'Not specified' : value.trim();
    final isMissing = value == null || value.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  display,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isMissing ? AppTheme.muted.withValues(alpha: 0.5) : AppTheme.ink,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreHeader(Map<String, dynamic> shop) {
    final name = (shop['shop_name'] ?? 'Store Details').toString();
    final verification = (shop['verification_status'] ?? 'pending').toString();
    final category = (shop['category_name'] ?? shop['category']?['category_name'] ?? 'Retail Store').toString();
    final isVerified = verification.toLowerCase() == 'verified';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/shop-banner.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.2),
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVerified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                              size: 13,
                              color: isVerified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              verification.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: isVerified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Shop3DArtworkWidget(width: 72, height: 72),
              ],
            ),
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
        title: const Text('Store Details'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Refresh details',
            onPressed: () => _reload(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureShop,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonListLoader(count: 3, itemHeight: 140),
            );
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load store details',
              subtitle: OnboardingApi.toUserMessage(snap.error),
              action: ElevatedButton.icon(
                onPressed: () => _reload(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            );
          }

          final shop = snap.data ?? {};
          final ecomStatus = (shop['ecom_listing_status'] ?? 'none').toString().toLowerCase();
          final lat = (shop['latitude'] as num?)?.toDouble();
          final lng = (shop['longitude'] as num?)?.toDouble();
          final coords = (lat != null && lng != null) ? '$lat, $lng' : null;

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => _reload(forceRefresh: true),
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset > 0 ? bottomInset + 32 : 40),
              children: [
                _buildStoreHeader(shop),
                const SizedBox(height: 16),

                SectionCard(
                  title: 'Owner & Contact Details',
                  subtitle: 'Registered contact information for this store.',
                  children: [
                    _infoRow(
                      Icons.person_outline_rounded,
                      'Owner Name',
                      shop['owner_name']?.toString(),
                    ),
                    _infoRow(
                      Icons.phone_outlined,
                      'Phone Number',
                      shop['phone_no'] != null ? '+233 ${shop['phone_no']}' : null,
                    ),
                    _infoRow(
                      Icons.mail_outline_rounded,
                      'Email Address',
                      shop['email']?.toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                SectionCard(
                  title: 'Location & GPS Address',
                  subtitle: 'Store physical location and GhanaPost GPS details.',
                  children: [
                    if (lat != null && lng != null) ...[
                      StoreMapPreview(latitude: lat, longitude: lng),
                      const SizedBox(height: 6),
                    ],
                    _infoRow(
                      Icons.pin_drop_outlined,
                      'GhanaPost GPS Address',
                      shop['shop_gps_address']?.toString(),
                      iconColor: const Color(0xFFD97706),
                    ),
                    _infoRow(
                      Icons.location_city_rounded,
                      'Address / Landmark',
                      shop['address']?.toString(),
                      iconColor: const Color(0xFF2563EB),
                    ),
                    _infoRow(
                      Icons.my_location_rounded,
                      'GPS Coordinates',
                      coords,
                      iconColor: const Color(0xFF059669),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                SectionCard(
                  title: 'Mobile Money Payout Account',
                  subtitle: 'Payout details for web and POS sales settlements.',
                  children: [
                    _infoRow(
                      Icons.account_balance_wallet_outlined,
                      'MoMo Network',
                      shop['momo_network']?.toString(),
                      iconColor: const Color(0xFFD97706),
                    ),
                    _infoRow(
                      Icons.phone_android_rounded,
                      'MoMo Account Number',
                      shop['momo_number']?.toString(),
                      iconColor: const Color(0xFF2563EB),
                    ),
                    _infoRow(
                      Icons.badge_outlined,
                      'Account Holder Name',
                      shop['momo_name']?.toString(),
                      iconColor: const Color(0xFF059669),
                    ),
                    _infoRow(
                      Icons.account_balance_rounded,
                      'Bank Name',
                      shop['bank_name']?.toString(),
                      iconColor: const Color(0xFF7C3AED),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _buildEcomSection(ecomStatus),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEcomSection(String ecomStatus) {
    final isApproved = ecomStatus == 'approved';
    final isPending = ecomStatus == 'pending';

    final statusBg = isApproved
        ? const Color(0xFFDCFCE7)
        : isPending
            ? const Color(0xFFFEF3C7)
            : AppTheme.canvas;
    final statusFg = isApproved
        ? const Color(0xFF15803D)
        : isPending
            ? const Color(0xFFB45309)
            : AppTheme.muted;

    return SectionCard(
      title: 'Troskit ECOM — Website Listing',
      subtitle: 'Listing is requested automatically when the shop is created.',
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: statusFg.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isApproved
                    ? Icons.check_circle_rounded
                    : isPending
                        ? Icons.hourglass_top_rounded
                        : Icons.storefront_outlined,
                size: 20,
                color: statusFg,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS: ${ecomStatus.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: statusFg,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isApproved
                          ? 'Store is active and listed on Troskit ECOM.'
                          : isPending
                              ? 'Request submitted at create — awaiting admin review.'
                              : 'No ECOM listing request on file for this store.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: statusFg.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
