// lib/features/reminder/presentation/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/notifications/notification_permission_bloc.dart';
import '../bloc/location_bloc.dart';
import '../bloc/reminder_bloc.dart';
import '../bloc/tracking_bloc.dart';
import '../widgets/map_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<LocationBloc>()),
        BlocProvider(
          create: (_) => sl<ReminderBloc>()..add(const ReminderLoaded()),
        ),
        BlocProvider(create: (_) => sl<TrackingBloc>()),
        BlocProvider(
          create: (_) =>
              sl<NotificationPermissionBloc>()
                ..add(const NotificationPermissionChecked()),
        ),
      ],
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _labelController = TextEditingController(text: 'Narayanganj');
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '200');

  @override
  void didChangeDependencies() {
    context.read<TrackingBloc>().add(const TrackingStartedForLocationOnly());
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Reminder'), centerTitle: true),
      body: Column(
        children: [
          // ==================== MAP SECTION ====================
          BlocBuilder<TrackingBloc, TrackingState>(
            buildWhen: (previous, current) {
              print(
                '🔵 [UI] buildWhen - prev: ${previous.current?.timestamp}, curr: ${current.current?.timestamp}',
              );
              print('🔵 [UI] Are they equal? ${previous == current}');
              return previous !=
                  current; // Only rebuild if states are different
            },
            builder: (context, state) {
              if (state.current == null ||
                  state.status == TrackingStatus.loading) {
                return Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              if (state.status == TrackingStatus.failure) {
                return Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: Center(
                    child: Text(
                      'Error loading map:\n${state.errorMessage}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }
              if (state.current != null) {
                return Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: MapView(
                    isLive: state.isLive,
                    currentLocation: state.current,
                    activeReminder: state.activeReminder,
                  ),
                );
              }
              return Center(
                child: Text(
                  'Unexpected state: ${state.status}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            },
          ),

          // ==================== SCROLLABLE CONTENT ====================
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // -------- Destination Form --------
                _buildSectionTitle('Set Destination'),
                const SizedBox(height: 12),
                _buildDestinationForm(),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // -------- Tracking Controls --------
                _buildSectionTitle('Live Tracking'),
                const SizedBox(height: 12),
                _buildTrackingControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildDestinationForm() {
    return Column(
      children: [
        TextField(
          controller: _labelController,
          decoration: const InputDecoration(
            labelText: 'Label',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.label),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _lngController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _radiusController,
          decoration: const InputDecoration(
            labelText: 'Radius (meters)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.radio_button_unchecked),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),

        // Save/Clear Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Validate and save reminder
                },
                icon: const Icon(Icons.save),
                label: const Text('Save Reminder'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Clear reminder
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Active Reminder Display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: const Text(
            'Active Reminder: (none)',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          // TODO: Replace with BlocBuilder<ReminderBloc, ReminderState>
        ),
      ],
    );
  }

  Widget _buildTrackingControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Start tracking
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Tracking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: null, // TODO: Enable when tracking
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Tracking Info Display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: Idle',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4),
              Text('Distance: -'),
              Text('Inside Radius: -'),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _buildReminderOrNull() {
  return const Text('No active reminder');
}
