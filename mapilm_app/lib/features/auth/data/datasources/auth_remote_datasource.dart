import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/dio_client.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDatasource {
  // Returns the verificationId, or null when Firebase auto-verified the phone
  // (Android instant-verify): caller should skip OTP screen in that case.
  Future<String?> sendOtp(String phone);
  Future<UserModel> verifyOtp({
    required String verificationId,
    required String otp,
  });
  // Exchanges the already-signed-in Firebase user's token for a backend session.
  // Call this after instant-verify (sendOtp returned null).
  Future<UserModel> completeAutoVerify();
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
  String? _lastPhone;
  int? _resendToken;

  @override
  Future<String?> sendOtp(String phone) async {
    if (kDebugMode) {
      await _auth.setSettings(appVerificationDisabledForTesting: true);
    }

    // Reset token when switching phone numbers — resend tokens are bound to
    // their original phone number and Firebase rejects them for other numbers.
    if (phone != _lastPhone) {
      _resendToken = null;
      _lastPhone = phone;
    }

    final completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      verificationCompleted: (credential) async {
        // Android instant-verify: user is already signed in. Return null so
        // the caller knows to skip the OTP screen entirely.
        try {
          await _auth.signInWithCredential(credential);
          if (!completer.isCompleted) completer.complete(null);
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(Exception(e.toString()));
          }
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(e.message ?? 'فشل إرسال الرمز'));
        }
      },
      codeSent: (verificationId, resendToken) {
        _resendToken = resendToken;
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (_) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('انتهت مهلة التحقق'));
        }
      },
      timeout: const Duration(seconds: 60),
    );

    return completer.future;
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
  Future<UserModel> completeAutoVerify() async {
    final token = await _auth.currentUser!.getIdToken();
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
