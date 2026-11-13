import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_theme.dart';

/// Full-screen Google Map to pin a store location.
/// Pops with [LatLng] on confirm, or `null` on cancel.
class MapLocationPickerPage extends StatefulWidget {
  final LatLng? initial;
  final String title;

  const MapLocationPickerPage({
    super.key,
    this.initial,
    this.title = 'Pin store on map',
  });

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage> {
  GoogleMapController? _mapController;
  late LatLng _pin;
  bool _ready = false;
  String? _hint;

  /// Accra — default when GPS is unavailable.
  static const _fallback = LatLng(5.6037, -0.1870);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (widget.initial != null) {
      setState(() {
        _pin = widget.initial!;
        _ready = true;
        _hint = 'Drag the map or pin to set the exact store location.';
      });
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _pin = LatLng(pos.latitude, pos.longitude);
        _ready = true;
        _hint = 'Drag the map or pin to set the exact store location.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pin = _fallback;
        _ready = true;
        _hint =
            'Could not get GPS. Move the map to pin the store location, then confirm.';
      });
    }
  }

  Future<void> _goToMe() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = here);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(here, 16),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get GPS. Move the map to set your pin.'),
        ),
      );
    }
  }

  void _onCameraMove(CameraPosition position) {
    setState(() => _pin = position.target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: !_ready
          ? const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pin,
                    zoom: 16,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  onCameraMove: _onCameraMove,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  markers: {
                    Marker(
                      markerId: const MarkerId('store_pin'),
                      position: _pin,
                      draggable: true,
                      onDragEnd: (p) => setState(() => _pin = p),
                    ),
                  },
                ),
                const Center(
                  child: IgnorePointer(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 36),
                      child: Icon(
                        Icons.location_on,
                        size: 40,
                        color: Color(0x99DC2626),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 12,
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _hint ??
                            'Drag the map or pin to set the exact store location.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.ink,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: FloatingActionButton.small(
                    heroTag: 'onboard_map_me',
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    onPressed: _goToMe,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: SafeArea(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, _pin),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        'Confirm pin  (${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)})',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
