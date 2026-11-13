import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/image_compress_util.dart';

/// Rotate (90°) + Straighten dial. Same UX in POS + onboarding.
Future<File?> showImageAdjustSheet({
  required BuildContext context,
  required File file,
  String title = 'Adjust photo',
}) {
  return Navigator.of(context).push<File>(
    MaterialPageRoute(
      builder: (_) => _ImageAdjustPage(file: file, title: title),
      fullscreenDialog: true,
    ),
  );
}

enum _AdjustTool { rotate, straighten }

class _ImageAdjustPage extends StatefulWidget {
  final File file;
  final String title;

  const _ImageAdjustPage({required this.file, required this.title});

  @override
  State<_ImageAdjustPage> createState() => _ImageAdjustPageState();
}

class _ImageAdjustPageState extends State<_ImageAdjustPage> {
  late File _source;
  _AdjustTool _tool = _AdjustTool.straighten;
  int _quarterTurns = 0;
  double _tilt = 0; // -45 .. 45
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _source = widget.file;
  }

  double get _previewDegrees => _quarterTurns * 90.0 + _tilt;

  void _onRotateTap() {
    HapticFeedback.selectionClick();
    setState(() {
      _tool = _AdjustTool.rotate;
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
  }

  void _onStraightenTap() {
    HapticFeedback.selectionClick();
    // Keep current rotation — only switch to the tilt dial.
    setState(() => _tool = _AdjustTool.straighten);
  }

  void _onReset() {
    HapticFeedback.selectionClick();
    setState(() {
      _quarterTurns = 0;
      _tilt = 0;
      _tool = _AdjustTool.straighten;
    });
  }

  Future<void> _finish() async {
    if (_busy) return;
    final degrees = _previewDegrees;
    if (degrees.abs() < 0.05) {
      Navigator.pop(context, _source);
      return;
    }
    setState(() => _busy = true);
    try {
      final out = await ImageCompressUtil.rotateOrTilt(_source, degrees);
      if (!mounted) return;
      Navigator.pop(context, out);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        Navigator.pop(context, _source);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _busy ? null : _onReset,
            child: const Text(
              'Reset',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _finish,
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRect(
                        child: Transform.rotate(
                          angle: _previewDegrees * math.pi / 180,
                          child: Image.file(
                            _source,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_busy)
                    const ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_tool == _AdjustTool.straighten) ...[
              Text(
                _tilt == 0
                    ? '0°'
                    : '${_tilt > 0 ? '+' : ''}${_tilt.toStringAsFixed(0)}°',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: _StraightenRuler(
                  value: _tilt,
                  onChanged: (v) {
                    if ((v - _tilt).abs() < 0.01) return;
                    setState(() {
                      _tool = _AdjustTool.straighten;
                      _tilt = v;
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
            ] else
              const SizedBox(height: 72),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ToolButton(
                    label: 'Rotate',
                    selected: _tool == _AdjustTool.rotate,
                    onTap: _onRotateTap,
                    icon: Icons.rotate_right_rounded,
                  ),
                  _ToolButton(
                    label: 'Straighten',
                    selected: _tool == _AdjustTool.straighten,
                    onTap: _onStraightenTap,
                    iconBuilder: (color) => Transform.rotate(
                      angle: -0.35,
                      child: Icon(
                        Icons.crop_landscape_rounded,
                        color: color,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _busy ? null : _finish,
                  child: const Text(
                    'Use adjusted photo',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget Function(Color color)? iconBuilder;

  const _ToolButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.black : Colors.white;
    final bg = selected ? Colors.white : const Color(0xFF2A2A2A);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: iconBuilder != null
                  ? iconBuilder!(fg)
                  : Icon(icon, color: fg, size: 26),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drag-based straighten dial (±45°) with yellow center marker.
class _StraightenRuler extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _StraightenRuler({required this.value, required this.onChanged});

  static const double minDeg = -45;
  static const double maxDeg = 45;
  static const double pxPerDeg = 10;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) {
            final next = (value - d.delta.dx / pxPerDeg)
                .clamp(minDeg, maxDeg)
                .roundToDouble();
            onChanged(next);
          },
          onTapUp: (d) {
            final dx = d.localPosition.dx - width / 2;
            final next =
                (value + dx / pxPerDeg).clamp(minDeg, maxDeg).roundToDouble();
            onChanged(next);
          },
          child: CustomPaint(
            size: Size(width, 56),
            painter: _RulerPainter(value: value),
          ),
        );
      },
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double value;

  _RulerPainter({required this.value});

  static const double minDeg = -45;
  static const double maxDeg = 45;
  static const double pxPerDeg = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final tickPaint = Paint()..strokeWidth = 2;

    for (var deg = minDeg; deg <= maxDeg; deg++) {
      final x = cx + (deg - value) * pxPerDeg;
      if (x < -4 || x > size.width + 4) continue;
      final major = deg % 5 == 0;
      tickPaint.color = major ? Colors.white : Colors.white38;
      final h = major ? 28.0 : 18.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, cy), width: 2, height: h),
          const Radius.circular(1),
        ),
        tickPaint,
      );
    }

    final centerPaint = Paint()..color = const Color(0xFFFFD60A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 3, height: 36),
        const Radius.circular(2),
      ),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) =>
      oldDelegate.value != value;
}
