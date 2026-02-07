import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/destination_reminder.dart';
import '../../domain/entities/user_location.dart';

class MapViewV2 extends StatelessWidget {
  final UserLocation? currentLocation;
  final DestinationReminder? activeReminder;
  final LatLng? selectedLocation;
  final double triggerDistance;
  final bool isLive;
  final Function(LatLng) onMapTap;

  const MapViewV2({
    super.key,
    required this.currentLocation,
    this.activeReminder,
    this.selectedLocation,
    required this.triggerDistance,
    required this.isLive,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: currentLocation != null
            ? LatLng(currentLocation!.latitude, currentLocation!.longitude)
            : const LatLng(23.685, 90.3563),
        initialZoom: 15,
        onTap: (tapPosition, latLng) => onMapTap(latLng),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.location_reminder',
        ),

        // ==================== CIRCLES ====================
        CircleLayer(
          circles: [
            // Current location circle (alert zone) - only show when tracking
            if (currentLocation != null && activeReminder != null)
              CircleMarker(
                point: LatLng(
                  currentLocation!.latitude,
                  currentLocation!.longitude,
                ),
                radius: activeReminder!.triggerDistanceMeters,
                useRadiusInMeter: true,
                color: Colors.blue.withOpacity(0.15),
                borderColor: Colors.blue.withOpacity(0.5),
                borderStrokeWidth: 2,
              ),
          ],
        ),

        // ==================== MARKERS ====================
        MarkerLayer(
          markers: [
            // Current location marker
            if (currentLocation != null)
              Marker(
                point: LatLng(
                  currentLocation!.latitude,
                  currentLocation!.longitude,
                ),
                child: Icon(
                  Icons.my_location,
                  color: isLive ? Colors.blue : Colors.grey,
                  size: 32,
                ),
              ),

            // Active reminder marker (destination - red pin, no circle)
            if (activeReminder != null)
              Marker(
                point: LatLng(
                  activeReminder!.latitude,
                  activeReminder!.longitude,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),

            // Selected location marker (preview - green pin, no circle)
            if (selectedLocation != null && activeReminder == null)
              Marker(
                point: selectedLocation!,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.green,
                  size: 40,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
