import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.phone,
    super.name,
    super.bio,
    super.avatarUrl,
    super.isOnline,
    super.lastSeen,
    super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: (json['id'] ?? '').toString(),
        // Backend serializer field is `phone_number`. Tolerate `phone` for
        // any older payload shape.
        phone: (json['phone_number'] ?? json['phone'] ?? '').toString(),
        name: json['name'] as String?,
        // Backend field is `status` (one-line user status). Tolerate `bio`.
        bio: (json['status'] ?? json['bio']) as String?,
        avatarUrl: json['avatar_url'] as String?,
        isOnline: json['is_online'] as bool? ?? false,
        lastSeen: json['last_seen'] != null
            ? DateTime.tryParse(json['last_seen'] as String)
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'bio': bio,
        'avatar_url': avatarUrl,
        'is_online': isOnline,
        'last_seen': lastSeen?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };
}
