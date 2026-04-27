import 'package:dartz/dartz.dart';
import '../repositories/auth_repository.dart';

class SendOtpUsecase {
  const SendOtpUsecase(this._repository);
  final AuthRepository _repository;

  Future<Either<String, String>> call(String phone) =>
      _repository.sendOtp(phone);
}
