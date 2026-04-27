import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/entities/contact_entity.dart';

// ── Me (own profile) ───────────────────────────────────────────────────────

final meProvider =
    AsyncNotifierProvider<MeNotifier, Map<String, dynamic>>(MeNotifier.new);

class MeNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    final client = ref.watch(dioClientProvider);
    final res = await client.get<Map<String, dynamic>>('/users/me/');
    return res.data!;
  }

  Future<bool> updateProfile({
    String? name,
    String? bio,
    String? avatarPath,
  }) async {
    final prev = state.valueOrNull;
    state = const AsyncLoading();
    try {
      final client = ref.read(dioClientProvider);
      final formData = FormData.fromMap({
        if (name != null) 'name': name,
        if (bio != null) 'bio': bio,
        if (avatarPath != null)
          'avatar': await MultipartFile.fromFile(avatarPath),
      });
      final res = await client.putUpload<Map<String, dynamic>>(
        '/users/profile/update/',
        formData,
      );
      state = AsyncData(res.data!);
      return true;
    } catch (e) {
      state = AsyncData(prev ?? {});
      return false;
    }
  }

  Future<String?> generateInviteLink() async {
    try {
      final client = ref.read(dioClientProvider);
      final res =
          await client.post<Map<String, dynamic>>('/invite/generate/');
      return res.data?['link'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() => FirebaseAuth.instance.signOut();
}

// ── Contacts ───────────────────────────────────────────────────────────────

final contactsProvider =
    AsyncNotifierProvider<ContactsNotifier, List<ContactEntity>>(
  ContactsNotifier.new,
);

class ContactsNotifier extends AsyncNotifier<List<ContactEntity>> {
  @override
  Future<List<ContactEntity>> build() async {
    final client = ref.watch(dioClientProvider);
    final res = await client.get<List<dynamic>>('/contacts/');
    return (res.data ?? [])
        .map((e) => _map(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addContact({required String phone, String? nickname}) async {
    try {
      final client = ref.read(dioClientProvider);
      final res = await client.post<Map<String, dynamic>>(
        '/contacts/add/',
        data: {'phone': phone, if (nickname != null) 'nickname': nickname},
      );
      final contact = _map(res.data!);
      state.whenData((list) => state = AsyncData([contact, ...list]));
    } catch (_) {}
  }

  Future<void> blockUser(String userId) async {
    try {
      await ref.read(dioClientProvider).post('/contacts/block/$userId/');
      _updateBlocked(userId, blocked: true);
    } catch (_) {}
  }

  Future<void> unblockUser(String userId) async {
    try {
      await ref.read(dioClientProvider).delete('/contacts/unblock/$userId/');
      _updateBlocked(userId, blocked: false);
    } catch (_) {}
  }

  void _updateBlocked(String id, {required bool blocked}) {
    state.whenData(
      (list) => state = AsyncData(
        list
            .map((c) => c.id == id
                ? ContactEntity(
                    id: c.id,
                    phone: c.phone,
                    name: c.name,
                    avatarUrl: c.avatarUrl,
                    bio: c.bio,
                    isOnline: c.isOnline,
                    isBlocked: blocked,
                  )
                : c)
            .toList(),
      ),
    );
  }

  ContactEntity _map(Map<String, dynamic> j) => ContactEntity(
        id: j['id'] as String,
        phone: j['phone'] as String,
        name: j['name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        bio: j['bio'] as String?,
        isOnline: j['is_online'] as bool? ?? false,
        isBlocked: j['is_blocked'] as bool? ?? false,
      );
}

// ── Settings ───────────────────────────────────────────────────────────────

class SettingsState {
  const SettingsState({
    this.notifyMessages = true,
    this.notifyGroups = true,
    this.sounds = true,
    this.vibration = true,
  });
  final bool notifyMessages;
  final bool notifyGroups;
  final bool sounds;
  final bool vibration;

  SettingsState copyWith({
    bool? notifyMessages,
    bool? notifyGroups,
    bool? sounds,
    bool? vibration,
  }) =>
      SettingsState(
        notifyMessages: notifyMessages ?? this.notifyMessages,
        notifyGroups: notifyGroups ?? this.notifyGroups,
        sounds: sounds ?? this.sounds,
        vibration: vibration ?? this.vibration,
      );
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void toggle(String field) {
    state = switch (field) {
      'messages' => state.copyWith(notifyMessages: !state.notifyMessages),
      'groups' => state.copyWith(notifyGroups: !state.notifyGroups),
      'sounds' => state.copyWith(sounds: !state.sounds),
      'vibration' => state.copyWith(vibration: !state.vibration),
      _ => state,
    };
  }
}
