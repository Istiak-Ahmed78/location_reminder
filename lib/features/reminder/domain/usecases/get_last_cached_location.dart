import 'package:dartz/dartz.dart';
import 'package:location_reminder/core/error/failures.dart';
import 'package:location_reminder/core/usecase/usecase.dart';
import 'package:location_reminder/features/reminder/domain/entities/user_location.dart';
import 'package:location_reminder/features/reminder/domain/repositories/location_repository.dart';

class GetLastCachedLocation
    extends UseCase<Either<Failure, UserLocation?>, NoParams> {
  final LocationRepository repository;
  GetLastCachedLocation(this.repository);
  @override
  Future<Either<Failure, UserLocation?>> call(NoParams params) {
    return repository.getLastCachedCurrentLocation();
  }
}
