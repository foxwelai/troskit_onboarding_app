import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../api.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';

class StoreDetailsPage extends StatefulWidget {
  final String shopUuid;
  const StoreDetailsPage({super.key, required this.shopUuid});

  @override
  State<StoreDetailsPage> createState() => _StoreDetailsPageState();
}

class _StoreDetailsPageState extends State<StoreDetailsPage> {
  late Future<Map<String, dynamic>> _futureShop;
  bool _ecomBusy = false;

  @override
  void initState() {
    super.initState();
    _futureShop = OnboardingApi.getShop(widget.shopUuid);
  }

  void _reload({bool forceRefresh = true}) {
    setState(() {
      _futureShop = OnboardingApi.getShop(widget.shopUuid, forceRefresh: forceRefresh);
    });
  }

  Future<void> _requestEcom(Map<String, dynamic> shop) async {
    setState(() => _ecomBusy = true);
    try {
      double? lat = (shop['latitude'] as num?)?.toDouble();
      double? lng = (shop['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw Exception(
            'Location permission is required to request ECOM listing. '
            'Please grant device location permission to proceed.',
          );
        }
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw Exception('Please turn on device location services to pin store location.');
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }

      final res = await OnboardingApi.requestEcom(
        shopUuid: widget.shopUuid,
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'ECOM listing request submitted'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFC2410C),
        ),
      );
    } finally {
      if (mounted) setState(() => _ecomBusy = false);
    }
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
                Image.asset(
                  'assets/images/shop.png',
                  height: 72,
                  width: 72,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.storefront_rounded, size: 30, color: Colors.white),
                  ),
                ),
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
          final lat = shop['latitude'];
          final lng = shop['longitude'];
          final coords = (lat != null && lng != null) ? '$lat, $lng' : null;

          // Build Google Maps Static Preview URL
          String? mapUrl;
          if (lat != null && lng != null) {
            mapUrl =
                'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lng&zoom=15&size=600x300&maptype=roadmap&markers=color:red%7C$lat,$lng&key=${ApiConstants.googleMapsApiKey}';
          } else if (shop['shop_gps_address'] != null && shop['shop_gps_address'].toString().trim().isNotEmpty) {
            final loc = Uri.encodeComponent('${shop['shop_gps_address']}, Ghana');
            mapUrl =
                'https://maps.googleapis.com/maps/api/staticmap?center=$loc&zoom=14&size=600x300&maptype=roadmap&markers=color:red%7C$loc&key=${ApiConstants.googleMapsApiKey}';
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => _reload(forceRefresh: true),
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset > 0 ? bottomInset + 32 : 40),
              children: [
                // 1. Header Banner Store Card
                _buildStoreHeader(shop),
                const SizedBox(height: 16),

                // 2. Business Details Card
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

                // 3. Location & Google Map Card
                SectionCard(
                  title: 'Location & GPS Address',
                  subtitle: 'Store physical location and GhanaPost GPS details.',
                  children: [
                    if (mapUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.canvas,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.line),
                          ),
                          child: Image.network(
                            mapUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _mapFallback(coords),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
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

                // 4. MoMo Payout Account Card
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

                // 5. ECOM Listing Card
                _buildEcomSection(shop, ecomStatus),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEcomSection(Map<String, dynamic> shop, String ecomStatus) {
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
      subtitle: 'Publish store catalog for web buyers and online ordering.',
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
                              ? 'Request submitted — awaiting admin review.'
                              : 'Store is not yet listed on Troskit ECOM.',
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
        const SizedBox(height: 16),
        PrimaryButton(
          label: isApproved
              ? 'Re-request ECOM Listing'
              : isPending
                  ? 'Awaiting Admin Approval'
                  : 'Request ECOM Listing',
          loading: _ecomBusy,
          icon: isApproved
              ? Icons.sync_rounded
              : isPending
                  ? Icons.hourglass_top_rounded
                  : Icons.rocket_launch_rounded,
          onPressed: (_ecomBusy || isPending) ? null : () => _requestEcom(shop),
        ),
      ],
    );
  }

  Widget _mapFallback(String? coords) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_rounded, color: AppTheme.muted, size: 36),
            const SizedBox(height: 6),
            Text(
              coords ?? 'Location Map Window',
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
