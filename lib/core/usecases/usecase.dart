import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../error/failures.dart';

/// Contract every use case in the domain layer must satisfy.
///
/// [T] is the success value; [Params] is the input. Using [call] lets
/// callers treat a use case instance as a function: `await getUsers(NoParams())`.
abstract interface class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Passed to [UseCase.call] when a use case requires no input parameters.
final class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
