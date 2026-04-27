import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.phone,
    this.name,
    this.bio,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
  });

  final String id;
  final String phone;
  final String? name;
  final String? bio;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  bool get isProfileComplete => name != null && name!.isNotEmpty;

  UserEntity copyWith({
    String? id,
    String? phone,
    String? name,
    String? bio,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) =>
      UserEntity(
        id: id ?? this.id,
        phone: phone ?? this.phone,
        name: name ?? this.name,
        bio: bio ?? this.bio,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props =>
      [id, phone, name, bio, avatarUrl, isOnline, lastSeen, createdAt];
}
