import '../../../../core/usecase/usecase.dart';
import '../entities/user_location.dart';
import '../repositories/location_repository.dart';

class GetCurrentLocation extends UseCase<UserLocation, NoParams> {
  final LocationRepository repository;
  GetCurrentLocation(this.repository);

  @override
  Future<UserLocation> call(NoParams params) {
    return repository.getCurrentLocation();
  }
}
