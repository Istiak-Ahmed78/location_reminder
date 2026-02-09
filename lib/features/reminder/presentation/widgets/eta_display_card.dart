import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/eta_bloc.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/eta_state.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/tracking_bloc.dart';
import 'package:location_reminder/features/reminder/domain/entities/destination_reminder.dart';
import 'package:location_reminder/features/reminder/domain/entities/eta_result.dart';

class ETADisplayCard extends StatelessWidget {
  // ← Changed to StatelessWidget
  final DestinationReminder reminder;
  final VoidCallback onTap;

  const ETADisplayCard({Key? key, required this.reminder, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🎨 ETADisplayCard: build called');

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.alarm, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reminder.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 12),

                // Distance Info
                BlocBuilder<TrackingBloc, TrackingState>(
                  builder: (context, trackingState) {
                    if (trackingState.distanceMeters != null) {
                      final distance = trackingState.distanceMeters!;
                      final distanceText = distance >= 1000
                          ? '${(distance / 1000).toStringAsFixed(1)} km'
                          : '${distance.toInt()} m';

                      final gpsIcon = trackingState.isLive
                          ? Icons.gps_fixed
                          : Icons.gps_not_fixed;
                      final gpsColor = trackingState.isLive
                          ? Colors.green
                          : Colors.grey;

                      return Row(
                        children: [
                          Icon(gpsIcon, size: 14, color: gpsColor),
                          const SizedBox(width: 4),
                          Text(
                            '$distanceText away',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (!trackingState.isLive) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(cached)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      );
                    }

                    return Text(
                      'Calculating...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    );
                  },
                ),

                // ETA Display - Use BlocBuilder directly
                const SizedBox(height: 8),
                BlocBuilder<ETABloc, ETAState>(
                  // ← Use BlocBuilder directly!
                  builder: (context, etaState) {
                    print(
                      '🎨 ETADisplayCard: BlocBuilder called - eta: ${etaState.eta?.seconds}',
                    );
                    return _buildETADisplay(etaState);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildETADisplay(ETAState etaState) {
    print(
      '🎨 _buildETADisplay called - eta: ${etaState.eta?.seconds}, isActive: ${etaState.isActive}',
    );

    if (etaState.error != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: Colors.red),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              etaState.error!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
      );
    }

    if (!etaState.isActive) {
      return Text(
        'ETA calculation inactive',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (etaState.eta == null) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Calculating ETA...',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      );
    }

    // Format ETA
    final eta = etaState.eta!;
    final minutes = (eta.seconds / 60).floor();
    final seconds = eta.seconds % 60;
    final etaText = minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

    // Source icon
    IconData sourceIcon;
    Color sourceColor;
    switch (eta.source) {
      case ETASource.localGPS:
        sourceIcon = Icons.gps_fixed;
        sourceColor = Colors.blue;
        break;
      case ETASource.api:
        sourceIcon = Icons.cloud;
        sourceColor = Colors.purple;
        break;
      case ETASource.blended:
        sourceIcon = Icons.merge_type;
        sourceColor = Colors.green;
        break;
      case ETASource.cached:
        // TODO: Handle this case.
        throw UnimplementedError();
    }

    return Row(
      children: [
        Icon(sourceIcon, size: 14, color: sourceColor),
        const SizedBox(width: 4),
        Text(
          'ETA: $etaText',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        if (etaState.isFetchingAPI) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}
