import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Top-of-screen toast / notification that renders on the root overlay,
/// ensuring it appears ABOVE open bottom sheets and dialogs.
class TopToast {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    bool isError = true,
    Duration duration = const Duration(seconds: 4),
  }) {
    dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (ctx) => _TopToastWidget(
        title: title ?? (isError ? 'Oh no, something went wrong!' : 'Notice'),
        message: message,
        isError: isError,
        onDismiss: dismiss,
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  static void showError(
    BuildContext context,
    dynamic error, {
    String? title,
  }) {
    final msg = formatErrorMessage(error);
    show(
      context,
      title: title ?? 'Oh no, something went wrong!',
      message: msg,
      isError: true,
    );
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
    String title = 'Success',
  }) {
    show(
      context,
      title: title,
      message: message,
      isError: false,
    );
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }

  /// Converts any technical or raw error into friendly, human-understandable copy.
  static String formatErrorMessage(dynamic error) {
    if (error == null) {
      return 'Something went wrong! Please try again or contact Admin.';
    }

    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();

    // AI quota / credit exhausted
    if (lower.contains('quota') ||
        lower.contains('credit') ||
        lower.contains('billing') ||
        lower.contains('insufficient') ||
        lower.contains('exhaust')) {
      return 'AI credit limit reached! Please contact Admin or try again later.';
    }

    // Rate limits
    if (lower.contains('429') ||
        lower.contains('too many requests') ||
        lower.contains('rate limit') ||
        lower.contains('ai-enhance-min')) {
      return 'AI Agent is doing too much work! Try again after some time or contact Admin.';
    }

    // Backend route / 404 / Cannot POST
    if (lower.contains('cannot post') ||
        lower.contains('cannot get') ||
        lower.contains('404') ||
        lower.contains('not found')) {
      return 'Oh no, something went wrong! AI Agent is doing too much work! Try again after some time or contact Admin.';
    }

    // OpenAI key expired / invalid (distinct from cold-start)
    if (lower.contains('api key has expired') ||
        lower.contains('invalid api key') ||
        lower.contains('incorrect api key')) {
      return 'AI service key needs renewal. Please contact Admin.';
    }

    // OpenAI key missing / cold start / 503
    // (avoid matching "No active prompt configured …" via bare "not configured")
    if (lower.contains('503') ||
        lower.contains('chat_gpt_api_key') ||
        lower.contains('service unavailable') ||
        lower.contains('temporarily unavailable') ||
        lower.contains('is not configured on the server') ||
        lower.contains('not initialis') ||
        lower.contains('not initializ') ||
        lower.contains('ai agent not') ||
        lower.contains('ai agent is not')) {
      return 'AI Agent is not ready yet. Please try again in a moment, or contact Admin.';
    }

    // Network connection errors
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('clientexception')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    }

    // Timeout
    if (lower.contains('timeoutexception') || lower.contains('timeout')) {
      return 'The server took too long to respond. Please try again.';
    }

    // Auth / access
    if (lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('unauthorized') ||
        lower.contains('access blocked') ||
        lower.contains('access removed')) {
      return 'Access restricted: Please contact Admin.';
    }

    // Hide stack traces, endpoints, URLs
    if (lower.contains('http://') ||
        lower.contains('https://') ||
        lower.contains('formaterror') ||
        lower.contains('typeerror') ||
        lower.contains('nosuchmethoderror') ||
        lower.contains('/onboarding/')) {
      return 'Oh no, something went wrong! AI Agent is doing too much work! Try again after some time or contact Admin.';
    }

    return raw;
  }
}

class _TopToastWidget extends StatefulWidget {
  final String title;
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    required this.title,
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  Future<void> _handleDismiss() async {
    await _anim.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final accent = widget.isError ? AppTheme.primary : const Color(0xFF10B981);
    final icon = widget.isError ? Icons.smart_toy_outlined : Icons.check_circle_outline_rounded;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, top + 10, 14, 0),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta != null && details.primaryDelta! < -4) {
                    _handleDismiss();
                  }
                },
                child: Material(
                  color: Colors.transparent,
                  elevation: 10,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.isError
                            ? const Color(0xFFFFD6DA)
                            : const Color(0xFFA7F3D0),
                        width: 1.2,
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 5,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: accent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.message,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF475569),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _handleDismiss,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: Colors.black38,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
