import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api.dart';
import '../../core/services/ai_image_vault.dart';
import '../../core/theme/app_theme.dart';

enum AiEnhanceFeature {
  removeBackground(
    'remove_background',
    'Remove Background',
    Icons.layers_clear_outlined,
  ),
  reimagineProduct(
    'reimagine_product',
    'Reimagine Product',
    Icons.auto_awesome_outlined,
  );

  const AiEnhanceFeature(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;

  List<String> get statusLines {
    switch (this) {
      case AiEnhanceFeature.removeBackground:
        return const [
          'Detecting product edges…',
          'Separating subject from scene…',
          'Cleaning fine outlines…',
          'Softening leftover fringe…',
          'Building a transparent cutout…',
          'Polishing the silhouette…',
        ];
      case AiEnhanceFeature.reimagineProduct:
        return const [
          'Reading product details…',
          'Adding soft studio light…',
          'Beautifying texture & color…',
          'Balancing shadows gently…',
          'Giving a premium backdrop…',
          'Sharpening catalog clarity…',
          'Finishing the reimagined look…',
        ];
    }
  }
}

/// Result of the AI Enhancer flow.
class AiEnhancerResult {
  final File file;
  final bool usedAi;
  final bool skipped;
  final AiVaultImage? vaultImage;

  const AiEnhancerResult({
    required this.file,
    this.usedAi = false,
    this.skipped = false,
    this.vaultImage,
  });
}

/// After capture/upload — optional AI tools.
Future<AiEnhancerResult> showAiEnhancerSheet({
  required BuildContext context,
  required File originalFile,
  String? remotePreviewUrl,
}) async {
  final action = await showModalBottomSheet<Object?>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: remotePreviewUrl != null && remotePreviewUrl.isNotEmpty
                          ? Image.network(remotePreviewUrl, fit: BoxFit.cover)
                          : Image.file(originalFile, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Enhancer',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                            color: AppTheme.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Optional — improve this photo now or later while editing.',
                          style: TextStyle(fontSize: 12, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final f in AiEnhanceFeature.values) ...[
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppTheme.line),
                  ),
                  leading: Icon(f.icon, color: AppTheme.primary),
                  title: Text(
                    f.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
                  onTap: () => Navigator.pop(ctx, f),
                ),
                const SizedBox(height: 8),
              ],
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppTheme.line),
                ),
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                title: const Text(
                  'Select from previously Generated images',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
                onTap: () => Navigator.pop(ctx, 'pick_vault'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text(
                  'Maybe later',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (action == null || !context.mounted) {
    return AiEnhancerResult(file: originalFile, skipped: true);
  }

  if (action == 'pick_vault') {
    final picked = await _pickFromVaultImages(context);
    if (picked == null || !context.mounted) {
      return AiEnhancerResult(file: originalFile, skipped: true);
    }
    return AiEnhancerResult(
      file: picked.file,
      usedAi: true,
      vaultImage: picked.entry,
    );
  }

  return _runEnhanceAndChoose(
    context: context,
    originalFile: originalFile,
    feature: action as AiEnhanceFeature,
  );
}

class _VaultPick {
  final File file;
  final AiVaultImage entry;
  _VaultPick({required this.file, required this.entry});
}

Future<_VaultPick?> _pickFromVaultImages(BuildContext context) async {
  final items = await AiImageVault.list();
  if (!context.mounted) return null;

  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No previously generated AI images yet')),
    );
    return null;
  }

  return showModalBottomSheet<_VaultPick>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height * 0.72;
      return SafeArea(
        child: SizedBox(
          height: h,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Previously generated images',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tap an image to use it for this product. Long-press to preview full screen.',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final entry = items[i];
                    return FutureBuilder<File?>(
                      future: AiImageVault.fileFor(entry),
                      builder: (context, snap) {
                        final file = snap.data;
                        if (file == null) {
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.canvas,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }
                        return InkWell(
                          onTap: () => Navigator.pop(
                            ctx,
                            _VaultPick(file: file, entry: entry),
                          ),
                          onLongPress: () => _openImageFullscreen(context, file),
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.line),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(file, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _openImageFullscreen(BuildContext context, File file) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('AI Image'),
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.file(file, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

Future<AiEnhancerResult> _runEnhanceAndChoose({
  required BuildContext context,
  required File originalFile,
  required AiEnhanceFeature feature,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _SamsungStyleAiProgress(feature: feature),
  );

  Map<String, dynamic> result;
  try {
    result = await OnboardingApi.enhanceProductImage(
      file: originalFile,
      featureKey: feature.key,
    );
  } catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
    return AiEnhancerResult(file: originalFile);
  }

  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

  final b64 = (result['image_base64'] ?? '').toString();
  if (b64.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI returned an empty image')),
      );
    }
    return AiEnhancerResult(file: originalFile);
  }

  late final Uint8List bytes;
  try {
    bytes = base64Decode(b64);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to decode AI image')),
      );
    }
    return AiEnhancerResult(file: originalFile);
  }

  // Always keep AI output in the local vault (even if user picks Original).
  final vault = await AiImageVault.saveBytes(
    bytes: bytes,
    featureKey: feature.key,
    featureLabel: feature.label,
  );
  final aiFile = await AiImageVault.fileFor(vault) ??
      await File(
        '${Directory.systemTemp.path}/troskit_ai_${vault.id}.png',
      ).writeAsBytes(bytes, flush: true);

  if (!context.mounted) {
    return AiEnhancerResult(file: originalFile, vaultImage: vault);
  }

  final pageContext = context;
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
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
              const SizedBox(height: 14),
              Text(
                feature.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'AI image is saved in the app. Choose what to upload for this product.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.35),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _compareTile(
                      label: 'Original',
                      child: Image.file(originalFile, fit: BoxFit.cover),
                      onTap: () => _openImageFullscreen(pageContext, originalFile),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _compareTile(
                      label: 'AI result · tap to view',
                      child: Image.file(aiFile, fit: BoxFit.cover),
                      onTap: () => _openImageFullscreen(pageContext, aiFile),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 'ai'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Use AI image',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'original'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Use Original image',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'vault'),
                child: const Text(
                  'View saved AI images',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (choice == 'vault' && pageContext.mounted) {
    pageContext.push('/ai-images');
  }

  if (choice == 'ai') {
    return AiEnhancerResult(file: aiFile, usedAi: true, vaultImage: vault);
  }
  return AiEnhancerResult(file: originalFile, vaultImage: vault);
}

Widget _compareTile({
  required String label,
  required Widget child,
  VoidCallback? onTap,
}) {
  return Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.ink,
        ),
      ),
      const SizedBox(height: 8),
      AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: AppTheme.canvas,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.line),
              ),
              child: child,
            ),
          ),
        ),
      ),
    ],
  );
}

