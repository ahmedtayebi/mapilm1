import 'package:equatable/equatable.dart';

class ContactEntity extends Equatable {
  const ContactEntity({
    required this.id,
    required this.phone,
    this.name,
    this.avatarUrl,
    this.bio,
    this.isOnline = false,
    this.isBlocked = false,
  });

  final String id;
  final String phone;
  final String? name;
  final String? avatarUrl;
  final String? bio;
  final bool isOnline;
  final bool isBlocked;

  String get displayName => name ?? phone;

  @override
  List<Object?> get props =>
      [id, phone, name, avatarUrl, bio, isOnline, isBlocked];
}
