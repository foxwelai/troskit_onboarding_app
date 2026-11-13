import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageCompressUtil {
  static bool _aiReady = false;
  static Future<void>? _aiReadyFuture;

  /// Nest multer limit is 8MB — stay comfortably under for AI uploads.
  static const int aiMaxBytes = 4 * 1024 * 1024;

  /// Crops [file] to exact 3:3 (1:1 square) aspect ratio, centered.
  static Future<File> cropToSquare(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final croppedBytes = await compute(_cropToSquareSync, bytes);
      if (croppedBytes != null) {
        await file.writeAsBytes(croppedBytes);
      }
    } catch (e) {
      debugPrint('[ImageCrop] Error cropping to square (3:3): $e');
    }
    return file;
  }

  /// Backward-compatible alias for 3:3 cropping
  static Future<File> cropTo3by4(File file) => cropToSquare(file);

  /// Opaque RGB canvas filled with pure white, then [src] composited on top.
  static img.Image _flattenOnPureWhite(img.Image src) {
    final canvas = img.Image(
      width: src.width,
      height: src.height,
      numChannels: 3,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, src);
    return canvas;
  }

  static Uint8List? _cropToSquareSync(Uint8List rawBytes) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;

    final needsFlatten =
        decoded.numChannels >= 4 || _isPng(rawBytes) || _isWebp(rawBytes);
    final alreadySquare = decoded.width == decoded.height;
    if (alreadySquare && !needsFlatten) return null;

    img.Image square = decoded;
    if (!alreadySquare) {
      final side =
          decoded.width < decoded.height ? decoded.width : decoded.height;
      final xOffset = ((decoded.width - side) / 2).round();
      final yOffset = ((decoded.height - side) / 2).round();
      square = img.copyCrop(
        decoded,
        x: xOffset,
        y: yOffset,
        width: side,
        height: side,
      );
    }

    // Flatten onto pure white before JPEG (transparent uploads → not black).
    final flat = _flattenOnPureWhite(square);
    return Uint8List.fromList(img.encodeJpg(flat, quality: 92));
  }

  static bool _isJpeg(List<int> bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;

  static bool _isPng(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;

  static bool _isWebp(List<int> bytes) =>
      bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;

  static bool _isAiUploadable(List<int> bytes) =>
      _isJpeg(bytes) || _isPng(bytes) || _isWebp(bytes);

  /// Warms the native image compressor so the first camera enhance does not
  /// hit a cold FlutterImageCompress / HEIC→JPEG failure.
  static Future<void> ensureAiReady() {
    if (_aiReady) return Future.value();
    return _aiReadyFuture ??= _warmAiPipeline();
  }

  static Future<void> _warmAiPipeline() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final seed = File(
        '${tempDir.path}/troskit_ai_warmup_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final tiny = img.Image(width: 8, height: 8);
      img.fill(tiny, color: img.ColorRgb8(255, 255, 255));
      await seed.writeAsBytes(img.encodeJpg(tiny, quality: 80), flush: true);
      final outPath =
          '${tempDir.path}/troskit_ai_warmup_out_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final warmed = await FlutterImageCompress.compressAndGetFile(
        seed.absolute.path,
        outPath,
        quality: 80,
        minWidth: 8,
        minHeight: 8,
        format: CompressFormat.jpeg,
      );
      try {
        await seed.delete();
      } catch (_) {}
      try {
        await File(outPath).delete();
      } catch (_) {}
      if (warmed == null) {
        throw StateError('Warm-up compress returned null');
      }
      _aiReady = true;
      debugPrint('[ImageCompress] AI pipeline ready');
    } catch (e) {
      debugPrint('[ImageCompress] AI warm-up failed: $e');
      // Allow retry on next enhance attempt.
      _aiReadyFuture = null;
      _aiReady = false;
    }
  }

  static Future<File> _writeTempJpeg(Uint8List bytes, String prefix) async {
    final tempDir = await getTemporaryDirectory();
    final out = File(
      '${tempDir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(bytes, flush: true);
    return out;
  }

  /// Force a real JPEG (magic bytes) via the Dart image decoder.
  /// Transparent pixels are composited onto pure white (#FFFFFF).
  static Future<File?> _forceJpegViaDart(
    File file, {
    int maxSide = 1280,
    int quality = 82,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      img.Image resized = decoded;
      final side = decoded.width > decoded.height ? decoded.width : decoded.height;
      if (side > maxSide) {
        resized = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxSide : null,
          height: decoded.height > decoded.width ? maxSide : null,
          interpolation: img.Interpolation.average,
        );
      }
      final flat = _flattenOnPureWhite(resized);
      var jpg = Uint8List.fromList(img.encodeJpg(flat, quality: quality));
      var q = quality;
      while (jpg.length > aiMaxBytes && q > 45) {
        q -= 10;
        jpg = Uint8List.fromList(img.encodeJpg(flat, quality: q));
      }
      return _writeTempJpeg(jpg, 'ai_force');
    } catch (e) {
      debugPrint('[ImageCompress] forceJpegViaDart failed: $e');
      return null;
    }
  }

  /// Always produce a verified JPEG/PNG/WebP under [aiMaxBytes] for AI upload.
  /// Camera HEIC / cold compressor failures previously sent a bad first payload.
  static Future<File> prepareForAiEnhance(File file) async {
    await ensureAiReady();

    File? candidate;

    try {
      final tempDir = await getTemporaryDirectory();
      final rawName = file.path.split('/').last.split('\\').last;
      final nameWithoutExt = rawName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final targetPath =
          '${tempDir.path}/ai_src_${DateTime.now().millisecondsSinceEpoch}_$nameWithoutExt.jpg';

      // 1280 keeps quality for OpenAI edits and stays under multer 8MB.
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 82,
        minWidth: 1280,
        minHeight: 1280,
        keepExif: false,
        format: CompressFormat.jpeg,
      );
      if (result != null) {
        candidate = File(result.path);
        _aiReady = true;
      }
    } catch (e) {
      debugPrint('[ImageCompress] prepareForAiEnhance native error: $e');
    }

    // Validate magic bytes — native can write a path that is still HEIC/invalid.
    if (candidate != null) {
      final bytes = await candidate.readAsBytes();
      if (!_isAiUploadable(bytes)) {
        debugPrint(
          '[ImageCompress] native output not JPEG/PNG/WebP — dart fallback',
        );
        candidate = await _forceJpegViaDart(file);
      } else if (bytes.length > aiMaxBytes) {
        candidate = await _forceJpegViaDart(candidate, quality: 70);
      }
    } else {
      candidate = await _forceJpegViaDart(file);
    }

    if (candidate == null) {
      // Last chance: original if already a small valid image.
      final bytes = await file.readAsBytes();
      if (_isAiUploadable(bytes) && bytes.length <= aiMaxBytes) {
        return file;
      }
      throw Exception(
        'Could not prepare photo for AI. Please retake as JPEG and try again.',
      );
    }

    final outBytes = await candidate.readAsBytes();
    if (!_isAiUploadable(outBytes)) {
      throw Exception(
        'Could not prepare photo for AI. Please retake as JPEG and try again.',
      );
    }
    if (outBytes.length > aiMaxBytes) {
      final smaller = await _forceJpegViaDart(candidate, maxSide: 1024, quality: 65);
      if (smaller == null || await smaller.length() > aiMaxBytes) {
        throw Exception(
          'Photo is too large for AI enhance. Please retake closer / lower resolution.',
        );
      }
      return smaller;
    }
    return candidate;
  }

  /// Flatten any transparency onto **pure white (#FFFFFF)** then JPEG.
  /// Fixes AI cutouts / transparent uploads that previously became black.
  static Future<File> compositeOnPureWhite(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final out = await compute(_compositeOnPureWhiteSync, bytes);
      if (out == null) return file;
      return _writeTempJpeg(out, 'white_bg');
    } catch (e) {
      debugPrint('[ImageCompress] compositeOnPureWhite error: $e');
      return file;
    }
  }

  static Uint8List? _compositeOnPureWhiteSync(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final needsFlatten =
        decoded.numChannels >= 4 || _isPng(bytes) || _isWebp(bytes);
    if (!needsFlatten && _isJpeg(bytes)) {
      // Already opaque JPEG — keep as-is (return null → caller keeps file).
      return null;
    }
    final flat = _flattenOnPureWhite(decoded);
    return Uint8List.fromList(img.encodeJpg(flat, quality: 92));
  }

  /// Fixed rotate (90/180/270) or small tilt. Expanded corners = pure white.
  static Future<File> rotateOrTilt(File file, double degrees) async {
    final bytes = await file.readAsBytes();
    final out = await compute(
      _rotateOrTiltSync,
      _RotateParams(bytes: bytes, degrees: degrees),
    );
    if (out == null) return file;
    return _writeTempJpeg(out, 'rot');
  }

  static Uint8List? _rotateOrTiltSync(_RotateParams p) {
    final decoded = img.decodeImage(p.bytes);
    if (decoded == null) return null;
    final rotated = img.copyRotate(decoded, angle: p.degrees);

    // Exact 90° steps keep full frame. Small tilts crop inset so no white wedges.
    final normalized = p.degrees % 90;
    final isQuarter =
        normalized.abs() < 0.01 || (normalized.abs() - 90).abs() < 0.01;
    img.Image out = rotated;
    if (!isQuarter) {
      final rad = p.degrees.abs() * math.pi / 180;
      final origSide =
          decoded.width < decoded.height ? decoded.width : decoded.height;
      final maxSide = math.min(rotated.width, rotated.height);
      final inset = (origSide / (math.cos(rad) + math.sin(rad)))
          .floor()
          .clamp(1, maxSide)
          .toInt();
      final x = ((rotated.width - inset) / 2).round();
      final y = ((rotated.height - inset) / 2).round();
      out = img.copyCrop(rotated, x: x, y: y, width: inset, height: inset);
    }

    final flat = _flattenOnPureWhite(out);
    return Uint8List.fromList(img.encodeJpg(flat, quality: 92));
  }

  /// Compresses [file] with visually lossless quality (~85%) while preserving
  /// high resolution (up to 1920x1920, Full-HD catalog standard).
  /// Transparent PNGs are flattened onto pure white first (never black).
  static Future<File> compressProductImage(
    File file, {
    int minWidth = 1920,
    int minHeight = 1920,
    int quality = 85,
  }) async {
    try {
      // Kill black backgrounds from AI cutouts / alpha PNGs before JPEG encode.
      file = await compositeOnPureWhite(file);

      final bytes = await file.length();
      final isPng = file.path.toLowerCase().endsWith('.png');
      // Only skip when already a small *JPEG* (magic bytes), not HEIC renamed .jpg.
      if (bytes < 300 * 1024 && !isPng) {
        final head = await file.openRead(0, 12).first;
        if (_isJpeg(head)) return file;
      }

      final tempDir = await getTemporaryDirectory();
      final rawName = file.path.split('/').last.split('\\').last;
      final nameWithoutExt = rawName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final targetPath =
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_$nameWithoutExt.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        keepExif: false,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        _aiReady = true;
        final compressedFile = File(result.path);
        final compressedBytes = await compressedFile.length();
        debugPrint(
          '[ImageCompress] Original: ${(bytes / 1024).toStringAsFixed(1)} KB -> Compressed: ${(compressedBytes / 1024).toStringAsFixed(1)} KB',
        );
        return compressedFile;
      }
    } catch (e) {
      debugPrint('[ImageCompress] Compression error (fallback to original): $e');
    }
    return file;
  }
}

class _RotateParams {
  final Uint8List bytes;
  final double degrees;

  _RotateParams({required this.bytes, required this.degrees});
}
