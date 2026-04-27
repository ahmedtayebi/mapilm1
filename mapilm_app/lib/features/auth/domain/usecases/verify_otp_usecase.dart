import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpUsecase {
  const VerifyOtpUsecase(this._repository);
  final AuthRepository _repository;

  Future<Either<String, UserEntity>> call({
    required String verificationId,
    required String otp,
  }) =>
      _repository.verifyOtp(
        verificationId: verificationId,
        otp: otp,
      );
}
