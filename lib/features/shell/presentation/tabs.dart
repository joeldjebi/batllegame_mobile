import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../activity/data/providers.dart';

/// Profil, the iOS account way: photo, name and number, then grouped rows.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final c = context.colors;
    if (user == null) {
      return const SafeArea(
        child: SignInPrompt(icon: AppIcons.profile, title: 'Ton profil', message: 'Crée ton compte en 30 secondes pour voter et participer.'),
      );
    }
    final unread = ref.watch(unreadActivityProvider);

    return ColoredBox(
      color: groupedBackground(context),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.primary,
          onRefresh: () => ref.read(sessionProvider.notifier).refresh().catchError((Object _) {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xxl),
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => context.push('/profil/modifier'),
                  child: Avatar(name: user.name, url: user.avatarUrl, size: 104),
                ),
              ),
              const SizedBox(height: Space.lg),
              Text(
                user.name,
                textAlign: TextAlign.center,
                style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              const SizedBox(height: Space.xs),
              Text(
                [user.phone, ?user.email].join(' · '),
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(color: c.textMuted),
              ),
              if (user.locationLabel != null)
                Text(
                  user.locationLabel!,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: c.textMuted),
                ),
              const SizedBox(height: Space.xxl),
              GroupedSection(
                children: [
                  GroupedTile(icon: AppIcons.edit, title: 'Infos personnelles', onTap: () => context.push('/profil/modifier')),
                  GroupedTile(icon: AppIcons.password, title: 'Connexion et sécurité', onTap: () => context.push('/auth/mot-de-passe')),
                  GroupedTile(
                    icon: user.phoneVerified ? AppIcons.done : AppIcons.unverified,
                    iconColor: user.phoneVerified ? null : c.warning,
                    title: 'Numéro de téléphone',
                    value: user.phoneVerified ? 'Vérifié' : 'À vérifier',
                    valueColor: user.phoneVerified ? null : c.warning,
                    onTap: user.phoneVerified ? null : () => context.push('/auth/verification'),
                  ),
                ],
              ),
              GroupedSection(
                children: [
                  GroupedTile(icon: AppIcons.trophy, iconColor: c.primary, title: 'Mes compétitions', onTap: () => context.go('/publier')),
                  if (user.isJudge)
                    GroupedTile(icon: AppIcons.jury, iconColor: const Color(0xFF0A84FF), title: 'Espace jury', onTap: () => context.go('/jury')),
                  GroupedTile(
                    icon: AppIcons.activity,
                    iconColor: c.like,
                    title: 'Activité',
                    value: unread > 0 ? '$unread nouveau${unread > 1 ? 'x' : ''}' : null,
                    onTap: () => context.go('/activite'),
                  ),
                ],
              ),
              GroupedSection(
                children: [
                  GroupedTile(icon: AppIcons.settings, title: 'Réglages', subtitle: 'Apparence, vidéos, cache', onTap: () => context.push('/reglages')),
                ],
              ),
              GroupedSection(
                children: [GroupedTile(title: 'Se déconnecter', destructive: true, onTap: () => ref.read(sessionProvider.notifier).logout())],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// For guests: what they get with an account, and the two ways in.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: icon,
    title: title,
    message: message,
    action: Column(
      children: [
        AppButton(label: 'Créer un compte', onPressed: () => context.push('/auth/inscription')),
        const SizedBox(height: Space.md),
        AppButton(label: 'Se connecter', variant: AppButtonVariant.secondary, onPressed: () => context.push('/auth/connexion')),
      ],
    ),
  );
}
