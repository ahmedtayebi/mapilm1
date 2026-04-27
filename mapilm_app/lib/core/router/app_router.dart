import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/phone_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/setup_profile_screen.dart';
import '../../features/conversations/presentation/screens/home_screen.dart';
import '../../features/messages/presentation/screens/chat_screen.dart';
import '../../features/messages/presentation/screens/group_chat_screen.dart';
import '../../features/conversations/presentation/screens/create_group_screen.dart';
import '../../features/conversations/presentation/screens/group_info_screen.dart';
import '../../features/profile/presentation/screens/contacts_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../shared/providers/auth_provider.dart';

// Global router reference — used by notification handler for background navigation
GoRouter? globalRouter;

abstract final class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String phone = '/phone';
  static const String otp = '/otp';
  static const String setupProfile = '/setup-profile';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String groupChat = '/group-chat';
  static const String createGroup = '/create-group';
  static const String groupInfo = '/group-info';
  static const String contacts = '/contacts';
  static const String profile = '/profile';
  static const String settings = '/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isOnAuthRoutes = [
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.phone,
        AppRoutes.otp,
        AppRoutes.setupProfile,
      ].contains(state.fullPath);

      if (!isLoggedIn && !isOnAuthRoutes) return AppRoutes.splash;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => _slideTransition(
          state,
          const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.phone,
        name: 'phone',
        pageBuilder: (context, state) => _slideTransition(
          state,
          const PhoneScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.otp,
        name: 'otp',
        pageBuilder: (context, state) => _slideTransition(
          state,
          OtpScreen(
            phone: state.extra as String? ?? '',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.setupProfile,
        name: 'setupProfile',
        pageBuilder: (context, state) => _slideTransition(
          state,
          const SetupProfileScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const HomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        pageBuilder: (context, state) => _slideTransition(
          state,
          ChatScreen(
            args: state.extra as ChatScreenArgs,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.groupChat,
        name: 'groupChat',
        pageBuilder: (context, state) => _slideTransition(
          state,
          GroupChatScreen(
            args: state.extra as GroupChatScreenArgs,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.createGroup,
        name: 'createGroup',
        pageBuilder: (context, state) => _slideTransition(
          state,
          const CreateGroupScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.groupInfo,
        name: 'groupInfo',
        pageBuilder: (context, state) => _slideTransition(
          state,
          GroupInfoScreen(
            groupId: state.extra as String,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.contacts,
        name: 'contacts',
        pageBuilder: (context, state) => _slideTransition(
          state,
          const ContactsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        pageBuilder: (context, state) => _slideTransition(
          state,
          ProfileScreen(
            userId: state.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) => _slideTransition(
          state,
          const SettingsScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('الصفحة غير موجودة: ${state.error}'),
      ),
    ),
  );
  globalRouter = router;
  return router;
});

CustomTransitionPage<void> _fadeTransition(
  GoRouterState state,
  Widget child,
) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: child,
      ),
    );

CustomTransitionPage<void> _slideTransition(
  GoRouterState state,
  Widget child,
) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
    );
