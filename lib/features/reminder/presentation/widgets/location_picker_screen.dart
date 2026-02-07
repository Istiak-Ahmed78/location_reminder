import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late MapController _mapController;
  LatLng? _currentCenter;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = widget.initialLocation ?? const LatLng(25.2828, 89.1077);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _confirmLocation() {
    // Get the exact center of the map (where the marker pin bottom is pointing)
    final center = _mapController.camera.center;
    Navigator.pop(context, center);
  }

  void _onMapMove() {
    // Update center as map moves
    setState(() {
      _currentCenter = _mapController.camera.center;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: _confirmLocation,
            tooltip: 'Confirm Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter ?? const LatLng(25.2828, 89.1077),
              initialZoom: 15,
              minZoom: 5,
              maxZoom: 18,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  _onMapMove();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.location_reminder',
              ),
            ],
          ),

          // Center Marker (Fixed) - Pin bottom points to exact location
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 48,
                  color: Colors.red,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                const SizedBox(height: 48), // Offset so pin bottom is at center
              ],
            ),
          ),

          // Crosshair at exact center (for precision)
          Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red, width: 2),
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),

          // Instructions Card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Move the map to select your location',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_currentCenter != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_currentCenter!.latitude.toStringAsFixed(6)}, ${_currentCenter!.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Confirm Button (Bottom)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: _confirmLocation,
              icon: const Icon(Icons.check_circle),
              label: const Text('Confirm Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),

          // Current Location Button
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: () {
                // Center on initial/current location
                final targetLocation =
                    widget.initialLocation ?? const LatLng(25.2828, 89.1077);
                _mapController.move(targetLocation, 15);
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
