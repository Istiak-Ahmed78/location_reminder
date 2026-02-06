import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

class WatchPositionParams extends Equatable {
  final double? distanceFilter;
  final LocationAccuracy? accuracy;

  const WatchPositionParams({this.distanceFilter, this.accuracy});

  @override
  List<Object?> get props => [distanceFilter, accuracy];
}
