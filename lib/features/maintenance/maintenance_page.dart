import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../core/services/maintenance_service.dart';
import '../../core/theme/app_theme.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  bool _isChecking = false;

  Future<void> _checkAgain() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final status = await MaintenanceService.instance.checkStatus();
      if (!mounted) return;

      if (!status.isMaintenance) {
        // Router refresh listener will automatically redirect to /splash
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maintenance is still in progress. Please check again shortly.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to reach server. Please check your connection.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: ListenableBuilder(
        listenable: MaintenanceService.instance,
        builder: (context, _) {
          final status = MaintenanceService.instance.status;
          final title = status.title;
          final message = status.message;

          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Troskit Brand Logo
                      Image.asset(
                        AppTheme.logoAsset,
                        width: 125,
                        height: 125,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 6),

                      Text(
                        'Troskit Onboarding',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 16),


                      // Lottie Animation
                      SizedBox(
                        width: 230,
                        height: 230,
                        child: Lottie.asset(
                          'assets/animations/under-maintenance.lottie',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('[MaintenancePage] Lottie load error: $error');
                            return const Center(
                              child: Icon(
                                Icons.build_circle_rounded,
                                size: 90,
                                color: Color(0xFFF59E0B),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),


                      // Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Message
                      Container(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Retry / Check again button
                      SizedBox(
                        width: 200,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isChecking ? null : _checkAgain,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _isChecking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.refresh_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Check again',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
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
        },
      ),
    );
  }
}
