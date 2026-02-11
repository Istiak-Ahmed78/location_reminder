import 'package:flutter/material.dart';
import 'package:location_reminder/features/reminder/domain/entities/eta_result.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/eta_state.dart';
import 'package:location_reminder/features/reminder/domain/entities/destination_reminder.dart';

class ETADisplayCard extends StatelessWidget {
  final DestinationReminder reminder;
  final VoidCallback onTap;
  final double? distanceMeters;
  final bool isLive;
  final ETAState etaState; // ← ADD THIS PARAMETER

  const ETADisplayCard({
    super.key,
    required this.reminder,
    required this.onTap,
    this.distanceMeters,
    this.isLive = false,
    required this.etaState, // ← ADD THIS
  });

  @override
  Widget build(BuildContext context) {
    print(
      '🎨 ETADisplayCard: Building with reminder "${reminder.label}", ETA: ${etaState.eta?.seconds}s, isActive: ${etaState.isActive}',
    );

    // Check if widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🖼️ ETADisplayCard rendered in frame');
    });

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              if (distanceMeters != null) ...[
                Row(
                  children: [
                    Icon(
                      isLive ? Icons.gps_fixed : Icons.gps_not_fixed,
                      size: 14,
                      color: isLive ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDistance(distanceMeters!),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!isLive) ...[
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
                ),
                const SizedBox(height: 8),
              ],

              // ETA Display
              _buildETADisplay(etaState),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km away';
    } else {
      return '${meters.toInt()} m away';
    }
  }

  Widget _buildETADisplay(ETAState etaState) {
    print(
      '🎨 ETADisplayCard: Building ETA display - eta: ${etaState.eta?.seconds}, isActive: ${etaState.isActive}',
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
    String sourceText;

    switch (eta.source) {
      case ETASource.localGPS:
        sourceIcon = Icons.gps_fixed;
        sourceColor = Colors.blue;
        sourceText = 'GPS';
        break;
      case ETASource.api:
        sourceIcon = Icons.cloud;
        sourceColor = Colors.purple;
        sourceText = 'API';
        break;
      case ETASource.blended:
        sourceIcon = Icons.merge_type;
        sourceColor = Colors.green;
        sourceText = 'Enhanced';
        break;
      case ETASource.cached:
        sourceIcon = Icons.cached;
        sourceColor = Colors.orange;
        sourceText = 'Cached';
        break;
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
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: sourceColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: sourceColor.withOpacity(0.3), width: 0.5),
          ),
          child: Text(
            sourceText,
            style: TextStyle(
              fontSize: 10,
              color: sourceColor,
              fontWeight: FontWeight.w500,
            ),
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
