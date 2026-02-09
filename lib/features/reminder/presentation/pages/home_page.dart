import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_reminder/core/di/injection_container.dart'
    as di; // ← ADD THIS IMPORT
import 'package:location_reminder/features/reminder/domain/entities/destination_reminder.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/eta_event.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/eta_state.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/reminder_bloc.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/tracking_bloc.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/eta_bloc.dart';
import 'package:location_reminder/features/reminder/domain/entities/eta_result.dart';
import 'package:location_reminder/features/reminder/presentation/widgets/eta_display_card.dart';
import 'package:location_reminder/features/reminder/presentation/widgets/location_picker_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeView();
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late MapController _mapController;
  LatLng? _selectedLocation;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Load reminder first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderBloc>().add(const ReminderLoaded());

      // Wait a bit for reminder to load, then check
      Future.delayed(const Duration(milliseconds: 500), () {
        final reminderState = context.read<ReminderBloc>().state;
        print(
          '🚀 HomePage init: Reminder state - active: ${reminderState.active?.label}',
        );

        if (reminderState.active != null) {
          print('🚀 Starting tracking with reminder...');
          context.read<TrackingBloc>().add(const TrackingStarted());
        } else {
          print('🚀 Starting location-only tracking...');
          context.read<TrackingBloc>().add(
            const TrackingStartedForLocationOnly(),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ==================== SHOW CREATE REMINDER BOTTOM SHEET ====================
  void _showCreateReminderSheet() {
    final labelController = TextEditingController();
    final distanceController = TextEditingController(text: '100');
    LatLng? pickedLocation;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 60,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.add_alarm, color: Colors.orange, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'Set Up New Location Alert',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // Label Field
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  labelText: 'Alarm Name',
                  hintText: 'e.g., Home, Office, School',
                  prefixIcon: const Icon(Icons.label),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Location Field (Read-only, opens picker)
              InkWell(
                onTap: () async {
                  final result = await Navigator.push<LatLng>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationPickerScreen(
                        initialLocation: pickedLocation ?? _currentLocation,
                      ),
                    ),
                  );

                  if (result != null) {
                    setSheetState(() {
                      pickedLocation = result;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Location',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pickedLocation != null
                                  ? '${pickedLocation!.latitude.toStringAsFixed(4)}, ${pickedLocation!.longitude.toStringAsFixed(4)}'
                                  : 'Tap to select location',
                              style: TextStyle(
                                fontSize: 14,
                                color: pickedLocation != null
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Distance Field
              TextField(
                controller: distanceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Alert Distance (meters)',
                  hintText: 'e.g., 100',
                  prefixIcon: const Icon(Icons.notifications_active),
                  suffixText: 'm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final label = labelController.text.trim();
                    final distance = double.tryParse(distanceController.text);

                    if (label.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Please enter an alarm name'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    if (pickedLocation == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Please select a location'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    if (distance == null || distance <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Please enter a valid distance'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    _saveReminder(label, distance, pickedLocation!);
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Create Alarm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveReminder(String label, double distance, LatLng location) {
    final reminder = DestinationReminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      latitude: location.latitude,
      longitude: location.longitude,
      triggerDistanceMeters: distance,
      createdAt: DateTime.now(),
      isActive: true,
    );

    context.read<ReminderBloc>().add(ReminderSaved(reminder));
    context.read<TrackingBloc>().add(const TrackingStarted());

    if (_currentLocation != null) {
      final bounds = LatLngBounds.fromPoints([_currentLocation!, location]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
      );
    } else {
      _mapController.move(location, 15);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Alarm "$label" created and tracking started!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==================== SHOW REMINDER DETAILS ====================
  void _showReminderDetails(DestinationReminder reminder) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.alarm, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reminder.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              Icons.location_on,
              'Location',
              '${reminder.latitude.toStringAsFixed(4)}, ${reminder.longitude.toStringAsFixed(4)}',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.notifications_active,
              'Alert Distance',
              '${reminder.triggerDistanceMeters.toInt()}m',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.access_time,
              'Created',
              _formatDateTime(reminder.createdAt),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ReminderBloc>().add(const ReminderCleared());
              context.read<TrackingBloc>().add(const TrackingStopped());

              // Get ETABloc from DI instead of context.read
              final etaBloc = di.sl<ETABloc>();
              etaBloc.add(const ETACalculationStopped());

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Alarm deleted successfully'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // ==================== BUILD LOCATION MARKER ====================
  Widget _buildLocationMarker(bool isLive) {
    if (isLive) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.withOpacity(0.3),
        ),
        child: const Center(
          child: Icon(Icons.my_location, color: Colors.blue, size: 24),
        ),
      );
    } else {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromARGB(255, 149, 142, 142).withOpacity(0.3),
        ),
        child: const Center(
          child: Icon(Icons.location_searching, color: Colors.grey, size: 24),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get ETABloc from DI (SINGLETON instance)
    final etaBloc = di.sl<ETABloc>();
    print('🚨 ETABloc instance check: ${etaBloc.hashCode}');
    print(
      '🚨 ETABloc current state: isActive=${etaBloc.state.isActive}, eta=${etaBloc.state.eta?.seconds}',
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // ==================== MAP ====================
            BlocBuilder<TrackingBloc, TrackingState>(
              builder: (context, trackingState) {
                if (trackingState.current != null) {
                  _currentLocation = LatLng(
                    trackingState.current!.latitude,
                    trackingState.current!.longitude,
                  );
                }

                return BlocBuilder<ReminderBloc, ReminderState>(
                  builder: (context, reminderState) {
                    final reminder = reminderState.active;

                    return FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter:
                            _currentLocation ?? const LatLng(25.2828, 89.1077),
                        initialZoom: 13,
                        minZoom: 5,
                        maxZoom: 18,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.location_reminder',
                        ),

                        // Dotted line between current location and reminder
                        if (_currentLocation != null && reminder != null)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: [
                                  _currentLocation!,
                                  LatLng(reminder.latitude, reminder.longitude),
                                ],
                                strokeWidth: 3,
                                color: Colors.orange,
                                borderColor: Colors.white,
                                borderStrokeWidth: 1,
                                pattern: const StrokePattern.dotted(
                                  spacingFactor: 2,
                                ),
                              ),
                            ],
                          ),

                        // Current location marker
                        if (_currentLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _currentLocation!,
                                width: 40,
                                height: 40,
                                child: _buildLocationMarker(
                                  trackingState.isLive,
                                ),
                              ),
                            ],
                          ),

                        // Reminder marker
                        if (reminder != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  reminder.latitude,
                                  reminder.longitude,
                                ),
                                width: 48,
                                height: 48,
                                alignment: Alignment.topCenter,
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 48,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                );
              },
            ),

            // ==================== FLOATING REMINDER CARD ====================
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: StreamBuilder<ETAState>(
                stream: etaBloc.stream,
                initialData: etaBloc.state,
                builder: (context, snapshot) {
                  final reminderState = context.watch<ReminderBloc>().state;
                  final trackingState = context.watch<TrackingBloc>().state;
                  final etaState = snapshot.data ?? ETAState.initial();

                  final reminder = reminderState.active;

                  print(
                    '🎯 StreamBuilder: reminder=${reminder?.label}, etaState.isActive=${etaState.isActive}, eta=${etaState.eta?.seconds}',
                  );

                  if (reminder == null) {
                    return const SizedBox.shrink();
                  }

                  return ETADisplayCard(
                    key: ValueKey(
                      'eta_card_${etaState.eta?.seconds}_${etaState.isActive}_${DateTime.now().millisecondsSinceEpoch}',
                    ),
                    reminder: reminder,
                    onTap: () => _showReminderDetails(reminder),
                    distanceMeters: trackingState.distanceMeters,
                    isLive: trackingState.isLive,
                    etaState: etaState,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateReminderSheet,
        icon: const Icon(Icons.add_alarm),
        label: const Text('Create Alarm'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // ==================== FORMAT ETA FROM SECONDS ====================
  String _formatETA(int seconds) {
    if (seconds < 60) {
      return '< 1m';
    }

    final duration = Duration(seconds: seconds);

    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      return '${hours}h ${minutes}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}
