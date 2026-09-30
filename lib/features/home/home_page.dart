import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0;
  late Future<List<dynamic>> _futureShops;
  late Future<List<dynamic>> _futureActivity;
  Map<String, dynamic>? _me;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _shopStatusFilter = 'all'; // all | pending | approved | rejected

  @override
  void initState() {
    super.initState();
    _futureShops = OnboardingApi.listShops();
    _futureActivity = OnboardingApi.listActivityFeed();
    _checkAccessAndLoadMe();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAccessAndLoadMe() async {
    try {
      final me = await OnboardingApi.me();
      if (!mounted) return;
      setState(() => _me = me);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      final blocked =
          e is AccessBlockedException ||
          msg.toLowerCase().contains('disabled') ||
          msg.toLowerCase().contains('blocked') ||
          msg.toLowerCase().contains('inactive') ||
          msg.toLowerCase().contains('unauthorized') ||
          msg.toLowerCase().contains('not authorized') ||
          msg.toLowerCase().contains('access removed');
      if (blocked) {
        context.go('/blocked', extra: msg);
        return;
      }
      final cached = await OnboardingApi.currentEmployee();
      if (mounted) setState(() => _me = cached);
    }
  }

  void _reloadShops({bool forceRefresh = true}) {
    setState(() {
      _futureShops = OnboardingApi.listShops(forceRefresh: forceRefresh);
    });
    _checkAccessAndLoadMe();
  }

  void _reloadActivity({bool forceRefresh = true}) {
    setState(() {
      _futureActivity = OnboardingApi.listActivityFeed(forceRefresh: forceRefresh);
    });
  }

  String get _agentName {
    final n = (_me?['name'] ?? '').toString().trim();
    return n.isEmpty ? 'Field Agent' : n;
  }

  String get _agentInitial {
    final n = _agentName;
    return n.isNotEmpty ? n.substring(0, 1).toUpperCase() : 'A';
  }

  bool get _canOnboard => _me?['can_onboard_shops'] == true;

  Future<void> _confirmLogout() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppTheme.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppTheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Log out of account?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'You will need to sign in again to access your shop onboarding dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Log out'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok == true && mounted) {
      await OnboardingApi.logout();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _openProfileSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final email = (_me?['email'] ?? '').toString();
        final role = (_me?['role'] ?? 'Field Agent').toString();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    _agentInitial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _agentName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/ai-images');
                    },
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('AI Images'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _checkAccessAndLoadMe();
                    },
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Refresh profile'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF2F2),
                      foregroundColor: AppTheme.primary,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmLogout();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Log out'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            IndexedStack(
              index: _tabIndex,
              children: [
                _buildHomeTab(),
                _buildMyShopsTab(),
                _buildHistoryTab(),
              ],
            ),
            GlassmorphismCapsuleBar(
              selectedIndex: _tabIndex,
              onTabSelected: (idx) => setState(() => _tabIndex = idx),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HOME TAB ───────────────────────────────────────────────

  Widget _buildHomeTab() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(
            children: [
              Image.asset(AppTheme.logoAsset, height: 42, fit: BoxFit.contain),
              const Spacer(),
              _headerIconButton(Icons.refresh_rounded, onTap: _reloadShops),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openProfileSheet,
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFFDC2626),
                  child: Text(
                    _agentInitial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _futureShops,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: SkeletonListLoader(count: 4, itemHeight: 90),
                );
              }
              if (snap.hasError) {
                return _shopsError(snap.error);
              }

              final shops = (snap.data ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
              final approved = shops
                  .where(
                    (s) =>
                        (s['verification_status'] ?? '')
                            .toString()
                            .toLowerCase() ==
                        'approved',
                  )
                  .length;
              final pending = shops
                  .where(
                    (s) =>
                        (s['verification_status'] ?? '')
                            .toString()
                            .toLowerCase() !=
                        'approved',
                  )
                  .length;
              final upcoming = shops
                  .where(
                    (s) =>
                        (s['verification_status'] ?? '')
                            .toString()
                            .toLowerCase() !=
                        'approved',
                  )
                  .toList();

              return RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: () async => _reloadShops(),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    10,
                    18,
                    bottomInset > 0 ? bottomInset + 96 : 108,
                  ),
                  children: [
                    _welcomeCard(total: shops.length),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard(
                            icon: Icons.shopping_cart_outlined,
                            title: 'Completed',
                            value: '$approved',
                            trend: '12.4%',
                            subtitle: 'Prev Month',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricCard(
                            icon: Icons.inventory_2_outlined,
                            title: 'Pending Approval',
                            value: '$pending',
                            trend: '12.4%',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Upcoming Onboarding',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (upcoming.isEmpty)
                      const EmptyState(
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'You\'re all caught up',
                        subtitle:
                            'New shops assigned by admin will show here for setup.',
                      )
                    else
                      for (final shop in upcoming.take(8)) ...[
                        _upcomingShopTile(shop),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _welcomeCard({required int total}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              child: SizedBox(
                width: 160,
                height: 110,
                child: CustomPaint(painter: RedWaveSparklinePainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 140, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Akwaaba',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _agentName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Onboarded',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$total Shops',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    required String trend,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.north_east_rounded,
                size: 13,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: 3),
              Text(
                trend,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16A34A),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _upcomingShopTile(Map<String, dynamic> shop) {
    final uuid = shop['uuid']?.toString();
    final name = shop['shop_name']?.toString() ?? 'Shop';
    final owner = shop['owner_name']?.toString() ?? '—';
    final phone = shop['phone_no']?.toString() ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: uuid == null
            ? null
            : () async {
                await context.push('/shops/$uuid');
                _reloadShops();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F2),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: AppTheme.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$owner  •  +233 $phone',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF374151),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SHOPS TAB ──────────────────────────────────────────────

  Widget _buildMyShopsTab() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        Column(
          children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _tabIndex = 0),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                ),
              ),
              const Expanded(
                child: Text(
                  'My Shops',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              _headerIconButton(Icons.refresh_rounded, onTap: _reloadShops),
            ],
          ),
        ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SearchInputField(
                      hint: 'Search by Shop Name',
                      controller: _searchCtrl,
                      onChanged: (q) =>
                          setState(() => _searchQuery = q.trim().toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.tune_rounded, color: AppTheme.ink),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _futureShops,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SkeletonListLoader(count: 4, itemHeight: 96),
                    );
                  }
                  if (snap.hasError) return _shopsError(snap.error);

                  final allShops = (snap.data ?? [])
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList();

                  final pendingCount = allShops
                      .where(
                        (s) =>
                            (s['verification_status'] ?? '')
                                .toString()
                                .toLowerCase() ==
                            'pending',
                      )
                      .length;

                  final filtered = allShops.where((s) {
                    final status = (s['verification_status'] ?? 'pending')
                        .toString()
                        .toLowerCase();
                    if (_shopStatusFilter != 'all' &&
                        status != _shopStatusFilter) {
                      return false;
                    }
                    if (_searchQuery.isEmpty) return true;
                    final name = (s['shop_name'] ?? '')
                        .toString()
                        .toLowerCase();
                    final owner = (s['owner_name'] ?? '')
                        .toString()
                        .toLowerCase();
                    final phone = (s['phone_no'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(_searchQuery) ||
                        owner.contains(_searchQuery) ||
                        phone.contains(_searchQuery);
                  }).toList();

                  if (allShops.isEmpty) {
                    return EmptyState(
                      icon: Icons.assignment_ind_outlined,
                      title: 'No shops assigned yet',
                      subtitle:
                          'When admin assigns a vendor enquiry to you, the shop appears here.',
                      action: _canOnboard
                          ? OutlinedButton.icon(
                              onPressed: () async {
                                await context.push('/shops/new');
                                _reloadShops();
                              },
                              icon: const Icon(Icons.add_business_rounded),
                              label: const Text('Register walk-in shop'),
                            )
                          : ElevatedButton.icon(
                              onPressed: _reloadShops,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Refresh'),
                            ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () async => _reloadShops(),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        bottomInset > 0 ? bottomInset + 110 : 120,
                      ),
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _statusPill('all', 'All (${allShops.length})'),
                              _statusPill('pending', 'Pending ($pendingCount)'),
                              _statusPill('processing', 'Processing'),
                              _statusPill('shipped', 'Shipped'),
                              _statusPill('delivered', 'Delivered'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matching shops',
                            subtitle: 'Try another search or filter.',
                          )
                        else
                          for (final shop in filtered) ...[
                            _buildShopListCard(shop),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (_canOnboard)
          Positioned(
            right: 18,
            bottom: bottomInset > 0 ? bottomInset + 88 : 100,
            child: FloatingActionButton(
              heroTag: 'fab-shops',
              backgroundColor: AppTheme.primary,
              onPressed: () async {
                await context.push('/shops/new');
                _reloadShops();
              },
              child: const Icon(
                Icons.add_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _statusPill(String key, String label) {
    final selected = _shopStatusFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _shopStatusFilter = key),
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
      ),
    );
  }

  Widget _buildShopListCard(Map<String, dynamic> shop) {
    final status = (shop['verification_status'] ?? 'pending').toString();
    final shopUuid = shop['uuid']?.toString();
    final name = shop['shop_name']?.toString() ?? 'Shop';
    final owner = shop['owner_name']?.toString() ?? '—';
    final phone = shop['phone_no']?.toString() ?? '';
    final itemCount = int.tryParse(
          '${shop['product_count'] ?? shop['products_count'] ?? 0}',
        ) ??
        0;
    final itemsLabel = itemCount == 1 ? '1 Item' : '$itemCount Items';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: shopUuid == null
            ? null
            : () async {
                await context.push('/shops/$shopUuid');
                _reloadShops();
              },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F2),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Shop3DArtworkWidget(width: 50, height: 50),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              color: AppTheme.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppTheme.ink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$owner • +233 $phone',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
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
            ],
          ),
        ),
      ),
    );
  }

  // ─── HISTORY TAB ────────────────────────────────────────────

  // ─── HISTORY / ACTIVITY FEED TAB ────────────────────────────

  // ── Activity type config ────────────────────────────────────
  static const _activityConfig = <String, Map<String, dynamic>>{
    'shop_onboarded': {
      'icon': Icons.storefront_rounded,
      'bgColor': Color(0xFFFFF0F2),
      'iconColor': Color(0xFFDC2626),
      'borderColor': Color(0xFFDC2626),
      'label': 'Shop Onboarded',
    },
    'shop_approved': {
      'icon': Icons.verified_rounded,
      'bgColor': Color(0xFFF0FDF4),
      'iconColor': Color(0xFF16A34A),
      'borderColor': Color(0xFF16A34A),
      'label': 'Shop Approved',
    },
    'shop_rejected': {
      'icon': Icons.cancel_rounded,
      'bgColor': Color(0xFFFFF7ED),
      'iconColor': Color(0xFFEA580C),
      'borderColor': Color(0xFFEA580C),
      'label': 'Shop Rejected',
    },
    'product_added': {
      'icon': Icons.inventory_2_rounded,
      'bgColor': Color(0xFFEFF6FF),
      'iconColor': Color(0xFF2563EB),
      'borderColor': Color(0xFF2563EB),
      'label': 'Product Added',
    },
    'product_approved': {
      'icon': Icons.check_circle_rounded,
      'bgColor': Color(0xFFF0FDF4),
      'iconColor': Color(0xFF16A34A),
      'borderColor': Color(0xFF16A34A),
      'label': 'Product Approved',
    },
    'product_rejected': {
      'icon': Icons.cancel_rounded,
      'bgColor': Color(0xFFFFF7ED),
      'iconColor': Color(0xFFEA580C),
      'borderColor': Color(0xFFEA580C),
      'label': 'Product Rejected',
    },
    'shop_access_granted': {
      'icon': Icons.key_rounded,
      'bgColor': Color(0xFFFAF5FF),
      'iconColor': Color(0xFF7C3AED),
      'borderColor': Color(0xFF7C3AED),
      'label': 'Access Granted',
    },
  };

  Widget _buildHistoryTab() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _tabIndex = 0),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
              const Expanded(
                child: Text(
                  'Activity',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              _headerIconButton(
                Icons.refresh_rounded,
                onTap: _reloadActivity,
              ),
            ],
          ),
        ),

        // ── Feed ────────────────────────────────────────────────
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _futureActivity,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: SkeletonListLoader(count: 6, itemHeight: 80),
                );
              }
              if (snap.hasError) {
                return EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load activity',
                  subtitle: OnboardingApi.toUserMessage(snap.error),
                  action: ElevatedButton.icon(
                    onPressed: _reloadActivity,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                );
              }

              final events = (snap.data ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();

              if (events.isEmpty) {
                return const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No activity yet',
                  subtitle:
                      'Your shop onboardings, product additions and approvals will appear here.',
                );
              }

              // Build list items: group by date with sticky headers
              final items = _buildActivityItems(events);

              return RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: () async => _reloadActivity(),
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    bottomInset > 0 ? bottomInset + 96 : 108,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    if (item['_isHeader'] == true) {
                      return _buildDateHeader(item['label'] as String);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildActivityCard(
                        item,
                        onTap: _shopUuidFromEvent(item),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Inserts date-header entries between events that fall on different days.
  List<Map<String, dynamic>> _buildActivityItems(
    List<Map<String, dynamic>> events,
  ) {
    final items = <Map<String, dynamic>>[];
    String? lastDateKey;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final e in events) {
      final ts = DateTime.tryParse(e['timestamp']?.toString() ?? '');
      if (ts == null) continue;
      final local = ts.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final dateKey = '${local.year}-${local.month}-${local.day}';

      if (dateKey != lastDateKey) {
        lastDateKey = dateKey;
        final String label;
        if (day == today) {
          label = 'Today';
        } else if (day == yesterday) {
          label = 'Yesterday';
        } else {
          label = '${local.day} ${_actMonth(local.month)} ${local.year}';
        }
        items.add({'_isHeader': true, 'label': label});
      }
      items.add(e);
    }
    return items;
  }

  String? _shopUuidFromEvent(Map<String, dynamic> event) =>
      event['shop_uuid']?.toString();

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    Map<String, dynamic> event, {
    String? onTap,
  }) {
    final type = event['type']?.toString() ?? 'shop_onboarded';
    final cfg = _activityConfig[type] ?? _activityConfig['shop_onboarded']!;
    final icon = cfg['icon'] as IconData;
    final bgColor = cfg['bgColor'] as Color;
    final iconColor = cfg['iconColor'] as Color;
    final borderColor = cfg['borderColor'] as Color;
    final label = cfg['label'] as String;

    final title = event['title']?.toString() ?? '';
    final subtitle = event['subtitle']?.toString() ?? '';
    final ts = DateTime.tryParse(event['timestamp']?.toString() ?? '')?.toLocal();
    final timeLabel = ts != null
        ? '${_actMonth(ts.month)} ${ts.day}, ${_fmt2(ts.hour)}:${_fmt2(ts.minute)}'
        : '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap == null
            ? null
            : () async {
                await context.push('/shops/$onTap');
                _reloadShops();
              },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.line),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Coloured left accent bar
                Container(
                  width: 4,
                  color: borderColor,
                ),
                const SizedBox(width: 12),
              // Icon bubble
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 20, color: iconColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Text content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Type pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: iconColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Time
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.muted,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  String _actMonth(int m) =>
      const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  String _fmt2(int v) => v.toString().padLeft(2, '0');



  // ─── Shared helpers ─────────────────────────────────────────

  Widget _headerIconButton(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: const Color(0xFF374151)),
        ),
      ),
    );
  }

  Widget _shopsError(Object? error) {
    final userMsg = OnboardingApi.toUserMessage(error);
    final isBlocked =
        error is AccessBlockedException ||
        userMsg.toLowerCase().contains('blocked') ||
        userMsg.toLowerCase().contains('disabled') ||
        userMsg.toLowerCase().contains('unauthorized') ||
        userMsg.toLowerCase().contains('not authorized') ||
        userMsg.toLowerCase().contains('access removed');
    if (isBlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/blocked', extra: userMsg);
      });
      return const SizedBox.shrink();
    }
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'Could not load shops',
      subtitle: userMsg,
      action: ElevatedButton.icon(
        onPressed: _reloadShops,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Try again'),
      ),
    );
  }
}
