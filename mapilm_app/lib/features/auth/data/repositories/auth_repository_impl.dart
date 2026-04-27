import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._datasource);
  final AuthRemoteDatasource _datasource;

  @override
  Future<Either<String, String>> sendOtp(String phone) async {
    try {
      final verificationId = await _datasource.sendOtp(phone);
      return Right(verificationId);
    } on FirebaseAuthException catch (e) {
      return Left(e.message ?? 'فشل إرسال رمز التحقق');
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserEntity>> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final user = await _datasource.verifyOtp(
        verificationId: verificationId,
        otp: otp,
      );
      return Right(user);
    } on FirebaseAuthException catch (e) {
      return Left(e.message ?? 'رمز التحقق غير صحيح');
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserEntity>> setupProfile({
    required String name,
    String? bio,
    String? avatarPath,
  }) async {
    try {
      final user = await _datasource.setupProfile(
        name: name,
        bio: bio,
        avatarPath: avatarPath,
      );
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserEntity>> getCurrentUser() async {
    try {
      final user = await _datasource.getMe();
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<void> signOut() => FirebaseAuth.instance.signOut();
}
