import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';

class AlarmScreen extends StatelessWidget {
  final String destinationName;
  final double distance;

  const AlarmScreen({
    super.key,
    required this.destinationName,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.alarm, size: 120, color: Colors.white),
              const SizedBox(height: 24),
              Text(
                'ARRIVED AT',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                destinationName,
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '${distance.toInt()}m away',
                style: const TextStyle(fontSize: 20, color: Colors.white70),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () async {
                  await Alarm.stop(999);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'STOP ALARM',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
