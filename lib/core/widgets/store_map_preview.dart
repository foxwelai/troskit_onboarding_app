import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/api_constants.dart';
import '../theme/app_theme.dart';

/// Compact store location map (Google) with expand + open-in-Maps actions.
class StoreMapPreview extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double height;

  const StoreMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 160,
  });

  String get _staticMapUrl =>
      'https://maps.googleapis.com/maps/api/staticmap'
      '?center=$latitude,$longitude'
      '&zoom=15'
      '&size=600x300'
      '&maptype=roadmap'
      '&markers=color:red%7C$latitude,$longitude'
      '&key=${ApiConstants.googleMapsApiKey}';

  Future<void> _openExternalMaps(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Maps — restart the app')),
      );
    }
  }

  void _expand(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ExpandedStoreMapPage(
          latitude: latitude,
          longitude: longitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _expand(context),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              height: height,
              decoration: BoxDecoration(
                color: AppTheme.canvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      _staticMapUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 720,
                      cacheHeight: 360,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) => _fallback(),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fullscreen_rounded, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Expand',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _openExternalMaps(context),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open in Maps'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_rounded, color: AppTheme.muted, size: 36),
            const SizedBox(height: 6),
            Text(
              '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedStoreMapPage extends StatefulWidget {
  final double latitude;
  final double longitude;

  const _ExpandedStoreMapPage({
    required this.latitude,
    required this.longitude,
  });

  @override
  State<_ExpandedStoreMapPage> createState() => _ExpandedStoreMapPageState();
}

class _ExpandedStoreMapPageState extends State<_ExpandedStoreMapPage> {
  late final LatLng _point = LatLng(widget.latitude, widget.longitude);

  Future<void> _openExternalMaps(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Maps — restart the app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Store location'),
        actions: [
          IconButton(
            tooltip: 'Open in Maps',
            onPressed: () => _openExternalMaps(context),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _point, zoom: 16),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        markers: {
          Marker(
            markerId: const MarkerId('store'),
            position: _point,
          ),
        },
      ),
    );
  }
}
