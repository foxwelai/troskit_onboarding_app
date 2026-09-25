import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';

class BlockedAccessPage extends StatefulWidget {
  final String? message;
  const BlockedAccessPage({super.key, this.message});

  @override
  State<BlockedAccessPage> createState() => _BlockedAccessPageState();
}

class _BlockedAccessPageState extends State<BlockedAccessPage> {
  bool _busy = false;

  Future<void> _recheck() async {
    setState(() => _busy = true);
    try {
      await OnboardingApi.me();
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            OnboardingApi.toUserMessage(e),
          ),
          backgroundColor: const Color(0xFFC2410C),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await OnboardingApi.logout();
    if (mounted) context.go('/login');
  }

  void _exit() {
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = (size.width * 0.07).clamp(20.0, 32.0);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Stack(
        children: [
          // Background ambient soft circles matching Splash & Login
          Positioned(
            top: -70,
            right: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primarySoft.withValues(alpha: 0.45),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primarySoft.withValues(alpha: 0.3),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: pad, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Troskit Brand Logo & Lock Badge
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppTheme.primarySoft.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Image.asset(
                              'assets/logos/troskit-logo.png',
                              width: 72,
                              height: 72,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Access Removed',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'NOT AUTHORIZED',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDark,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Details Card matching light theme surface
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.line),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.message != null &&
                                  widget.message!.trim().isNotEmpty
                              ? widget.message!
                              : 'Your onboarding agent privileges have been removed or disabled by Troskit Admin. You no longer have access to onboard stores or view shop catalogs.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.ink,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: 'Re-check access status',
                        loading: _busy,
                        icon: Icons.refresh_rounded,
                        onPressed: _recheck,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Sign in with another account'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.ink,
                            side: const BorderSide(color: AppTheme.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _exit,
                        child: const Text(
                          'Exit App',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
