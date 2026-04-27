import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<String, String>> sendOtp(String phone);
  Future<Either<String, UserEntity>> verifyOtp({
    required String verificationId,
    required String otp,
  });
  Future<Either<String, UserEntity>> setupProfile({
    required String name,
    String? bio,
    String? avatarPath,
  });
  Future<Either<String, UserEntity>> getCurrentUser();
  Future<void> signOut();
}
