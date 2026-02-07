import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_reminder/features/reminder/domain/entities/destination_reminder.dart';
import 'package:location_reminder/features/reminder/domain/entities/user_location.dart';

class MapView extends StatelessWidget {
  final bool isLive;
  final UserLocation? currentLocation;
  final DestinationReminder? activeReminder;

  const MapView({
    super.key,
    required this.isLive,
    this.currentLocation,
    this.activeReminder,
  });

  @override
  Widget build(BuildContext context) {
    final destination = activeReminder;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: currentLocation != null
                ? LatLng(currentLocation!.latitude, currentLocation!.longitude)
                : const LatLng(23.685, 90.3563),
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.location_reminder',
            ),

            // Destination circle (if exists)
            if (destination != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(destination.latitude, destination.longitude),
                    radius: destination.triggerDistanceMeters, // ← FIXED
                    useRadiusInMeter: true,
                    color: Colors.blue.withOpacity(0.3),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),

            // Markers
            MarkerLayer(
              markers: [
                // User location marker
                if (currentLocation != null)
                  Marker(
                    point: LatLng(
                      currentLocation!.latitude,
                      currentLocation!.longitude,
                    ),
                    child: Icon(
                      Icons.my_location,
                      color: isLive ? Colors.blue : Colors.grey,
                      size: 30,
                    ),
                  ),

                // Destination marker
                if (destination != null)
                  Marker(
                    point: LatLng(destination.latitude, destination.longitude),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Status indicator
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: isLive ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  isLive ? 'Live' : 'Cached',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