/// Samsung-style generative AI progress: orb + rotating status lines.
class _SamsungStyleAiProgress extends StatefulWidget {
  const _SamsungStyleAiProgress({required this.feature});

  final AiEnhanceFeature feature;

  @override
  State<_SamsungStyleAiProgress> createState() => _SamsungStyleAiProgressState();
}

class _SamsungStyleAiProgressState extends State<_SamsungStyleAiProgress>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _pulse;
  late final List<String> _lines;
  int _lineIndex = 0;
  Timer? _lineTimer;

  @override
  void initState() {
    super.initState();
    _lines = widget.feature.statusLines;
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _lineTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() => _lineIndex = (_lineIndex + 1) % _lines.length);
    });
  }

  @override
  void dispose() {
    _lineTimer?.cancel();
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_spin, _pulse]),
                  builder: (context, _) {
                    final pulse = 0.85 + (_pulse.value * 0.2);
                    return Transform.scale(
                      scale: pulse,
                      child: SizedBox(
                        width: 118,
                        height: 118,
                        child: CustomPaint(
                          painter: _AiOrbPainter(
                            progress: _spin.value,
                            accent: AppTheme.primary,
                            light: true,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.auto_awesome,
                              color: AppTheme.primary,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                const Text(
                  'Troskit AI',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.feature.label,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _lines[_lineIndex],
                    key: ValueKey(_lineIndex),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please keep this screen open',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiOrbPainter extends CustomPainter {
  _AiOrbPainter({
    required this.progress,
    required this.accent,
    this.light = false,
  });

  final double progress;
  final Color accent;
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: light ? 0.18 : 0.35),
          accent.withValues(alpha: light ? 0.05 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(progress * math.pi * 2),
        colors: [
          (light ? AppTheme.line : Colors.white).withValues(alpha: light ? 0.4 : 0.05),
          accent.withValues(alpha: 0.95),
          const Color(0xFFF59E0B).withValues(alpha: 0.85),
          (light ? AppTheme.line : Colors.white).withValues(alpha: light ? 0.4 : 0.05),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r - 6));
    canvas.drawCircle(c, r - 8, ring);

    final core = Paint()
      ..shader = RadialGradient(
        colors: light
            ? [
                AppTheme.primarySoft.withValues(alpha: 0.9),
                Colors.white,
              ]
            : [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.06),
              ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 0.55));
    canvas.drawCircle(c, r * 0.52, core);
  }

  @override
  bool shouldRepaint(covariant _AiOrbPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.light != light;
}
