import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/blocked_access_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/splash_page.dart';
import 'features/barcode_scanner_page.dart';
import 'features/home/home_page.dart';
import 'features/products/add_product_page.dart';
import 'features/shops/onboard_shop_page.dart';
import 'features/shops/shop_detail_page.dart';
import 'features/shops/store_details_page.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[PlatformError] $error\n$stack');
      return true;
    };

    // Bundled under google_fonts/ — avoid release crashes when offline.
    GoogleFonts.config.allowRuntimeFetching = false;
    SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUi);
    runApp(const TroskitOnboardingApp());
  }, (error, stack) {
    debugPrint('[ZoneError] $error\n$stack');
  });
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/blocked',
      builder: (context, state) => BlockedAccessPage(
        message: state.extra is String ? state.extra as String : null,
      ),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/shops/new',
      builder: (context, state) => const OnboardShopPage(),
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => const BarcodeScannerPage(),
    ),
    GoRoute(
      path: '/shops/:uuid',
      builder: (context, state) => ShopDetailPage(
        shopUuid: state.pathParameters['uuid']!,
      ),
      routes: [
        GoRoute(
          path: 'store-details',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => StoreDetailsPage(
            shopUuid: state.pathParameters['uuid']!,
          ),
        ),
        GoRoute(
          path: 'products/new',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => AddProductPage(
            shopUuid: state.pathParameters['uuid']!,
            hasBarcode: state.uri.queryParameters['hasBarcode'] != 'false',
          ),
        ),
        GoRoute(
          path: 'products/:productUuid/edit',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => AddProductPage(
            shopUuid: state.pathParameters['uuid']!,
            productUuid: state.pathParameters['productUuid'],
            hasBarcode: state.uri.queryParameters['hasBarcode'] != 'false',
          ),
        ),
      ],
    ),
  ],
);

class TroskitOnboardingApp extends StatelessWidget {
  const TroskitOnboardingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemUi,
      child: MaterialApp.router(
        title: 'Troskit Onboarding',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
