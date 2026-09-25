import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';

class OnboardShopPage extends StatefulWidget {
  const OnboardShopPage({super.key});
  @override
  State<OnboardShopPage> createState() => _OnboardShopPageState();
}

class _MomoProviderOption {
  final String code;
  final String name;
  final String subtitle;
  final Color bg;
  final Color fg;

  const _MomoProviderOption({
    required this.code,
    required this.name,
    required this.subtitle,
    required this.bg,
    required this.fg,
  });
}

const List<_MomoProviderOption> _momoProviders = [
  _MomoProviderOption(
    code: 'MTN',
    name: 'MTN Mobile Money',
    subtitle: 'MTN MoMo Ghana',
    bg: Color(0xFFFFCC00),
    fg: Color(0xFF000000),
  ),
  _MomoProviderOption(
    code: 'TELECEL',
    name: 'Telecel Cash',
    subtitle: 'Vodafone / Telecel Cash',
    bg: Color(0xFFE60000),
    fg: Color(0xFFFFFFFF),
  ),
  _MomoProviderOption(
    code: 'AIRTELTIGO',
    name: 'AT Money',
    subtitle: 'AirtelTigo / AT Money',
    bg: Color(0xFF003399),
    fg: Color(0xFFFFFFFF),
  ),
];

class _OnboardShopPageState extends State<OnboardShopPage> {
  final _shopName = TextEditingController();
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _gps = TextEditingController();
  String _selectedMomoNetwork = 'MTN';
  final _momoNumber = TextEditingController();
  final _momoName = TextEditingController();
  final String _shopType = 'store'; // Hardcoded store type (switch hidden per requirements)
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _shopName.dispose();
    _ownerName.dispose();
    _email.dispose();
    _phone.dispose();
    _gps.dispose();
    _momoNumber.dispose();
    _momoName.dispose();
    super.dispose();
  }

  Future<void> _showMomoProviderBottomSheet() async {
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
                const SizedBox(height: 14),
                const Text(
                  'Select Network Provider',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                    color: AppTheme.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose Mobile Money payout network for store owner',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 16),
                for (final item in _momoProviders) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() => _selectedMomoNetwork = item.code);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedMomoNetwork == item.code
                            ? AppTheme.primarySoft.withValues(alpha: 0.35)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedMomoNetwork == item.code
                              ? AppTheme.primary
                              : AppTheme.line,
                          width: _selectedMomoNetwork == item.code ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: item.bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                item.code == 'AIRTELTIGO'
                                    ? 'AT'
                                    : item.code == 'TELECEL'
                                        ? 'TC'
                                        : 'MTN',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: item.fg,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _selectedMomoNetwork == item.code
                                        ? AppTheme.primary
                                        : AppTheme.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedMomoNetwork == item.code)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primary,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final name = _shopName.text.trim();
    final owner = _ownerName.text.trim();
    final phone = _phone.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter the business name');
      return;
    }
    if (owner.isEmpty) {
      setState(() => _error = 'Please enter the owner name');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter a valid phone number');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await OnboardingApi.createShop({
        'shop_name': name,
        'owner_name': owner,
        'email': _email.text.trim(),
        'phone_no': phone,
        'shop_type': _shopType,
        'shop_gps_address': _gps.text.trim(),
        'momo_network': _selectedMomoNetwork,
        'momo_number': _momoNumber.text.trim(),
        'momo_name': _momoName.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Walk-in shop registered — pending admin verification. Add products next.',
          ),
          backgroundColor: Color(0xFF15803D),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = OnboardingApi.toUserMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Walk-in shop'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset > 0 ? bottomInset + 32 : 36),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDBA74)),
            ),
            child: const Text(
              'Website vendors apply on /sell and are assigned by admin — they already appear under Assigned Shops. '
              'Use this form only for walk-in / field registrations.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF9A3412),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Business Information',
            subtitle: 'Register a walk-in store for Troskit admin review.',
            children: [
              const FieldLabel('Business name', required: true),
              TextField(
                controller: _shopName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Accra Fresh Supermarket',
                  prefixIcon: Icon(Icons.storefront_rounded),
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Owner name', required: true),
              TextField(
                controller: _ownerName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Full name of business owner',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Email address'),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'owner@example.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Phone number', required: true),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                decoration: const InputDecoration(
                  hintText: '9-digit phone number',
                  counterText: '',
                  prefixText: '🇬🇭 +233  ',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Store Location',
            subtitle: 'GhanaPost GPS address to pin store location.',
            children: [
              const FieldLabel('GhanaPost GPS address'),
              TextField(
                controller: _gps,
                decoration: const InputDecoration(
                  hintText: 'e.g. GA-123-4567',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Mobile Money Payout',
            subtitle: 'Payout account details for the store owner.',
            children: [
              const FieldLabel('Network provider'),
              Builder(
                builder: (context) {
                  final activeProvider = _momoProviders.firstWhere(
                    (p) => p.code == _selectedMomoNetwork,
                    orElse: () => _momoProviders.first,
                  );
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _showMomoProviderBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: activeProvider.bg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                activeProvider.code == 'AIRTELTIGO'
                                    ? 'AT'
                                    : activeProvider.code == 'TELECEL'
                                        ? 'TC'
                                        : 'MTN',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: activeProvider.fg,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  activeProvider.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  activeProvider.subtitle,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.muted,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              const FieldLabel('MoMo account number'),
              TextField(
                controller: _momoNumber,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '024 XXX XXXX',
                  prefixIcon: Icon(Icons.phone_android_rounded),
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Account holder name'),
              TextField(
                controller: _momoName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Name registered on MoMo account',
                  prefixIcon: Icon(Icons.badge_outlined),
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
            label: 'Submit store for verification',
            loading: _busy,
            icon: Icons.verified_outlined,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
