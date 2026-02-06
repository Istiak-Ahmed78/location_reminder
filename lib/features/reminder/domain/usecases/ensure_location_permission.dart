import '../../../../core/usecase/usecase.dart';
import '../repositories/location_repository.dart';

class EnsureLocationPermission extends UseCase<void, NoParams> {
  final LocationRepository repository;
  EnsureLocationPermission(this.repository);

  @override
  Future<void> call(NoParams params) {
    return repository.ensurePermission();
  }
}
