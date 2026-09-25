import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/session.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verify_phone_screen.dart';
import '../../features/competitions/presentation/competition_screen.dart';
import '../../features/competitions/presentation/discover_screen.dart';
import '../../features/competitions/presentation/match_screen.dart';
import '../../features/feed/data/feed_item.dart';
import '../../features/feed/presentation/home_feed_screen.dart';
import '../../features/jury/presentation/jury_home_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shell/presentation/tabs.dart';
import '../config/env.dart';
import '../providers.dart';

/// Routes and guards. Guests browse freely (feed, competitions); an account is
/// needed for the verification, the password and the jury space. A temporary
/// password must be replaced before anything else.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Env.startRoute,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final user = session.user;
      final path = state.matchedLocation;
      final onAuth = path.startsWith('/auth');

      if (user == null) {
        const private = ['/auth/verification', '/auth/mot-de-passe', '/jury'];
        return private.any(path.startsWith) ? '/auth/connexion' : null;
      }
      if (user.mustChangePassword) return path == '/auth/mot-de-passe' ? null : '/auth/mot-de-passe';
      if (path == '/auth/connexion' || path == '/auth/inscription') return '/';
      if (path.startsWith('/jury') && !user.isJudge) return '/';
      if (onAuth && path == '/auth/verification' && user.phoneVerified) return '/';
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const HomeFeedScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/decouvrir', builder: (_, _) => const DiscoverScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/publier', builder: (_, _) => const CreateTab())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/activite', builder: (_, _) => const ActivityTab())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profil', builder: (_, _) => const ProfileTab())],
          ),
        ],
      ),
      GoRoute(path: '/auth/connexion', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/auth/inscription', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/auth/verification', builder: (_, _) => const VerifyPhoneScreen()),
      GoRoute(path: '/auth/mot-de-passe', builder: (_, _) => const ChangePasswordScreen()),
      GoRoute(path: '/jury', builder: (_, _) => const JuryHomeScreen()),
      GoRoute(path: '/competitions/:slug', builder: (_, state) => CompetitionScreen(slug: state.pathParameters['slug']!)),
      GoRoute(
        path: '/competitions/:slug/prestations',
        builder: (_, state) => CompetitionFeedScreen(slug: state.pathParameters['slug']!, title: state.uri.queryParameters['titre']),
      ),
      GoRoute(
        path: '/competitions/:slug/matchs/:id',
        builder: (_, state) => MatchScreen(slug: state.pathParameters['slug']!, id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/lecture',
        builder: (_, state) {
          final args = state.extra! as ({String key, MediaInfo media, String? title});
          return PlayerScreen(cacheKey: args.key, media: args.media, title: args.title);
        },
      ),
    ],
  );
});
