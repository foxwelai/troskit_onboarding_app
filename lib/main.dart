import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/api_constants.dart';
import 'core/services/maintenance_service.dart';
import 'features/auth/blocked_access_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/splash_page.dart';
import 'features/maintenance/maintenance_page.dart';
import 'features/home/home_page.dart';

// Heavy routes — deferred so camera/scanner/AI/shop editors aren't pulled into
// the initial isolate startup graph.
import 'features/barcode_scanner_page.dart' deferred as scanner;
import 'features/products/add_product_page.dart' deferred as add_product;
import 'features/products/ai_images_page.dart' deferred as ai_images;
import 'features/shops/onboard_shop_page.dart' deferred as onboard_shop;
import 'features/shops/shop_detail_page.dart' deferred as shop_detail;
import 'features/shops/store_details_page.dart' deferred as store_details;

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

    await ApiConstants.init();
    MaintenanceService.instance.startMonitoring();

    runApp(const TroskitOnboardingApp());
  }, (error, stack) {
    debugPrint('[ZoneError] $error\n$stack');
  });
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Cache deferred-library futures so rebuilds don't re-call [loadLibrary].
final Map<Object, Future<void>> _deferredFutures = {};

Widget _deferred(Future<void> Function() load, Widget Function() builder) {
  final future = _deferredFutures.putIfAbsent(load, load);
  return FutureBuilder<void>(
    future: future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        );
      }
      if (snap.hasError) {
        return Scaffold(
          body: Center(child: Text('Failed to load screen: ${snap.error}')),
        );
      }
      return builder();
    },
  );
}

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  refreshListenable: MaintenanceService.instance,
  redirect: (context, state) {
    final isMaint = MaintenanceService.instance.isMaintenance;
    final atMaint = state.matchedLocation == '/maintenance';

    if (isMaint) {
      return atMaint ? null : '/maintenance';
    }

    if (atMaint) {
      return '/splash';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/maintenance',
      builder: (context, state) => const MaintenancePage(),
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
      path: '/ai-images',
      builder: (context, state) => _deferred(
        ai_images.loadLibrary,
        () => ai_images.AiImagesPage(),
      ),
    ),
    GoRoute(
      path: '/shops/new',
      builder: (context, state) => _deferred(
        onboard_shop.loadLibrary,
        () => onboard_shop.OnboardShopPage(),
      ),
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => _deferred(
        scanner.loadLibrary,
        () => scanner.BarcodeScannerPage(),
      ),
    ),
    GoRoute(
      path: '/shops/:uuid',
      builder: (context, state) => _deferred(
        shop_detail.loadLibrary,
        () => shop_detail.ShopDetailPage(
          shopUuid: state.pathParameters['uuid']!,
        ),
      ),
      routes: [
        GoRoute(
          path: 'store-details',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => _deferred(
            store_details.loadLibrary,
            () => store_details.StoreDetailsPage(
              shopUuid: state.pathParameters['uuid']!,
            ),
          ),
        ),
        GoRoute(
          path: 'products/new',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => _deferred(
            add_product.loadLibrary,
            () => add_product.AddProductPage(
              shopUuid: state.pathParameters['uuid']!,
              hasBarcode: state.uri.queryParameters['hasBarcode'] != 'false',
            ),
          ),
        ),
        GoRoute(
          path: 'products/:productUuid/edit',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => _deferred(
            add_product.loadLibrary,
            () => add_product.AddProductPage(
              shopUuid: state.pathParameters['uuid']!,
              productUuid: state.pathParameters['productUuid'],
              hasBarcode: state.uri.queryParameters['hasBarcode'] != 'false',
            ),
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
