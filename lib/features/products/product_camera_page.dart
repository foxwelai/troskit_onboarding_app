import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_compress_util.dart';
import '../../core/widgets/image_adjust_sheet.dart';

class ProductCameraPage extends StatefulWidget {
  const ProductCameraPage({super.key});

  @override
  State<ProductCameraPage> createState() => _ProductCameraPageState();
}

class _ProductCameraPageState extends State<ProductCameraPage>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _initializing = true;
  String? _error;
  bool _takingPicture = false;
  File? _capturedFile;
  FlashMode _flashMode = FlashMode.auto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Warm AI compressor while camera boots — first enhance must not cold-start.
    ImageCompressUtil.ensureAiReady();
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _initializing = false;
            _error = 'No camera found on this device.';
          });
        }
        return;
      }

      // Default to back camera
      final backIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _selectedCameraIndex = backIdx >= 0 ? backIdx : 0;
      await _initCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Could not access camera: $e';
        });
      }
    }
  }

  Future<void> _initCameraController(CameraDescription camera) async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    // Use ResolutionPreset.high (1080p / ~2MP).
    // This prevents phones with 50MP/108MP sensors from running out of memory
    // and ensures fast capture, sharp product photos, and no OS crashes.
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      try {
        await controller.setFlashMode(_flashMode);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _controller = controller;
          _initializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    FlashMode next;
    switch (_flashMode) {
      case FlashMode.auto:
        next = FlashMode.always;
        break;
      case FlashMode.always:
        next = FlashMode.off;
        break;
      default:
        next = FlashMode.auto;
        break;
    }

    try {
      await controller.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (_) {}
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.always:
        return Icons.flash_on_rounded;
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
      default:
        return Icons.flash_auto_rounded;
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _takingPicture) {
      return;
    }

    try {
      setState(() => _takingPicture = true);
      HapticFeedback.lightImpact();

      final xfile = await controller.takePicture();
      var originalFile = File(xfile.path);

      // Crop to exact 3:3 (1:1 square) ratio for AI compatibility
      originalFile = await ImageCompressUtil.cropToSquare(originalFile);

      if (mounted) {
        setState(() {
          _capturedFile = originalFile;
          _takingPicture = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _takingPicture = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take photo: $e')),
        );
      }
    }
  }

  Future<void> _showDeviceCameraDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Open Device Camera',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
        content: const Text(
          'This will switch to your phone\'s default camera app to capture the photo.',
          style: TextStyle(fontSize: 14, color: AppTheme.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context, 'FALLBACK_SYSTEM_CAMERA');
    }
  }

  Future<void> _confirmPhoto() async {
    final file = _capturedFile;
    if (file == null) return;

    setState(() => _takingPicture = true);
    // Prefer AI-ready JPEG so first enhance after capture never sends HEIC/raw.
    File ready;
    try {
      ready = await ImageCompressUtil.prepareForAiEnhance(file);
    } catch (_) {
      ready = await ImageCompressUtil.compressProductImage(file);
    }

    if (mounted) {
      Navigator.pop(context, ready);
    }
  }

  void _retakePhoto() {
    final file = _capturedFile;
    if (file != null && file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
    setState(() {
      _capturedFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _capturedFile != null
            ? _buildPreviewScreen()
            : _buildCameraScreen(),
      ),
    );
  }

  Widget _buildPreviewScreen() {
    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _retakePhoto,
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                tooltip: 'Retake',
              ),
              const Text(
                'Review Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 48), // Balance close button
            ],
          ),
        ),
        // Image preview — edge-to-edge cover, no letterbox bars
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  _capturedFile!,
                  key: ValueKey(_capturedFile!.path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _takingPicture
                      ? null
                      : () async {
                          final next = await showImageAdjustSheet(
                            context: context,
                            file: _capturedFile!,
                          );
                          if (next != null && mounted) {
                            setState(() => _capturedFile = next);
                          }
                        },
                  icon: const Icon(Icons.crop_rotate_rounded, size: 18),
                  label: const Text(
                    'Adjust',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _retakePhoto,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      'Retake',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _takingPicture ? null : _confirmPhoto,
                    icon: _takingPicture
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _takingPicture ? 'Saving...' : 'Use Photo',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraScreen() {
    if (_initializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text(
              'Opening Camera...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_error != null || _controller == null || !_controller!.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 54),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Unable to open camera.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context, 'FALLBACK_SYSTEM_CAMERA'),
                child: const Text('Use System Camera Instead'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Camera Viewfinder (3:3 / 1:1 square ratio)
        Center(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize != null
                      ? _controller!.value.previewSize!.height
                      : 1080,
                  height: _controller!.value.previewSize != null
                      ? _controller!.value.previewSize!.width
                      : 1080,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
        ),

        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.black38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                ),
                const Text(
                  'Product Camera',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(_flashIcon, color: Colors.white, size: 24),
                      tooltip: 'Flash',
                    ),
                    if (_cameras.length > 1)
                      IconButton(
                        onPressed: _switchCamera,
                        icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 24),
                        tooltip: 'Switch Camera',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Device Camera button below switch camera at top right
        Positioned(
          top: 68,
          right: 18,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _showDeviceCameraDialog,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                  border: Border.all(color: Colors.white30, width: 1),
                ),
                child: const Icon(
                  Icons.photo_camera_back_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),

        // Bottom control bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            color: Colors.black45,
            child: Center(
              child: GestureDetector(
                onTap: _takingPicture ? null : _takePicture,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: _takingPicture ? Colors.grey : Colors.white.withValues(alpha: 0.2),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: _takingPicture
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
