import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import 'app_shell.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/agenda/agenda_screen.dart';
import '../screens/shopping/shopping_screen.dart';
import '../screens/community/family_screen.dart';
import '../screens/community/family_details_screen.dart';
import '../screens/community/invitations_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/auth/forgot_password_screen.dart';

GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: auth,
    redirect: (context, state) {
      if (auth.isLoading) return null;
      final isAuth = auth.isAuthenticated;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register' || loc == '/forgot-password';
      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (ctx, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/register', builder: (ctx, _) => const RegisterScreen()),
      GoRoute(
        path: '/notifications',
        builder: (ctx, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/invitations',
        builder: (ctx, _) => const InvitationsScreen(),
      ),
      GoRoute(
        path: '/families/:id',
        builder: (ctx, state) => FamilyDetailsScreen(
          familyId: int.parse(state.pathParameters['id']!),
        ),
      ),
      // StatefulShellRoute preserves each tab's state across navigation
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (ctx, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/agenda', builder: (ctx, _) => const AgendaScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shopping',
                builder: (ctx, _) => const ShoppingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/families',
                builder: (ctx, _) => const FamilyScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/profile', builder: (ctx, _) => const ProfileScreen()),
            ],
          ),
        ],
      ),
    ],
  );
}
