import 'dart:async';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_location.dart';
import '../repositories/location_repository.dart';
import 'watch_position_params.dart';

class WatchPosition extends UseCase<Stream<UserLocation>, WatchPositionParams> {
  final LocationRepository repository;
  WatchPosition(this.repository);

  @override
  Future<Stream<UserLocation>> call(WatchPositionParams params) async {
    await repository.ensurePermission();
    return repository.watchPosition(
      distanceFilter: params.distanceFilter,
      accuracy: params.accuracy,
    );
  }
}
