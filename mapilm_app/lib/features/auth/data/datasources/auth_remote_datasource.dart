import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/network/dio_client.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDatasource {
  Future<String> sendOtp(String phone);
  Future<UserModel> verifyOtp({
    required String verificationId,
    required String otp,
  });
  Future<UserModel> setupProfile({
    required String name,
    String? bio,
    String? avatarPath,
  });
  Future<UserModel> getMe();
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  AuthRemoteDatasourceImpl(this._client);
  final DioClient _client;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;

  @override
  Future<String> sendOtp(String phone) async {
    final completer = <String>[];
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (e) {
        throw Exception(e.message ?? 'فشل إرسال الرمز');
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        completer.add(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
    if (completer.isEmpty) {
      throw Exception('لم يُرسل رمز التحقق');
    }
    return completer.first;
  }

  @override
  Future<UserModel> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    final result = await _auth.signInWithCredential(credential);
    final token = await result.user!.getIdToken();
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/verify/',
      data: {'firebase_token': token},
    );
    return UserModel.fromJson(response.data!);
  }

  @override
  Future<UserModel> setupProfile({
    required String name,
    String? bio,
    String? avatarPath,
  }) async {
    FormData formData = FormData.fromMap({
      'name': name,
      if (bio != null && bio.isNotEmpty) 'bio': bio,
      if (avatarPath != null)
        'avatar': await MultipartFile.fromFile(avatarPath),
    });
    final response = await _client.upload<Map<String, dynamic>>(
      '/users/me/setup/',
      formData,
    );
    return UserModel.fromJson(response.data!);
  }

  @override
  Future<UserModel> getMe() async {
    final response =
        await _client.get<Map<String, dynamic>>('/users/me/');
    return UserModel.fromJson(response.data!);
  }
}
