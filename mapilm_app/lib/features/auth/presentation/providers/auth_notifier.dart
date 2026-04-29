import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  final datasource = AuthRemoteDatasourceImpl(client);
  return AuthRepositoryImpl(datasource);
});

final sendOtpUsecaseProvider = Provider<SendOtpUsecase>(
  (ref) => SendOtpUsecase(ref.watch(authRepositoryProvider)),
);

final verifyOtpUsecaseProvider = Provider<VerifyOtpUsecase>(
  (ref) => VerifyOtpUsecase(ref.watch(authRepositoryProvider)),
);

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    sendOtp: ref.watch(sendOtpUsecaseProvider),
    verifyOtp: ref.watch(verifyOtpUsecaseProvider),
    repository: ref.watch(authRepositoryProvider),
  );
});

// ── State ──────────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class OtpSent extends AuthState {
  const OtpSent(this.verificationId, this.phone);
  final String verificationId;
  final String phone;
}

class AuthSuccess extends AuthState {
  const AuthSuccess(this.user);
  final UserEntity user;
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

// ── Notifier ───────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required this.sendOtp,
    required this.verifyOtp,
    required this.repository,
  }) : super(const AuthInitial());

  final SendOtpUsecase sendOtp;
  final VerifyOtpUsecase verifyOtp;
  final AuthRepository repository;

  Future<void> requestOtp(String phone) async {
    state = const AuthLoading();
    final result = await sendOtp(phone);
    result.fold(
      (error) { state = AuthError(error); },
      (verificationId) {
        if (verificationId == null) {
          // Android instant-verify: already signed in, exchange token for backend session.
          _completeAutoVerify();
        } else {
          state = OtpSent(verificationId, phone);
        }
      },
    );
  }

  Future<void> _completeAutoVerify() async {
    final result = await repository.completeAutoVerify();
    result.fold(
      (error) { state = AuthError(error); },
      (user) { state = AuthSuccess(user); },
    );
  }

  Future<void> confirmOtp({
    required String verificationId,
    required String otp,
  }) async {
    state = const AuthLoading();
    final result = await verifyOtp(
      verificationId: verificationId,
      otp: otp,
    );
    result.fold(
      (error) => state = AuthError(error),
      (user) => state = AuthSuccess(user),
    );
  }

  Future<void> setupProfile({
    required String name,
    String? bio,
    String? avatarPath,
  }) async {
    state = const AuthLoading();
    final result = await repository.setupProfile(
      name: name,
      bio: bio,
      avatarPath: avatarPath,
    );
    result.fold(
      (error) => state = AuthError(error),
      (user) => state = AuthSuccess(user),
    );
  }

  Future<void> signOut() => repository.signOut();

  void reset() => state = const AuthInitial();
}
